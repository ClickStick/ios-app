//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct ShareExtensionView: View {
    @Bindable var viewModel: ShareExtensionViewModel
    let onCancel: () -> Void
    let onComplete: () -> Void
    let onAddDevice: () -> Void

    var body: some View {
        // iOS already presents the extension in a system sheet that dims the host
        // behind it, so we keep the backdrop clear (a second dim double-stacks) and
        // draw only a compact card pinned to the bottom, sized to its content.
        ZStack(alignment: .bottom) {
            Color.clear

            cardContent
                .frame(maxWidth: .infinity, alignment: .top)
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: 44, topTrailingRadius: 44, style: .continuous)
                        .fill(ShareColors.sheet)
                        .ignoresSafeArea(edges: .bottom)
                }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.phase)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    @ViewBuilder private var cardContent: some View {
        switch viewModel.phase {
        case .input:
            inputContent
        case let .sending(sent, total):
            sendingContent(sent: sent, total: total)
        case .sent:
            sentContent
        }
    }

    // MARK: - Input

    private var inputContent: some View {
        VStack(spacing: 0) {
            Text("Send to ClickStick", comment: "Share extension title")
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)

            deviceCard
                .padding(.top, 32)

            textCard
                .padding(.top, 16)

            controlsRow
                .padding(.top, 16)

            buttonsRow
                .padding(.top, 24)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    private var deviceCard: some View {
        Menu {
            ForEach(viewModel.devices) { device in
                Button {
                    viewModel.select(device)
                } label: {
                    Text(device.displayName)
                    if device.id == viewModel.selectedDeviceID {
                        Image(systemName: "checkmark")
                    }
                }
            }
            Button {
                onAddDevice()
            } label: {
                Label("Add Device", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deviceTitle)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let device = viewModel.selectedDevice {
                        DeviceStatusLine(state: device.uiState)
                    }
                }
                Spacer(minLength: 12)
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ShareColors.secondaryIcon)
            }
            .padding(.horizontal, 20)
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(ShareColors.cardFill))
        }
        .tint(.primary)
    }

    private var deviceTitle: String {
        viewModel.selectedDevice?.displayName
            ?? String(localized: "Select device", comment: "Share extension device picker placeholder")
    }

    private var textCard: some View {
        Text(viewModel.text)
            .font(.body)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
            .frame(height: 115)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(ShareColors.cardFill))
    }

    private var controlsRow: some View {
        HStack(spacing: 16) {
            DropdownPill(title: viewModel.selectedLayout.shareMenuTitle) {
                ForEach(CSKeyboardLayout.allCases, id: \.self) { layout in
                    Button(layout.shareMenuTitle) { viewModel.selectedLayout = layout }
                }
            }
            DropdownPill(title: viewModel.selectedOS.shareTitle) {
                ForEach(CSTypingOS.allCases) { os in
                    Button(os.shareTitle) { viewModel.selectedOS = os }
                }
            }
        }
    }

    private var buttonsRow: some View {
        HStack(spacing: 16) {
            Button { onCancel() } label: {
                Text("Cancel", comment: "Share extension cancel button")
            }
            .buttonStyle(AppSecondaryButtonStyle())

            Button { viewModel.send() } label: {
                Text("Send", comment: "Share extension send button")
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(!viewModel.canSend)
        }
    }

    // MARK: - Sending

    private func sendingContent(sent: Int, total: Int) -> some View {
        VStack(spacing: 24) {
            Text("Sending...", comment: "Share extension sending title")
                .font(.title.bold())
                .foregroundStyle(.primary)

            ShareProgressBar(fraction: total == 0 ? 0 : Double(sent) / Double(total))
                .frame(height: 8)

            Text("\(sent) of \(total) characters", comment: "Share extension send progress")
                .font(.body)
                .foregroundStyle(.secondary)

            Button { viewModel.cancelSending() } label: {
                Text("Cancel", comment: "Share extension cancel button")
            }
            .buttonStyle(AppSecondaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 24)
    }

    // MARK: - Sent

    private var sentContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white, Color.green)
                .accessibilityHidden(true)

            Text("Sent!", comment: "Share extension sent title")
                .font(.title.bold())
                .foregroundStyle(.primary)

            Text("Text delivered to \(viewModel.selectedDevice?.displayName ?? "")", comment: "Share extension sent subtitle")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 44)
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            onComplete()
        }
    }
}

// MARK: - Device status line

private struct DeviceStatusLine: View {
    let state: DeviceUIState

