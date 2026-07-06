//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppRouter {

    // MARK: - Navigation State

    var selectedDeviceID: UUID?
    var presentedSheet: Sheet?
    var pendingSendTextRequest: PendingSendTextRequest?

    // MARK: - Sheet Types

    enum Sheet: Identifiable {
        case deviceSetup(DeviceModel)

        var id: String {
            switch self {
            case .deviceSetup(let device):
                return "deviceSetup-\(device.id)"
            }
        }
    }

    // MARK: - Methods

    func selectDevice(_ device: DeviceModel) {
        selectedDeviceID = device.id
    }

    func deselectDevice() {
        guard selectedDeviceID != nil else { return }
        selectedDeviceID = nil
    }

    func showDeviceSetup(for device: DeviceModel) {
        presentedSheet = .deviceSetup(device)
    }

    func queueSendText(_ request: PendingSendTextRequest) {
        pendingSendTextRequest = request
    }

    func markPendingSendTextReadyForSelectedDevice() {
        guard let request = pendingSendTextRequest,
              !request.isReadyForSelectedDevice else { return }
        // Deferred to the next run loop turn so this reaction doesn't nest another write to
        // pendingSendTextRequest inside the SwiftUI update pass that's already processing the
        // change that triggered it (e.g. selecting an already-connected device synchronously
        // resolves a deep link in one pass) -- that reentrancy is what SwiftUI's "tried to
        // update multiple times per frame" warning flags.
        Task { [weak self] in
            guard let self, self.pendingSendTextRequest?.id == request.id else { return }
            self.pendingSendTextRequest = request.readyForSelectedDevice()
        }
    }

    func consumeSendTextRequest(_ request: PendingSendTextRequest) {
        guard pendingSendTextRequest?.id == request.id else { return }
        // See markPendingSendTextReadyForSelectedDevice() -- same reentrancy concern.
        Task { [weak self] in
            guard let self, self.pendingSendTextRequest?.id == request.id else { return }
            self.pendingSendTextRequest = nil
        }
    }

}

// MARK: - Environment Key

extension EnvironmentValues {
    @Entry var appRouter: AppRouter = _defaultAppRouter
    private static let _defaultAppRouter = AppRouter()
}
