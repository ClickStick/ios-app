//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI

struct TextEntryView: View {
    @State private var viewModel: TextEntryViewModel
    @Environment(\.appRouter) private var router
    @FocusState private var isTextFieldFocused: Bool

    init(device: DeviceModel, premiumService: PremiumService) {
        _viewModel = State(
            initialValue: TextEntryViewModel(device: device, premiumService: premiumService)
        )
    }

    var body: some View {
        content(viewModel)
    }

    @ViewBuilder
    private func content(_ viewModel: TextEntryViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Spacing.md) {
                    layoutRow(viewModel)
                    textEditor(viewModel)
                    presetButtons(viewModel)
                    sendSection(viewModel)
                        .id("sendButton")
                }
                .padding(Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: isTextFieldFocused) { _, isFocused in
                if isFocused {
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
                Button(String(localized: "Done", comment: "Dismiss keyboard button")) {
                    isTextFieldFocused = false
                }
            }
        }
        .errorAlert(Binding(
            get: { viewModel.alertError },
            set: { viewModel.alertError = $0 }
        ))
        .sheet(isPresented: Binding(
            get: { viewModel.showPaywallAfterSend },
            set: { viewModel.showPaywallAfterSend = $0 }
        )) {
            PaywallView()
        }
    }

    // MARK: - Layout Row

    private func layoutRow(_ viewModel: TextEntryViewModel) -> some View {
        HStack {
            Label("Keyboard Layout", systemImage: "globe")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Keyboard Layout", selection: Binding(
                get: { viewModel.selectedLayout },
                set: { viewModel.selectedLayout = $0 }
            )) {
                ForEach(CSKeyboardLayout.allCases, id: \.self) { layout in
                    Text(layout.description).tag(layout)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Text Editor

    private func textEditor(_ viewModel: TextEntryViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "keyboard")
                    .foregroundStyle(Color.clickStickBlue)
                    .accessibilityHidden(true)
                Text("Text to type", comment: "Text entry section header")
                    .font(.headline)
            }
            .accessibilityAddTraits(.isHeader)

            TextEditor(text: Binding(
                get: { viewModel.text },
                set: { viewModel.text = $0 }
            ))
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
                .accessibilityLabel(String(localized: "Text to send", comment: "Text editor accessibility label"))
                .accessibilityHint(String(localized: "Enter the text you want to type on the connected device", comment: "Text editor accessibility hint"))
                .accessibilityValue(viewModel.isEmpty
                    ? String(localized: "Empty", comment: "Empty text field value")
                    : String(localized: "\(viewModel.characterCount) characters", comment: "Text field character count"))

            HStack {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "character.cursor.ibeam")
                        .font(.caption2)
                    Text("\(viewModel.characterCount) characters", comment: "Character count label")
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
                            Text("Clear", comment: "Clear text button")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(String(localized: "Clear text", comment: "Clear text button accessibility"))
                }
            }
        }
    }

    // MARK: - Preset Buttons

    private func presetButtons(_ viewModel: TextEntryViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color.clickStickOrange)
                    .accessibilityHidden(true)
                Text("Quick Presets", comment: "Quick presets section header")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.xs) {
                ForEach(TextPreset.allCases) { preset in
                    Button {
                        viewModel.setPreset(preset)
                    } label: {
                        Text(preset.title)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.secondary)
                    .accessibilityLabel(String(localized: "Insert \(preset.title)", comment: "Preset button accessibility"))
                    .accessibilityHint(String(localized: "Replaces current text", comment: "Preset button hint"))
                }
            }
        }
    }

    // MARK: - Send Section (quota indicator + send button)

    private func sendSection(_ viewModel: TextEntryViewModel) -> some View {
        VStack(spacing: Spacing.sm) {
            if viewModel.showsQuotaIndicator {
                quotaIndicator(viewModel)
            }

            if viewModel.isSending && viewModel.isThrottled {
                // Human speed: Cancel button takes the send button's place, progress bar below
                VStack(spacing: Spacing.xs) {
                    Button {
                        viewModel.cancelSend()
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Cancel", comment: "Cancel send button")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary)
                    .accessibilityLabel(String(localized: "Cancel sending", comment: "Cancel send accessibility"))

                    if let progress = viewModel.sendingProgress {
                        VStack(spacing: Spacing.xxs) {
                            ProgressView(value: progress)
                                .tint(Color.clickStickOrange)
                            Text("Sending at human speed... \(Int(progress * 100))%", comment: "Throttled send progress")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                // Instant send or idle: show the send button, briefly disabled during instant send
                Button {
                    isTextFieldFocused = false
                    viewModel.sendText()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: viewModel.sendButtonIcon)
                        Text(viewModel.sendButtonTitle)
                    }
                }
                .buttonStyle(.primary)
                .disabled(!viewModel.canSend)
                .accessibilityLabel(String(localized: "Send text to device", comment: "Send button accessibility"))
                .accessibilityHint(viewModel.buttonAccessibilityHint)
            }
        }
    }

    // MARK: - Quota Indicator

    private func quotaIndicator(_ viewModel: TextEntryViewModel) -> some View {
        Button {
            router.showPaywall()
        } label: {
            VStack(spacing: Spacing.xs) {
                HStack {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: viewModel.isThrottled ? "tortoise.fill" : "bolt.fill")
                            .font(.caption2)
                            .accessibilityHidden(true)
                        Text(viewModel.quotaStatusText)
                            .font(.caption)
                    }
                    .foregroundStyle(viewModel.isThrottled ? .orange : .secondary)

                    Spacer()

                    HStack(spacing: 2) {
                        Text("Upgrade", comment: "Upgrade link label")
                            .font(.caption.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.clickStickBlue)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))

                        Capsule()
                            .fill(viewModel.isThrottled
                                ? Color.orange
                                : Color.clickStickGreen)
                            .frame(width: max(0, geometry.size.width * viewModel.quotaProgress))
                    }
                }
                .frame(height: 4)
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.secondary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.quotaAccessibilityLabel)
    }
}

// MARK: - Preview

#Preview {
    TextEntryView(
        device: .preview,
        premiumService: PremiumService(defaults: .standard, autoSyncStoreKit: false)
    )
}
