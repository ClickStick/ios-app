//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct MainView: View {
    @Environment(\.clickStickService) private var service
    @Environment(\.urlOpener) private var urlOpener
    @State private var deviceListViewModel: DeviceListViewModel?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            if let viewModel = deviceListViewModel {
                DeviceListView(viewModel: viewModel)
            } else {
                ProgressView()
                    .onAppear {
                        deviceListViewModel = DeviceListViewModel(service: service, urlOpener: urlOpener)
                    }
            }
        } detail: {
            if let deviceID = deviceListViewModel?.selectedDeviceID,
               let device = service.device(for: deviceID) {
                DeviceDetailView(device: device)
            } else {
                placeholderView
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            service.startScanning()
        }
    }

    // MARK: - Placeholder View

    private var placeholderView: some View {
        ContentUnavailableView {
            Label("No Device Selected", systemImage: "cable.connector.horizontal")
        } description: {
            Text("Select a ClickStick device from the sidebar to get started.")
        } actions: {
            if service.devices.isEmpty && !service.isScanning {
                Button("Start Scanning") {
                    service.startScanning()
                }
                .buttonStyle(.borderedProminent)
            } else if service.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning for devices...")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No device selected")
        .accessibilityHint("Select a device from the sidebar")
    }
}

// MARK: - Preview

#Preview {
    MainView()
}

