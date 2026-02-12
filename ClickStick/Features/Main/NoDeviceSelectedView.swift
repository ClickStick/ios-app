//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import DesignSystem
import SwiftUI

struct NoDeviceSelectedView: View {
    let isScanning: Bool
    let hasDevices: Bool
    let onStartScanning: () -> Void

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: Spacing.md) {
                FeatureIcon(systemName: "cable.connector.horizontal")
                Text("No Device Selected")
                    .font(.title2.weight(.semibold))
            }
        } description: {
            Text("Select a ClickStick device from the sidebar to get started.")
        } actions: {
            actionContent
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No device selected")
        .accessibilityHint("Select a device from the sidebar")
    }

    @ViewBuilder
    private var actionContent: some View {
        if !hasDevices && !isScanning {
            Button {
                onStartScanning()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Start Scanning")
                }
            }
            .buttonStyle(.primary)
            .padding(.horizontal, Spacing.xxl)
        } else if isScanning {
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
}

// MARK: - Previews

#Preview("No Devices") {
    NoDeviceSelectedView(
        isScanning: false,
        hasDevices: false,
        onStartScanning: {}
    )
}

#Preview("Scanning") {
    NoDeviceSelectedView(
        isScanning: true,
        hasDevices: false,
        onStartScanning: {}
    )
}

#Preview("Has Devices") {
    NoDeviceSelectedView(
        isScanning: false,
        hasDevices: true,
        onStartScanning: {}
    )
}
