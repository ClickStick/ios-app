//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct TouchpadClickButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(buttonBackground)
            .overlay { buttonHighlight }
            .overlay { buttonBorder }
            .contentShape(RoundedRectangle(cornerRadius: 22))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color(uiColor: .touchpadButtonFill))
            .shadow(color: Color.black.opacity(0.12), radius: 2, y: 2)
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 6)
    }

    private var buttonHighlight: some View {
        RoundedRectangle(cornerRadius: 22)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(0.95),
                        .white.opacity(0.2),
                        .black.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 4
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: 22)
            .stroke(Color(uiColor: .touchpadStroke), lineWidth: 1)
    }
}
