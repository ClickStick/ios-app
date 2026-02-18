//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation

/// Protocol defining the interface for a ViewModel that handles text typing
/// Used by both DeepLinkTypeSheet and ShareExtension to share UI components
@MainActor
protocol TypeTextViewModel: AnyObject, Observable {
    // MARK: - Text Properties

    /// The text to be typed
    var text: String { get }

    /// Character count for display
    var characterCount: Int { get }

    /// Display text (masked or visible based on isTextVisible)
    var displayText: String { get }

    /// Whether text is currently visible or masked
    var isTextVisible: Bool { get set }

    // MARK: - Layout

    /// Currently selected keyboard layout
    var selectedLayout: CSKeyboardLayout { get set }

    // MARK: - Device Properties

    /// Available devices (only known/paired devices)
    var devices: [DeviceModel] { get }

    /// Currently selected device ID
    var selectedDeviceID: UUID? { get set }

    /// Currently selected device
    var selectedDevice: DeviceModel? { get }

    /// Whether a device is connected and ready
    var isDeviceReady: Bool { get }

    /// Whether the device is connecting
    var isConnecting: Bool { get }

    /// Status message for the selected device
    var deviceStatusMessage: String { get }

    // MARK: - State

    /// Whether text is currently being sent
    var isSending: Bool { get }

    /// Whether we can proceed with typing
    var canType: Bool { get }

    /// Connection error message, if any
    var connectionError: String? { get }

    // MARK: - Actions

    /// Toggle text visibility
    func toggleTextVisibility()

    /// Connect to the selected device
    func connectDevice()

    /// Send the text to the device. Returns true on success.
    func sendText() async -> Bool
}

// MARK: - Default Implementations

extension TypeTextViewModel {
    var characterCount: Int { text.count }

    var displayText: String {
        isTextVisible ? text : String(repeating: "•", count: min(text.count, 20))
    }

    var selectedDevice: DeviceModel? {
        guard let id = selectedDeviceID else { return nil }
        return devices.first { $0.id == id }
    }

    var isDeviceReady: Bool {
        selectedDevice?.isConnected == true
    }

    var isConnecting: Bool {
        selectedDevice?.isConnecting == true
    }

    var canType: Bool {
        isDeviceReady && !isSending
    }

    var deviceStatusMessage: String {
        guard let device = selectedDevice else {
            return String(localized: "No device selected", comment: "Device status")
        }
        switch device.connectionState {
        case .disconnected:
            return String(localized: "Not connected", comment: "Device status")
        case .serviceDiscovery:
            return String(localized: "Connecting...", comment: "Device status")
        case .connectedUnauthorized:
            return String(localized: "Authorizing...", comment: "Device status")
        case .connectedAuthorized:
            return String(localized: "Connected", comment: "Device status")
        }
    }

    func toggleTextVisibility() {
        isTextVisible.toggle()
    }
}
