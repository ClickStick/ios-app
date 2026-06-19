//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct TextEntryView: View {
    @Bindable var viewModel: TextEntryViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var unsupportedSheetHeight: CGFloat = .zero
    @State private var progressSheetHeight: CGFloat = .zero
    @State private var connectionLostSheetHeight: CGFloat = .zero
    @State private var shouldSendAfterUnsupportedSheetDismisses = false

    var body: some View {
        VStack(spacing: 12) {
            textEditor
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
        .onAppear(perform: focusTextEditor)
        .sheet(isPresented: Binding(
            get: { viewModel.unsupportedPrompt != nil },
            set: { if !$0 { viewModel.dismissUnsupportedPrompt() } }
        ), onDismiss: sendAfterUnsupportedSheetDismissesIfNeeded) {
            unsupportedCharactersSheet
                .measureHeight($unsupportedSheetHeight)
                .presentationBackground(Color(.systemBackground))
                .presentationDetents(sheetDetents(for: unsupportedSheetHeight))
                .presentationBackgroundInteraction(.disabled)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.progress != nil },
            set: { if !$0 { viewModel.dismissProgressSheet() } }
        )) {
            progressSheet
                .measureHeight($progressSheetHeight)
                .presentationBackground(Color(.systemBackground))
                .presentationDetents(sheetDetents(for: progressSheetHeight))
                .interactiveDismissDisabled(viewModel.isSending)
                .presentationBackgroundInteraction(.disabled)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showConnectionLost },
            set: { if !$0 { viewModel.dismissConnectionLost() } }
        )) {
            connectionLostSheet
                .measureHeight($connectionLostSheetHeight)
                .presentationBackground(Color(.systemBackground))
                .presentationDetents(sheetDetents(for: connectionLostSheetHeight))
                .presentationBackgroundInteraction(.disabled)
        }
    }

    private func focusTextEditor() {
        DispatchQueue.main.async {
            isTextFieldFocused = true
        }
    }

    private var textEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                TextEditor(text: $viewModel.text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 40)

                if viewModel.text.isEmpty {
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
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(borderColor, lineWidth: 2)
            )
            .accessibilityLabel(String(localized: "Text to send", comment: "Text editor accessibility label"))
            .accessibilityValue(viewModel.isEmpty
                ? String(localized: "Empty", comment: "Empty text field value")
                : String(localized: "\(viewModel.characterCount) characters", comment: "Text field character count"))

            if let message = viewModel.inlineUnsupportedMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color(.systemRed))
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(CSKeyboardLayout.allCases, id: \.self) { layout in
                    Button(layout.description.replacingOccurrences(of: " - ", with: "-")) {
                        viewModel.selectedLayout = layout
                    }
                }
            } label: {
                menuPillLabel(viewModel.selectedLayout.description.replacingOccurrences(of: " - ", with: "-"))
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

    private var connectionLostSheet: some View {
        TextEntryWarningSheet(
            title: "Connection lost",
            message: "Bluetooth disconnected.\nCheck your device and try again.",
            secondaryTitle: "Close",
            secondaryAction: viewModel.dismissConnectionLost,
            primaryTitle: "Try again",
            primaryAction: viewModel.retryAfterConnectionLost,
            primaryIsDisabled: !viewModel.canSend
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
        viewModel.hasUnsupportedCharacters ? Color(.systemRed) : Color.accentBlue
    }
}

// MARK: - Preview

#Preview("Typing") {
    let viewModel = TextEntryViewModel(device: PreviewTextEntryDevice())
    return PreviewTextEntryShell(viewModel: viewModel)
}

#Preview("Sent Toast") {
    let viewModel = TextEntryViewModel(device: PreviewTextEntryDevice())
    viewModel.configureForPreview(isToastVisible: true)
    return PreviewTextEntryShell(viewModel: viewModel)
}

#Preview("Unsupported") {
    let viewModel = TextEntryViewModel(device: PreviewTextEntryDevice())
    viewModel.configureForPreview(text: "admin Щ", presentsSheets: false)
    return PreviewTextEntryShell(viewModel: viewModel, previewSheet: .unsupported)
}

#Preview("Sending") {
    let viewModel = TextEntryViewModel(device: PreviewTextEntryDevice())
    viewModel.configureForPreview(text: "admin@company.local", presentsSheets: false)
    return PreviewTextEntryShell(viewModel: viewModel, previewSheet: .sending(sent: 250, total: 300))
}

