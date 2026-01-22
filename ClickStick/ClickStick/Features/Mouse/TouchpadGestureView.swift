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

// MARK: - UIKit Touchpad View

class TouchpadView: UIView {
    var onMove: (Int8, Int8) -> Void
    var onScroll: (Int8, Int8) -> Void
    var onTap: () -> Void
    var onTwoFingerTap: () -> Void

    // Movement accumulation
    private var accumulatedDX: CGFloat = 0
    private var accumulatedDY: CGFloat = 0
    private var accumulatedScrollV: CGFloat = 0
    private var accumulatedScrollH: CGFloat = 0

    // Timing
    private var sendTimer: Timer?
    private let sendInterval: TimeInterval = 0.05 // 50ms batching

    // Sensitivity
    private let movementSensitivity: CGFloat = 1.5
    private let scrollSensitivity: CGFloat = 0.3

    // Haptic feedback
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private var scrollThresholdReached = false
    private let scrollHapticThreshold: CGFloat = 20

    init(
        onMove: @escaping (Int8, Int8) -> Void,
        onScroll: @escaping (Int8, Int8) -> Void,
        onTap: @escaping () -> Void,
        onTwoFingerTap: @escaping () -> Void
    ) {
        self.onMove = onMove
        self.onScroll = onScroll
        self.onTap = onTap
        self.onTwoFingerTap = onTwoFingerTap

        super.init(frame: .zero)
        setupView()
        setupGestureRecognizers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.cgColor

        isMultipleTouchEnabled = true
        feedbackGenerator.prepare()
    }

    private func setupGestureRecognizers() {
        // Single tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1
        addGestureRecognizer(tapGesture)

        // Two-finger tap (right click)
        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap))
        twoFingerTap.numberOfTapsRequired = 1
        twoFingerTap.numberOfTouchesRequired = 2
        addGestureRecognizer(twoFingerTap)

        // Single finger pan (mouse move)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        addGestureRecognizer(panGesture)

        // Two-finger pan (scroll)
        let scrollGesture = UIPanGestureRecognizer(target: self, action: #selector(handleScroll))
        scrollGesture.minimumNumberOfTouches = 2
        scrollGesture.maximumNumberOfTouches = 2
        addGestureRecognizer(scrollGesture)
    }

    // MARK: - Gesture Handlers

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        feedbackGenerator.impactOccurred(intensity: 0.5)
        onTap()
    }

    @objc private func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
        feedbackGenerator.impactOccurred(intensity: 0.7)
        onTwoFingerTap()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            startSendTimer()
        case .changed:
            let translation = gesture.translation(in: self)
            accumulatedDX += translation.x * movementSensitivity
            accumulatedDY += translation.y * movementSensitivity
            gesture.setTranslation(.zero, in: self)
        case .ended, .cancelled:
            flushAccumulatedMovement()
            stopSendTimer()
        default:
            break
        }
    }

    @objc private func handleScroll(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            startSendTimer()
            scrollThresholdReached = false
        case .changed:
            let translation = gesture.translation(in: self)
            accumulatedScrollV -= translation.y * scrollSensitivity // Invert for natural scrolling
            accumulatedScrollH += translation.x * scrollSensitivity
            gesture.setTranslation(.zero, in: self)

            // Haptic feedback at scroll thresholds
            let totalScroll = abs(accumulatedScrollV) + abs(accumulatedScrollH)
            if totalScroll > scrollHapticThreshold && !scrollThresholdReached {
                feedbackGenerator.impactOccurred(intensity: 0.3)
                scrollThresholdReached = true
            }
        case .ended, .cancelled:
            flushAccumulatedScroll()
            stopSendTimer()
        default:
            break
        }
    }

    // MARK: - Timer Management

    private func startSendTimer() {
        stopSendTimer()
        sendTimer = Timer.scheduledTimer(withTimeInterval: sendInterval, repeats: true) { [weak self] _ in
            self?.flushAccumulatedMovement()
            self?.flushAccumulatedScroll()
        }
    }

    private func stopSendTimer() {
        sendTimer?.invalidate()
        sendTimer = nil
    }

    // MARK: - Flush Accumulated Values

    private func flushAccumulatedMovement() {
        guard accumulatedDX != 0 || accumulatedDY != 0 else { return }

        let dx = clampToInt8(accumulatedDX)
        let dy = clampToInt8(accumulatedDY)

        accumulatedDX = 0
        accumulatedDY = 0

        if dx != 0 || dy != 0 {
            onMove(dx, dy)
        }
    }

    private func flushAccumulatedScroll() {
        guard accumulatedScrollV != 0 || accumulatedScrollH != 0 else { return }

        let scrollV = clampToInt8(accumulatedScrollV)
        let scrollH = clampToInt8(accumulatedScrollH)

        accumulatedScrollV = 0
        accumulatedScrollH = 0

        if scrollV != 0 || scrollH != 0 {
            onScroll(scrollV, scrollH)
        }
    }

    private func clampToInt8(_ value: CGFloat) -> Int8 {
        let clamped = max(-127, min(127, Int(value)))
        return Int8(clamped)
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
