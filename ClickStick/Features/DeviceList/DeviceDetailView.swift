//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI

struct DeviceDetailView: View {
    let device: DeviceModel

    @State private var selectedTab: DeviceFeatureTab = .textEntry
    @State private var textEntryViewModel: TextEntryViewModel

    init(device: DeviceModel, initialTab: DeviceFeatureTab = .textEntry) {
        self.device = device
        _selectedTab = State(initialValue: initialTab)
        _textEntryViewModel = State(initialValue: TextEntryViewModel(device: device))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            if availableTabs.contains(.textEntry) {
                TextEntryView(viewModel: textEntryViewModel)
                    .tabItem {
                        Label(DeviceFeatureTab.textEntry.localizedTitle, systemImage: DeviceFeatureTab.textEntry.icon)
                    }
                    .tag(DeviceFeatureTab.textEntry)
            }

            if availableTabs.contains(.snippets) {
                snippetsPlaceholder
                    .tabItem {
                        Label(DeviceFeatureTab.snippets.localizedTitle, systemImage: DeviceFeatureTab.snippets.icon)
                    }
                    .tag(DeviceFeatureTab.snippets)
            }

            if availableTabs.contains(.mouse) {
                MouseView(device: device)
                    .tabItem {
                        Label(DeviceFeatureTab.mouse.localizedTitle, systemImage: DeviceFeatureTab.mouse.icon)
                    }
                    .tag(DeviceFeatureTab.mouse)
            }
        }
        .tint(.clickStickBlue)
        .toolbarBackground(Color.clickStickGroupedBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
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
                    .tint(.clickStickBlue)
                    .accessibilityLabel(String(localized: "Create snippet", comment: "Create snippet button accessibility"))
                case .mouse:
                    EmptyView()
                }
            }
        }
    }

    private var availableTabs: [DeviceFeatureTab] {
        DeviceFeatureTab.allCases.filter { tab in
            switch tab {
            case .textEntry, .snippets:
                true
            case .mouse:
                device.features.contains(.mouse)
            }
        }
    }

    private var snippetsPlaceholder: some View {
        VStack(spacing: Spacing.sm) {
            Text("No snippets yet")
                .font(.clickStickTitle.weight(.bold))
                .foregroundStyle(.primary)
            Text("Tap + to create your first snippet")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clickStickGroupedBackground)
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
