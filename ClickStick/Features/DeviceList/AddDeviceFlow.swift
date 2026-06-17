//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI

// MARK: - Add Device (scanning) modal

/// Modal presented from the Devices screen ("Scan for devices" / "+").
/// Shows the looking / paused scanning states with Cancel + "Add Device" chrome.
/// When a device is discovered, the host swaps this sheet for `FoundDevicesSheet`.
struct AddDeviceScanSheet: View {
    let viewModel: DeviceListViewModel
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            DiscoveryStateBlock(isScanning: viewModel.isScanning)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clickStickGroupedBackground)
                .safeAreaInset(edge: .bottom) {
                    bottomButton
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.sm)
                }
                .navigationTitle("Add Device")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                            .accessibilityLabel("Cancel add device")
                    }
                }
        }
        .presentationDragIndicator(.hidden)
    }

    // Two distinct ButtonStyle types resolved via an `if` expression into a single
    // concrete view, avoiding a ViewBuilder branch over button styles.
    private var bottomButton: AnyView {
        if viewModel.isScanning {
            AnyView(
                Button("Stop") { viewModel.stopScanning() }
                    .buttonStyle(.secondary(tint: .primary))
            )
        } else {
            AnyView(
                Button("Scan again") { viewModel.startScanning() }
                    .buttonStyle(.primary)
            )
        }
    }
}

// MARK: - Found devices modal

/// Modal shown once devices are discovered: a list to pick from, with a Stop button.
/// Presented over the dimmed Devices list.
struct FoundDevicesSheet: View {
    let viewModel: DeviceListViewModel
    let previewRows: [DiscoveryDeviceRowModel]?
    let onConnect: (DeviceModel) -> Void
    let onStop: () -> Void

    private var rows: [DiscoveryDeviceRowModel] {
        previewRows ?? viewModel.devices.map(DiscoveryDeviceRowModel.init(device:))
    }

    private var title: String {
        String(localized: "\(rows.count) devices found", comment: "Discovered device count")
    }

    var body: some View {
        VStack(spacing: 0) {
            RadioWaveIconView(tint: .clickStickOrange, size: 80)
                .padding(.top, Spacing.xxxl + Spacing.xl)

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Select your device carefully. Connect only to a device you recognize and trust.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 330)
            .padding(.top, Spacing.xl)

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    ForEach(rows) { row in
                        Button {
                            if let device = row.device { onConnect(device) }
                        } label: {
                            DiscoveryDeviceRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.top, Spacing.xxxl + Spacing.lg)
            }

            Button("Stop", action: onStop)
                .buttonStyle(.secondary(tint: .primary))
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clickStickCardBackground)
        .presentationDetents([.large])
        .presentationCornerRadius(CornerRadius.modal)
        .presentationDragIndicator(.hidden)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Shared discovery views

/// The centered radar/text block used by the scanning modal in both
/// looking and paused states.
private struct DiscoveryStateBlock: View {
    let isScanning: Bool

    var body: some View {
        VStack(spacing: Spacing.xxxl) {
            animation

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
        }
        .padding(.horizontal, Spacing.lg)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var animation: some View {
        if isScanning {
            BluetoothDiscoveryAnimationView(size: 184)
        } else {
            DiscoveryRadarView(isActive: false, size: 184, tint: .clickStickBlue, style: .pausedRadar)
        }
    }

    private var title: LocalizedStringKey {
        isScanning ? "Looking for nearby devices..." : "Scanning paused"
    }

    private var subtitle: LocalizedStringKey {
        isScanning
            ? "Make sure your ClickStick is plugged in and Bluetooth is on"
            : "Tap Scan again to search for devices"
    }
}

struct DiscoveryDeviceRowModel: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
    let device: DeviceModel?

    init(device: DeviceModel) {
        self.id = device.id
        self.name = device.displayName
        self.rssi = device.rssi
        self.device = device
    }

    init(id: UUID = UUID(), name: String, rssi: Int) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.device = nil
    }

    #if DEBUG
    static let figmaPreviewRows: [Self] = [
        .init(name: "ClickStick 9F8C", rssi: -42),
        .init(name: "ClickStick 8F8C", rssi: -71),
        .init(name: "ClickStick A1B2", rssi: -88)
    ]
    #endif
}

private struct DiscoveryDeviceRow: View {
    let row: DiscoveryDeviceRowModel

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(row.name)
                    .font(.system(size: 19))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(rssiText)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.sm)

            SignalStrengthView(
                strength: normalizedSignalStrength,
                activeColor: signalColor
            )
            .frame(width: 24)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.name), \(rssiText)")
        .accessibilityHint("Double-tap to connect")
    }

    private var rssiText: String {
        guard row.rssi > -200 else { return String(localized: "Signal unknown") }
        return "\(row.rssi) dBm"
    }

    private var normalizedSignalStrength: Double {
        guard row.rssi > -200 else { return 0.55 }
        return min(max((Double(row.rssi) + 95) / 55, 0.15), 1.0)
    }

    private var signalColor: Color {
        row.rssi <= -80 ? .clickStickDestructive : .clickStickBlue
    }
}

// MARK: - Previews

#Preview("Add Device · Scanning") {
    AddDeviceScanSheet(
        viewModel: DeviceListViewModel(service: ClickStickService(), urlOpener: URLOpener()),
        onCancel: {}
    )
}

#Preview("Found Devices") {
    FoundDevicesSheet(
        viewModel: DeviceListViewModel(service: ClickStickService(), urlOpener: URLOpener()),
        previewRows: DiscoveryDeviceRowModel.figmaPreviewRows,
        onConnect: { _ in },
        onStop: {}
    )
}
