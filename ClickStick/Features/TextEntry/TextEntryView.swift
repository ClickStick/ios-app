//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct TextEntryView: View {
    @Bindable var viewModel: TextEntryViewModel
    @FocusState private var isTextFieldFocused: Bool

    init(device: DeviceModel) {
        self._viewModel = Bindable(wrappedValue: TextEntryViewModel(device: device))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    keyboardLayoutPicker
                    textEditor
                    presetButtons
                    sendButton
                        .id("sendButton")
                }
                .padding()
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Text to type")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            TextEditor(text: $viewModel.text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120, maxHeight: 200)
                .scrollContentBackground(.hidden)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .focused($isTextFieldFocused)
                .accessibilityLabel("Text to send")
                .accessibilityHint("Enter the text you want to type on the connected device")
                .accessibilityValue(viewModel.isEmpty
                    ? String(localized: "Empty", comment: "Empty text field value")
                    : String(localized: "\(viewModel.characterCount) characters"))

            HStack {
                Text("\(viewModel.characterCount) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !viewModel.isEmpty {
                    Button("Clear") {
                        withAnimation {
                            viewModel.clearText()
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear text")
                }
            }
        }
    }

    // MARK: - Preset Buttons

    private var presetButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Presets")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TextPreset.allCases) { preset in
                        Button {
                            viewModel.setPreset(preset)
                        } label: {
                            Text(preset.title)
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
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
            HStack {
                if viewModel.isSending {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(viewModel.sendButtonTitle)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
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

