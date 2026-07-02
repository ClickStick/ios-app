//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct OnboardingPresentationView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let onComplete: (OnboardingCompletionAction) -> Void
    let onGetClickStick: () -> Void

    var body: some View {
        if AppLayout.usesWideLayout(horizontalSizeClass: horizontalSizeClass) {
            onboardingView
                .frame(maxWidth: 480, maxHeight: 750)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.4).ignoresSafeArea())
        } else {
            onboardingView
        }
    }

    private var onboardingView: some View {
        OnboardingView(
            onComplete: onComplete,
            onGetClickStick: onGetClickStick
        )
    }
}

// MARK: - Previews

#Preview("iPad Onboarding") {
    OnboardingPresentationView(onComplete: { _ in }, onGetClickStick: {})
        .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPad Onboarding Dark") {
    OnboardingPresentationView(onComplete: { _ in }, onGetClickStick: {})
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.colorScheme, .dark)
}
