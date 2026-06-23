//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct TextEntryView: View {
    @Bindable var viewModel: TextEntryViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var unsupportedSheetHeight: CGFloat = .zero
    @State private var progressSheetHeight: CGFloat = .zero
    @State private var shouldSendAfterUnsupportedSheetDismisses = false

    var body: some View {
        VStack(spacing: 12) {
            TextEditorCard(
                text: $viewModel.text,
                isFocused: $isTextFieldFocused,
                characterCount: viewModel.characterCount,
                inlineUnsupportedMessage: viewModel.inlineUnsupportedMessage,
                borderColor: borderColor
            ) {
                controls
            }
            .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .background(Color.groupedBackground.ignoresSafeArea())
        .overlay(alignment: .center) {
            if viewModel.showSentToast {
                sentToast
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showSentToast)
        .task { isTextFieldFocused = true }
        .sheet(isPresented: $viewModel.isShowingUnsupportedPrompt, onDismiss: sendAfterUnsupportedSheetDismissesIfNeeded) {
            unsupportedCharactersSheet
                .measureHeight($unsupportedSheetHeight)
                .presentationBackground(Color(.systemBackground))
                .presentationDetents(sheetDetents(for: unsupportedSheetHeight))
                .presentationBackgroundInteraction(.disabled)
        }
        .sheet(item: $viewModel.progress) { _ in
            progressSheet
                .measureHeight($progressSheetHeight)
                .presentationBackground(Color(.systemBackground))
                .presentationDetents(sheetDetents(for: progressSheetHeight))
                .interactiveDismissDisabled(viewModel.isSending)
                .presentationBackgroundInteraction(.disabled)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(CSKeyboardLayout.allCases, id: \.self) { layout in
                    Button(layout.description.replacing(" - ", with: "-")) {
                        viewModel.selectedLayout = layout
                    }
                }
            } label: {
                menuPillLabel(viewModel.selectedLayout.description.replacing(" - ", with: "-"))
            }

            Menu {
                ForEach(TypingOS.allCases) { os in
                    Button(os.title) {
                        viewModel.selectedOS = os
                    }
                }
            } label: {
                menuPillLabel(viewModel.selectedOS.title)
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
        .background(Capsule(style: .continuous).fill(Color(.systemGray5)))
    }

    private var sentToast: some View {
        Label("Sent to \(viewModel.deviceName)", systemImage: "checkmark.circle")
            .font(.body.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Capsule(style: .continuous).fill(Color.black))
            .accessibilityElement(children: .combine)
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
    @FocusState.Binding var isFocused: Bool
    let characterCount: Int
    let inlineUnsupportedMessage: String?
    let borderColor: Color
    @ViewBuilder let controls: Controls

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 40)

                if text.isEmpty {
                    VStack {
                        HStack {
                            Text("Type or paste text to send...")
                                .font(.body)
                                .foregroundStyle(.secondary.opacity(0.5))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                            Spacer()
                        }
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }

                controls
                    .padding(.leading, 16)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(borderColor, lineWidth: 2)
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
