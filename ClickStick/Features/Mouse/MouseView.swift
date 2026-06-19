//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct MouseView: View {
    @Bindable var viewModel: MouseViewModel

    var body: some View {
        VStack(spacing: 16) {
            touchpad
                .aspectRatio(361.0 / 380.0, contentMode: .fit)

            clickButtons

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 84)
        .background(Color.groupedBackground)
    }

    private var touchpad: some View {
        TouchpadGestureView(
            onMove: { dx, dy in viewModel.handleMove(dx: dx, dy: dy) },
            onScroll: { vertical, horizontal in viewModel.handleScroll(vertical: vertical, horizontal: horizontal) },
            onTap: { viewModel.handleTap() },
            onTwoFingerTap: { viewModel.handleRightClick() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Touchpad area")
        .accessibilityHint("Drag with one finger to move cursor, two fingers to scroll, tap to click, two-finger tap for right click")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    private var clickButtons: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.handleLeftClick()
            } label: {
                Text("LEFT CLICK")
            }
            .buttonStyle(TouchpadClickButtonStyle())
            .accessibilityLabel("Left click")
            .accessibilityHint("Double-tap to perform a left click")

            Button {
                viewModel.handleRightClick()
            } label: {
                Text("RIGHT CLICK")
            }
            .buttonStyle(TouchpadClickButtonStyle())
            .accessibilityLabel("Right click")
            .accessibilityHint("Double-tap to perform a right click")
        }
    }
}

private struct TouchpadClickButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(buttonBackground)
            .overlay(buttonHighlight)
            .overlay(buttonBorder)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color(uiColor: .touchpadButtonFill))
            .shadow(color: Color.black.opacity(0.12), radius: 2, y: 2)
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 6)
    }

    private var buttonHighlight: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
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
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color(uiColor: .touchpadStroke), lineWidth: 1)
    }
}

// MARK: - Preview

#Preview {
    MouseView(viewModel: MouseViewModel(device: DeviceModel.preview))
}
