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

            if showsSignalBars {
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

            if case .connected = device.uiState {
                Circle()
                    .fill(Color(.systemGreen))
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
        }
    }

    private var statusColor: Color {
        switch device.uiState {
        case .compromised, .failed:
            return Color(.systemRed)
        default:
            return Color.secondary
        }
    }

    private var cardBackground: Color {
        isSelected ? Color.accentBlue.opacity(0.12) : Color.cardBackground
    }

    private var cardBorderColor: Color? {
        switch device.uiState {
        case .compromised:
            return Color(.systemRed)
        default:
            return isSelected ? Color.accentBlue.opacity(0.2) : nil
        }
    }

    private var statusDescription: String {
        switch device.uiState {
        case .connected:
            return String(localized: "Connected", comment: "Device row status")
        case .authorizing:
            return String(localized: "Authorizing...", comment: "Device row status")
        case .setupRequired:
            return String(localized: "Setup required", comment: "Device row status")
        case .connecting:
            return String(localized: "Connecting...", comment: "Device row status")
        case .available:
            return String(localized: "Tap to connect", comment: "Device row status")
        case .newDevice:
            return String(localized: "Tap to set up", comment: "Device row status")
        case .weakSignal:
            return String(localized: "Weak signal", comment: "Device row status")
        case .outOfRange:
            return String(localized: "Out of range", comment: "Device row status")
        case .compromised:
            return String(localized: "Security warning", comment: "Compromised device status")
        case .failed(let error):
            return error.localizedDescription
        }
    }

    private var showsSignalBars: Bool {
        switch device.uiState {
        case .outOfRange, .compromised:
            return false
        default:
            return true
        }
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
        switch device.uiState {
        case .connected:
            return .accentBlue
        case .weakSignal:
            return Color(.systemRed)
        default:
            return device.isConnectable ? .accentBlue : .secondary
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
        switch device.uiState {
        case .connected:
            return String(localized: "Double-tap to view device options", comment: "Accessibility hint")
        case .authorizing, .connecting:
            return String(localized: "Connection in progress", comment: "Accessibility hint")
        case .setupRequired:
            return String(localized: "Double-tap to authenticate", comment: "Accessibility hint")
        case .available, .newDevice, .weakSignal:
            return String(localized: "Double-tap to connect", comment: "Accessibility hint")
        case .outOfRange, .failed, .compromised:
            return ""
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
