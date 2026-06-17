//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Signal-strength bars for a device row. App-local replacement for the
/// DesignSystem `SignalStrengthView` (still used by the not-yet-migrated
/// add-device flow), hence the distinct name.
struct SignalBarsView: View {
    private enum Metric {
        static let barWidth: CGFloat = 3
        static let barSpacing: CGFloat = 3
        static let minBarHeight: CGFloat = 5
        static let barHeightStep: CGFloat = 4
    }

    let strength: Double
    var barCount: Int = 4
    var activeColor: Color = .accentBlue
    var inactiveColor: Color = .mutedFill

    var body: some View {
        HStack(alignment: .bottom, spacing: Metric.barSpacing) {
            ForEach(0..<max(1, barCount), id: \.self) { index in
                RoundedRectangle(cornerRadius: Metric.barWidth / 2, style: .continuous)
                    .fill(index < activeBarCount ? activeColor : inactiveColor)
                    .frame(width: Metric.barWidth, height: barHeight(for: index))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Signal strength"))
        .accessibilityValue(Text("\(activeBarCount) of \(max(1, barCount)) bars"))
    }

    private var activeBarCount: Int {
        let clamped = min(max(strength, 0), 1)
        return min(max(1, barCount), max(0, Int(ceil(clamped * Double(max(1, barCount))))))
    }

    private func barHeight(for index: Int) -> CGFloat {
        Metric.minBarHeight + CGFloat(index) * Metric.barHeightStep
    }
}
