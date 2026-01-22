//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct TextEntryView: View {
    let device: DeviceModel

    @State private var text: String = ""
    @State private var selectedLayout: CSKeyboardLayout = .usQWERTY
    @State private var isSending: Bool = false
    @State private var lastError: String?

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            keyboardLayoutPicker
            textEditor
            presetButtons
            sendButton

            if let error = lastError {
                errorBanner(error)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            selectedLayout = detectSystemLayout()
        }
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

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120, maxHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .focused($isTextFieldFocused)
                .accessibilityLabel("Text to send")
                .accessibilityHint("Enter the text you want to type on the connected device")

            Text("\(text.count) characters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Preset Buttons

    private var presetButtons: some View {
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
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(isSending ? "Sending..." : "Send Text")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(text.isEmpty || isSending || !device.isConnected)
        .accessibilityLabel(isSending ? "Sending text" : "Send text to device")
        .accessibilityHint(text.isEmpty ? "Enter text first" : "Double-tap to send")
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
            Spacer()
            Button("Dismiss") {
                lastError = nil
            }
            .font(.caption)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func sendText() {
        guard !text.isEmpty, device.isConnected else { return }

        isSending = true
        lastError = nil
        isTextFieldFocused = false

        device.sendText(text, layout: selectedLayout) { result in
            isSending = false
            switch result {
            case .success:
                // Optionally clear text after successful send
                break
            case .failure(let error):
                lastError = error.localizedDescription
            }
        }
    }

    private func detectSystemLayout() -> CSKeyboardLayout {
        guard let languageCode = Locale.current.language.languageCode?.identifier else {
            return .usQWERTY
        }

        switch languageCode {
        case "de":
            return .deQWERTZ
        case "fr":
            return .frAZERTY_Classic
        default:
            return .usQWERTY
        }
    }
}

