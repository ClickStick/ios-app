//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Modal presented from the Devices screen ("Scan for devices" / "+").
/// Shows the looking / paused scanning states with Cancel + "Add Device" chrome.
/// When a device is discovered, the host swaps this sheet for `FoundDevicesSheet`.
struct AddDeviceScanSheet: View {
    let viewModel: DeviceListViewModel
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            DiscoveryStateBlock(isScanning: viewModel.isScanning)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.groupedBackground)
                .safeAreaInset(edge: .bottom) {
                    bottomButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }
                .navigationTitle("Add Device")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                            .accessibilityLabel("Cancel add device")
                    }
                }
        }
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private var bottomButton: some View {
        if viewModel.isScanning {
            Button("Stop") { viewModel.stopScanning() }
                .buttonStyle(AppSecondaryButtonStyle())
        } else {
            Button("Scan again") { viewModel.startScanning() }
                .buttonStyle(AppPrimaryButtonStyle())
        }
    }
}

// MARK: - Discovery state block

/// The centered radar/text block used by the scanning modal in both looking and paused states.
private struct DiscoveryStateBlock: View {
    let isScanning: Bool

    var body: some View {
        VStack(spacing: 40) {
            animation

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var animation: some View {
        if isScanning {
            BluetoothDiscoveryAnimationView(size: 184)
        } else {
            ScanRadarView(showsSweep: false, tint: .accentBlue, size: 184)
        }
    }

    private var title: LocalizedStringKey {
        isScanning ? "Looking for nearby devices..." : "Scanning paused"
    }

    private var subtitle: LocalizedStringKey {
        isScanning
            ? "Make sure your ClickStick is plugged in and Bluetooth is on"
            : "Tap Scan again to search for devices"
    }
}

// MARK: - Preview

#Preview("Add Device · Scanning") {
    AddDeviceScanSheet(
        viewModel: DeviceListViewModel(service: ClickStickService(), urlOpener: URLOpener()),
        onCancel: {}
    )
}
