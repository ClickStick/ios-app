//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log

/// ViewModel for handling deep link type requests
@Observable
@MainActor
final class DeepLinkTypeViewModel {
    private let log = Logger(subsystem: "io.clickstick", category: "DeepLinkTypeViewModel")

    // MARK: - Dependencies

    private let service: ClickStickService
    private let deepLinkHandler: DeepLinkHandler
    let request: TypeRequest

    // MARK: - State

    var selectedLayout: CSKeyboardLayout
    var selectedDeviceID: UUID?
    var isTextVisible: Bool = false
    var isSending: Bool = false
    var connectionError: String?

    // MARK: - Computed Properties

    /// Character count for accessibility
    var characterCount: Int { request.text.count }

    /// Display text (masked or visible)
    var displayText: String {
        isTextVisible ? request.text : String(repeating: "•", count: min(request.text.count, 20))
    }

    /// Available devices
    var devices: [DeviceModel] {
        service.devices.filter { $0.isKnownDevice }
    }

    /// Currently selected device
    var selectedDevice: DeviceModel? {
        guard let id = selectedDeviceID else { return nil }
        return devices.first { $0.id == id }
    }

    /// Whether a device is connected and ready
    var isDeviceReady: Bool {
        selectedDevice?.isConnected == true
    }

    /// Whether the device is connecting
    var isConnecting: Bool {
        selectedDevice?.isConnecting == true
    }

    /// Whether we can proceed with typing
    var canType: Bool {
        isDeviceReady && !isSending
    }

    /// Source app name for display - uses x-source parameter when available
    var sourceAppName: String {
        request.sourceApp ?? String(localized: "External app", comment: "Unknown source app for deep link")
    }

    /// Whether the request came from a known source app
    var hasKnownSourceApp: Bool {
        request.sourceApp != nil
    }

    /// Status message for the selected device
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

    // MARK: - Initialization

    init(request: TypeRequest, service: ClickStickService, deepLinkHandler: DeepLinkHandler) {
        self.request = request
        self.service = service
        self.deepLinkHandler = deepLinkHandler
        self.selectedLayout = request.effectiveLayout

        // Auto-select device based on request or find first connected/known device
        if let deviceIdentifier = request.deviceIdentifier {
            // Try to find by UUID first
            if let uuid = UUID(uuidString: deviceIdentifier),
               let device = devices.first(where: { $0.id == uuid }) {
                selectedDeviceID = device.id
            }
            // Try to find by alias/name
            else if let device = devices.first(where: {
                $0.displayName.localizedCaseInsensitiveCompare(deviceIdentifier) == .orderedSame
            }) {
                selectedDeviceID = device.id
            }
        }

        // If no device specified or not found, select first connected device
        if selectedDeviceID == nil {
            selectedDeviceID = devices.first { $0.isConnected }?.id
        }

        // If still none, select first known device
        if selectedDeviceID == nil {
            selectedDeviceID = devices.first?.id
        }
    }

    // MARK: - Actions

    /// Connect to the selected device
    func connectDevice() {
        guard let device = selectedDevice, !device.isConnected else { return }
        connectionError = nil
        device.connect()
    }

    /// Send the text to the device
    func sendText(completion: @escaping (Bool) -> Void) {
        guard let device = selectedDevice, canType else {
            completion(false)
            return
        }

        isSending = true
        log.info("Sending \(self.characterCount) characters via deep link")

        device.sendText(request.text, layout: selectedLayout) { [weak self] result in
            guard let self else { return }
            isSending = false

            switch result {
            case .success:
                log.info("Deep link text sent successfully")
                deepLinkHandler.callSuccessURL(for: request)
                completion(true)

            case .failure(let error):
                log.error("Deep link text failed: \(error.localizedDescription)")
                deepLinkHandler.callErrorURL(
                    for: request,
                    errorCode: .typingFailed,
                    errorMessage: error.localizedDescription
                )
                completion(false)
            }
        }
    }

    /// Cancel and call the cancel URL
    func cancel() {
        log.info("Deep link cancelled by user")
        deepLinkHandler.callCancelURL(for: request)
    }

    /// Toggle text visibility
    func toggleTextVisibility() {
        isTextVisible.toggle()
    }
}
