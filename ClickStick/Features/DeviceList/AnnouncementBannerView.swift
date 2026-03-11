//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import DesignSystem
import SwiftUI

struct AnnouncementBannerView: View {
    struct Configuration {
        let title: String?
        let message: String?
        let image: Image
        let actionTitle: String?
        var style: BannerStyle = .info

        enum BannerStyle {
            case info
            case welcome
            case warning

            var iconBackgroundColors: [Color] {
                switch self {
                case .info: return [.clickStickBlue, .clickStickTeal]
                case .welcome: return [.clickStickGreen, .clickStickTeal]
                case .warning: return [.clickStickOrange, .red.opacity(0.8)]
                }
            }

            var accentColor: Color {
                switch self {
                case .info: return .clickStickBlue
                case .welcome: return .clickStickGreen
                case .warning: return .clickStickOrange
                }
            }
        }
    }
    let configuration: Configuration
    let onAction: (() -> Void)?
    let onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: configuration.style.iconBackgroundColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                configuration.image
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let title = configuration.title {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                if let message = configuration.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let actionTitle = configuration.actionTitle, let onAction {
                    Button {
                        onAction()
                    } label: {
                        HStack(spacing: 4) {
                            Text(actionTitle)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .accessibilityHidden(true)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(configuration.style.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Spacing.xxs)
                }
            }

            Spacer(minLength: 0)

            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(Spacing.xs)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(0.1))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(Spacing.md)
        .background(Color(white: 0.5).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - List Row Modifier

extension View {
    func announcementRow(id: String) -> some View {
        self
            .id("announcement-\(id)")
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                )
            )
            .listRowInsets(EdgeInsets(top: Spacing.xs, leading: 1, bottom: Spacing.xs, trailing: 1))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

#Preview {
    List {
        Section {
            AnnouncementBannerView(
                configuration: .welcome,
                onAction: {},
                onDismiss: {}
            ).announcementRow(id: "welcome")
            AnnouncementBannerView(
                configuration: .demo,
                onAction: {},
                onDismiss: {}
            ).announcementRow(id: "demo")
        }
    }
}
