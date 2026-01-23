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
        .tint(.clickStickBlue)
        .onAppear {
            service.startScanning()
        }
    }

    // MARK: - Placeholder View

    private var placeholderView: some View {
        VStack(spacing: Spacing.xl) {
            // Animated device icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clickStickBlue.opacity(0.15), Color.clickStickTeal.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "cable.connector.horizontal")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient.brandGradient
                    )
            }
            
            VStack(spacing: Spacing.sm) {
                Text("No Device Selected")
                    .font(.title2.weight(.semibold))
                
                Text("Select a ClickStick device from the sidebar to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            
            if service.devices.isEmpty && !service.isScanning {
                Button {
                    service.startScanning()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Start Scanning")
                    }
                }
                .buttonStyle(.primary)
                .frame(width: 200)
            } else if service.isScanning {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning for devices...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(Color.clickStickBlue.opacity(0.1))
                )
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