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

}

// MARK: - Environment Key

extension EnvironmentValues {
    @Entry var appRouter: AppRouter = _defaultAppRouter
    private static let _defaultAppRouter = AppRouter()
}
