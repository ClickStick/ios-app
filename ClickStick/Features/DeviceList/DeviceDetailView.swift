//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI

struct DeviceDetailView: View {
    let device: DeviceModel
    @Environment(\.premiumService) private var premiumService
    @State private var selectedTab: DeviceFeatureTab = .textEntry
    @State private var alertError: AlertError?
    @State private var rotationAngle: Double = 0

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
        .onChange(of: device.lastErrorTimestamp) { _, _ in
            if let error = device.lastError {
                alertError = AlertError(error: error)
            }
        }
    }

    // MARK: - Connected Content

    private var connectedContent: some View {
        TabView(selection: $selectedTab) {
            if availableTabs.contains(.textEntry) {
                TextEntryView(device: device, premiumService: premiumService)
                    .tabItem {
                        Label(DeviceFeatureTab.textEntry.localizedTitle,
                              systemImage: DeviceFeatureTab.textEntry.icon)
                    }
                    .tag(DeviceFeatureTab.textEntry)
            }
            if availableTabs.contains(.mouse) {
                MouseView(device: device)
                    .tabItem {
                        Label(DeviceFeatureTab.mouse.localizedTitle,
                              systemImage: DeviceFeatureTab.mouse.icon)
                    }
                    .tag(DeviceFeatureTab.mouse)
            }
        }
    }

    private var availableTabs: [DeviceFeatureTab] {
        DeviceFeatureTab.allCases.filter { tab in
            device.features.contains(tab.feature)
        }
    }

    // MARK: - Connecting Content

    private var connectingContent: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(Color.clickStickBlue.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient.clickStickGradient,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotationAngle - 90))
            }

            Image(systemName: "cable.connector.horizontal")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.clickStickBlue)

            VStack(spacing: Spacing.xs) {
                Text("Connecting...")
                    .font(.headline)
                Text(device.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting to \(device.displayName)")
    }

    // MARK: - Disconnected Content

    private var disconnectedContent: some View {
        VStack(spacing: Spacing.xl) {
            // Icon with gradient
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "cable.connector.horizontal")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: Spacing.xs) {
                Text("Disconnected")
                    .font(.title2.weight(.semibold))

                if let error = device.lastError {
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Tap Connect to start using this device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button {
                device.connect()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "bolt.fill")
                    Text("Connect")
                }
            }
            .buttonStyle(.primary)
            .frame(width: 200)
        }
        .padding(Spacing.xl)
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
