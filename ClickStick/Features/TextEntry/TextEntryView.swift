//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI

struct TextEntryView: View {
    @Bindable var viewModel: TextEntryViewModel
    @FocusState private var isTextFieldFocused: Bool
    @State private var unsupportedSheetHeight: CGFloat = .zero
    @State private var progressSheetHeight: CGFloat = .zero
    @State private var connectionLostSheetHeight: CGFloat = .zero

    var body: some View {
        VStack(spacing: Spacing.sm) {
            textEditor
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xl)
        .background(Color.clickStickGroupedBackground)
        .overlay(alignment: .center) {
            if viewModel.showSentToast {
                sentToast
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: Motion.regular), value: viewModel.showSentToast)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: "Done", comment: "Dismiss keyboard button")) {
                    isTextFieldFocused = false
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.unsupportedPrompt != nil },
            set: { if !$0 { viewModel.dismissUnsupportedPrompt() } }
        )) {
            unsupportedCharactersSheet
                .measureHeight($unsupportedSheetHeight)
                .presentationBackground(Color.clickStickElevatedBackground)
                .presentationDetents(unsupportedSheetDetents)
                .presentationBackgroundInteraction(.disabled)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.progress != nil },
            set: { if !$0 { viewModel.dismissProgressSheet() } }
        )) {
            progressSheet
                .measureHeight($progressSheetHeight)
                .presentationBackground(Color.clickStickElevatedBackground)
                .presentationDetents(progressSheetDetents)
                .interactiveDismissDisabled(viewModel.isSending)
                .presentationBackgroundInteraction(.disabled)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showConnectionLost },
            set: { if !$0 { viewModel.dismissConnectionLost() } }
        )) {
            connectionLostSheet
                .measureHeight($connectionLostSheetHeight)
                .presentationBackground(Color.clickStickElevatedBackground)
                .presentationDetents(connectionLostSheetDetents)
                .presentationBackgroundInteraction(.disabled)
        }
    }

    private var textEditor: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ZStack(alignment: .bottomLeading) {
                TextEditor(text: $viewModel.text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl)

                if viewModel.text.isEmpty {
                    VStack {
                        HStack {
                            Text("Type or paste text to send...")
                                .font(.body)
                                .foregroundStyle(.secondary.opacity(OpacityLevel.disabled))
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.xl)
                            Spacer()
                        }
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }

                controls
                    .padding(.leading, Spacing.md)
                    .padding(.bottom, Spacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.clickStickCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .stroke(borderColor, lineWidth: BorderWidth.thick)
            )
            .accessibilityLabel(String(localized: "Text to send", comment: "Text editor accessibility label"))
            .accessibilityValue(viewModel.isEmpty
                ? String(localized: "Empty", comment: "Empty text field value")
                : String(localized: "\(viewModel.characterCount) characters", comment: "Text field character count"))

            if let message = viewModel.inlineUnsupportedMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.clickStickDestructive)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xxs)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: Spacing.xs) {
            Picker("Keyboard Layout", selection: $viewModel.selectedLayout) {
                ForEach(CSKeyboardLayout.allCases, id: \.self) { layout in
                    Text(layout.description.replacingOccurrences(of: " - ", with: "-"))
                        .tag(layout)
                }
            }
            .pickerStyle(.menu)

            Picker("Target OS", selection: $viewModel.selectedOS) {
                ForEach(TypingOS.allCases) { os in
                    Text(os.title).tag(os)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var sentToast: some View {
        Label("Sent to \(viewModel.deviceName)", systemImage: "checkmark.circle")
            .font(.body.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Capsule(style: .continuous).fill(Color.black))
            .accessibilityElement(children: .combine)
    }

    private var unsupportedCharactersSheet: some View {
        TextEntryWarningSheet(
            title: "Unsupported characters",
            message: viewModel.unsupportedPromptMessage ?? "Some characters can’t be typed with the selected layout. They will be skipped.",
            secondaryTitle: "Send anyway",
            secondaryAction: viewModel.sendAnyway,
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
            primaryAction: viewModel.retryAfterConnectionLost
        )
    }

    private var progressSheet: some View {
        TextEntryProgressSheet(
            progress: viewModel.progress,
            cancelAction: viewModel.cancelSend,
            dismissAction: viewModel.dismissProgressSheet
        )
    }

    private var borderColor: Color {
        viewModel.hasUnsupportedCharacters ? Color.clickStickDestructive : Color.clickStickBlue
    }

    private var unsupportedSheetDetents: Set<PresentationDetent> {
        sheetDetents(for: unsupportedSheetHeight)
    }

    private var progressSheetDetents: Set<PresentationDetent> {
        sheetDetents(for: progressSheetHeight)
    }

    private var connectionLostSheetDetents: Set<PresentationDetent> {
        sheetDetents(for: connectionLostSheetHeight)
    }

    private func sheetDetents(for height: CGFloat) -> Set<PresentationDetent> {
        height > .zero ? [.height(height)] : [.medium]
    }

}

private struct TextEntryWarningSheet: View {
    let title: LocalizedStringKey
    let message: String
    let secondaryTitle: LocalizedStringKey
    let secondaryAction: () -> Void
    let primaryTitle: LocalizedStringKey
    let primaryAction: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.circle")
                .font(.largeTitle)
                .foregroundStyle(Color.clickStickDestructive)
                .padding(Spacing.lg)
                .background(Circle().fill(Color.clickStickDestructive.opacity(OpacityLevel.subtleFill)))
                .accessibilityHidden(true)

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextEntrySheetButtonRow(
                secondaryTitle: secondaryTitle,
                secondaryAction: secondaryAction,
                primaryTitle: primaryTitle,
                primaryAction: primaryAction
            )
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

private struct TextEntryProgressSheet: View {
    let progress: TextEntryViewModel.ProgressState?
    let cancelAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            if let progress {
                switch progress {
                case .sending(let sent, let total):
                    progressContent(sent: sent, total: total)
                case .stopped(let sent, let total):
                    progressContent(sent: sent, total: total, stopped: true)
                case .sent:
                    VStack(spacing: Spacing.lg) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.clickStickGreen)
                            .accessibilityHidden(true)
                        Text("Sent!")
                            .font(.title.bold())
                    }
                    .padding(.vertical, Spacing.xxxl)
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xxxl)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func progressContent(sent: Int, total: Int, stopped: Bool = false) -> some View {
        VStack(spacing: Spacing.xl) {
            Text("Sending...")
                .font(.title.bold())

            ProgressView(value: total == 0 ? 0 : Double(sent) / Double(total))
                .tint(Color.clickStickBlue)
                .accessibilityLabel(String(localized: "Sending text", comment: "Send progress accessibility"))

            Text("\(sent) of \(total) characters")
                .font(.title3)
                .foregroundStyle(.secondary)

            if stopped {
                Text("Stopped at \(sent) of \(total). Some text may have appeared on the host device.")
                    .font(.body)
                    .foregroundStyle(Color.clickStickDestructive)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(Color.clickStickDestructive.opacity(OpacityLevel.faintFill))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(Color.clickStickDestructive.opacity(OpacityLevel.subtleBorder), lineWidth: BorderWidth.thin)
                    )
            }

            Button(stopped ? "Close" : "Cancel") {
                if stopped {
                    dismissAction()
                } else {
                    cancelAction()
                }
            }
            .buttonStyle(.secondary(tint: .primary))
        }
    }
}

private struct TextEntrySheetButtonRow: View {
    let secondaryTitle: LocalizedStringKey
    let secondaryAction: () -> Void
    let primaryTitle: LocalizedStringKey
    let primaryAction: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.md) {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.secondary(tint: .primary))

                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.primary)
            }

            VStack(spacing: Spacing.sm) {
                Button(primaryTitle, action: primaryAction)
                    .buttonStyle(.primary)

                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(.secondary(tint: .primary))
            }
        }
    }
}

private func sheetDetents(for height: CGFloat) -> Set<PresentationDetent> {
    height > .zero ? [.height(height)] : [.medium]
}

private extension View {
    func measureHeight(_ height: Binding<CGFloat>) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size.height, initial: true) { _, newHeight in
                        height.wrappedValue = newHeight
                    }
            }
        }
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
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xl)

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
            .tint(.clickStickBlue)
            .toolbarBackground(Color.clickStickGroupedBackground, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
        }
        .clickStickScreenBackground()
        .sheet(isPresented: $isPreviewSheetPresented) {
            if let previewSheet {
                previewSheetContent(previewSheet)
                    .measureHeight($previewSheetHeight)
                    .presentationDetents(sheetDetents(for: previewSheetHeight))
                    .presentationBackground(Color.clickStickElevatedBackground)
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
