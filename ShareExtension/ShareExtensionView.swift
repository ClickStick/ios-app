//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct ShareExtensionView: View {
    let viewModel: ShareExtensionViewModel
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
                        .fill(Color.cardBackground)
                        .ignoresSafeArea(edges: .bottom)
                }
        }
        // Key the animation on the phase *kind* only, so it drives the card
        // transitions (input → sending → sent) without re-firing on every
        // per-character progress update during `.sending`.
        .animation(.easeInOut(duration: 0.2), value: viewModel.phase.transitionID)
        .onAppear { viewModel.onAppear() }
        // Teardown (`onDisappear`) is driven explicitly by the hosting controller's
        // cancel()/complete() so scanning stops synchronously before the process exits.
        .onChange(of: viewModel.deviceListChangeToken) { _, _ in
            viewModel.devicesDidChange()
        }
    }

    @ViewBuilder private var cardContent: some View {
        switch viewModel.phase {
        case .input:
            ShareInputCard(viewModel: viewModel, onCancel: onCancel, onAddDevice: onAddDevice)
                .transition(cardTransition)
        case let .sending(sent, total):
            // Narrow inputs (just `sent`/`total`) so this card's invalidation
            // boundary doesn't pull in the rest of `viewModel` — per-character
            // progress updates only re-evaluate this small view.
            ShareSendingCard(sent: sent, total: total, onCancel: viewModel.cancelSending)
                .transition(cardTransition)
        case .sent:
            ShareSentCard(deviceName: viewModel.selectedDevice?.displayName ?? "", onComplete: onComplete)
                .transition(cardTransition)
        case .connectionLost:
            ShareConnectionLostCard(
                onClose: viewModel.dismissConnectionLost,
                onTryAgain: viewModel.retryAfterConnectionLost
            )
            .transition(cardTransition)
        }
    }

    /// Scale + fade between the phase cards, matching the app's sent toast
    /// (`TextEntryView`). The card itself resizes under the same animation, so
    /// the height change animates alongside the transition.
    private var cardTransition: AnyTransition {
        .scale.combined(with: .opacity)
    }
}

// MARK: - Input

private struct ShareInputCard: View {
    let viewModel: ShareExtensionViewModel
    let onCancel: () -> Void
    let onAddDevice: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Send to ClickStick", comment: "Share extension title")
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)

            DeviceCard(viewModel: viewModel, onAddDevice: onAddDevice)
                .padding(.top, 32)

            TextCard(text: viewModel.text)
                .padding(.top, 16)

            ControlsRow(viewModel: viewModel)
                .padding(.top, 16)

            ButtonsRow(viewModel: viewModel, onCancel: onCancel)
                .padding(.top, 24)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}

private struct DeviceCard: View {
    let viewModel: ShareExtensionViewModel
    let onAddDevice: () -> Void

    var body: some View {
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
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 20)
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        // Paint the card on the Menu, not inside its label: when iOS opens the
        // picker it lifts the label into a highlight platter, and a background
        // inside the label vanishes from the source spot (flashes white).
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.cardFill))
        .tint(.primary)
    }

    private var deviceTitle: String {
        viewModel.selectedDevice?.displayName
            ?? String(localized: "Select device", comment: "Share extension device picker placeholder")
    }
}

private struct TextCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
            .frame(height: 115)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.cardFill))
    }
}

private struct ControlsRow: View {
    let viewModel: ShareExtensionViewModel

    var body: some View {
        HStack(spacing: 16) {
            DropdownPill(title: viewModel.selectedLayout.title) {
                ForEach(CSKeyboardLayout.allCases, id: \.self) { layout in
                    Button(layout.title) { viewModel.selectedLayout = layout }
                }
            }
            DropdownPill(title: viewModel.selectedOS.title) {
                ForEach(CSTypingOS.allCases) { os in
                    Button(os.title) { viewModel.selectedOS = os }
                }
            }
        }
    }
}

private struct ButtonsRow: View {
    let viewModel: ShareExtensionViewModel
    let onCancel: () -> Void

    var body: some View {
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
}

// MARK: - Sending

private struct ShareSendingCard: View {
    let sent: Int
    let total: Int
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Sending...", comment: "Share extension sending title")
                .font(.title.bold())
                .foregroundStyle(.primary)

            ProgressView(value: total == 0 ? 0 : Double(sent) / Double(total))
                .tint(Color.accentBlue)
                .accessibilityLabel(String(localized: "Sending text", comment: "Send progress accessibility"))

            Text("\(sent) of \(total) characters", comment: "Share extension send progress")
                .font(.body)
                .foregroundStyle(.secondary)

            Button { onCancel() } label: {
                Text("Cancel", comment: "Share extension cancel button")
            }
            .buttonStyle(AppSecondaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 24)
    }
}

// MARK: - Sent

private struct ShareSentCard: View {
    let deviceName: String
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white, Color.green)
                .accessibilityHidden(true)

            Text("Sent!", comment: "Share extension sent title")
                .font(.title.bold())
                .foregroundStyle(.primary)

            Text("Text delivered to \(deviceName)", comment: "Share extension sent subtitle")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 44)
        .task {
            // Brief confirmation, then dismiss. Kept short because the extension
            // process is torn down on completion — users want back to the host app.
            try? await Task.sleep(for: .seconds(0.7))
            onComplete()
        }
    }
}

// MARK: - Connection lost

private struct ShareConnectionLostCard: View {
    let onClose: () -> Void
    let onTryAgain: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.circle")
                .font(.largeTitle)
                .foregroundStyle(Color(uiColor: .systemRed))
                .padding(20)
                .background(Circle().fill(Color(uiColor: .systemRed).opacity(0.08)))
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Connection lost", comment: "Share extension connection lost title")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("Bluetooth disconnected.\nCheck your device and try again.", comment: "Share extension connection lost message")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    Button("Close", action: onClose)
                        .buttonStyle(AppSecondaryButtonStyle())

                    Button("Try again", action: onTryAgain)
                        .buttonStyle(AppPrimaryButtonStyle())
                }

                VStack(spacing: 12) {
                    Button("Try again", action: onTryAgain)
                        .buttonStyle(AppPrimaryButtonStyle())

                    Button("Close", action: onClose)
                        .buttonStyle(AppSecondaryButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 24)
    }
}

// MARK: - Device status line

private struct DeviceStatusLine: View {
    let state: DeviceUIState

    var body: some View {
        HStack(spacing: 6) {
            Text(state.statusDescription)
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

    private var statusColor: Color {
        switch state {
        case .compromised, .failed: Color.red
        default: Color.secondary
        }
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
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.border, lineWidth: 1)
            )
        }
        .tint(.primary)
    }
}

// MARK: - Phase transitions

private extension ShareExtensionViewModel.Phase {
    /// Coarse identity used to drive card transitions. Unlike the full `Phase`
    /// value, it doesn't change on per-character progress, so the input → sending
    /// → sent animation fires once per real transition, not on every character.
    var transitionID: Int {
        switch self {
        case .input: 0
        case .sending: 1
        case .sent: 2
        case .connectionLost: 3
        }
    }
}
