//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

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

// MARK: - Device row

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

// MARK: - Preview

#Preview("Found Devices") {
    FoundDevicesSheet(
        viewModel: DeviceListViewModel(service: ClickStickService(), urlOpener: URLOpener()),
        previewRows: DiscoveryDeviceRowModel.figmaPreviewRows,
        onConnect: { _ in },
        onStop: {}
    )
}
