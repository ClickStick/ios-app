//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct StatusBadge: View {
    public enum Status: Sendable {
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
    }

    let status: Status

    public init(status: Status) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            if status == .connecting {
                ProgressView()
                    .controlSize(.mini)
                    .tint(status.color)
            } else {
                Image(systemName: status.icon)
                    .font(.caption)
                    .foregroundStyle(status.color)
            }
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(
            Capsule()
                .fill(status.color.opacity(OpacityLevel.accentFill))
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        StatusBadge(status: .connected)
        StatusBadge(status: .connecting)
        StatusBadge(status: .disconnected)
        StatusBadge(status: .unauthorized)
    }
    .padding()
}
