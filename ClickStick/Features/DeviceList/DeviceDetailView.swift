//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct DeviceDetailView: View {
    let device: DeviceModel
    @State private var selectedTab: DeviceFeatureTab = .textEntry
    @State private var alertError: AlertError?

    var body: some View {
        VStack(spacing: 0) {
            if device.isConnected {
                connectedContent
            } else if device.isConnecting {
                connectingContent
            } else {
                disconnectedContent
            }
        }
        .navigationTitle(device.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                connectionButton
            }
        }
        .errorAlert($alertError)
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidFail)) { notification in
            guard let error = notification.userInfo?["error"] as? CSError,
                  let deviceID = notification.userInfo?["deviceID"] as? UUID,
                  deviceID == device.id else { return }
            alertError = AlertError(error: error)
        }
    }

    // MARK: - Connected Content

    private var connectedContent: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "Feature"), selection: $selectedTab) {
                ForEach(availableTabs) { tab in
                    Label(tab.localizedTitle, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .accessibilityLabel("Device features")
            .accessibilityHint("Select between text entry and touchpad modes")

            Group {
                switch selectedTab {
                case .textEntry:
                    TextEntryView(device: device)
                case .mouse:
                    MouseView(device: device)
                }
            }
            .frame(maxHeight: .infinity)
            .transition(.opacity)
        }
    }

    private var availableTabs: [DeviceFeatureTab] {
        DeviceFeatureTab.allCases.filter { tab in
            device.features.contains(tab.feature)
        }
    }

    // MARK: - Connecting Content

    private var connectingContent: some View {
        ContentUnavailableView {
            ProgressView()
                .controlSize(.large)
        } description: {
            Text("Connecting to \(device.displayName)...")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting to \(device.displayName)")
    }

    // MARK: - Disconnected Content

    private var disconnectedContent: some View {
        ContentUnavailableView {
            Label(String(localized: "Disconnected", comment: "Connection status"), systemImage: "cable.connector.horizontal")
        } description: {
            if let error = device.lastError {
                Text(error.localizedDescription)
            } else {
                Text("Tap Connect to start using this device.")
            }
        } actions: {
            Button("Connect") {
                device.connect()
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Device disconnected")
        .accessibilityHint("Double-tap the connect button to reconnect")
    }

    // MARK: - Connection Button

    private var connectionButton: some View {
        Group {
            if device.isConnected {
                Button("Disconnect", role: .destructive) {
                    device.disconnect()
                }
                .accessibilityLabel("Disconnect from device")
            } else if device.isConnecting {
                Button("Cancel") {
                    device.disconnect()
                }
                .accessibilityLabel("Cancel connection")
            } else {
                Button("Connect") {
                    device.connect()
                }
                .accessibilityLabel("Connect to device")
            }
        }
    }
}

// MARK: - Preview

#Preview("Connected") {
    NavigationStack {
        DeviceDetailView(device: .preview)
    }
}

#Preview("Disconnected") {
    NavigationStack {
        DeviceDetailView(device: .previewDisconnected)
    }
}
