//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct TextEntryView: View {
    let device: DeviceModel

    @State private var text: String = ""
    @State private var selectedLayout: CSKeyboardLayout = .usQWERTY
    @State private var isSending: Bool = false
    @State private var alertError: AlertError?

    @FocusState private var isTextFieldFocused: Bool

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
        .onAppear {
            selectedLayout = CSKeyboardLayout.fromSystemLocale()
        }
        .errorAlert($alertError)
    }

    // MARK: - Keyboard Layout Picker

    private var keyboardLayoutPicker: some View {
        KeyboardLayoutPicker(selection: $selectedLayout)
    }

    // MARK: - Text Editor

    private var textEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text to type")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            TextEditor(text: $text)
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
                .accessibilityValue(text.isEmpty
                    ? String(localized: "Empty", comment: "Empty text field value")
                    : String(localized: "\(text.count) characters"))

            HStack {
                Text("\(text.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !text.isEmpty {
                    Button("Clear") {
                        withAnimation {
                            text = ""
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
                            text = preset.text
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
            sendText()
        } label: {
            HStack {
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(isSending
                    ? String(localized: "Sending...", comment: "Sending in progress")
                    : String(localized: "Send Text"))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(text.isEmpty || isSending || !device.isConnected)
        .accessibilityLabel(isSending
            ? String(localized: "Sending text")
            : String(localized: "Send text to device"))
        .accessibilityHint(buttonAccessibilityHint)
    }

    private var buttonAccessibilityHint: String {
        if text.isEmpty {
            return String(localized: "Enter text first")
        } else if !device.isConnected {
            return String(localized: "Device not connected", comment: "Accessibility hint")
        } else if isSending {
            return String(localized: "Please wait", comment: "Accessibility hint")
        } else {
            return String(localized: "Double-tap to send \(text.count) characters", comment: "Accessibility hint")
        }
    }

    // MARK: - Actions

    private func sendText() {
        guard !text.isEmpty, device.isConnected else { return }

        isSending = true
        isTextFieldFocused = false

        device.sendText(text, layout: selectedLayout) { result in
            isSending = false
            switch result {
            case .success:
                // Text sent successfully
                break
            case .failure(let error):
                alertError = AlertError(error: error)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TextEntryView(device: .preview)
}

