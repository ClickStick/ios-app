//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Concentric-ring radar used for the scanning sheet's paused state and as the
/// reduced-motion fallback for the Lottie discovery animation.
struct ScanRadarView: View {
    var showsSweep: Bool = false
    var tint: Color = .accentBlue
    var size: CGFloat = 184

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.16)).frame(width: size, height: size)
            Circle().fill(tint.opacity(0.16)).frame(width: size * 0.68, height: size * 0.68)
            Circle().fill(tint.opacity(0.16)).frame(width: size * 0.36, height: size * 0.36)
            Circle().fill(tint.opacity(0.2)).frame(width: size * 0.14, height: size * 0.14)

            if showsSweep {
                RadarSweepShape()
                    .fill(tint.opacity(0.16))
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct RadarSweepShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addLine(to: point(center: center, radius: radius, degrees: -120))
        path.addLine(to: point(center: center, radius: radius, degrees: -60))
        path.closeSubpath()
        return path
    }

    private func point(center: CGPoint, radius: CGFloat, degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: center.x + radius * cos(radians),
            y: center.y + radius * sin(radians)
        )
    }
}
