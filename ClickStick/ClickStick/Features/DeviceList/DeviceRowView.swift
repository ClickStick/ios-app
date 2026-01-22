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
            connectionStatus
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
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

            HStack(spacing: 4) {
                signalIndicator
                Text(signalDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Signal Indicator

    private var signalIndicator: some View {
        HStack(spacing: 1) {
            ForEach(1...4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1)
                    .fill(bar <= device.signalStrength.barsCount ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 3, height: CGFloat(bar * 3 + 3))
            }
        }
        .accessibilityHidden(true)
    }

    private var signalDescription: String {
        switch device.signalStrength {
        case .excellent: "Excellent signal"
        case .good: "Good signal"
        case .fair: "Fair signal"
        case .weak: "Weak signal"
        case .none: "No signal"
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
        parts.append(signalDescription)

        switch device.connectionState {
        case .disconnected:
            parts.append("Not connected")
        case .serviceDiscovery:
            parts.append("Connecting")
        case .connectedUnauthorized:
            parts.append("Requires authentication")
        case .connectedAuthorized:
            parts.append("Connected")
        }

        if device.isDemoDevice {
            parts.append("Demo device")
        }

        return parts.joined(separator: ", ")
    }
}

