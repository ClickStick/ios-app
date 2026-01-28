//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

/// Sheet presented when the app receives a deep link request to type text
struct DeepLinkTypeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let request: TypeRequest
    let service: ClickStickService
    let deepLinkHandler: DeepLinkHandler

    @State private var viewModel: DeepLinkTypeViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    DeepLinkTypeContentView(viewModel: viewModel, dismiss: { dismiss() })
                } else {
                    ProgressView()
                        .onAppear {
                            viewModel = DeepLinkTypeViewModel(
                                request: request,
                                service: service,
                                deepLinkHandler: deepLinkHandler
                            )
                        }
                }
            }
            .navigationTitle("Type Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel?.cancel()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Content View

private struct DeepLinkTypeContentView: View {
    @Bindable var viewModel: DeepLinkTypeViewModel
    let dismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                sourceAppHeader
                textPreview
                layoutPicker
                deviceSection
                actionButton
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Source App Header

    private var sourceAppHeader: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "arrow.down.app")
                .font(.title2)
                .foregroundStyle(Color.clickStickBlue)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("\(viewModel.sourceAppName) wants to type:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.clickStickBlue.opacity(0.1))
        )
    }

    // MARK: - Text Preview

    private var textPreview: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "keyboard")
                        .foregroundStyle(Color.clickStickBlue)
                    Text("Text to type")
                        .font(.headline)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.toggleTextVisibility()
                    }
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: viewModel.isTextVisible ? "eye.slash" : "eye")
                        Text(viewModel.isTextVisible ? "Hide" : "Show")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.clickStickBlue)
                }
                .buttonStyle(.plain)
            }

            Text(viewModel.displayText)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.secondary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .accessibilityLabel("Text to type")
                .accessibilityValue(viewModel.isTextVisible
                    ? viewModel.request.text
                    : String(localized: "\(viewModel.characterCount) characters (hidden)"))

            Text("\(viewModel.characterCount) characters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Layout Picker

    private var layoutPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "globe")
                    .foregroundStyle(Color.clickStickTeal)
                Text("Keyboard Layout")
                    .font(.headline)
            }

            HStack(spacing: Spacing.xxs) {
                ForEach(CSKeyboardLayout.allCases, id: \.self) { layout in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedLayout = layout
                        }
                    } label: {
                        Text(layout.description)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(viewModel.selectedLayout == layout ? .white : .primary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.small)
                                    .fill(viewModel.selectedLayout == layout
                                        ? Color.clickStickTeal
                                        : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.secondary.opacity(0.1))
            )
        }
    }

    // MARK: - Device Section

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "cable.connector.horizontal")
                    .foregroundStyle(Color.clickStickOrange)
                Text("Device")
                    .font(.headline)
            }

            if viewModel.devices.isEmpty {
                noDevicesView
            } else if viewModel.devices.count == 1, let device = viewModel.devices.first {
                singleDeviceView(device: device)
            } else {
                devicePicker
            }
        }
    }

    private var noDevicesView: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("No paired devices found")
                .font(.subheadline)
            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private func singleDeviceView(device: DeviceModel) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "cable.connector.horizontal")
                .font(.title3)
                .foregroundStyle(device.isConnected ? Color.clickStickTeal : .secondary)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(device.displayName)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: Spacing.xxs) {
                    if device.isConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if device.isConnecting {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                    }
                    Text(viewModel.deviceStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !device.isConnected && !device.isConnecting {
                Button("Connect") {
                    viewModel.connectDevice()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var devicePicker: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(viewModel.devices) { device in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedDeviceID = device.id
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: viewModel.selectedDeviceID == device.id
                            ? "checkmark.circle.fill"
                            : "circle")
                            .foregroundStyle(viewModel.selectedDeviceID == device.id
                                ? Color.clickStickBlue
                                : .secondary)

                        Text(device.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        if device.isConnected {
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if device.isConnecting {
                            HStack(spacing: Spacing.xxs) {
                                ProgressView()
                                    .controlSize(.mini)
                                Text("Connecting")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(viewModel.selectedDeviceID == device.id
                                ? Color.clickStickBlue.opacity(0.1)
                                : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    // MARK: - Action Button

    private var actionButton: some View {
        VStack(spacing: Spacing.sm) {
            if !viewModel.isDeviceReady && viewModel.selectedDevice != nil && !viewModel.isConnecting {
                Button {
                    viewModel.connectDevice()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Connect Device")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
            }

            Button {
                viewModel.sendText { success in
                    if success {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    if viewModel.isSending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(viewModel.isSending ? "Sending..." : "Type Now")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
            .disabled(!viewModel.canType)
            .opacity(viewModel.canType ? 1 : 0.6)
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var service = ClickStickService()
    @Previewable @State var handler = DeepLinkHandler(urlOpener: URLOpener())

    DeepLinkTypeSheet(
        request: TypeRequest(
            text: "MySecretPassword123!@#",
            layout: .usQWERTY,
            deviceIdentifier: nil,
            sourceApp: "KeePassium",
            successURL: nil,
            errorURL: nil,
            cancelURL: nil
        ),
        service: service,
        deepLinkHandler: handler
    )
}
