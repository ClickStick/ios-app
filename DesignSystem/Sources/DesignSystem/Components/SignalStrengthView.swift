//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct SignalStrengthView: View {
    private enum Metric {
        static let barWidth: CGFloat = 3
        static let barSpacing: CGFloat = 3
        static let minBarHeight: CGFloat = 5
        static let barHeightStep: CGFloat = 4
    }

    private let strength: Double
    private let barCount: Int
    private let activeColor: Color
    private let inactiveColor: Color

    public init(
        strength: Double,
        barCount: Int = 4,
        activeColor: Color = .clickStickBlue,
        inactiveColor: Color = .clickStickMutedFill
    ) {
        self.strength = strength
        self.barCount = max(1, barCount)
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: Metric.barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: Metric.barWidth / 2, style: .continuous)
                    .fill(index < activeBarCount ? activeColor : inactiveColor)
                    .frame(width: Metric.barWidth, height: barHeight(for: index))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Signal strength"))
        .accessibilityValue(Text("\(activeBarCount) of \(barCount) bars"))
    }

    private var activeBarCount: Int {
        let clampedStrength = min(max(strength, 0), 1)
        return min(barCount, max(0, Int(ceil(clampedStrength * Double(barCount)))))
    }

    private func barHeight(for index: Int) -> CGFloat {
        Metric.minBarHeight + CGFloat(index) * Metric.barHeightStep
    }
}

#Preview {
    HStack(spacing: Spacing.lg) {
        SignalStrengthView(strength: 0.25)
        SignalStrengthView(strength: 0.5)
        SignalStrengthView(strength: 1.0, activeColor: .clickStickGreen)
    }
    .padding()
    .background(Color.clickStickGroupedBackground)
}
