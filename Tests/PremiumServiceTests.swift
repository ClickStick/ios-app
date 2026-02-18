//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Testing
import Foundation
@testable import ClickStick

@MainActor
struct PremiumServiceTests {

    /// Creates a PremiumService backed by an ephemeral UserDefaults suite
    private func makePremiumService() -> (PremiumService, UserDefaults, String) {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        let service = PremiumService(defaults: defaults, autoSyncStoreKit: false)
        return (service, defaults, suiteName)
    }

    private func currentMonthKey() -> String {
        PremiumService.monthKey(for: .now)
    }

    private func makeSubscriptionService(
        tier: String,
        monthlyUsedBytes: Int = 0,
        oneTimeQuotaBytes: Int = 0
    ) -> (PremiumService, UserDefaults, String) {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: "premium.freeQuotaGranted")
        defaults.set(oneTimeQuotaBytes, forKey: "premium.totalQuotaBytes")
        defaults.set(0, forKey: "premium.bytesUsedAtFullSpeed")
        defaults.set(true, forKey: "premium.hasActiveSubscription")
        defaults.set(tier, forKey: "premium.subscriptionTier")
        defaults.set(monthlyUsedBytes, forKey: "premium.subscriptionBytesUsedThisMonth")
        defaults.set(currentMonthKey(), forKey: "premium.subscriptionUsageMonth")

