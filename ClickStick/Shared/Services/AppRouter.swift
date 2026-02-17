//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation
import Observation
import SwiftUI

/// Centralized navigation coordinator for the app.
/// Manages navigation state and sheet presentations to simplify ViewModels and Views.
@Observable
@MainActor
final class AppRouter {

    // MARK: - Navigation State

    /// Currently selected device ID (drives detail view in NavigationSplitView)
    var selectedDeviceID: UUID?

    /// Currently presented sheet
    var presentedSheet: Sheet?

    // MARK: - Sheet Types

    enum Sheet: Identifiable {
        case deviceSetup(DeviceModel)
        case paywall

        var id: String {
            switch self {
            case .deviceSetup(let device):
                return "deviceSetup-\(device.id)"
            case .paywall:
                return "paywall"
            }
        }
    }

    // MARK: - Navigation Actions

    func selectDevice(_ device: DeviceModel) {
        selectedDeviceID = device.id
    }

    func deselectDevice() {
        selectedDeviceID = nil
    }

    func showDeviceSetup(for device: DeviceModel) {
        presentedSheet = .deviceSetup(device)
    }

    func showPaywall() {
        presentedSheet = .paywall
    }

    func dismissSheet() {
        presentedSheet = nil
    }
}

// MARK: - Environment Key

private struct AppRouterKey: EnvironmentKey {
    @MainActor static let defaultValue = AppRouter()
}

extension EnvironmentValues {
    var appRouter: AppRouter {
        get { self[AppRouterKey.self] }
        set { self[AppRouterKey.self] = newValue }
    }
}
