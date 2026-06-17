//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI

struct DeviceDetailView: View {
    let device: DeviceModel

    @Environment(\.appRouter) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: DeviceFeatureTab = .textEntry
    @State private var textEntryViewModel: TextEntryViewModel
    @State private var alertError: AlertError?
    @State private var rotationAngle: Double = 0

    init(device: DeviceModel) {
        self.device = device
        _textEntryViewModel = State(initialValue: TextEntryViewModel(device: device))
    }

    var body: some View {
        VStack(spacing: 0) {
            if device.isConnected {
                connectedContent
            } else if device.isConnecting {
                connectingContent
            } else {
                disconnectedContent
            }
        }
        .clickStickScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .errorAlert($alertError)
        .onChange(of: device.lastErrorTimestamp) { _, _ in
            if let error = device.lastError {
                alertError = AlertError(error: error)
            }
        }
    }

    // MARK: - Connected Content

    private var connectedContent: some View {
        VStack(spacing: 0) {
            header

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
        }
    }

    private var header: some View {
        ZStack {
            Text(device.displayName)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, Spacing.xxxl)

            HStack {
                Button {
                    router.deselectDevice()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel(String(localized: "Back", comment: "Back button accessibility"))

                Spacer()

                if selectedTab == .textEntry {
                    Button {
                        textEntryViewModel.requestSend()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.title2.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .disabled(!textEntryViewModel.canSend)
                    .opacity(textEntryViewModel.canSend ? 1 : OpacityLevel.disabled)
                    .accessibilityLabel(String(localized: "Send text", comment: "Header send button accessibility"))
                } else {
                    Image(systemName: "arrow.up")
                        .hidden()
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }

    private var availableTabs: [DeviceFeatureTab] {
        DeviceFeatureTab.allCases.filter { tab in
            guard let feature = tab.feature else { return true }
            return device.features.contains(feature)
        }
    }

    private var snippetsPlaceholder: some View {
        VStack(spacing: Spacing.md) {
            FeatureIcon(
                systemName: "list.bullet",
                size: IconSize.hero,
                iconSize: IconSize.large,
                tint: .clickStickBlue
            )
            Text("Snippets")
                .font(.clickStickTitle)
            Text("Snippet management will be added later.")
                .font(.clickStickBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Connecting Content

    private var connectingContent: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(Color.clickStickBlue.opacity(OpacityLevel.subtleBorder), lineWidth: BorderWidth.thick)
.frame(maxWidth: IconSize.hero, maxHeight: IconSize.hero)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient.clickStickGradient,
                        style: StrokeStyle(lineWidth: BorderWidth.thick, lineCap: .round)
                    )
.frame(maxWidth: IconSize.hero, maxHeight: IconSize.hero)
                    .rotationEffect(.degrees(rotationAngle - 90))
            }

            Image(systemName: "cable.connector.horizontal")
.font(.title2)
                .foregroundStyle(Color.clickStickBlue)

            VStack(spacing: Spacing.xs) {
                Text("Connecting...")
                    .font(.headline)
                Text(device.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting to \(device.displayName)")
    }

    // MARK: - Disconnected Content

    private var disconnectedContent: some View {
        VStack(spacing: Spacing.xl) {
            FeatureIcon(
                systemName: "cable.connector.horizontal",
                size: IconSize.hero,
                iconSize: IconSize.large,
                tint: .clickStickBlue
            )

            VStack(spacing: Spacing.xs) {
                Text("Disconnected")
                    .font(.clickStickTitle)

                if let error = device.lastError {
                    Text(error.localizedDescription)
                        .font(.clickStickBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Tap Connect to start using this device.")
                        .font(.clickStickBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button {
                device.connect()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "bolt.fill")
                    Text("Connect")
                }
            }
            .buttonStyle(.primary)

        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Device disconnected")
        .accessibilityHint("Double-tap the connect button to reconnect")
    }
}

// MARK: - Preview

#Preview("Connected") {
    DeviceDetailView(device: .preview)
}

#Preview("Disconnected") {
    DeviceDetailView(device: .previewDisconnected)
}
