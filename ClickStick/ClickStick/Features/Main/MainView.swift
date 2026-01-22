//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct MainView: View {
    @Environment(\.clickStickService) private var service
    @State private var selectedDeviceID: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            DeviceListView(selectedDeviceID: $selectedDeviceID)
        } detail: {
            if let deviceID = selectedDeviceID,
               let device = service.device(for: deviceID) {
                DeviceDetailView(device: device)
            } else {
                ContentUnavailableView {
                    Label("No Device Selected", systemImage: "cable.connector.horizontal")
                } description: {
                    Text("Select a ClickStick device from the sidebar to get started.")
                } actions: {
                    if service.devices.isEmpty {
                        Button("Start Scanning") {
                            service.startScanning()
                        }
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            service.startScanning()
        }
    }
}

