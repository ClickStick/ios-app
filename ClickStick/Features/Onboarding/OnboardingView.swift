//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct OnboardingView: View {
    private static let pageCount = 3

    private let onComplete: (OnboardingCompletionAction) -> Void
    private let onGetClickStick: () -> Void

    @State private var currentPage: Int = 0
    @State private var selectedMode: OnboardingStartMode = .addDevice

    init(
        onComplete: @escaping (OnboardingCompletionAction) -> Void,
        onGetClickStick: @escaping () -> Void
    ) {
        self.onComplete = onComplete
        self.onGetClickStick = onGetClickStick
    }

    var body: some View {
        ZStack {
            OnboardingBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                OnboardingPageIndicator(pageCount: Self.pageCount, currentPage: currentPage)
                    .safeAreaPadding(.top, 24)

                TabView(selection: $currentPage) {
                    OnboardingIntroPage(
                        title: "What is ClickStick",
                        subtitle: "ClickStick is a USB dongle that works as a keyboard controlled by your phone. No drivers required.",
                        illustration: .image("OnboardingClickStick")
                    )
                    .tag(0)

                    OnboardingIntroPage(
                        title: "Why ClickStick",
                        subtitle: "Type long passwords and text instantly. Your phone becomes a keyboard for any device.",
                        illustration: .textEntryExplainer(isPlaying: currentPage == 1)
                    )
                    .tag(1)

                    OnboardingStartPage(selectedMode: $selectedMode)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OnboardingBottomBar(
                isLastPage: currentPage == Self.pageCount - 1,
                selectedMode: selectedMode,
                onPrimaryAction: primaryAction,
                onGetClickStick: onGetClickStick
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func primaryAction() {
        if currentPage < Self.pageCount - 1 {
            withAnimation(.easeInOut(duration: 0.35)) {
                currentPage += 1
            }
            return
        }

        switch selectedMode {
        case .addDevice:
            onComplete(.addDevice)
        case .demoMode:
            onComplete(.demoMode)
        }
    }
}

private enum OnboardingStartMode: Hashable {
    case addDevice
    case demoMode
}

private struct OnboardingBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            stops: colorScheme == .dark ? darkStops : lightStops,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var lightStops: [Gradient.Stop] {
        [
            .init(color: Color(red: 0.92, green: 0.96, blue: 1), location: 0),
            .init(color: Color(red: 0.68, green: 0.82, blue: 0.98), location: 0.2),
            .init(color: Color(red: 0.91, green: 0.94, blue: 0.98), location: 0.42),
            .init(color: Color.groupedBackground, location: 0.72)
        ]
    }

    private var darkStops: [Gradient.Stop] {
        [
            .init(color: Color(red: 0.05, green: 0.09, blue: 0.15), location: 0),
            .init(color: Color(red: 0.08, green: 0.16, blue: 0.28), location: 0.24),
            .init(color: Color.groupedBackground, location: 0.72)
        ]
    }
}

private enum OnboardingIllustration {
    case image(String)
    case textEntryExplainer(isPlaying: Bool)
}

private struct OnboardingIntroPage: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let illustration: OnboardingIllustration

    var body: some View {
        VStack(spacing: 40) {
            OnboardingTextBlock(title: title, subtitle: subtitle)
                .padding(.horizontal, 20)

            Spacer(minLength: 24)

            illustrationView
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

            Spacer(minLength: 24)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var illustrationView: some View {
        switch illustration {
        case let .image(name):
            Image(name)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        case let .textEntryExplainer(isPlaying):
            TextEntryExplainerAnimationView(isPlaying: isPlaying)
        }
    }
}

private struct OnboardingStartPage: View {
    @Binding var selectedMode: OnboardingStartMode

    var body: some View {
        VStack(spacing: 40) {
            OnboardingTextBlock(
                title: "Get Started",
                subtitle: "Choose how you'd like to begin. You can always switch modes later."
            )
            .padding(.horizontal, 20)

            Spacer(minLength: 24)

            VStack(spacing: 16) {
                OnboardingModeCard(
                    mode: .addDevice,
                    selectedMode: $selectedMode,
                    icon: Image("DongleIcon"),
                    title: "I already have a ClickStick",
                    subtitle: "Add and pair a nearby device."
                )

                OnboardingModeCard(
                    mode: .demoMode,
                    selectedMode: $selectedMode,
                    icon: Image(systemName: "play.fill"),
                    title: "Explore Demo Mode",
                    subtitle: "Try the app without hardware."
                )
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 24)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct OnboardingTextBlock: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingBottomBar: View {
    let isLastPage: Bool
    let selectedMode: OnboardingStartMode
    let onPrimaryAction: () -> Void
    let onGetClickStick: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Button(primaryTitle, action: onPrimaryAction)
                .buttonStyle(AppPrimaryButtonStyle())

            // Always laid out so the primary button keeps a constant position
            // across pages; only revealed on the final page.
            Button("Get your ClickStick at clickstick.io", action: onGetClickStick)
                .font(.body)
                .foregroundStyle(Color.accentBlue)
                .multilineTextAlignment(.center)
                .buttonStyle(.plain)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHint("Opens the ClickStick website")
                .opacity(isLastPage ? 1 : 0)
                .disabled(!isLastPage)
                .accessibilityHidden(!isLastPage)
        }
    }

    private var primaryTitle: LocalizedStringKey {
        if !isLastPage {
            return "Continue"
        }

        switch selectedMode {
        case .addDevice:
            return "Add Device"
        case .demoMode:
            return "Explore Demo Mode"
        }
    }
}

private struct OnboardingPageIndicator: View {
    let pageCount: Int
    let currentPage: Int

    @ScaledMetric(relativeTo: .body) private var dotLength: Double = 8
    @ScaledMetric(relativeTo: .body) private var activeLength: Double = 24

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<pageCount, id: \.self) { page in
                Capsule(style: .continuous)
                    .fill(page == currentPage ? Color.accentBlue : Color.accentBlue.opacity(0.32))
                    .frame(width: page == currentPage ? activeLength : dotLength, height: dotLength)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding page \(currentPage + 1) of \(pageCount)")
    }
}

private struct OnboardingModeCard: View {
    let mode: OnboardingStartMode
    @Binding var selectedMode: OnboardingStartMode
    let icon: Image
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    private var isSelected: Bool { selectedMode == mode }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMode = mode
            }
        } label: {
            HStack(alignment: .center, spacing: 16) {
                OnboardingModeIcon(icon: icon, isSelected: isSelected)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        // Keep the title clear of the corner selection indicator.
                        .padding(.trailing, 28)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay { cardBorder }
            .overlay(alignment: .topTrailing) {
                OnboardingSelectionIndicator(isSelected: isSelected)
                    .padding(12)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(isSelected ? Color.cardBackground : Color.cardBackground.opacity(0.56))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                isSelected ? Color.accentBlue : Color.secondary.opacity(0.2),
                lineWidth: isSelected ? 2 : 1.5
            )
    }
}

private struct OnboardingModeIcon: View {
    let icon: Image
    let isSelected: Bool

    @ScaledMetric(relativeTo: .body) private var iconContainerSize: Double = 56
    @ScaledMetric(relativeTo: .body) private var glyphSize: Double = 28

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(isSelected ? Color.accentBlue : Color.mutedFill)
            .frame(width: iconContainerSize, height: iconContainerSize)
            .overlay {
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: glyphSize, height: glyphSize)
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
            }
            .accessibilityHidden(true)
    }
}

private struct OnboardingSelectionIndicator: View {
    let isSelected: Bool

    @ScaledMetric(relativeTo: .body) private var indicatorSize: Double = 20

    var body: some View {
        Circle()
            .stroke(isSelected ? Color.accentBlue : Color.secondary.opacity(0.45), lineWidth: 2)
            .frame(width: indicatorSize, height: indicatorSize)
            .overlay {
                if isSelected {
                    Circle()
                        .fill(Color.accentBlue)
                        .padding(indicatorSize / 5)
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview {
    OnboardingView(onComplete: { _ in }, onGetClickStick: {})
}

#Preview("Why ClickStick page") {
    ZStack {
        OnboardingBackground()
            .ignoresSafeArea()
        OnboardingIntroPage(
            title: "Why ClickStick",
            subtitle: "Type long passwords and text instantly. Your phone becomes a keyboard for any device.",
            illustration: .textEntryExplainer(isPlaying: false)
        )
    }
}

#Preview("Get Started page") {
    @Previewable @State var mode: OnboardingStartMode = .addDevice
    ZStack {
        OnboardingBackground()
            .ignoresSafeArea()
        OnboardingStartPage(selectedMode: $mode)
    }
}
