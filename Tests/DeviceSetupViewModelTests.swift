import Testing
@testable import ClickStick
import ClickStickKit
import Foundation

@MainActor
struct DeviceSetupViewModelTests {

    private static let validHex = "0102030405060708090A0B0C0D0E0F10"
    private static let invalidHex = "notahexkey"

    private func makeViewModel(
        onComplete: @escaping (CSAppAuthKey, String?) -> Bool = { _, _ in true },
        onAuthenticationFailure: @escaping () -> Void = {}
    ) -> DeviceSetupViewModel {
        DeviceSetupViewModel(
            onComplete: onComplete,
            onAuthenticationFailure: onAuthenticationFailure
        )
    }

    // MARK: - Initial State

    @Test
    func initialStateIsEmpty() {
        let viewModel = makeViewModel()

        #expect(viewModel.authKeyText.isEmpty)
        #expect(viewModel.validationError == nil)
        #expect(!viewModel.showingScanner)
        #expect(!viewModel.scannerShowsFailure)
        #expect(!viewModel.shouldDismiss)
        #expect(!viewModel.isVerifyingKey)
        #expect(!viewModel.isCancelDisabled)
        #expect(!viewModel.showsManualVerifyingSpinner)
    }

    @Test
    func isValidAuthKeyFalseForEmptyText() {
        let viewModel = makeViewModel()
        #expect(!viewModel.isValidAuthKey)
    }

    @Test
    func isValidAuthKeyTrueForValidHex() {
        let viewModel = makeViewModel()
        viewModel.authKeyText = Self.validHex
        #expect(viewModel.isValidAuthKey)
    }

    // MARK: - onAppear

    @Test
    func onAppearWithAutoScanOpensScanner() {
        let viewModel = makeViewModel()

        viewModel.onAppear(shouldAutoScan: true)

        #expect(viewModel.showingScanner)
    }

    @Test
    func onAppearWithoutAutoScanDoesNotOpenScanner() {
        let viewModel = makeViewModel()

        viewModel.onAppear(shouldAutoScan: false)

        #expect(!viewModel.showingScanner)
    }

    @Test
    func onAppearIsIdempotent() {
        let viewModel = makeViewModel()

        viewModel.onAppear(shouldAutoScan: true)
        viewModel.showingScanner = false
        viewModel.onAppear(shouldAutoScan: true)

        #expect(!viewModel.showingScanner)
    }

    // MARK: - handleScannedKey

    @Test
    func scannedValidKeyCallsOnComplete() {
        var completedKey: CSAppAuthKey?
        let viewModel = makeViewModel(onComplete: { key, _ in
            completedKey = key
            return true
        })

        viewModel.handleScannedKey(Self.validHex)

        #expect(completedKey != nil)
        #expect(viewModel.isVerifyingKey)
        #expect(viewModel.isCancelDisabled)
    }

    @Test
    func scannedInvalidKeyShowsScannerFailure() {
        let viewModel = makeViewModel()

        viewModel.handleScannedKey(Self.invalidHex)

        #expect(viewModel.scannerShowsFailure)
        #expect(!viewModel.isVerifyingKey)
    }

    @Test
    func scannedKeyWhenOnCompleteReturnsFalseShowsFailure() {
        let viewModel = makeViewModel(onComplete: { _, _ in false })

        viewModel.handleScannedKey(Self.validHex)

        #expect(viewModel.scannerShowsFailure)
        #expect(!viewModel.isVerifyingKey)
    }

    // MARK: - submitAuthKey

    @Test
    func submitWithInvalidKeyTextSetsValidationError() {
        let viewModel = makeViewModel()
        viewModel.authKeyText = Self.invalidHex

        viewModel.submitAuthKey()

        #expect(viewModel.validationError != nil)
        #expect(!viewModel.isVerifyingKey)
    }

    @Test
    func submitWithValidKeySetsAwaitingAuth() {
        let viewModel = makeViewModel()
        viewModel.authKeyText = Self.validHex

        viewModel.submitAuthKey()

        #expect(viewModel.isVerifyingKey)
        #expect(viewModel.showsManualVerifyingSpinner)
        #expect(viewModel.isCancelDisabled)
    }

