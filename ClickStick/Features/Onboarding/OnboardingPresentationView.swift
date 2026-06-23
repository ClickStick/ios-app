//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct OnboardingPresentationView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let onComplete: (OnboardingCompletionAction) -> Void
    let onGetClickStick: () -> Void

    var body: some View {
        if horizontalSizeClass == .regular {
            onboardingView
                .frame(maxWidth: 480)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
