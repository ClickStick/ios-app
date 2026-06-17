//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct DiscoveryRadarView: View {
    public enum Style: Sendable {
        case radioIcon
        case radar
        case pausedRadar
    }

    private let isActive: Bool
    private let size: CGFloat
    private let tint: Color
    private let style: Style

    public init(
        isActive: Bool,
        size: CGFloat = 184,
        tint: Color = .clickStickBlue,
        style: Style? = nil,
        systemImage: String = "antenna.radiowaves.left.and.right"
    ) {
        self.isActive = isActive
        self.size = size
        self.tint = tint
        self.style = style ?? (isActive ? .radar : .radioIcon)
        _ = systemImage
    }

    public var body: some View {
        Group {
            switch style {
            case .radioIcon:
                RadioWaveIconView(tint: tint, size: size)
            case .radar:
                radar(showsSweep: true)
            case .pausedRadar:
                radar(showsSweep: false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isActive ? Text("Looking for nearby devices") : Text("Device discovery paused"))
    }

    private func radar(showsSweep: Bool) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: size, height: size)

            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: size * 0.68, height: size * 0.68)

            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: size * 0.36, height: size * 0.36)

            Circle()
                .fill(tint.opacity(0.2))
                .frame(width: size * 0.14, height: size * 0.14)

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

public struct RadioWaveIconView: View {
    private let tint: Color
    private let background: Color
    private let size: CGFloat

    public init(
        tint: Color = .clickStickBlue,
        background: Color? = nil,
        size: CGFloat = 80
    ) {
        self.tint = tint
        self.background = background ?? tint.opacity(0.14)
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(background)

            Image(systemName: "antenna.radiowaves.left.and.right")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
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

#Preview {
    VStack(spacing: Spacing.xl) {
        RadioWaveIconView(tint: .clickStickBlue, size: 80)
        RadioWaveIconView(tint: .clickStickOrange, size: 80)
        DiscoveryRadarView(isActive: true)
        DiscoveryRadarView(isActive: false, size: 184, style: .pausedRadar)
    }
    .padding()
}
