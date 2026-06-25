//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation
import Observation
import os.log
import SwiftUI
import UIKit

protocol URLOpening: Sendable {
    @MainActor func open(_ url: URL, completion: ((Bool) -> Void)?)
}

@MainActor
final class URLOpener: URLOpening {
    private let log = Logger(subsystem: "io.clickstick", category: "URLOpener")

    // MARK: - URLs

    private let appSettingsURL = URL(string: UIApplication.openSettingsURLString)!
    private let gettingStartedURL = URL(string: "https://clickstick.io/")!

    // MARK: - Initialization

    init() {}

    // MARK: - Methods

    func open(_ url: URL, completion: ((Bool) -> Void)? = nil) {
        UIApplication.shared.open(url, options: [:]) { success in
            completion?(success)
        }
    }

    func openBLEPermissions() {
        open(appSettingsURL) { [weak self] success in
            self?.log.debug("BLE permissions page opened: \(success)")
        }
    }

    func openCameraPermissions() {
        open(appSettingsURL) { [weak self] success in
            self?.log.debug("Camera permissions page opened: \(success)")
        }
    }

    func openGettingStartedPage() {
        open(gettingStartedURL) { [weak self] success in
            self?.log.debug("Getting started page opened: \(success)")
        }
    }

    func openAppSettings() {
        open(appSettingsURL) { [weak self] success in
            self?.log.debug("App settings opened: \(success)")
        }
    }
}