        let service = PremiumService(defaults: defaults, autoSyncStoreKit: false)
        return (service, defaults, suiteName)
    }

    @Test
    func defaultHumanDelayIsOneSecond() {
        #expect(TypingSpeed.defaultHumanDelay == 1000)
    }

    @Test
    func freeQuotaGrantedOnFirstLaunch() {
        let (service, defaults, suiteName) = makePremiumService()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(service.totalQuotaBytes == 500)
        #expect(service.remainingBytes == 500)
        #expect(service.isPremium == true)
    }

    @Test
    func freeQuotaNotGrantedTwice() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // First launch
        let service1 = PremiumService(defaults: defaults, autoSyncStoreKit: false)
        #expect(service1.totalQuotaBytes == 500)

        // Simulate recording some bytes
        service1.recordBytesTyped(100)

        // Second launch
        let service2 = PremiumService(defaults: defaults, autoSyncStoreKit: false)
        #expect(service2.totalQuotaBytes == 500)
        #expect(service2.bytesUsedAtFullSpeed == 100)
        #expect(service2.remainingBytes == 400)
    }

    @Test
    func recordBytesDeductsFromQuota() {
        let (service, defaults, suiteName) = makePremiumService()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        service.recordBytesTyped(200)
        #expect(service.remainingBytes == 300)
        #expect(service.isPremium == true)

        service.recordBytesTyped(300)
        #expect(service.remainingBytes == 0)
        #expect(service.isPremium == false)
    }

    @Test
    func isPremiumFalseWhenQuotaExhausted() {
        let (service, defaults, suiteName) = makePremiumService()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        service.recordBytesTyped(500)
        #expect(service.isPremium == false)
        #expect(service.remainingBytes == 0)
    }

    @Test
    func typingSpeedUnlimitedWhenQuotaAvailable() {
        let (service, defaults, suiteName) = makePremiumService()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let speed = service.typingSpeed(for: 100)
        if case .unlimited = speed {
            // Expected
        } else {
            Issue.record("Expected unlimited typing speed when quota is available")
        }
    }

    @Test
    func typingSpeedHumanWhenQuotaExhausted() {
        let (service, defaults, suiteName) = makePremiumService()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        service.recordBytesTyped(500)

        let speed = service.typingSpeed(for: 100)
        if case .human = speed {
            // Expected
        } else {
            Issue.record("Expected human typing speed when quota is exhausted")
        }
    }

    @Test
    func remainingBytesNeverNegative() {
        let (service, defaults, suiteName) = makePremiumService()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Consume all 500 bytes of free quota (fits, so gets full speed)
        service.recordBytesTyped(500)
        #expect(service.remainingBytes == 0)

        // Trying to record more doesn't push remaining below zero —
        // makeSendDecision returns .human for 100 bytes (no quota left),
        // so recordCompletedSend is a no-op.
        service.recordBytesTyped(100)
        #expect(service.remainingBytes == 0)
    }

    @Test
    func statePersistsAcrossInstances() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service1 = PremiumService(defaults: defaults, autoSyncStoreKit: false)
        service1.recordBytesTyped(250)

        let service2 = PremiumService(defaults: defaults, autoSyncStoreKit: false)
        #expect(service2.bytesUsedAtFullSpeed == 250)
        #expect(service2.remainingBytes == 250)
    }

    @Test
    func smallSubscriptionUsesMonthlyQuota() {
        let (service, defaults, suiteName) = makeSubscriptionService(tier: PremiumService.subMonthlySmall)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(service.remainingSubscriptionBytesThisMonth == 10 * 1024)

        let decision = service.makeSendDecision(for: 1024)
        if case .unlimited = decision.speed {
            service.recordCompletedSend(decision)
            #expect(service.remainingSubscriptionBytesThisMonth == 9 * 1024)
        } else {
            Issue.record("Expected full speed when message fits monthly quota")
        }
    }

    @Test
    func limitedSubscriptionFallsBackToHumanForOversizedMessage() {
        let (service, defaults, suiteName) = makeSubscriptionService(
            tier: PremiumService.subMonthlySmall,
            monthlyUsedBytes: 0,
            oneTimeQuotaBytes: 0
        )
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let decision = service.makeSendDecision(for: (10 * 1024) + 1)
        if case .human = decision.speed {
            // Expected
        } else {
            Issue.record("Expected human speed for oversized message")
        }
    }

    @Test
    func limitedSubscriptionCanUseOneTimeQuotaAfterMonthlyQuotaIsSpent() {
        let (service, defaults, suiteName) = makeSubscriptionService(
            tier: PremiumService.subMonthlySmall,
            monthlyUsedBytes: 10 * 1024,
            oneTimeQuotaBytes: 500
        )
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let decision = service.makeSendDecision(for: 400)
        if case .unlimited = decision.speed {
            service.recordCompletedSend(decision)
            #expect(service.remainingBytes == 100)
            #expect(service.remainingSubscriptionBytesThisMonth == 0)
        } else {
            Issue.record("Expected one-time quota fallback when monthly quota is exhausted")
        }
    }

    @Test
    func largeSubscriptionHasFiftyKilobytesPerMonth() {
        let (service, defaults, suiteName) = makeSubscriptionService(tier: PremiumService.subMonthlyLarge)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(service.remainingSubscriptionBytesThisMonth == 50 * 1024)
    }

    @Test
    func subscriptionUsageResetsOnNewMonth() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: "premium.freeQuotaGranted")
        defaults.set(0, forKey: "premium.totalQuotaBytes")
        defaults.set(0, forKey: "premium.bytesUsedAtFullSpeed")
        defaults.set(true, forKey: "premium.hasActiveSubscription")
        defaults.set(PremiumService.subMonthlySmall, forKey: "premium.subscriptionTier")
        defaults.set(1000, forKey: "premium.subscriptionBytesUsedThisMonth")
        defaults.set("2000-01", forKey: "premium.subscriptionUsageMonth")

        let service = PremiumService(defaults: defaults, autoSyncStoreKit: false)

        // After init, resetSubscriptionUsageIfNeeded should have run,
        // so a fresh makeSendDecision should see full monthly quota
        let decision = service.makeSendDecision(for: 1)
        if case .unlimited = decision.speed {
            // Expected — monthly quota was reset
        } else {
            Issue.record("Expected full speed after monthly usage reset")
        }
        #expect(service.remainingSubscriptionBytesThisMonth == 10 * 1024)
    }

    @Test
    func oversizedOneTimeQuotaMessageUsesHumanSpeed() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: "premium.freeQuotaGranted")
        defaults.set(100, forKey: "premium.totalQuotaBytes")
        defaults.set(0, forKey: "premium.bytesUsedAtFullSpeed")
        defaults.set(false, forKey: "premium.hasActiveSubscription")

        let service = PremiumService(defaults: defaults, autoSyncStoreKit: false)
        let decision = service.makeSendDecision(for: 101)

        if case .human = decision.speed {
            // Expected
        } else {
            Issue.record("Expected human speed when message exceeds one-time quota")
        }
    }

    @Test
    func monthKeyUsesUTC() {
        // Verify the month key is deterministic regardless of local timezone
        let date = Date(timeIntervalSince1970: 0) // 1970-01-01 00:00 UTC
        let key = PremiumService.monthKey(for: date)
        #expect(key == "1970-01")
    }
}
