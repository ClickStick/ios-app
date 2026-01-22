//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct DeviceListView: View {
    @Environment(\.clickStickService) private var service
    @Binding var selectedDeviceID: UUID?
    @State private var showingSetupSheet = false
    @State private var deviceNeedingSetup: DeviceModel?

    var body: some View {
        List(selection: $selectedDeviceID) {
            if service.devices.isEmpty {
                emptyStateView
            } else {
                ForEach(service.devices) { device in
                    DeviceRowView(device: device)
                        .tag(device.id)
                        .onTapGesture {
                            handleDeviceTap(device)
                        }
                }
            }
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    service.isDemoMode.toggle()
                } label: {
                    Label(
                        service.isDemoMode ? "Demo Mode On" : "Demo Mode Off",
                        systemImage: service.isDemoMode ? "testtube.2" : "antenna.radiowaves.left.and.right"
                    )
                }
                .accessibilityLabel(service.isDemoMode ? "Disable demo mode" : "Enable demo mode")
            }
        }
        .refreshable {
            service.startScanning()
        }
        .sheet(item: $deviceNeedingSetup) { device in
            DeviceSetupSheet(device: device) { authKey, alias in
                saveDeviceSettings(device: device, authKey: authKey, alias: alias)
            }
        }
        .overlay {
            if let error = service.bluetoothError {
                bluetoothErrorView(error)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Devices Found", systemImage: "magnifyingglass")
        } description: {
            if service.isScanning {
                Text("Searching for ClickStick devices...")
            } else {
                Text("Pull to refresh or tap the button below to scan for devices.")
            }
        } actions: {
            if !service.isScanning {
                Button("Scan for Devices") {
                    service.startScanning()
                }
                .buttonStyle(.borderedProminent)
            } else {
                ProgressView()
            }
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Bluetooth Error

    private func bluetoothErrorView(_ error: CSError) -> some View {
        ContentUnavailableView {
            Label("Bluetooth Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func handleDeviceTap(_ device: DeviceModel) {
        if device.connectionState == .disconnected {
            // Check if device needs authentication
            if CSDeviceSettingsManager.hasSettings(for: device.id) || device.isDemoDevice {
                device.connect()
                selectedDeviceID = device.id
            } else {
                // Show setup sheet for new devices
                deviceNeedingSetup = device
            }
        } else if device.needsAuthentication {
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
            device.connect(with: authKey)
            selectedDeviceID = device.id
            deviceNeedingSetup = nil
        } catch {
            // Settings save failed, but try to connect anyway
            device.connect(with: authKey)
            selectedDeviceID = device.id
            deviceNeedingSetup = nil
        }
    }
}

