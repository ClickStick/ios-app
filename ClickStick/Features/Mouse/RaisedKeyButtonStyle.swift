//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct RaisedKeyButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    var height: CGFloat
    var cornerRadius: CGFloat
    var horizontalPadding: CGFloat = 20
    var font: Font = .system(size: 17, weight: .regular)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(.primary)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(buttonBackground)
            .overlay { buttonBorder }
            .overlay { topEdgeHighlight }
            .overlay { bottomEdgeShade }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(surfaceGradient)
            .shadow(color: dropShadowColor, radius: colorScheme == .dark ? 4 : 5, x: 0, y: colorScheme == .dark ? 2 : 3)
            .shadow(color: contactShadowColor, radius: 1, x: 0, y: 1)
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(borderGradient, lineWidth: 1)
    }

    private var topEdgeHighlight: some View {
        RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
            .stroke(topEdgeColor, lineWidth: 1)
            .offset(y: 1)
            .mask(alignment: .top) {
                Rectangle()
                    .frame(height: colorScheme == .dark ? 10 : 8)
            }
    }

    private var bottomEdgeShade: some View {
        RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
            .stroke(bottomEdgeColor, lineWidth: 1)
            .offset(y: -1)
            .mask(alignment: .bottom) {
                Rectangle()
                    .frame(height: colorScheme == .dark ? 12 : 10)
            }
    }

    private var surfaceGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: surfaceTopColor, location: 0),
                .init(color: surfaceMidColor, location: 0.48),
                .init(color: surfaceBottomColor, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [borderTopColor, borderBottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var dropShadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.30) : .black.opacity(0.07)
    }

    private var contactShadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.34) : .black.opacity(0.09)
    }

    private var surfaceTopColor: Color {
        colorScheme == .dark
            ? Color(red: 51 / 255, green: 51 / 255, blue: 53 / 255)
            : Color(red: 248 / 255, green: 249 / 255, blue: 252 / 255)
    }

    private var surfaceMidColor: Color {
        colorScheme == .dark
            ? Color(red: 43 / 255, green: 43 / 255, blue: 45 / 255)
            : Color(red: 242 / 255, green: 243 / 255, blue: 247 / 255)
    }

    private var surfaceBottomColor: Color {
        colorScheme == .dark
            ? Color(red: 35 / 255, green: 35 / 255, blue: 37 / 255)
            : Color(red: 233 / 255, green: 237 / 255, blue: 242 / 255)
    }

    private var borderTopColor: Color {
        colorScheme == .dark ? .white.opacity(0.18) : .white.opacity(0.82)
    }

    private var borderBottomColor: Color {
        colorScheme == .dark ? .black.opacity(0.32) : .black.opacity(0.13)
    }

    private var topEdgeColor: Color {
        colorScheme == .dark ? .white.opacity(0.13) : .white.opacity(0.55)
    }

    private var bottomEdgeColor: Color {
        colorScheme == .dark ? .black.opacity(0.24) : .black.opacity(0.08)
    }
}
