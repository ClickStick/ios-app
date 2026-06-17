//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct StatusBadge: View {
    public enum Status: Equatable, Sendable {
        case connected
        case connecting
        case disconnected
        case unauthorized

        var color: Color {
            switch self {
            case .connected: return .clickStickGreen
            case .connecting: return .clickStickBlue
            case .disconnected: return .secondary
            case .unauthorized: return .clickStickOrange
            }
        }

        var icon: String {
            switch self {
            case .connected: return "checkmark.circle.fill"
            case .connecting: return "arrow.triangle.2.circlepath"
            case .disconnected: return "circle"
            case .unauthorized: return "lock.fill"
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .connected: return "Connected"
            case .connecting: return "Connecting"
            case .disconnected: return "Disconnected"
            case .unauthorized: return "Locked"
            }
        }
    }

    private let status: Status
    private let showsLabel: Bool

    public init(status: Status, showsLabel: Bool = false) {
        self.status = status
        self.showsLabel = showsLabel
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            if status == .connecting {
                ProgressView()
                    .controlSize(.mini)
                    .tint(status.color)
            } else {
                Image(systemName: status.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status.color)
            }

            if showsLabel {
                Text(status.title)
                    .font(.clickStickCaption.weight(.semibold))
                    .foregroundStyle(status.color)
            }
        }
        .padding(.horizontal, showsLabel ? Spacing.xs : Spacing.xxs)
        .frame(minHeight: ComponentSize.badgeHeight)
        .background(
            Capsule()
                .fill(status.color.opacity(OpacityLevel.tintedFill))
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        StatusBadge(status: .connected)
        StatusBadge(status: .connecting, showsLabel: true)
        StatusBadge(status: .disconnected, showsLabel: true)
        StatusBadge(status: .unauthorized, showsLabel: true)
    }
    .padding()
    .background(Color.clickStickGroupedBackground)
}