#Preview("Stopped") {
    let viewModel = TextEntryViewModel(device: PreviewTextEntryDevice())
    viewModel.configureForPreview(text: "admin@company.local", presentsSheets: false)
    return PreviewTextEntryShell(viewModel: viewModel, previewSheet: .stopped(sent: 87, total: 300))
}

#Preview("Sent Sheet") {
    let viewModel = TextEntryViewModel(device: PreviewTextEntryDevice())
    viewModel.configureForPreview(text: "admin@company.local", presentsSheets: false)
    return PreviewTextEntryShell(viewModel: viewModel, previewSheet: .sent)
}

#Preview("Connection Lost") {
    let viewModel = TextEntryViewModel(device: PreviewTextEntryDevice())
    viewModel.configureForPreview(text: "admin@company.local", presentsSheets: false)
    return PreviewTextEntryShell(viewModel: viewModel, previewSheet: .connectionLost)
}

#if DEBUG
private final class PreviewTextEntryDevice: TextSendingDevice {
    let displayName = "ClickStick 9F8C"
    let isConnected = true

    func sendText(_ text: String, layout: CSKeyboardLayout) async throws {}

    func sendText(
        _ text: String,
        layout: CSKeyboardLayout,
        onCharacterProgress: @escaping @MainActor (_ sent: Int, _ total: Int) -> Void
    ) async throws {
        await onCharacterProgress(text.count, text.count)
    }
}

private enum PreviewSheet {
    case unsupported
    case sending(sent: Int, total: Int)
    case stopped(sent: Int, total: Int)
    case sent
    case connectionLost
}

private struct PreviewTextEntryShell: View {
    @State var viewModel: TextEntryViewModel
    let previewSheet: PreviewSheet?
    @State private var isPreviewSheetPresented: Bool
    @State private var previewSheetHeight: CGFloat = .zero

    init(viewModel: TextEntryViewModel, previewSheet: PreviewSheet? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.previewSheet = previewSheet
        _isPreviewSheetPresented = State(initialValue: previewSheet != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(viewModel.deviceName)
                    .font(.headline)
                HStack {
                    Button {} label: {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    Spacer()
                    Button {} label: {
                        Image(systemName: "arrow.up")
                            .font(.title2.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)

            TabView(selection: .constant(DeviceFeatureTab.textEntry)) {
                TextEntryView(viewModel: viewModel)
                    .tabItem {
                        Label("Text Entry", systemImage: DeviceFeatureTab.textEntry.icon)
                    }
                    .tag(DeviceFeatureTab.textEntry)

                Text("Snippets")
                    .tabItem {
                        Label("Snippets", systemImage: DeviceFeatureTab.snippets.icon)
                    }
                    .tag(DeviceFeatureTab.snippets)

                Text("Touchpad")
                    .tabItem {
                        Label("Touchpad", systemImage: DeviceFeatureTab.mouse.icon)
                    }
                    .tag(DeviceFeatureTab.mouse)
            }
            .tint(.accentBlue)
            .toolbarBackground(Color.groupedBackground, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
        }
        .background(Color.groupedBackground.ignoresSafeArea())
        .sheet(isPresented: $isPreviewSheetPresented) {
            if let previewSheet {
                previewSheetContent(previewSheet)
                    .measureHeight($previewSheetHeight)
                    .presentationDetents(sheetDetents(for: previewSheetHeight))
                    .presentationBackground(Color(.systemBackground))
            }
        }
    }

    @ViewBuilder
    private func previewSheetContent(_ sheet: PreviewSheet) -> some View {
        switch sheet {
        case .unsupported:
            TextEntryWarningSheet(
                title: "Unsupported characters",
                message: "Щ can't be typed with US-QWERTY. They will be skipped.",
                secondaryTitle: "Send anyway",
                secondaryAction: {},
                primaryTitle: "Change layout",
                primaryAction: {}
            )
        case .sending(let sent, let total):
            TextEntryProgressSheet(
                progress: .sending(sent: sent, total: total),
                cancelAction: {},
                dismissAction: {}
            )
        case .stopped(let sent, let total):
            TextEntryProgressSheet(
                progress: .stopped(sent: sent, total: total),
                cancelAction: {},
                dismissAction: {}
            )
        case .sent:
            TextEntryProgressSheet(
                progress: .sent,
                cancelAction: {},
                dismissAction: {}
            )
        case .connectionLost:
            TextEntryWarningSheet(
                title: "Connection lost",
                message: "Bluetooth disconnected.\nCheck your device and try again.",
                secondaryTitle: "Close",
                secondaryAction: {},
                primaryTitle: "Try again",
                primaryAction: {}
            )
        }
    }
}
#endif
