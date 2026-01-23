//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Combine
import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class DeviceListViewModel {
    static let hasShownWelcome = "hasShownWelcome"
    static let hasDismissedDemoPrompt = "hasDismissedDemoPrompt"

    // MARK: - Dependencies

    private let service: ClickStickService
    private let urlOpener: URLOpener
    private var cancellables = Set<AnyCancellable>()

    // MARK: - State

    var selectedDeviceID: UUID?
    var deviceNeedingSetup: DeviceModel?
    var alertError: AlertError?

    // Stored properties that sync with UserDefaults
    var hasShownWelcome: Bool {
        didSet {
            UserDefaults.standard.set(hasShownWelcome, forKey: Self.hasShownWelcome)
        }
    }

    var hasDismissedDemoPrompt: Bool {
        didSet {
            UserDefaults.standard.set(hasDismissedDemoPrompt, forKey: Self.hasDismissedDemoPrompt)
        }
    }

    // MARK: - Computed Properties

    var devices: [DeviceModel] { service.devices }
    var isScanning: Bool { service.isScanning }
    var bluetoothError: CSError? { service.bluetoothError }

    var isEmpty: Bool {
        !hasAnnouncements && devices.isEmpty
    }

    var hasAnnouncements: Bool {
        bluetoothError != nil || !hasShownWelcome || showDemoPrompt
    }

    var showDemoPrompt: Bool {
        !hasDismissedDemoPrompt && !service.isDemoMode
    }

    // MARK: - Initialization

    init(service: ClickStickService, urlOpener: URLOpener) {
        self.service = service
        self.urlOpener = urlOpener
        // Load persisted values from UserDefaults
        self.hasShownWelcome = UserDefaults.standard.bool(forKey: Self.hasShownWelcome)
        self.hasDismissedDemoPrompt = UserDefaults.standard.bool(forKey: Self.hasDismissedDemoPrompt)
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .deviceNeedsAuthentication)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleDeviceNeedsAuthentication(notification)
            }
            .store(in: &cancellables)
    }

    private func handleDeviceNeedsAuthentication(_ notification: Notification) {
        guard let deviceID = notification.userInfo?["deviceID"] as? UUID,
              let device = service.device(for: deviceID) else { return }
        // Clear old settings and show setup
        try? CSDeviceSettingsManager.deleteSettings(for: device.id)
        device.refreshSettingsCache()
        deviceNeedingSetup = device
    }

    // MARK: - Actions

    func startScanning() {
        service.startScanning()
    }

    func stopScanning() {
        service.stopScanning()
    }

    func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }

    func dismissWelcome() {
        hasShownWelcome = true
    }

    func dismissDemoPrompt() {
        hasDismissedDemoPrompt = true
    }

    func enableDemoMode() {
        service.isDemoMode = true
        dismissDemoPrompt()
    }

    func openGettingStarted() {
        urlOpener.openGettingStartedPage()
    }

    func openBLESettings() {
        urlOpener.openBLEPermissions()
    }

    func handleDeviceTap(_ device: DeviceModel) {
        switch device.connectionState {
        case .disconnected:
            // Try to connect - if auth key is missing or wrong, deviceNeedsAuthentication will be triggered
            device.connect()
        case .serviceDiscovery, .connectedAuthorized, .connectedUnauthorized:
            // Already connecting or connected - show details
            selectedDeviceID = device.id
        }
    }

    func forgetDevice(_ device: DeviceModel) {
        do {
            try CSDeviceSettingsManager.deleteSettings(for: device.id)
            device.refreshSettingsCache()
            device.disconnect()
            if selectedDeviceID == device.id {
                selectedDeviceID = nil
            }
        } catch {
            alertError = AlertError(title: String(localized: "Error"), error: error)
        }
    }

    func saveDeviceSettings(device: DeviceModel, authKey: CSAppAuthKey, alias: String?) {
        let settings = CSDeviceSettings(
            deviceUUID: device.id,
            appAuthKey: authKey,
            deviceAlias: alias
        )
        do {
            try CSDeviceSettingsManager.saveSettings(settings)
            device.refreshSettingsCache()
            deviceNeedingSetup = nil
            // Connect after dismissing the sheet
            device.connect(with: authKey)
        } catch {
            alertError = AlertError(title: String(localized: "Settings Error"), error: error)
        }
    }

    func device(for id: UUID) -> DeviceModel? {
        service.device(for: id)
    }
}
