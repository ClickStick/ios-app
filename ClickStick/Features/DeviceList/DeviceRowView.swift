//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct DeviceRowView: View {
    let device: DeviceModel

    var body: some View {
        HStack(spacing: 12) {
            deviceIcon
            deviceInfo
            Spacer()
            knownDeviceIndicator
            connectionStatus
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Device Icon

    private var deviceIcon: some View {
        Image(systemName: device.isDemoDevice ? "testtube.2" : "cable.connector.horizontal")
            .font(.title2)
            .foregroundStyle(device.isConnected ? .green : .secondary)
            .frame(width: 32)
            .accessibilityHidden(true)
    }

    // MARK: - Device Info

    private var deviceInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(device.displayName)
                .font(.headline)
                .lineLimit(1)

            Text(statusDescription)
                .font(.caption)
                .foregroundStyle(device.lastError != nil ? .red : .secondary)
                .lineLimit(2)
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

    // MARK: - Known Device Indicator

    @ViewBuilder
    private var knownDeviceIndicator: some View {
        if device.isKnownDevice && !device.isDemoDevice {
            Image(systemName: device.isConnected ? "personalhotspot.circle.fill" : "personalhotspot.circle")
                .foregroundStyle(device.isConnected ? .green : .secondary)
                .font(.caption)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Connection Status

    private var connectionStatus: some View {
        Group {
            switch device.connectionState {
            case .disconnected:
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            case .serviceDiscovery:
                ProgressView()
                    .controlSize(.small)
            case .connectedUnauthorized:
                Image(systemName: "lock.fill")
                    .foregroundStyle(.orange)
            case .connectedAuthorized:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .accessibilityHidden(true)
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
