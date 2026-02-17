//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation

@Observable
@MainActor
final class TextEntryViewModel {
    // MARK: - Dependencies

    private let device: TextSendingDevice
    private let premiumService: PremiumService

    // MARK: - State

    var text: String = ""
    var selectedLayout: CSKeyboardLayout = .usQWERTY
    var isSending: Bool = false
    var sendingProgress: Double?
    var alertError: AlertError?
    var showPaywallAfterSend: Bool = false

    private var sendTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var characterCount: Int { text.count }
    var isEmpty: Bool { text.isEmpty }
    var isConnected: Bool { device.isConnected }

    var canSend: Bool {
        !isEmpty && !isSending && isConnected
    }

    var isThrottled: Bool {
        if case .human = premiumService.typingSpeed(for: text.utf8.count) { return true }
        return false
    }

    var hasActiveSubscription: Bool {
        premiumService.hasActiveSubscription
    }

    var remainingBytes: Int {
        premiumService.remainingFullSpeedBytes ?? 0
    }

    var totalQuotaBytes: Int {
        premiumService.totalFullSpeedBytes ?? 0
    }

    /// Quota progress from 0.0 (empty) to 1.0 (full), for the progress bar
    var quotaProgress: Double {
        guard totalQuotaBytes > 0 else { return 0 }
        return Double(remainingBytes) / Double(totalQuotaBytes)
    }

    /// Whether to show the quota/speed indicator (hide for unlimited subscribers)
    var showsQuotaIndicator: Bool {
        !premiumService.isUnlimitedSubscription
    }

    var sendButtonTitle: String {
        if isSending {
            return String(localized: "Sending...", comment: "Sending in progress")
        }
        return isThrottled
            ? String(localized: "Send at Human Speed", comment: "Throttled send button")
            : String(localized: "Send Instantly", comment: "Full-speed send button")
    }

    var sendButtonIcon: String {
        isThrottled ? "tortoise.fill" : "bolt.fill"
    }

    var quotaStatusText: String {
        if isThrottled {
            if remainingBytes == 0 {
                return String(localized: "Human speed — no full-speed quota left", comment: "Quota indicator when no full-speed bytes are available")
            }
            return String(localized: "Human speed for this text (\(remainingBytes) bytes left)", comment: "Quota indicator when current text exceeds remaining full-speed quota")
        }
        return String(localized: "\(remainingBytes) bytes of full speed left", comment: "Quota indicator with remaining bytes")
    }

    var quotaAccessibilityLabel: String {
        if isThrottled {
            if remainingBytes == 0 {
                return String(localized: "No full-speed quota remaining. Tap to upgrade.", comment: "Quota indicator accessibility when depleted")
            }
            return String(localized: "This text will be sent at human speed. \(remainingBytes) full-speed bytes remain.", comment: "Quota indicator accessibility when text exceeds quota")
        }
        return String(localized: "\(remainingBytes) bytes of full-speed quota remaining. Tap to upgrade.", comment: "Quota indicator accessibility with remaining bytes")
    }

    var buttonAccessibilityHint: String {
        if isEmpty {
            return String(localized: "Enter text first")
        } else if !isConnected {
            return String(localized: "Device not connected", comment: "Accessibility hint")
        } else if isSending {
            return String(localized: "Please wait", comment: "Accessibility hint")
        } else {
            return String(localized: "Double-tap to send \(characterCount) characters", comment: "Accessibility hint")
        }
    }

    // MARK: - Initialization

    init(device: any TextSendingDevice, premiumService: PremiumService) {
        self.device = device
        self.premiumService = premiumService
        self.selectedLayout = CSKeyboardLayout.fromSystemLocale()
    }

    // MARK: - Actions

    func clearText() {
        text = ""
    }

    func setPreset(_ preset: TextPreset) {
        text = preset.text
    }

    func sendText() {
        guard canSend else { return }

        isSending = true
        sendingProgress = nil

        let byteCount = text.utf8.count
        let hadFullSpeedBytesBeforeSend = premiumService.hasAnyFullSpeedBytes
        let decision = premiumService.makeSendDecision(for: byteCount)

        sendTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await device.sendText(text, layout: selectedLayout, speed: decision.speed) { progress in
                    Task { @MainActor [weak self] in
                        self?.sendingProgress = progress
                    }
                }
                premiumService.recordCompletedSend(decision)

                if case .unlimited = decision.speed,
                   hadFullSpeedBytesBeforeSend,
                   !premiumService.hasActiveSubscription,
                   !premiumService.hasAnyFullSpeedBytes {
                    showPaywallAfterSend = true
                }
            } catch is CancellationError {
                // User cancelled — no quota charged, no error shown
            } catch {
                alertError = AlertError(error: error)
            }

            isSending = false
            sendingProgress = nil
            sendTask = nil
        }
    }

    func cancelSend() {
        sendTask?.cancel()
        sendTask = nil
    }
}
