//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation
import Observation
import os.log
import SwiftUI
import UIKit

/// Service for opening external URLs and system settings
@MainActor
final class URLOpener {
    private let log = Logger(subsystem: "io.clickstick", category: "URLOpener")

    // MARK: - URLs

    private let blePermissionsURL = URL(string: UIApplication.openSettingsURLString)!
    private let cameraPermissionsURL = URL(string: UIApplication.openSettingsURLString)!
    private let gettingStartedURL = URL(string: "https://clickstick.io/")!

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Opens system settings page for granting Bluetooth permission to the app.
    func openBLEPermissions() {
        open(blePermissionsURL) { [weak self] success in
            self?.log.debug("BLE permissions page opened: \(success)")
        }
    }

    /// Opens system settings page for granting Camera permission to the app.
    func openCameraPermissions() {
        open(cameraPermissionsURL) { [weak self] success in
            self?.log.debug("Camera permissions page opened: \(success)")
        }
    }

    /// Opens the online getting started guide in the default browser.
    func openGettingStartedPage() {
        open(gettingStartedURL) { [weak self] success in
            self?.log.debug("Getting started page opened: \(success)")
        }
    }

    /// Opens the app's settings page in system Settings app.
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            open(url) { [weak self] success in
                self?.log.debug("App settings opened: \(success)")
            }
        }
    }

    // MARK: - Private Methods

    private func open(_ url: URL, completion: ((Bool) -> Void)? = nil) {
        UIApplication.shared.open(url, options: [:]) { success in
            completion?(success)
        }
    }
}

// MARK: - Environment Key

private struct URLOpenerKey: EnvironmentKey {
    static let defaultValue = URLOpener()
}

extension EnvironmentValues {
    var urlOpener: URLOpener {
        get { self[URLOpenerKey.self] }
        set { self[URLOpenerKey.self] = newValue }
    }
}
