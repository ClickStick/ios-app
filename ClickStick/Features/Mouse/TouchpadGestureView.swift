//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI
import UIKit

/// A touchpad-like gesture view for mouse control
struct TouchpadGestureView: UIViewRepresentable {
    let onMove: (Int8, Int8) -> Void
    let onScroll: (Int8, Int8) -> Void
    let onTap: () -> Void
    let onTwoFingerTap: () -> Void

    func makeUIView(context: Context) -> TouchpadView {
        let view = TouchpadView(
            onMove: onMove,
            onScroll: onScroll,
            onTap: onTap,
            onTwoFingerTap: onTwoFingerTap
        )
        return view
    }

    func updateUIView(_ uiView: TouchpadView, context: Context) {
        // Update callbacks if needed
        uiView.onMove = onMove
        uiView.onScroll = onScroll
        uiView.onTap = onTap
        uiView.onTwoFingerTap = onTwoFingerTap
    }
}

#Preview {
    TouchpadGestureView(
        onMove: { dx, dy in print("Move: \(dx), \(dy)") },
        onScroll: { v, h in print("Scroll: \(v), \(h)") },
        onTap: { print("Tap") },
        onTwoFingerTap: { print("Two-finger tap") }
    )
    .frame(height: 300)
    .padding()
}
