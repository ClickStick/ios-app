//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation

@Observable
@MainActor
final class TextEntryViewModel {
    // MARK: - Dependencies

    private let device: DeviceModel

    // MARK: - State

    var text: String = ""
    var selectedLayout: CSKeyboardLayout = .usQWERTY
    var isSending: Bool = false
    var alertError: AlertError?

    // MARK: - Computed Properties

    var characterCount: Int { text.count }
    var isEmpty: Bool { text.isEmpty }
    var isConnected: Bool { device.isConnected }

    var canSend: Bool {
        !isEmpty && !isSending && isConnected
    }

    var sendButtonTitle: String {
        isSending
            ? String(localized: "Sending...", comment: "Sending in progress")
            : String(localized: "Send Text")
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

    init(device: DeviceModel) {
        self.device = device
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

        device.sendText(text, layout: selectedLayout) { [weak self] result in
            guard let self else { return }
            isSending = false
            switch result {
            case .success:
                // Text sent successfully
                break
            case .failure(let error):
                alertError = AlertError(error: error)
            }
        }
    }
}
