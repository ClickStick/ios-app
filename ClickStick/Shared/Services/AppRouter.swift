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
        pendingSendTextRequest = request.readyForSelectedDevice()
    }

    func consumeSendTextRequest(_ request: PendingSendTextRequest) {
        guard pendingSendTextRequest?.id == request.id else { return }
        pendingSendTextRequest = nil
    }

}

// MARK: - Environment Key

extension EnvironmentValues {
    @Entry var appRouter: AppRouter = _defaultAppRouter
    private static let _defaultAppRouter = AppRouter()
}