    var body: some View {
        HStack(spacing: 6) {
            Text(statusText)
                .font(.body)
                .foregroundStyle(statusColor)
                .lineLimit(1)

            if state == .connected {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
        }
    }

    private var statusText: String {
        switch state {
        case .connected: String(localized: "Connected", comment: "Device status")
        case .authorizing: String(localized: "Authorizing...", comment: "Device status")
        case .setupRequired: String(localized: "Setup required", comment: "Device status")
        case .connecting: String(localized: "Connecting...", comment: "Device status")
        case .available: String(localized: "Tap to connect", comment: "Device status")
        case .newDevice: String(localized: "Tap to set up", comment: "Device status")
        case .weakSignal: String(localized: "Weak signal", comment: "Device status")
        case .outOfRange: String(localized: "Out of range", comment: "Device status")
        case .compromised: String(localized: "Security warning", comment: "Device status")
        case .failed: String(localized: "Connection failed", comment: "Device status")
        }
    }

    private var statusColor: Color {
        switch state {
        case .compromised, .failed: Color.red
        default: Color.secondary
        }
    }
}

// MARK: - Progress bar

private struct ShareProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color(uiColor: .systemGray5))
                Capsule(style: .continuous)
                    .fill(ShareColors.accent)
                    .frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Sending text", comment: "Send progress accessibility"))
    }
}

// MARK: - Dropdown pill

private struct DropdownPill<Content: View>: View {
    let title: String
    @ViewBuilder let menuItems: Content

    var body: some View {
        Menu {
            menuItems
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ShareColors.secondaryIcon)
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ShareColors.border, lineWidth: 1)
            )
        }
        .tint(.primary)
    }
}

// MARK: - Colors

enum ShareColors {
    /// Sheet background — white (light) / #1C1C1E (dark). Matches Figma `background/secondary`.
    static let sheet = Color(uiColor: .secondarySystemGroupedBackground)
    /// Inner card fill — #F2F2F7 (light) / #2C2C2E (dark). Matches Figma `background/primary`.
    static let cardFill = Color(uiColor: .tertiarySystemGroupedBackground)
    /// System blue (#007AFF / #0A84FF) — matches Figma `fill/primary` and the app accent.
    static let accent = Color.blue
    /// #E5E5EA (light) / #2C2C2E (dark) — matches Figma `fill/secondary`.
    static let secondaryButtonFill = Color(uiColor: .systemGray5)
    static let secondaryIcon = Color.secondary
    /// Dropdown border — #C8D0DA (light), subtle white (dark). Matches Figma `border/default`.
    static let border = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.16)
            : UIColor(red: 0.784, green: 0.816, blue: 0.855, alpha: 1)
    })
}

// MARK: - Localized titles

private extension CSKeyboardLayout {
    /// "US - QWERTY" → "US-QWERTY" to match the design.
    var shareMenuTitle: String {
        description.replacing(" - ", with: "-")
    }
}

private extension CSTypingOS {
    var shareTitle: String {
        switch self {
        case .windows: String(localized: "Windows", comment: "Target OS")
        case .macOS: String(localized: "macOS", comment: "Target OS")
        case .linux: String(localized: "Linux", comment: "Target OS")
        }
    }
}

// MARK: - Previews

#if DEBUG
@MainActor private func previewView(
    device: DeviceModel?,
    phase: ShareExtensionViewModel.Phase = .input,
    text: String = "admin@company.local"
) -> some View {
    ShareExtensionView(
        viewModel: ShareExtensionViewModel(previewText: text, device: device, phase: phase),
        onCancel: {},
        onComplete: {},
        onAddDevice: {}
    )
}

@MainActor private var previewConnectedDevice: DeviceModel {
    DeviceModel(device: .makePreview(name: "ClickStick 9F8C", state: .connected))
}

@MainActor private var previewOutOfRangeDevice: DeviceModel {
    DeviceModel(device: .makePreview(name: "ClickStick 9F8C", state: .outOfRange))
}

#Preview("Input — Light") {
    previewView(device: previewConnectedDevice)
}

#Preview("Input — Dark") {
    previewView(device: previewConnectedDevice)
        .preferredColorScheme(.dark)
}

#Preview("Out of range") {
    previewView(device: previewOutOfRangeDevice)
}

#Preview("No device") {
    previewView(device: nil)
}

#Preview("Sending — Light") {
    previewView(device: previewConnectedDevice, phase: .sending(sent: 250, total: 300))
}

#Preview("Sending — Dark") {
    previewView(device: previewConnectedDevice, phase: .sending(sent: 250, total: 300))
        .preferredColorScheme(.dark)
}

#Preview("Sent — Light") {
    previewView(device: previewConnectedDevice, phase: .sent)
}

#Preview("Sent — Dark") {
    previewView(device: previewConnectedDevice, phase: .sent)
        .preferredColorScheme(.dark)
}
#endif
