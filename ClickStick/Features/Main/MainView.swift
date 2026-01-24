//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct MainView: View {
    @Bindable var viewModel: DeviceListViewModel
    @Environment(\.appRouter) private var router
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            DeviceListView(viewModel: viewModel)
        } detail: {
            if let deviceID = router.selectedDeviceID,
               let device = viewModel.device(for: deviceID) {
                DeviceDetailView(device: device)
            } else {
                placeholderView
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.clickStickBlue)
        .sheet(item: Binding(
            get: { router.presentedSheet },
            set: { router.presentedSheet = $0 }
        )) { sheet in
            sheetContent(for: sheet)
        }
        .onAppear {
            viewModel.startScanning()
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: AppRouter.Sheet) -> some View {
        switch sheet {
        case .deviceSetup(let device):
            DeviceSetupSheet(device: device) { authKey, alias in
                if viewModel.saveDeviceSettings(device: device, authKey: authKey, alias: alias) {
                    router.dismissSheet()
                }
            }
        }
    }

    // MARK: - Placeholder View

    private var placeholderView: some View {
        VStack(spacing: Spacing.xl) {
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
                    .foregroundStyle(LinearGradient.brandGradient)
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

            if viewModel.devices.isEmpty && !viewModel.isScanning {
                Button {
                    viewModel.startScanning()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Start Scanning")
                    }
                }
                .buttonStyle(.primary)
                .frame(width: 200)
            } else if viewModel.isScanning {
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
    MainView(viewModel: DeviceListViewModel(
        service: ClickStickService(),
        urlOpener: URLOpener()
    ))
}