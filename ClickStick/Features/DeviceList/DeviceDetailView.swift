//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct DeviceDetailView: View {
    let device: DeviceModel

    @State private var selectedTab: DeviceFeatureTab = .textEntry
    @State private var textEntryViewModel: TextEntryViewModel
    @State private var mouseViewModel: MouseViewModel

    init(device: DeviceModel, initialTab: DeviceFeatureTab = .textEntry) {
        self.device = device
        _selectedTab = State(initialValue: initialTab)
        _textEntryViewModel = State(initialValue: TextEntryViewModel(device: device))
        _mouseViewModel = State(initialValue: MouseViewModel(device: device))
    }

    var body: some View {
        selectedTabContent
            .background(Color.groupedBackground.ignoresSafeArea())
            .tint(.accentBlue)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FloatingTabBar(items: tabBarItems, selection: $selectedTab)
                    .padding(.bottom, 12)
            }
            .navigationTitle(device.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    switch selectedTab {
                    case .textEntry:
                        Button {
                            textEntryViewModel.requestSend()
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .disabled(!textEntryViewModel.canSend)
                        .accessibilityLabel(String(localized: "Send text", comment: "Header send button accessibility"))
                    case .snippets:
                        Button {} label: {
                            Image(systemName: "plus")
                                .font(.title2.weight(.regular))
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.circle)
                        .tint(.accentBlue)
                        .accessibilityLabel(String(localized: "Create snippet", comment: "Create snippet button accessibility"))
                    case .mouse:
                        EmptyView()
                    }
                }
            }
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .textEntry:
            TextEntryView(viewModel: textEntryViewModel)
        case .snippets:
            snippetsPlaceholder
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

    private var snippetsPlaceholder: some View {
        VStack(spacing: 12) {
            Text("No snippets yet")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text("Tap + to create your first snippet")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.groupedBackground)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview("Text Entry") {
    NavigationStack {
        DeviceDetailView(device: .preview)
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
