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
            announcementsSection
            devicesSection
        }
        .refreshable {
            service.startScanning()
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                scanButton
            }
        }
        .sheet(item: $deviceNeedingSetup) { device in
            DeviceSetupSheet(device: device) { authKey, alias in
                saveDeviceSettings(device: device, authKey: authKey, alias: alias)
            }
        }
        .errorAlert($alertError)
    }

    @ViewBuilder
    private var announcementsSection: some View {
        if hasAnnouncements {
            Section {
                VStack(spacing: 8) {
                    if let error = service.bluetoothError {
                        bluetoothErrorBanner(error)
                    }
                    if !hasShownWelcome {
                        welcomeBanner
                    }
                    if !hasDismissedDemoPrompt && !service.isDemoMode && service.devices.isEmpty {
                        demoModeBanner
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    private var hasAnnouncements: Bool {
        if service.bluetoothError != nil {
            return true
        }
        if !hasShownWelcome {
            return true
        }
        if !hasDismissedDemoPrompt && !service.isDemoMode && service.devices.isEmpty {
            return true
        }
        return false
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
            },
            onDismiss: {
                withAnimation { hasDismissedDemoPrompt = true }
            }
        )
    }

    @ViewBuilder
    private var devicesSection: some View {
        if service.devices.isEmpty {
            Section {
                emptyStateContent
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        } else {
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
            //    if !buildAnnouncements().isEmpty {
                    Text("Devices")
              //  }
            }
        }
    }

    private var emptyStateContent: some View {
        ContentUnavailableView {
            Label(String(localized: "No Devices Found"), systemImage: "magnifyingglass")
        } description: {
            if service.isScanning {
                Text("Searching for ClickStick devices...")
            } else {
                Text("Pull to refresh or tap the scan button to search for devices.")
            }
        } actions: {
            if service.isScanning {
                ProgressView()
            } else {
                Button(String(localized: "Scan for Devices")) {
                    service.startScanning()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 60)
    }

    private var scanButton: some View {
        Button {
            if service.isScanning {
                service.stopScanning()
            } else {
                service.startScanning()
            }
        } label: {
            if service.isScanning {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning")
                }
            } else {
                Label(String(localized: "Scan"), systemImage: "arrow.clockwise")
            }
        }
        .accessibilityLabel(service.isScanning
            ? String(localized: "Stop scanning")
            : String(localized: "Scan for devices"))
    }

    @ViewBuilder
    private func deviceContextMenu(for device: DeviceModel) -> some View {
        let hasSettings = CSDeviceSettingsManager.hasSettings(for: device.id)

        Button(role: .destructive) {
            forgetDevice(device)
        } label: {
            Label(String(localized: "Forget Device"), systemImage: "trash")
        }
        .disabled(!hasSettings)

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
        if device.connectionState == .disconnected {
            if CSDeviceSettingsManager.hasSettings(for: device.id) || device.isDemoDevice {
                device.connect()
                selectedDeviceID = device.id
            } else {
                deviceNeedingSetup = device
            }
        } else if device.needsAuthentication {
            do {
                try CSDeviceSettingsManager.deleteSettings(for: device.id)
            } catch {
                alertError = AlertError(title: String(localized: "Settings Error"), error: error)
                return
            }
            deviceNeedingSetup = device
        } else {
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
            device.connect(with: authKey)
            selectedDeviceID = device.id
            deviceNeedingSetup = nil
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
