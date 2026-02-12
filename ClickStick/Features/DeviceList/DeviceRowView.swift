//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI

struct DeviceRowView: View {
    let device: DeviceModel

    var body: some View {
        HStack(spacing: Spacing.sm) {
            deviceIcon
            deviceInfo
            Spacer()
            connectionStatusBadge
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Device Icon

    private var deviceIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor.opacity(0.15))
                .frame(width: 44, height: 44)

            Image(systemName: device.isDemoDevice ? "testtube.2" : "cable.connector.horizontal")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(iconColor)
        }
        .overlay(
            Circle()
                .stroke(iconColor.opacity(device.isConnected ? 0.3 : 0), lineWidth: 2)
                .scaleEffect(device.isConnecting ? 1.3 : 1.0)
                .opacity(device.isConnecting ? 0 : 1)
                .animation(
                    device.isConnecting
                        ? .easeInOut(duration: 1.0).repeatForever(autoreverses: false)
                        : .default,
                    value: device.isConnecting
                )
        )
        .accessibilityHidden(true)
    }

    private var iconColor: Color {
        if device.isConnected {
            return .clickStickGreen
        } else if device.isConnecting {
            return .clickStickBlue
        } else {
            return .secondary
        }
    }

    private var iconBackgroundColor: Color {
        if device.isConnected {
            return .clickStickGreen
        } else if device.isConnecting {
            return .clickStickBlue
        } else if device.isKnownDevice {
            return .clickStickBlue
        } else {
            return .secondary
        }
    }

    // MARK: - Device Info

    private var deviceInfo: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Text(device.displayName)
                    .font(.headline)
                    .lineLimit(1)

                if device.isKnownDevice && !device.isDemoDevice {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.clickStickOrange)
                }
            }

            Text(statusDescription)
                .font(.subheadline)
                .foregroundStyle(device.lastError != nil ? .red : .secondary)
                .lineLimit(1)
        }
    }

    /// Status description matching the demo app: error message, or connection state + RSSI
    private var statusDescription: String {
        if let error = device.lastError {
            return error.localizedDescription
        }

        var parts: [String] = []
        parts.append(device.connectionState.description)
        if device.isFresh {
            parts.append("RSSI: \(device.rssi)")
        }
        return parts.joined(separator: " • ")
    }

    // MARK: - Connection Status Badge

    private var connectionStatusBadge: some View {
        StatusBadge(status: statusBadgeState)
            .accessibilityHidden(true)
    }

    private var statusBadgeState: StatusBadge.Status {
        switch device.connectionState {
        case .disconnected:
            return .disconnected
        case .serviceDiscovery:
            return .connecting
        case .connectedUnauthorized:
            return .unauthorized
        case .connectedAuthorized:
            return .connected
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append(device.displayName)
        parts.append(statusDescription)

        if device.isDemoDevice {
            parts.append(String(localized: "Demo device", comment: "Device type"))
        } else if device.isKnownDevice {
            parts.append(String(localized: "Saved device", comment: "Device type"))
        }

        return parts.joined(separator: ", ")
    }

    private var accessibilityHint: String {
        switch device.connectionState {
        case .disconnected:
            return String(localized: "Double-tap to connect", comment: "Accessibility hint")
        case .serviceDiscovery:
            return String(localized: "Connection in progress", comment: "Accessibility hint")
        case .connectedUnauthorized:
            return String(localized: "Double-tap to authenticate", comment: "Accessibility hint")
        case .connectedAuthorized:
            return String(localized: "Double-tap to view device options", comment: "Accessibility hint")
        }
    }
}

// MARK: - Preview

#Preview {
    List {
        DeviceRowView(device: .preview)
        DeviceRowView(device: .previewDisconnected)
    }
}
