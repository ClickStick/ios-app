//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import DesignSystem
import SwiftUI

/// Placeholder for the secondary pane on larger layouts.
/// The Figma discovery states belong to `DeviceListView`; this view intentionally stays neutral.
struct NoDeviceSelectedView: View {
    let isScanning: Bool
    let hasDevices: Bool
    let onStartScanning: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            FeatureIcon(
                systemName: "cable.connector.horizontal",
                size: 96,
                iconSize: IconSize.large,
                tint: .clickStickBlue
            )

            VStack(spacing: Spacing.xs) {
                Text("No Device Selected")
                    .font(.clickStickTitle)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.clickStickBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            if !hasDevices && !isScanning {
                Button("Scan for devices") {
                    onStartScanning()
                }
                .buttonStyle(.primary)
                .frame(maxWidth: 320)
                .padding(.top, Spacing.sm)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clickStickScreenBackground()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No device selected")
        .accessibilityHint(accessibilityHint)
    }

    private var message: String {
        if hasDevices {
            return String(localized: "Select a ClickStick from the device list.")
        }
        if isScanning {
            return String(localized: "Looking for nearby ClickSticks in the device list.")
        }
        return String(localized: "Scan for a ClickStick from the device list to get started.")
    }

    private var accessibilityHint: String {
        hasDevices
            ? String(localized: "Select a device from the sidebar")
            : String(localized: "Use Scan for devices to search for nearby ClickSticks")
    }
}

// MARK: - Previews

#Preview {
    NoDeviceSelectedView(
        isScanning: false,
        hasDevices: true,
        onStartScanning: {}
    )
}
