//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct DeviceDetailView: View {
    let device: DeviceModel

    @Environment(\.appRouter) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: DeviceFeatureTab = .textEntry
    @State private var textEntryViewModel: TextEntryViewModel
    @State private var mouseViewModel: MouseViewModel
    @State private var snippetsViewModel: SnippetsViewModel
    @State private var showConnectionLost = false
    @State private var connectionLostSheetHeight: CGFloat = .zero

    init(
        device: DeviceModel,
        urlOpener: (any URLOpening)? = nil,
        initialTab: DeviceFeatureTab = .textEntry,
        showsConnectionLost: Bool = false,
        previewText: String? = nil,
        previewIsSending: Bool = false,
        previewIsToastVisible: Bool = false,
        previewProgress: TextEntryViewModel.ProgressState? = nil,
        previewPresentsTextEntrySheets: Bool = false
    ) {
        self.device = device
        let textEntryViewModel = TextEntryViewModel(device: device, urlOpener: urlOpener)
#if DEBUG
        if previewText != nil || previewIsSending || previewIsToastVisible || previewProgress != nil || previewPresentsTextEntrySheets {
            textEntryViewModel.configureForPreview(
                text: previewText ?? "",
                isSending: previewIsSending,
                isToastVisible: previewIsToastVisible,
                progress: previewProgress,
                presentsSheets: previewPresentsTextEntrySheets
            )
        }
#endif
        _selectedTab = State(initialValue: initialTab)
        _textEntryViewModel = State(initialValue: textEntryViewModel)
        _mouseViewModel = State(initialValue: MouseViewModel(device: device))
        _snippetsViewModel = State(initialValue: SnippetsViewModel(device: device))
        _showConnectionLost = State(initialValue: showsConnectionLost)
    }

    var body: some View {
        // Read the send-button state here, in body, so the toolbar is rebuilt when it
        // changes. Toolbar content does not observe @Observable changes on its own — only
        // TextEntryView reads `text`, so without this the toolbar would never re-evaluate.
        let canSend = textEntryViewModel.canSend
        let isSending = textEntryViewModel.isSending

        let usesWideLayout = AppLayout.usesWideLayout(horizontalSizeClass: horizontalSizeClass)

        return content
            .background(Color.groupedBackground.ignoresSafeArea())
            .tint(.accentBlue)
            .navigationTitle(device.displayName)
            .navigationBarTitleDisplayMode(.inline)
            // On iPad the title moves to the pill above the editor and the send button is
            // inline, so the nav bar is empty — hide it entirely instead of leaving an empty
            // inline bar reserving ~44pt of space above the tab bar (doesn't match Figma).
            .toolbar(usesWideLayout ? .hidden : .automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    primaryToolbarAction(canSend: canSend, isSending: isSending)
                }
                .appHiddenSharedToolbarBackground()
            }
            .onChange(of: router.pendingSendTextRequest, initial: true) { _, request in
                applyPendingSendTextRequest(request)
            }
            .onChange(of: device.connectionState) { oldState, newState in
                handleConnectionStateChange(from: oldState, to: newState)
            }
            .onChange(of: textEntryViewModel.showConnectionLost) { _, isConnectionLost in
                if isConnectionLost && !device.didDisconnectIntentionally {
                    showConnectionLost = true
                }
            }
            .onChange(of: snippetsViewModel.showConnectionLost) { _, isConnectionLost in
                if isConnectionLost && !device.didDisconnectIntentionally {
                    showConnectionLost = true
                }
            }
            .sheet(isPresented: $showConnectionLost, onDismiss: dismissConnectionLost) {
                connectionLostSheet
                    .measureHeight($connectionLostSheetHeight)
                    .presentationBackground(Color(uiColor: .systemBackground))
                    .presentationDetents(sheetDetents(for: connectionLostSheetHeight))
                    .presentationBackgroundInteraction(.disabled)
            }
    }

    @ViewBuilder
    private func primaryToolbarAction(canSend: Bool, isSending: Bool) -> some View {
        switch selectedTab {
        case .textEntry:
            // On iPad the send button lives inline in the text entry card, next to the
            // layout/OS pickers, instead of the navigation bar (matches Figma).
            if !AppLayout.usesWideLayout(horizontalSizeClass: horizontalSizeClass) {
                SendButton(canSend: canSend, isSending: isSending) {
                    textEntryViewModel.requestSend()
                }
            }
        case .snippets:
            Button {
                snippetsViewModel.startNewSnippet()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(CircularToolbarButtonStyle(role: .prominent))
            .accessibilityLabel(String(localized: "Create snippet", comment: "Create snippet button accessibility"))
        case .mouse:
            EmptyView()
        }
    }

    /// On iPad the tab bar is the system-default floating top control (via `TabView`).
    /// On iPhone it stays the custom bottom `FloatingTabBar` to match the iPhone design.
    @ViewBuilder
    private var content: some View {
        if AppLayout.usesWideLayout(horizontalSizeClass: horizontalSizeClass) {
            TabView(selection: $selectedTab) {
                ForEach(DeviceFeatureTab.allCases) { tab in
                    Tab(tab.localizedTitle, systemImage: tab.icon, value: tab) {
                        tabContent(for: tab)
                    }
                    .defaultVisibility(.visible, for: .tabBar)
                }
            }
            .tabViewStyle(.tabBarOnly)
        } else {
            selectedTabContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    FloatingTabBar(items: tabBarItems, selection: $selectedTab)
                        .padding(.bottom, 12)
                }
        }
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        tabContent(for: selectedTab)
    }

    @ViewBuilder
    private func tabContent(for tab: DeviceFeatureTab) -> some View {
        switch tab {
        case .textEntry:
            TextEntryView(viewModel: textEntryViewModel)
        case .snippets:
            SnippetsListView(viewModel: snippetsViewModel)
                .ignoresSafeArea(.keyboard, edges: .bottom)
        case .mouse:
            MouseView(viewModel: mouseViewModel)
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    private var tabBarItems: [FloatingTabBarItem<DeviceFeatureTab>] {
        DeviceFeatureTab.allCases.map { tab in
            FloatingTabBarItem(
                id: tab,
                title: tab.localizedTitle,
                systemImage: tab.icon
            )
        }
    }

    private var connectionLostSheet: some View {
        TextEntryWarningSheet(
            title: "Connection lost",
            message: "Bluetooth disconnected.\nCheck your device and try again.",
            secondaryTitle: "Close",
            secondaryAction: { dismissConnectionLost() },
            primaryTitle: "Try again",
            primaryAction: { retryConnection() }
        )
    }

    private func handleConnectionStateChange(
        from oldState: CSDevice.ConnectionState,
        to newState: CSDevice.ConnectionState
    ) {
        if newState == .connectedAuthorized {
            dismissConnectionLost()
            return
        }

        guard newState == .disconnected, oldState != .disconnected else { return }
        // Suppress the prompt for disconnects we asked for (e.g. backgrounding).
        guard !device.didDisconnectIntentionally else { return }
        showConnectionLost = true
    }

    private func dismissConnectionLost() {
        showConnectionLost = false
        textEntryViewModel.dismissConnectionLost()
        snippetsViewModel.dismissConnectionLost()
    }

    private func retryConnection() {
        dismissConnectionLost()
        device.connect()
    }

    private func applyPendingSendTextRequest(_ request: PendingSendTextRequest?) {
        guard let request,
              request.isReadyForSelectedDevice,
              router.selectedDeviceID == device.id else { return }

        selectedTab = .textEntry
        textEntryViewModel.configureForSendTextDeepLink(text: request.text, callback: request.callback)
        router.consumeSendTextRequest(request)
    }
}

// MARK: - Preview

#Preview("Text Entry") {
    NavigationStack {
        DeviceDetailView(device: .preview)
    }
}

