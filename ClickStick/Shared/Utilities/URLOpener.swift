//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation
import Observation
import os.log
import SwiftUI
import UIKit

/// Protocol for opening URLs (mockable for testing)
protocol URLOpening: Sendable {
    @MainActor func open(_ url: URL, completion: ((Bool) -> Void)?)
}

/// Service for opening external URLs and system settings
@MainActor
final class URLOpener: URLOpening {
    private let log = Logger(subsystem: "io.clickstick", category: "URLOpener")

    // MARK: - URLs

    private let appSettingsURL = URL(string: UIApplication.openSettingsURLString)!
    private let gettingStartedURL = URL(string: "https://clickstick.io/")!

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Opens any URL
    func open(_ url: URL, completion: ((Bool) -> Void)? = nil) {
        UIApplication.shared.open(url, options: [:]) { success in
            completion?(success)
        }
    }

    /// Opens system settings page for granting Bluetooth permission to the app.
    func openBLEPermissions() {
        open(appSettingsURL) { [weak self] success in
            self?.log.debug("BLE permissions page opened: \(success)")
        }
    }

    /// Opens system settings page for granting Camera permission to the app.
    func openCameraPermissions() {
        open(appSettingsURL) { [weak self] success in
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
        open(appSettingsURL) { [weak self] success in
            self?.log.debug("App settings opened: \(success)")
        }
    }
}
