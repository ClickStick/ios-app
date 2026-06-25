//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Lottie
import SwiftUI

struct BluetoothDiscoveryAnimationView: View {
    let size: CGFloat
    var isPlaying = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                ScanRadarView(showsSweep: isPlaying, tint: .accentBlue, size: size)
            } else {
                LottieView {
                    try await DotLottieFile.named("Bluetooth", bundle: .main)
                }
                .resizable()
                .playing(loopMode: isPlaying ? .loop : .playOnce)
                .currentProgress(isPlaying ? nil : 0)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview("Bluetooth Discovery Animation") {
    VStack(spacing: 24) {
        BluetoothDiscoveryAnimationView(size: 184)
        BluetoothDiscoveryAnimationView(size: 184, isPlaying: false)
    }
    .padding()
    .background(Color.groupedBackground)
}
