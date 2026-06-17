//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import DesignSystem
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
                    .safeAreaPadding(.top, Spacing.xl)

                TabView(selection: $currentPage) {
                    OnboardingIntroPage(
                        title: "What is ClickStick",
                        subtitle: "ClickStick is a USB dongle that works as a keyboard controlled by your phone. No drivers required.",
                        illustrationName: "OnboardingClickStick"
                    )
                    .tag(0)

                    OnboardingIntroPage(
                        title: "Why ClickStick",
                        subtitle: "Type long passwords and text instantly. Your phone becomes a keyboard for any device.",
                        illustrationName: "OnboardingUseCase"
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
                currentPage: currentPage,
                selectedMode: selectedMode,
                onPrimaryAction: primaryAction,
                onGetClickStick: onGetClickStick
            )
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.md)
            .background(Color.clear)
        }
    }

    private func primaryAction() {
        if currentPage < Self.pageCount - 1 {
            withAnimation(.easeInOut(duration: Motion.expressive)) {
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
            .init(color: Color.clickStickGroupedBackground, location: 0.72)
        ]
    }

    private var darkStops: [Gradient.Stop] {
        [
            .init(color: Color(red: 0.05, green: 0.09, blue: 0.15), location: 0),
            .init(color: Color(red: 0.08, green: 0.16, blue: 0.28), location: 0.24),
            .init(color: Color.clickStickGroupedBackground, location: 0.72)
        ]
    }
}

private struct OnboardingIntroPage: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let illustrationName: String

    var body: some View {
        VStack(spacing: Spacing.xxxl) {
            OnboardingTextBlock(title: title, subtitle: subtitle)
                .padding(.horizontal, Spacing.lg)

            Spacer(minLength: Spacing.xl)

            Image(illustrationName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
                .accessibilityHidden(true)

            Spacer(minLength: Spacing.xl)
        }
        .padding(.top, Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingStartPage: View {
    @Binding var selectedMode: OnboardingStartMode

    var body: some View {
        VStack(spacing: Spacing.xxxl) {
            OnboardingTextBlock(
                title: "Get Started",
                subtitle: "Choose how you'd like to begin. You can always switch modes later."
            )
            .padding(.horizontal, Spacing.lg)

            Spacer(minLength: Spacing.xl)

            VStack(spacing: Spacing.md) {
                OnboardingModeCard(
                    mode: .addDevice,
                    selectedMode: $selectedMode,
                    icon: Image("dongle.usb"),
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
            .padding(.horizontal, Spacing.lg)

            Spacer(minLength: Spacing.xl)
        }
        .padding(.top, Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct OnboardingTextBlock: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingBottomBar: View {
    let currentPage: Int
    let selectedMode: OnboardingStartMode
    let onPrimaryAction: () -> Void
    let onGetClickStick: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Button(primaryTitle, action: onPrimaryAction)
                .buttonStyle(.primary)

            // Always laid out so the primary button keeps a constant position
            // across pages; only revealed on the final page.
            Button("Get your ClickStick at clickstick.io", action: onGetClickStick)
                .font(.title3)
                .foregroundStyle(Color.clickStickBlue)
                .multilineTextAlignment(.center)
                .buttonStyle(.plain)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHint("Opens the ClickStick website")
                .opacity(isLastPage ? 1 : 0)
                .disabled(!isLastPage)
                .accessibilityHidden(!isLastPage)
        }
    }

    private var isLastPage: Bool {
        currentPage == 2
    }

    private var primaryTitle: LocalizedStringKey {
        if currentPage < 2 {
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

    @ScaledMetric(relativeTo: .body) private var dotLength = Spacing.xs
    @ScaledMetric(relativeTo: .body) private var activeLength = Spacing.xl

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<pageCount, id: \.self) { page in
                Capsule(style: .continuous)
                    .fill(page == currentPage ? Color.clickStickBlue : Color.clickStickBlue.opacity(0.32))
                    .frame(width: page == currentPage ? activeLength : dotLength, height: dotLength)
                    .animation(.easeInOut(duration: Motion.regular), value: currentPage)
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
            withAnimation(.easeInOut(duration: Motion.regular)) {
                selectedMode = mode
            }
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                OnboardingModeIcon(icon: icon, isSelected: isSelected)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                OnboardingSelectionIndicator(isSelected: isSelected)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(cardBorder)
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
            .fill(isSelected ? Color.clickStickCardBackground : Color.clickStickCardBackground.opacity(0.56))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
            .stroke(
                isSelected ? Color.clickStickBlue : Color.secondary.opacity(OpacityLevel.subtleBorder),
                lineWidth: isSelected ? BorderWidth.thick : BorderWidth.regular
            )
    }
}

private struct OnboardingModeIcon: View {
    let icon: Image
    let isSelected: Bool

    @ScaledMetric(relativeTo: .body) private var iconContainerSize = ComponentSize.largeIconButton

    var body: some View {
        RoundedRectangle(cornerRadius: CornerRadius.extraLarge, style: .continuous)
            .fill(isSelected ? Color.clickStickBlue : Color.clickStickMutedFill)
            .frame(width: iconContainerSize, height: iconContainerSize)
            .overlay {
                icon
                    .symbolRenderingMode(.hierarchical)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
            }
            .accessibilityHidden(true)
    }
}

private struct OnboardingSelectionIndicator: View {
    let isSelected: Bool

    @ScaledMetric(relativeTo: .body) private var indicatorSize = IconSize.medium

    var body: some View {
        Circle()
            .stroke(isSelected ? Color.clickStickBlue : Color.secondary.opacity(OpacityLevel.prominentBorder), lineWidth: BorderWidth.thick)
            .frame(width: indicatorSize, height: indicatorSize)
            .overlay {
                if isSelected {
                    Circle()
                        .fill(Color.clickStickBlue)
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
