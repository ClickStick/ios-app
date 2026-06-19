//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct DeviceRowView: View {
    let device: DeviceModel
    var isSelected: Bool = false
    var showsMenuIndicator: Bool = true

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(device.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(device.isCompromised ? Color(.systemRed) : .primary)
                        .lineLimit(1)

                    if device.isCompromised {
                        Image(systemName: "exclamationmark.circle")
                            .font(.body)
                            .foregroundStyle(Color(.systemRed))
                            .accessibilityHidden(true)
                    }
                }

                statusLine
            }

            Spacer(minLength: 12)

            if !isOutOfRange && !device.isCompromised {
                SignalBarsView(
                    strength: normalizedSignalStrength,
                    activeColor: signalColor
                )
                .frame(width: 24)
            }

            Group {
                if showsMenuIndicator {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                } else {
                    Color.clear
                }
            }
            .frame(width: 24)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 78)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(cardBorderColor ?? .clear, lineWidth: cardBorderColor == nil ? 0 : (device.isCompromised ? 1.5 : 0.5))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(accessibilityHint)
    }

    private var statusLine: some View {
        HStack(spacing: 4) {
            Text(statusDescription)
                .font(.body)
                .foregroundStyle(statusColor)
                .lineLimit(1)

            if device.isConnected && !device.isCompromised {
                Circle()
                    .fill(Color(.systemGreen))
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
        }
    }

    private var statusColor: Color {
        (device.isCompromised || device.lastError != nil) ? Color(.systemRed) : Color.secondary
    }

    private var cardBackground: Color {
        if isSelected {
            return Color.accentBlue.opacity(0.12)
        }
        return Color.cardBackground
    }

    private var cardBorderColor: Color? {
        if device.isCompromised {
            return Color(.systemRed)
        }
        if isSelected {
            return Color.accentBlue.opacity(0.2)
        }
        return nil
    }

    /// Status description matching the redesigned device list.
    private var statusDescription: String {
        if device.isCompromised {
            return String(localized: "Security warning", comment: "Compromised device status")
        }

        if let error = device.lastError {
            return error.localizedDescription
        }

        switch device.connectionState {
        case .connectedAuthorized:
            return String(localized: "Connected", comment: "Device row status")
        case .connectedUnauthorized:
            return device.needsAuthentication
                ? String(localized: "Setup required", comment: "Device row status")
                : String(localized: "Authorizing...", comment: "Device row status")
        case .serviceDiscovery:
            return String(localized: "Connecting...", comment: "Device row status")
        case .disconnected:
            if isOutOfRange {
                return String(localized: "Out of range", comment: "Device row status")
            }
            if isWeakSignal {
                return String(localized: "Weak signal", comment: "Device row status")
            }
            return device.isKnownDevice
                ? String(localized: "Tap to connect", comment: "Device row status")
                : String(localized: "Tap to set up", comment: "Device row status")
        }
    }

    /// A disconnected device that is no longer advertising is treated as out of range:
    /// it shows an "Out of range" status and hides the signal indicator.
    private var isOutOfRange: Bool {
        device.connectionState == .disconnected && !device.isConnectable
    }

    /// A connectable but faint device (RSSI ≤ -85 dBm): shown with a "Weak signal"
    /// status and red signal bars.
    private var isWeakSignal: Bool {
        device.connectionState == .disconnected
            && device.isConnectable
            && device.rssi > -200
            && device.rssi <= -85
    }

    private var normalizedSignalStrength: Double {
        guard device.rssi > -200 else {
            return device.isConnected ? 0.85 : 0.55
        }

        // Approximate BLE RSSI range: -95 dBm (weak) ... -40 dBm (excellent).
        let normalized = (Double(device.rssi) + 95) / 55
        return min(max(normalized, 0.15), 1.0)
    }

    private var signalColor: Color {
        if device.isConnected {
            return .accentBlue
        }
        if isWeakSignal {
            return Color(.systemRed)
        }
        return device.isConnectable ? .accentBlue : .secondary
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
            return device.needsAuthentication
                ? String(localized: "Double-tap to authenticate", comment: "Accessibility hint")
                : String(localized: "Connection in progress", comment: "Accessibility hint")
        case .connectedAuthorized:
            return String(localized: "Double-tap to view device options", comment: "Accessibility hint")
        }
    }
}

// MARK: - Previews

#Preview("All states") {
    VStack(spacing: 12) {
        DeviceRowView(device: .preview, isSelected: true)
        DeviceRowView(device: .preview("TV Room", .available))
        DeviceRowView(device: .previewWeakSignal)
        DeviceRowView(device: .preview("ClickStick B3D2", .connecting))
        DeviceRowView(device: .preview("Home Router", .outOfRange))
        DeviceRowView(device: .previewCompromised)
    }
    .padding()
    .background(Color.groupedBackground)
}
