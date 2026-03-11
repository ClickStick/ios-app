//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI

/// Shared content view for typing text to a ClickStick device
/// Used by both DeepLinkTypeSheet and ShareExtension
struct TypeTextContentView<ViewModel: TypeTextViewModel, Header: View>: View {
    @Bindable var viewModel: ViewModel
    let onDismiss: () -> Void
    private let headerView: Header

    init(
        viewModel: ViewModel,
        onDismiss: @escaping () -> Void,
        @ViewBuilder header: () -> Header
    ) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self.headerView = header()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                headerView
                textPreview
                layoutPicker
                deviceSection
                actionButton
            }
            .padding(Spacing.md)
        }
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
                    withAnimation(.easeInOut(duration: Motion.regular)) {
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
                .accessibilityLabel(viewModel.isTextVisible ? "Hide text" : "Show text")
            }

            Text(viewModel.displayText)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.secondary.opacity(OpacityLevel.subtleFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.secondary.opacity(OpacityLevel.subtleBorder), lineWidth: BorderWidth.thin)
                )
                .accessibilityLabel("Text to type")
                .accessibilityValue(viewModel.isTextVisible
                    ? viewModel.text
                    : String(localized: "\(viewModel.characterCount) characters (hidden)"))

            Text("\(viewModel.characterCount) characters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Layout Picker

    private var layoutPicker: some View {
        HStack {
            Label("Keyboard Layout", systemImage: "globe")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Keyboard Layout", selection: $viewModel.selectedLayout) {
                ForEach(CSKeyboardLayout.allCases, id: \.self) { layout in
                    Text(layout.description).tag(layout)
                }
            }
            .pickerStyle(.menu)
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
            .accessibilityAddTraits(.isHeader)

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
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.clickStickOrange)
                Text("No paired devices found")
                    .font(.subheadline)
                Spacer()
            }

            Text("Open the ClickStick app to pair a device first.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.clickStickOrange.opacity(OpacityLevel.subtleFill))
        )
        .accessibilityElement(children: .combine)
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
                            .foregroundStyle(Color.clickStickGreen)
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
                .buttonStyle(.secondary)
                .controlSize(.small)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.secondary.opacity(OpacityLevel.subtleFill))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(device.displayName), \(viewModel.deviceStatusMessage)")
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
                                    .foregroundStyle(Color.clickStickGreen)
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
                    .segmentedControlItem(isSelected: viewModel.selectedDeviceID == device.id, tint: .clickStickBlue.opacity(0.12))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewModel.selectedDeviceID == device.id ? .isSelected : [])
                .accessibilityLabel("\(device.displayName), \(device.isConnected ? "connected" : "not connected")")
            }
        }
        .segmentedControlContainer()
    }

    // MARK: - Action Button

    private var actionButton: some View {
        VStack(spacing: Spacing.sm) {
            if let error = viewModel.connectionError {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }

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
                Task {
                    let success = await viewModel.sendText()
                    if success {
                        onDismiss()
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
            .opacity(viewModel.canType ? 1 : OpacityLevel.disabled)
            .accessibilityHint(viewModel.canType
                ? "Double tap to type the text"
                : "Connect to a device first")
        }
    }
}

// MARK: - Convenience Initializer

extension TypeTextContentView where Header == EmptyView {
    /// Creates a TypeTextContentView without a header
    init(viewModel: ViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self.headerView = EmptyView()
    }
}
