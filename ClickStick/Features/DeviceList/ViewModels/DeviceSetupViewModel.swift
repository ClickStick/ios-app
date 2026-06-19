//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation

@Observable
@MainActor
final class DeviceSetupViewModel {

    // MARK: - Exposed State

    var authKeyText: String = ""
    var validationError: String?
    var showingScanner: Bool = false
    var scannerShowsFailure: Bool = false
    var shouldDismiss: Bool = false

    // MARK: - Computed

    var isValidAuthKey: Bool {
        CSAppAuthKey.fromHexString(authKeyText) != nil
    }

    var isCancelDisabled: Bool {
        awaitingAuth
    }

    var showsManualVerifyingSpinner: Bool {
        awaitingAuth && authAttemptSource == .manual
    }

    var isVerifyingKey: Bool {
        awaitingAuth
    }

    // MARK: - Private State Machine

    private enum AuthAttemptSource {
        case scanner
        case manual
    }

    private var awaitingAuth = false
    private var authAttemptSource: AuthAttemptSource?
    private var didRequestInitialScan = false

    private let onComplete: (CSAppAuthKey, String?) -> Bool
    private let onAuthenticationFailure: () -> Void

    // MARK: - Init

    init(
        onComplete: @escaping (CSAppAuthKey, String?) -> Bool,
        onAuthenticationFailure: @escaping () -> Void = {}
    ) {
        self.onComplete = onComplete
        self.onAuthenticationFailure = onAuthenticationFailure
    }

    // MARK: - Lifecycle

    func onAppear(shouldAutoScan: Bool) {
        guard !didRequestInitialScan else { return }
        didRequestInitialScan = true
        if shouldAutoScan {
            showingScanner = true
        }
    }

    // MARK: - Actions

    func handleScannedKey(_ scannedKey: String) {
        authKeyText = scannedKey
        validationError = nil

        guard let authKey = CSAppAuthKey.fromHexString(scannedKey) else {
            scannerShowsFailure = true
            return
        }

        if onComplete(authKey, nil) {
            authAttemptSource = .scanner
            awaitingAuth = true
        } else {
            scannerShowsFailure = true
        }
    }

    func submitAuthKey() {
        guard let authKey = CSAppAuthKey.fromHexString(authKeyText) else {
            validationError = String(
                localized: "Invalid key format. Please enter a 32-character hex string.",
                comment: "Error message"
            )
            return
        }

        validationError = nil
        if onComplete(authKey, nil) {
            authAttemptSource = .manual
            awaitingAuth = true
        } else {
            validationError = String(
                localized: "Could not save device settings. Try again.",
                comment: "Device setup save failure message"
            )
        }
    }

    func scannerDismissed() {
        scannerShowsFailure = false
        // If scanner is dismissed while we're awaiting auth from a scanned key,
        // roll back the unverified key rather than leaving it persisted.
        if awaitingAuth, authAttemptSource == .scanner {
            reportAuthFailure()
        }
    }

    // MARK: - Device State Inputs (called by View's onChange handlers)

    func deviceConnectionStateChanged(to state: CSDevice.ConnectionState) {
        guard awaitingAuth else { return }
        switch state {
        case .connectedAuthorized:
            awaitingAuth = false
            authAttemptSource = nil
            showingScanner = false
            shouldDismiss = true
        case .disconnected:
            reportAuthFailure()
        default:
            break
        }
    }

    func deviceNeedsAuthenticationChanged(_ needsAuth: Bool) {
        if awaitingAuth, needsAuth {
            reportAuthFailure()
        }
    }

    func deviceFailedWithError() {
        if awaitingAuth {
            reportAuthFailure()
        }
    }

    // MARK: - Private

    private func reportAuthFailure() {
        let source = authAttemptSource
        awaitingAuth = false
        authAttemptSource = nil

        onAuthenticationFailure()

        switch source {
        case .scanner:
            scannerShowsFailure = true
        case .manual:
            validationError = String(
                localized: "Could not authenticate this device. Check the key and try again.",
                comment: "Manual authentication failure message"
            )
        case nil:
            break
        }
    }
}
