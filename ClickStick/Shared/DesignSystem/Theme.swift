//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

// MARK: - Brand Colors

extension Color {
    /// Primary brand blue - matches ClickStick website
    static let clickStickBlue = Color(red: 0.24, green: 0.51, blue: 0.87)

    /// Secondary brand teal for accents
    static let clickStickTeal = Color(red: 0.15, green: 0.68, blue: 0.72)

    /// Success green for connected states
    static let clickStickGreen = Color(red: 0.22, green: 0.78, blue: 0.45)

    /// Warning orange for authorization needed
    static let clickStickOrange = Color(red: 0.96, green: 0.65, blue: 0.14)
}

// MARK: - Gradients

extension LinearGradient {
    /// Primary brand gradient
    static let brandGradient = LinearGradient(
        colors: [Color.clickStickBlue, Color.clickStickTeal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle card gradient for depth
    static func cardGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(white: 0.15), Color(white: 0.1)]
                : [Color(white: 0.98), Color(white: 0.94)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Touchpad surface gradient
    static func touchpadGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(white: 0.12), Color(white: 0.08)]
                : [Color(white: 0.96), Color(white: 0.92)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Corner Radius

enum CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 20
}

// MARK: - Spacing

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Shadows

extension View {
    /// Subtle shadow for cards
    func cardShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 2
        )
    }

    /// Deeper shadow for elevated elements
    func elevatedShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.12),
            radius: 12,
            x: 0,
            y: 4
        )
    }

    /// Glow effect for active/connected states
    func glowEffect(color: Color, isActive: Bool) -> some View {
        self.shadow(
            color: isActive ? color.opacity(0.4) : .clear,
            radius: isActive ? 8 : 0,
            x: 0,
            y: 0
        )
    }
}

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(
                        isEnabled
                            ? LinearGradient.brandGradient
                            : LinearGradient(colors: [Color.gray], startPoint: .leading, endPoint: .trailing)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundColor(.clickStickBlue)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.clickStickBlue.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(Color.clickStickBlue.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

// MARK: - Card Style Modifier

struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let isHighlighted: Bool

    init(isHighlighted: Bool = false) {
        self.isHighlighted = isHighlighted
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color(white: colorScheme == .dark ? 0.15 : 1.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        isHighlighted ? Color.clickStickBlue.opacity(0.5) : Color.secondary.opacity(0.3),
                        lineWidth: isHighlighted ? 1.5 : 0.5
                    )
            )
            .cardShadow()
    }
}

extension View {
    func cardStyle(isHighlighted: Bool = false) -> some View {
        modifier(CardStyle(isHighlighted: isHighlighted))
    }
}

// MARK: - Animated Connection Indicator

struct PulsingDot: View {
    let color: Color
    let isAnimating: Bool

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 2)
                    .scaleEffect(scale)
                    .opacity(opacity)
            )
            .onAppear {
                guard isAnimating else { return }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    scale = 1.8
                    opacity = 0.0
                }
            }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    enum Status {
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

    var body: some View {
        HStack(spacing: 6) {
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
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(status.color.opacity(0.15))
        )
    }
}

// MARK: - Preview

#Preview("Theme Components") {
    ScrollView {
        VStack(spacing: 24) {
            // Colors
            HStack(spacing: 12) {
                Circle().fill(Color.clickStickBlue).frame(width: 40, height: 40)
                Circle().fill(Color.clickStickTeal).frame(width: 40, height: 40)
                Circle().fill(Color.clickStickGreen).frame(width: 40, height: 40)
                Circle().fill(Color.clickStickOrange).frame(width: 40, height: 40)
            }

            // Buttons
            VStack(spacing: 12) {
                Button("Primary Action") {}
                    .buttonStyle(.primary)

                Button("Secondary Action") {}
                    .buttonStyle(.secondary)
            }

            // Status badges
            HStack(spacing: 12) {
                StatusBadge(status: .connected)
                StatusBadge(status: .connecting)
                StatusBadge(status: .disconnected)
                StatusBadge(status: .unauthorized)
            }

            // Cards
            VStack(spacing: 12) {
                Text("Regular Card")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .cardStyle()

                Text("Highlighted Card")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .cardStyle(isHighlighted: true)
            }

            // Pulsing dots
            HStack(spacing: 20) {
                PulsingDot(color: .clickStickGreen, isAnimating: true)
                PulsingDot(color: .clickStickBlue, isAnimating: true)
            }
        }
        .padding()
    }
}
