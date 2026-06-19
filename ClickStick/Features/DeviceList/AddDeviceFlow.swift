//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
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
                .background(Color.groupedBackground)
                .safeAreaInset(edge: .bottom) {
                    bottomButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
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

    @ViewBuilder
    private var bottomButton: some View {
        if viewModel.isScanning {
            Button("Stop") { viewModel.stopScanning() }
                .buttonStyle(AppSecondaryButtonStyle())
        } else {
            Button("Scan again") { viewModel.startScanning() }
                .buttonStyle(AppPrimaryButtonStyle())
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
            foundIcon
                .padding(.top, 64)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Select your device carefully. Connect only to a device you recognize and trust.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 330)
            .padding(.top, 24)

            ScrollView {
                VStack(spacing: 24) {
                    ForEach(rows) { row in
                        Button {
                            if let device = row.device { onConnect(device) }
                        } label: {
                            DiscoveryDeviceRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 60)
            }

            Button("Stop", action: onStop)
                .buttonStyle(AppSecondaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.cardBackground)
        .presentationDetents([.large])
        .presentationCornerRadius(40)
        .presentationDragIndicator(.hidden)
        .accessibilityElement(children: .contain)
    }

    private var foundIcon: some View {
        ZStack {
            Circle().fill(Color(.systemOrange).opacity(0.14))

            Image(systemName: "antenna.radiowaves.left.and.right")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 80 * 0.42, weight: .semibold))
                .foregroundStyle(Color(.systemOrange))
        }
        .frame(width: 80, height: 80)
        .accessibilityHidden(true)
    }
}

// MARK: - Shared discovery views

/// The centered radar/text block used by the scanning modal in both
/// looking and paused states.
private struct DiscoveryStateBlock: View {
    let isScanning: Bool

    var body: some View {
        VStack(spacing: 40) {
            animation

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var animation: some View {
        if isScanning {
            BluetoothDiscoveryAnimationView(size: 184)
        } else {
            ScanRadarView(showsSweep: false, tint: .accentBlue, size: 184)
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
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(rssiText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            SignalBarsView(
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
        row.rssi <= -80 ? Color(.systemRed) : .accentBlue
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
