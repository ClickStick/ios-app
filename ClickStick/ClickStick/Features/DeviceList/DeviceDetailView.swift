//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct DeviceDetailView: View {
    let device: DeviceModel
    @State private var selectedTab: DeviceFeatureTab = .textEntry

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
    }

    // MARK: - Connected Content

    private var connectedContent: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Feature", selection: $selectedTab) {
                ForEach(availableTabs) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            Group {
                switch selectedTab {
                case .textEntry:
                    TextEntryView(device: device)
                case .mouse:
                    MouseView(device: device)
                }
            }
            .frame(maxHeight: .infinity)
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
    }

    // MARK: - Disconnected Content

    private var disconnectedContent: some View {
        ContentUnavailableView {
            Label("Disconnected", systemImage: "cable.connector.horizontal")
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
    }

    // MARK: - Connection Button

    private var connectionButton: some View {
        Group {
            if device.isConnected {
                Button("Disconnect", role: .destructive) {
                    device.disconnect()
                }
            } else if device.isConnecting {
                Button("Cancel") {
                    device.disconnect()
                }
            } else {
                Button("Connect") {
                    device.connect()
                }
            }
        }
    }
}

