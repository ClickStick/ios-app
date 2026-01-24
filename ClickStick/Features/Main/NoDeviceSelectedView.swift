//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct NoDeviceSelectedView: View {
    let isScanning: Bool
    let hasDevices: Bool
    let onStartScanning: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            icon
            message
            actionContent
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No device selected")
        .accessibilityHint("Select a device from the sidebar")
    }

    private var icon: some View {
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
    }

    private var message: some View {
        VStack(spacing: Spacing.sm) {
            Text("No Device Selected")
                .font(.title2.weight(.semibold))

            Text("Select a ClickStick device from the sidebar to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
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
            .frame(width: 200)
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
