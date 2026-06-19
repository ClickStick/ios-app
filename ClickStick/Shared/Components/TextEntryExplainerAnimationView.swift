//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Lottie
import SwiftUI

struct TextEntryExplainerAnimationView: View {
    var isPlaying = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private static let aspectRatio: CGFloat = 975 / 865

    private var animationName: String {
        colorScheme == .dark ? "TextEntryExplainerDark" : "TextEntryExplainerLight"
    }

    var body: some View {
        Group {
            if reduceMotion || !isPlaying {
                LottieView(animation: animation)
                    .resizable()
                    .paused(at: .progress(0))
                    .reloadAnimationTrigger(animationName)
            } else {
                LottieView(animation: animation)
                    .resizable()
                    .playing(loopMode: .loop)
                    .reloadAnimationTrigger(animationName)
            }
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var animation: LottieAnimation? {
        if let animation = LottieAnimation.named(animationName, bundle: .main) {
            return animation
        }

        guard let animationURL = Bundle.main.url(
            forResource: animationName,
            withExtension: "json",
            subdirectory: "Animations"
        ) else {
            return nil
        }

        return LottieAnimation.filepath(animationURL.path)
    }
}

#Preview("Text Entry Explainer Animation") {
    VStack(spacing: 24) {
        TextEntryExplainerAnimationView()
            .frame(height: 260)

        TextEntryExplainerAnimationView(isPlaying: false)
            .frame(height: 260)
    }
    .padding()
    .background(Color.groupedBackground)
}
