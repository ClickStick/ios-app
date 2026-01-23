//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct DeviceListView: View {
    @Environment(\.clickStickService) private var service
    @Environment(\.urlOpener) private var urlOpener
    @Binding var selectedDeviceID: UUID?

    @State private var deviceNeedingSetup: DeviceModel?
    @State private var alertError: AlertError?

    @AppStorage(AppStorageKey.hasShownWelcome) private var hasShownWelcome = false
    @AppStorage(AppStorageKey.hasDismissedDemoPrompt) private var hasDismissedDemoPrompt = false

    var body: some View {
        List(selection: $selectedDeviceID) {
            if hasAnnouncements {
                announcementsSection
            }
            if !service.devices.isEmpty {
                devicesSection
            }
        }
        .overlay {
            if isEmpty {
                emptyStateContent
            }
        }
        .refreshable {
            service.startScanning()
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                scanButton
            }
        }
        .sheet(item: $deviceNeedingSetup) { device in
            DeviceSetupSheet(device: device) { authKey, alias in
                saveDeviceSettings(device: device, authKey: authKey, alias: alias)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceNeedsAuthentication)) { notification in
            guard let deviceID = notification.userInfo?["deviceID"] as? UUID,
                  let device = service.device(for: deviceID) else { return }
            // Clear old settings and show setup
            try? CSDeviceSettingsManager.deleteSettings(for: device.id)
            device.refreshSettingsCache()
            deviceNeedingSetup = device
        }
        .errorAlert($alertError)
    }

    /// Returns true if there's nothing to show (no announcements and no devices)
    private var isEmpty: Bool {
        !hasAnnouncements && service.devices.isEmpty
    }

    private var hasAnnouncements: Bool {
        service.bluetoothError != nil || !hasShownWelcome || showDemoPrompt
    }

    private var showDemoPrompt: Bool {
        !hasDismissedDemoPrompt && !service.isDemoMode
    }

    @ViewBuilder
    private var announcementsSection: some View {
        Section {
            VStack(spacing: 8) {
                if let error = service.bluetoothError {
                    bluetoothErrorBanner(error)
                }
                if !hasShownWelcome {
                    welcomeBanner
                }
                if showDemoPrompt {
                    demoModeBanner
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func bluetoothErrorBanner(_ error: CSError) -> some View {
        let nsError = error as NSError
        let isPermissionError: Bool
        if case .bluetoothUnavailable(let reason) = error {
            isPermissionError = (reason == .permissionDenied)
        } else {
            isPermissionError = false
        }

        return AnnouncementBannerView(
            title: nsError.localizedDescription,
            message: nsError.localizedFailureReason,
            image: Image(.bluetooth),
            actionTitle: isPermissionError ? String(localized: "Open Settings") : nil,
            onAction: isPermissionError ? {
                urlOpener.openBLEPermissions()
            } : nil,
            onDismiss: nil
        )
    }

    private var welcomeBanner: some View {
        AnnouncementBannerView(
            title: String(localized: "Welcome!"),
            message: String(localized: "Plug in your ClickStick to get started."),
            image: Image(systemName: "hand.wave"),
            actionTitle: String(localized: "Getting Started"),
            onAction: {
                urlOpener.openGettingStartedPage()
            },
            onDismiss: {
                withAnimation { hasShownWelcome = true }
            }
        )
    }

    private var demoModeBanner: some View {
        AnnouncementBannerView(
            title: nil,
            message: String(localized: "Just looking around?"),
            image: Image(systemName: "rectangle.inset.filled.and.person.filled"),
            actionTitle: String(localized: "Try in Demo Mode"),
            onAction: {
                service.isDemoMode = true
                withAnimation { hasDismissedDemoPrompt = true }
            },
            onDismiss: {
                withAnimation { hasDismissedDemoPrompt = true }
            }
        )
    }

    @ViewBuilder
    private var devicesSection: some View {
        Section {
            ForEach(service.devices) { device in
                DeviceRowView(device: device)
                    .tag(device.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleDeviceTap(device)
                    }
                    .contextMenu {
                        deviceContextMenu(for: device)
                    }
            }
        } header: {
            Text("Devices")
        }
    }

    private var emptyStateContent: some View {
        ContentUnavailableView {
            Label(String(localized: "Welcome"), systemImage: "book")
        } description: {
            Text("Plug in your ClickStick to get started.")
        } actions: {
            Button {
                urlOpener.openGettingStartedPage()
            } label: {
                Label(String(localized: "Getting Started"), systemImage: "hand.wave")
            }
            .buttonStyle(.borderedProminent)

            Button(String(localized: "Try in Demo Mode")) {
                service.isDemoMode = true
            }
            .buttonStyle(.bordered)
        }
    }

    private var scanButton: some View {
        Button {
            if service.isScanning {
                service.stopScanning()
            } else {
                service.startScanning()
            }
        } label: {
            HStack(spacing: 8) {
                if service.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning")
                } else {
                    Image(systemName: "arrow.clockwise")
                    Text("Scan")
                }
            }
        }
        .animation(.default, value: service.isScanning)
        .accessibilityLabel(service.isScanning
            ? String(localized: "Stop scanning")
            : String(localized: "Scan for devices"))
    }

    @ViewBuilder
    private func deviceContextMenu(for device: DeviceModel) -> some View {
        Button(role: .destructive) {
            forgetDevice(device)
        } label: {
            Label(String(localized: "Forget Device"), systemImage: "trash")
        }
        .disabled(!device.isKnownDevice || device.isDemoDevice)

        if device.isConnected {
            Button {
                device.disconnect()
            } label: {
                Label(String(localized: "Disconnect"), systemImage: "cable.connector.horizontal")
            }
        }
    }

    private func forgetDevice(_ device: DeviceModel) {
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

    private func handleDeviceTap(_ device: DeviceModel) {
        switch device.connectionState {
        case .disconnected:
            // Try to connect - if auth key is missing or wrong, deviceNeedsAuthentication will be triggered
            device.connect()
        case .serviceDiscovery, .connectedAuthorized, .connectedUnauthorized:
            // Already connecting or connected - show details
            selectedDeviceID = device.id
        }
    }

    private func saveDeviceSettings(device: DeviceModel, authKey: CSAppAuthKey, alias: String?) {
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
            // Don't connect - user must dismiss error and retry
        }
    }
}

#Preview("With Announcements") {
    NavigationStack {
        DeviceListView(selectedDeviceID: .constant(nil))
    }
}

#Preview("With Devices") {
    NavigationStack {
        DeviceListView(selectedDeviceID: .constant(nil))
    }
}
