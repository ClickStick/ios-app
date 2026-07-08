//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct TextEntryView: View {
    @Bindable var viewModel: TextEntryViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var unsupportedSheetHeight: CGFloat = .zero
    @State private var progressSheetHeight: CGFloat = .zero
    @State private var shouldSendAfterUnsupportedSheetDismisses = false
    // Wide-layout editor height. `@ScaledMetric` scales it with Dynamic Type so the
    // inline controls row (semantic fonts) doesn't crowd the text at large sizes.
    @ScaledMetric private var editorHeight: CGFloat = 502

    var body: some View {
        let usesWideLayout = AppLayout.usesWideLayout(horizontalSizeClass: horizontalSizeClass)

        VStack(spacing: usesWideLayout ? 16 : 12) {
            if usesWideLayout {
                DeviceNamePill(name: viewModel.deviceName)
            }

            TextEditorCard(
                text: $viewModel.text,
                characterCount: viewModel.characterCount,
                inlineUnsupportedMessage: viewModel.inlineUnsupportedMessage,
                borderColor: borderColor,
                borderLineWidth: usesWideLayout ? 1 : 2
            ) {
                controls
            }
            // A max (not fixed) height so the card renders at `editorHeight` when
            // there's room but still compresses when the keyboard shrinks the safe
            // area — a fixed height would refuse to shrink and get clipped.
            .frame(maxHeight: usesWideLayout ? editorHeight : nil)
            .padding(.top, usesWideLayout ? 0 : 2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, usesWideLayout ? 10 : 0)
        .background(Color.groupedBackground.ignoresSafeArea())
        .overlay(alignment: .center) {
            if viewModel.showSentToast {
                SentToastView(deviceName: viewModel.deviceName)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showSentToast)
        .sheet(isPresented: $viewModel.isShowingUnsupportedPrompt, onDismiss: sendAfterUnsupportedSheetDismissesIfNeeded) {
            unsupportedCharactersSheet
                .measureHeight($unsupportedSheetHeight)
                .presentationBackground(Color(uiColor: .systemBackground))
                .presentationDetents(sheetDetents(for: unsupportedSheetHeight))
                .presentationBackgroundInteraction(.disabled)
        }
        .sheet(item: $viewModel.progress) { _ in
            progressSheet
                .measureHeight($progressSheetHeight)
                .presentationBackground(Color(uiColor: .systemBackground))
                .presentationDetents(sheetDetents(for: progressSheetHeight))
                .interactiveDismissDisabled(viewModel.isSending)
                .presentationBackgroundInteraction(.disabled)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(CSKeyboardLayout.allCases, id: \.self) { layout in
                    Button(layout.title) {
                        viewModel.selectedLayout = layout
                    }
                }
            } label: {
                menuPillLabel(viewModel.selectedLayout.title)
            }

            Menu {
                ForEach(CSTypingOS.allCases) { os in
                    Button(os.title) {
                        viewModel.selectedOS = os
                    }
                }
            } label: {
                menuPillLabel(viewModel.selectedOS.title)
            }

            // On iPad the send button lives here, next to the pickers, instead of the
            // navigation bar (matches Figma).
            if AppLayout.usesWideLayout(horizontalSizeClass: horizontalSizeClass) {
                Spacer(minLength: 8)
                SendButton(canSend: viewModel.canSend, isSending: viewModel.isSending) {
                    viewModel.requestSend()
                }
            }
        }
    }

    private func menuPillLabel(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.footnote.weight(.medium))
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Capsule(style: .continuous).fill(Color(uiColor: .systemGray5)))
    }

    private var unsupportedCharactersSheet: some View {
        TextEntryWarningSheet(
            title: "Unsupported characters",
            message: viewModel.unsupportedPromptMessage ?? "Some characters can't be typed with the selected layout. They will be skipped.",
            secondaryTitle: "Send anyway",
            secondaryAction: sendAnywayAfterUnsupportedSheetDismisses,
            primaryTitle: "Change layout",
            primaryAction: viewModel.dismissUnsupportedPrompt
        )
    }

    private var progressSheet: some View {
        TextEntryProgressSheet(
            progress: viewModel.progress,
            cancelAction: viewModel.cancelSend,
            dismissAction: viewModel.dismissProgressSheet
        )
    }

    private func sendAnywayAfterUnsupportedSheetDismisses() {
        shouldSendAfterUnsupportedSheetDismisses = true
        viewModel.dismissUnsupportedPrompt()
    }

    private func sendAfterUnsupportedSheetDismissesIfNeeded() {
        guard shouldSendAfterUnsupportedSheetDismisses else { return }
        shouldSendAfterUnsupportedSheetDismisses = false
        viewModel.sendAnyway()
    }

    private var borderColor: Color {
        viewModel.hasUnsupportedCharacters ? Color.red : Color.accentBlue
    }
}

// MARK: - Text Editor Card

private struct TextEditorCard<Controls: View>: View {
    @Binding var text: String
    let characterCount: Int
    let inlineUnsupportedMessage: String?
    let borderColor: Color
    let borderLineWidth: CGFloat
    @ViewBuilder let controls: Controls

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.body)

                    Text("Type or paste text to send...")
                        .foregroundStyle(.secondary.opacity(0.5))
                        .font(.body)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .opacity(text.isEmpty ? 1 : 0)
                }.padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)

                controls
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(borderColor, lineWidth: borderLineWidth)
            }
            .accessibilityLabel(String(localized: "Text to send", comment: "Text editor accessibility label"))
            .accessibilityValue(text.isEmpty
                ? String(localized: "Empty", comment: "Empty text field value")
                : String(localized: "\(characterCount) characters", comment: "Text field character count"))

            if let message = inlineUnsupportedMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Device Name Pill

/// Outlined capsule showing the selected device name above the editor in the wide
/// (iPad / Catalyst) layout, where the navigation bar no longer carries the title.
private struct DeviceNamePill: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.groupedBackground)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color(uiColor: .separator), lineWidth: 1)
            }
            .accessibilityLabel(String(localized: "Selected device", comment: "Selected device label accessibility"))
            .accessibilityValue(name)
    }
}