#Preview("Text Entry with text") {
    NavigationStack {
        DeviceDetailView(device: .preview, previewText: "admin@company.local")
    }
}

#Preview("Text Entry Sending") {
    NavigationStack {
        DeviceDetailView(
            device: .preview,
            previewText: "admin@company.local",
            previewIsSending: true
        )
    }
}

#Preview("Text Entry Sent Toast") {
    NavigationStack {
        DeviceDetailView(
            device: .preview,
            previewIsToastVisible: true
        )
    }
}

#Preview("Text Entry Unsupported Characters") {
    NavigationStack {
        DeviceDetailView(
            device: .preview,
            previewText: "admin Щ",
            previewPresentsTextEntrySheets: true
        )
    }
}

#Preview("Text Entry Progress Sending") {
    NavigationStack {
        DeviceDetailView(
            device: .preview,
            previewText: "admin@company.local",
            previewIsSending: true,
            previewProgress: .sending(sent: 250, total: 300),
            previewPresentsTextEntrySheets: true
        )
    }
}

#Preview("Text Entry Progress Stopped") {
    NavigationStack {
        DeviceDetailView(
            device: .preview,
            previewText: "admin@company.local",
            previewProgress: .stopped(sent: 87, total: 300),
            previewPresentsTextEntrySheets: true
        )
    }
}

#Preview("Text Entry Sent Sheet") {
    NavigationStack {
        DeviceDetailView(
            device: .preview,
            previewText: "admin@company.local",
            previewProgress: .sent,
            previewPresentsTextEntrySheets: true
        )
    }
}

#Preview("Snippets") {
    NavigationStack {
        DeviceDetailView(device: .preview, initialTab: .snippets)
    }
}

#Preview("Touchpad") {
    NavigationStack {
        DeviceDetailView(device: .preview, initialTab: .mouse)
    }
}

#Preview("Connection Lost") {
    NavigationStack {
        DeviceDetailView(device: .preview, showsConnectionLost: true)
    }
}

// Use the device picker at the bottom of the Canvas to preview this on iPad —
// `.previewDevice(...)` is ignored by the #Preview macro.
#Preview("iPad Text Entry") {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        NavigationStack {
            DeviceDetailView(device: .preview, previewText: "admin@company.local")
        }
    }
}
