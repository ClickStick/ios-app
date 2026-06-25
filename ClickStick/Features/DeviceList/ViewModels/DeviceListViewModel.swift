//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
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

    // MARK: - State

    var alertError: AlertError?

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
    var hasSavedDevices: Bool { devices.contains { $0.isKnownDevice && !$0.isDemoDevice } }

    var connectedDevices: [DeviceModel] {
        devices.filter { $0.isConnected }
    }

    var availableDevices: [DeviceModel] {
        devices.filter { device in
            !device.isConnected && (device.isConnectable || device.isConnecting)
        }
    }

    var outOfRangeDevices: [DeviceModel] {
        devices.filter { device in
            !device.isConnected && !device.isConnecting && !device.isConnectable
        }
    }

    var isEmpty: Bool {
        !hasAnnouncements && devices.isEmpty
    }

    var hasAnnouncements: Bool {
        bluetoothError != nil || !hasShownWelcome || showDemoPrompt
    }

    var showDemoPrompt: Bool {
        !hasDismissedDemoPrompt && !service.isDemoMode
    }

    var deviceRequiringAuthentication: DeviceModel? {
        devices.first { $0.needsAuthentication }
    }

    // MARK: - Initialization

    init(service: ClickStickService, urlOpener: URLOpener) {
        self.service = service
        self.urlOpener = urlOpener
        // Load persisted values from UserDefaults
        self.hasShownWelcome = UserDefaults.standard.bool(forKey: Self.hasShownWelcome)
        self.hasDismissedDemoPrompt = UserDefaults.standard.bool(forKey: Self.hasDismissedDemoPrompt)
    }

    func prepareDeviceForSetup(_ device: DeviceModel) {
        // Clear old settings before showing setup
        try? CSDeviceSettingsManager.deleteSettings(for: device.id)
        device.refreshSettingsCache()
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
        withAnimation(.easeInOut(duration: 0.25)) {
            hasShownWelcome = true
        }
    }

    func dismissDemoPrompt() {
        withAnimation(.easeInOut(duration: 0.25)) {
            hasDismissedDemoPrompt = true
        }
    }

    func enableDemoMode() {
        withAnimation(.easeInOut(duration: 0.25)) {
            service.isDemoMode = true
            hasDismissedDemoPrompt = true
        }
    }

    func completeOnboarding(enableDemoMode: Bool) {
        withAnimation(.easeInOut(duration: 0.25)) {
            service.isDemoMode = enableDemoMode
            hasShownWelcome = true
            hasDismissedDemoPrompt = true
        }
    }

    func openGettingStarted() {
        urlOpener.openGettingStartedPage()
    }

    func openBLESettings() {
        urlOpener.openBLEPermissions()
    }

    /// Connects a device if disconnected. Returns true if the View should navigate to device detail.
    func connectDevice(_ device: DeviceModel) -> Bool {
        switch device.connectionState {
        case .disconnected:
            device.connect()
            // Navigate immediately if device is already paired (shows connecting state)
            return device.isKnownDevice
        case .serviceDiscovery, .connectedAuthorized, .connectedUnauthorized:
            // Already connecting or connected - should show details
            return true
        }
    }

    /// Forgets a device. Returns true if the device was the currently selected one.
    func forgetDevice(_ device: DeviceModel, selectedDeviceID: UUID?) -> Bool {
        do {
            try CSDeviceSettingsManager.deleteSettings(for: device.id)
            device.refreshSettingsCache()
            device.disconnect()
            service.reloadDevices()
            return selectedDeviceID == device.id
        } catch {
            alertError = AlertError(title: String(localized: "Error"), error: error)
            return false
        }
    }

    func discardDeviceSettings(for device: DeviceModel) {
        try? CSDeviceSettingsManager.deleteSettings(for: device.id)
        device.refreshSettingsCache()
        device.disconnect()
        service.reloadDevices()
    }

    func saveDeviceSettings(device: DeviceModel, authKey: CSAppAuthKey, alias: String?) -> Bool {
        let settings = CSDeviceSettings(
            deviceUUID: device.id,
            appAuthKey: authKey,
            deviceAlias: alias
        )
        do {
            try CSDeviceSettingsManager.saveSettings(settings)
            device.refreshSettingsCache()
            device.connect(with: authKey)
            return true
        } catch {
            alertError = AlertError(title: String(localized: "Settings Error"), error: error)
            return false
        }
    }

    func device(for id: UUID) -> DeviceModel? {
        service.device(for: id)
    }
}
