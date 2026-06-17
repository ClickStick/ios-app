//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI

struct DeviceRowView: View {
    let device: DeviceModel
    var isSelected: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xxs) {
                    Text(device.displayName)
                        .font(.clickStickBodyEmphasized)
                        .foregroundStyle(device.isCompromised ? Color.clickStickDestructive : .primary)
                        .lineLimit(1)

                    if device.isCompromised {
                        Image(systemName: "exclamationmark.circle")
                            .font(.clickStickCallout)
                            .foregroundStyle(Color.clickStickDestructive)
                            .accessibilityHidden(true)
                    }
                }

                statusLine
            }

            Spacer(minLength: Spacing.sm)

            if !isOutOfRange && !device.isCompromised {
                SignalStrengthView(
                    strength: normalizedSignalStrength,
                    activeColor: signalColor
                )
                .frame(width: 24)
            }

            Image(systemName: "ellipsis")
                .font(.system(size: IconSize.inline, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 78)
        .clickStickCard(
            background: cardBackground,
            cornerRadius: CornerRadius.extraLarge,
            borderColor: cardBorderColor,
            borderWidth: device.isCompromised ? BorderWidth.regular : BorderWidth.hairline
        )
        .overlay(alignment: .leading) {
            if device.isConnecting && !reduceMotion {
                RoundedRectangle(cornerRadius: CornerRadius.extraLarge, style: .continuous)
                    .stroke(Color.clickStickBlue.opacity(OpacityLevel.subtleBorder), lineWidth: BorderWidth.thick)
                    .scaleEffect(1.015)
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: device.isConnecting)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(accessibilityHint)
    }

    private var statusLine: some View {
        HStack(spacing: Spacing.xxs) {
            Text(statusDescription)
                .font(.clickStickCallout)
                .foregroundStyle(statusColor)
                .lineLimit(1)

            if device.isConnected && !device.isCompromised {
                Circle()
                    .fill(Color.clickStickGreen)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
        }
    }

    private var statusColor: Color {
        (device.isCompromised || device.lastError != nil) ? Color.clickStickDestructive : Color.secondary
    }

    private var cardBackground: Color {
        if isSelected {
            return Color.clickStickBlue.opacity(OpacityLevel.tintedFill)
        }
        return Color.clickStickCardBackground
    }

    private var cardBorderColor: Color? {
        if device.isCompromised {
            return Color.clickStickDestructive
        }
        if isSelected {
            return Color.clickStickBlue.opacity(OpacityLevel.subtleBorder)
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
            return String(localized: "Setup required", comment: "Device row status")
        case .serviceDiscovery:
            return String(localized: "Connecting...", comment: "Device row status")
        case .disconnected:
            if isOutOfRange {
                return String(localized: "Out of range", comment: "Device row status")
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
            return .clickStickBlue
        }
        return device.isConnectable ? .clickStickBlue : .secondary
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

// MARK: - Previews

#Preview {
    VStack(spacing: Spacing.sm) {
        DeviceRowView(device: .preview, isSelected: true)
        DeviceRowView(device: .previewDisconnected)
        DeviceRowView(device: .previewCompromised)
    }
    .padding()
    .background(Color.clickStickGroupedBackground)
}