    @Test
    func submitWhenOnCompleteReturnsFalseSetsValidationError() {
        let viewModel = makeViewModel(onComplete: { _, _ in false })
        viewModel.authKeyText = Self.validHex

        viewModel.submitAuthKey()

        #expect(viewModel.validationError != nil)
        #expect(!viewModel.isVerifyingKey)
    }

    // MARK: - deviceConnectionStateChanged

    @Test
    func connectedAuthorizedWhileAwaitingDismisses() {
        let viewModel = makeViewModel()
        viewModel.handleScannedKey(Self.validHex)

        viewModel.deviceConnectionStateChanged(to: .connectedAuthorized)

        #expect(viewModel.shouldDismiss)
        #expect(!viewModel.showingScanner)
        #expect(!viewModel.isVerifyingKey)
    }

    @Test
    func disconnectedWhileAwaitingFromScannerShowsFailure() {
        var failureCalled = false
        let viewModel = makeViewModel(onAuthenticationFailure: { failureCalled = true })
        viewModel.handleScannedKey(Self.validHex)

        viewModel.deviceConnectionStateChanged(to: .disconnected)

        #expect(viewModel.scannerShowsFailure)
        #expect(!viewModel.isVerifyingKey)
        #expect(failureCalled)
    }

    @Test
    func disconnectedWhileAwaitingFromManualShowsValidationError() {
        var failureCalled = false
        let viewModel = makeViewModel(onAuthenticationFailure: { failureCalled = true })
        viewModel.authKeyText = Self.validHex
        viewModel.submitAuthKey()

        viewModel.deviceConnectionStateChanged(to: .disconnected)

        #expect(viewModel.validationError != nil)
        #expect(!viewModel.isVerifyingKey)
        #expect(failureCalled)
    }

    @Test
    func connectionStateChangeIgnoredWhenNotAwaiting() {
        let viewModel = makeViewModel()

        viewModel.deviceConnectionStateChanged(to: .connectedAuthorized)

        #expect(!viewModel.shouldDismiss)
    }

    // MARK: - deviceNeedsAuthenticationChanged

    @Test
    func needsAuthWhileAwaitingReportsFailure() {
        var failureCalled = false
        let viewModel = makeViewModel(onAuthenticationFailure: { failureCalled = true })
        viewModel.handleScannedKey(Self.validHex)

        viewModel.deviceNeedsAuthenticationChanged(true)

        #expect(failureCalled)
        #expect(!viewModel.isVerifyingKey)
    }

    @Test
    func needsAuthWhenNotAwaitingIsIgnored() {
        var failureCalled = false
        let viewModel = makeViewModel(onAuthenticationFailure: { failureCalled = true })

        viewModel.deviceNeedsAuthenticationChanged(true)

        #expect(!failureCalled)
    }

    // MARK: - deviceFailedWithError

    @Test
    func deviceErrorWhileAwaitingReportsFailure() {
        var failureCalled = false
        let viewModel = makeViewModel(onAuthenticationFailure: { failureCalled = true })
        viewModel.handleScannedKey(Self.validHex)

        viewModel.deviceFailedWithError()

        #expect(failureCalled)
        #expect(!viewModel.isVerifyingKey)
    }

    // MARK: - scannerDismissed

    @Test
    func scannerDismissedWhileAwaitingFromScannerTriggersRollback() {
        var failureCalled = false
        let viewModel = makeViewModel(onAuthenticationFailure: { failureCalled = true })
        viewModel.handleScannedKey(Self.validHex)

        viewModel.scannerDismissed()

        #expect(failureCalled)
        #expect(!viewModel.isVerifyingKey)
    }

    @Test
    func scannerDismissedWhenNotAwaitingClearsScannerFailure() {
        let viewModel = makeViewModel()
        viewModel.scannerShowsFailure = true

        viewModel.scannerDismissed()

        #expect(!viewModel.scannerShowsFailure)
    }
}
