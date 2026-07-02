//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Circular "send" action, reused in the iPhone navigation bar and inline in the
/// iPad text entry card. Takes plain `canSend`/`isSending` values rather than the
/// view model so callers can control exactly when the button re-evaluates.
struct SendButton: View {
    let canSend: Bool
    let isSending: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                if isSending {
                    SendButtonActivityIndicator(isAnimated: !accessibilityReduceMotion)
                } else {
                    Image(systemName: "arrow.up")
                }
            }
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
        }
        .buttonStyle(CircularToolbarButtonStyle(role: .prominent))
        .disabled(!canSend)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if isSending {
            String(localized: "Sending text", comment: "Header send button sending accessibility")
        } else {
            String(localized: "Send text", comment: "Header send button accessibility")
        }
    }
}

private struct SendButtonActivityIndicator: View {
    let isAnimated: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let lineWidth: CGFloat = 2
                let radius = min(size.width, size.height) / 2 - lineWidth / 2
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let rotation = isAnimated ? rotationAngle(at: timeline.date) : 0

                var path = Path()
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(rotation - 135),
                    endAngle: .degrees(rotation + 135),
                    clockwise: false
                )
                context.stroke(
                    path,
                    with: .color(.white),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            }
        }
        .frame(width: 22, height: 22)
    }

    private func rotationAngle(at date: Date) -> Double {
        let duration = 0.8
        let progress = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration) / duration
        return progress * 360
    }
}

#Preview {
    VStack(spacing: 20) {
        SendButton(canSend: true, isSending: false) {}
        SendButton(canSend: false, isSending: false) {}
        SendButton(canSend: true, isSending: true) {}
    }
    .padding()
}
