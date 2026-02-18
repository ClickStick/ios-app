//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Testing
@testable import ClickStick

@MainActor
struct TextEntryViewModelPremiumIntegrationTests {

    @MainActor
    private final class MockTextDevice: TextSendingDevice {
        enum MockError: Error {
            case sendFailed
        }

        var isConnected: Bool = true
        var shouldFailSend: Bool = false
        private(set) var lastSpeed: TypingSpeed?
        private(set) var sendCallCount: Int = 0

        func sendText(
            _ text: String,
            layout: CSKeyboardLayout,
            speed: TypingSpeed,
            onProgress: (@Sendable (Double) -> Void)?
        ) async throws {
            sendCallCount += 1
            lastSpeed = speed
            if shouldFailSend {
                throw MockError.sendFailed
            }
            onProgress?(1.0)
        }
    }

    private func currentMonthKey() -> String {
        PremiumService.monthKey(for: .now)
    }

    private func makePremiumService(
        hasSubscription: Bool = false,
        tier: String? = nil,
        monthlyUsedBytes: Int = 0,
        oneTimeQuotaBytes: Int = 0,
        oneTimeUsedBytes: Int = 0
    ) -> (PremiumService, UserDefaults, String) {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: "premium.freeQuotaGranted")
        defaults.set(oneTimeQuotaBytes, forKey: "premium.totalQuotaBytes")
        defaults.set(oneTimeUsedBytes, forKey: "premium.bytesUsedAtFullSpeed")
        defaults.set(hasSubscription, forKey: "premium.hasActiveSubscription")
        defaults.set(tier, forKey: "premium.subscriptionTier")
        defaults.set(monthlyUsedBytes, forKey: "premium.subscriptionBytesUsedThisMonth")
        defaults.set(currentMonthKey(), forKey: "premium.subscriptionUsageMonth")

        let service = PremiumService(defaults: defaults, autoSyncStoreKit: false)
        return (service, defaults, suiteName)
    }

    @Test
    func sendUsesHumanSpeedWhenSmallTierMessageExceedsMonthlyRemaining() async {
        let smallLimit = 10 * 1024
        let (premiumService, defaults, suiteName) = makePremiumService(
            hasSubscription: true,
            tier: PremiumService.subMonthlySmall,
            monthlyUsedBytes: smallLimit - 5
        )
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let device = MockTextDevice()
        let viewModel = TextEntryViewModel(device: device, premiumService: premiumService)
        viewModel.text = "1234567890" // 10 bytes, exceeds remaining 5

        await fulfillSendTask(viewModel)

        if case .human = device.lastSpeed {
            #expect(premiumService.remainingSubscriptionBytesThisMonth == 5)
        } else {
            Issue.record("Expected human speed for oversized message")
        }
    }

    @Test
    func sendDeductsFromSmallTierMonthlyQuotaWhenMessageFits() async {
        let (premiumService, defaults, suiteName) = makePremiumService(
            hasSubscription: true,
            tier: PremiumService.subMonthlySmall,
            monthlyUsedBytes: 0
        )
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let device = MockTextDevice()
        let viewModel = TextEntryViewModel(device: device, premiumService: premiumService)
        viewModel.text = String(repeating: "a", count: 100)

        await fulfillSendTask(viewModel)

        if case .unlimited = device.lastSpeed {
            #expect(premiumService.remainingSubscriptionBytesThisMonth == (10 * 1024) - 100)
        } else {
            Issue.record("Expected full speed for fitting message")
        }
    }

    @Test
    func sendFallsBackToOneTimeQuotaWhenMonthlyQuotaIsExhausted() async {
        let (premiumService, defaults, suiteName) = makePremiumService(
            hasSubscription: true,
            tier: PremiumService.subMonthlySmall,
            monthlyUsedBytes: 10 * 1024,
            oneTimeQuotaBytes: 500
        )
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let device = MockTextDevice()
        let viewModel = TextEntryViewModel(device: device, premiumService: premiumService)
        viewModel.text = String(repeating: "b", count: 200)

        await fulfillSendTask(viewModel)

        if case .unlimited = device.lastSpeed {
            #expect(premiumService.remainingSubscriptionBytesThisMonth == 0)
            #expect(premiumService.remainingBytes == 300)
        } else {
            Issue.record("Expected one-time quota fallback at full speed")
        }
    }

    @Test
    func sendShowsPaywallAfterUsingLastOneTimeQuotaWithoutSubscription() async {
        let (premiumService, defaults, suiteName) = makePremiumService(
            hasSubscription: false,
            oneTimeQuotaBytes: 100,
            oneTimeUsedBytes: 0
        )
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let device = MockTextDevice()
        let viewModel = TextEntryViewModel(device: device, premiumService: premiumService)
        viewModel.text = String(repeating: "x", count: 100)

        await fulfillSendTask(viewModel)

        #expect(viewModel.showPaywallAfterSend)
        #expect(premiumService.remainingBytes == 0)
    }

    @Test
    func failedSendDoesNotConsumeAnyQuota() async {
        let (premiumService, defaults, suiteName) = makePremiumService(
            hasSubscription: false,
            oneTimeQuotaBytes: 500
        )
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let device = MockTextDevice()
        device.shouldFailSend = true
        let viewModel = TextEntryViewModel(device: device, premiumService: premiumService)
        viewModel.text = String(repeating: "z", count: 200)

        await fulfillSendTask(viewModel)

        #expect(premiumService.remainingBytes == 500)
        #expect(viewModel.alertError != nil)
        #expect(!viewModel.showPaywallAfterSend)
    }

    @Test
    func noQuotaHumanSpeedSendDoesNotAutoShowPaywall() async {
        let (premiumService, defaults, suiteName) = makePremiumService(
            hasSubscription: false,
            oneTimeQuotaBytes: 100,
            oneTimeUsedBytes: 100
        )
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let device = MockTextDevice()
        let viewModel = TextEntryViewModel(device: device, premiumService: premiumService)
        viewModel.text = "hello"

        await fulfillSendTask(viewModel)

        if case .human = device.lastSpeed {
            #expect(!viewModel.showPaywallAfterSend)
            #expect(premiumService.remainingBytes == 0)
        } else {
            Issue.record("Expected human speed when quota is exhausted")
        }
    }

    // MARK: - Helpers

    /// Triggers sendText() and waits for the internal Task to complete.
    private func fulfillSendTask(_ viewModel: TextEntryViewModel) async {
        viewModel.sendText()
        // Yield to let the spawned Task run to completion
        while viewModel.isSending {
            await Task.yield()
        }
    }
}
