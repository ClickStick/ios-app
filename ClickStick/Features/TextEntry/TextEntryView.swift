//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct TextEntryView: View {
    @State private var viewModel: TextEntryViewModel
    @FocusState private var isTextFieldFocused: Bool

    init(device: DeviceModel) {
        self._viewModel = State(wrappedValue: TextEntryViewModel(device: device))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Spacing.md) {
                    keyboardLayoutPicker
                    textEditor
                    presetButtons
                    sendButton
                        .id("sendButton")
                }
                .padding(Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: isTextFieldFocused) { _, isFocused in
                if isFocused {
                    // Scroll to send button when keyboard appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            proxy.scrollTo("sendButton", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTextFieldFocused = false
                }
            }
        }
        .errorAlert($viewModel.alertError)
    }

    // MARK: - Keyboard Layout Picker

    private var keyboardLayoutPicker: some View {
        KeyboardLayoutPicker(selection: $viewModel.selectedLayout)
    }

    // MARK: - Text Editor

    private var textEditor: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "keyboard")
                    .foregroundStyle(Color.clickStickBlue)
                Text("Text to type")
                    .font(.headline)
            }
            .accessibilityAddTraits(.isHeader)

            TextEditor(text: $viewModel.text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 140, maxHeight: 220)
                .scrollContentBackground(.hidden)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.secondary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(
                            isTextFieldFocused ? Color.clickStickBlue : Color.secondary.opacity(0.2),
                            lineWidth: isTextFieldFocused ? 2 : 1
                        )
                )
                .focused($isTextFieldFocused)
                .animation(.easeInOut(duration: 0.2), value: isTextFieldFocused)
                .accessibilityLabel("Text to send")
                .accessibilityHint("Enter the text you want to type on the connected device")
                .accessibilityValue(viewModel.isEmpty
                    ? String(localized: "Empty", comment: "Empty text field value")
                    : String(localized: "\(viewModel.characterCount) characters"))

            HStack {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "character.cursor.ibeam")
                        .font(.caption2)
                    Text("\(viewModel.characterCount) characters")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                Spacer()

                if !viewModel.isEmpty {
                    Button {
                        withAnimation {
                            viewModel.clearText()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear text")
                }
            }
        }
    }

    // MARK: - Preset Buttons

    private var presetButtons: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color.clickStickOrange)
                Text("Quick Presets")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(TextPreset.allCases) { preset in
                        Button {
                            viewModel.setPreset(preset)
                        } label: {
                            Text(preset.title)
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.secondary)
                        .accessibilityLabel("Insert \(preset.title)")
                        .accessibilityHint("Replaces current text")
                    }
                }
            }
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            isTextFieldFocused = false
            viewModel.sendText()
        } label: {
            HStack(spacing: Spacing.xs) {
                if viewModel.isSending {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(viewModel.sendButtonTitle)
            }
        }
        .buttonStyle(.primary)
        .disabled(!viewModel.canSend)
        .accessibilityLabel(viewModel.isSending
            ? String(localized: "Sending text")
            : String(localized: "Send text to device"))
        .accessibilityHint(viewModel.buttonAccessibilityHint)
    }
}

// MARK: - Preview

#Preview {
    TextEntryView(device: .preview)
}