//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI

struct MouseView: View {
    let device: DeviceModel

    var body: some View {
        content
    }

    private var content: some View {
        VStack(spacing: Spacing.xl) {
            touchpad
                .aspectRatio(353.0 / 380.0, contentMode: .fit)
            clickButtons
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xxxl)
        .background(Color.clickStickGroupedBackground)
    }

    private var touchpad: some View {
        TouchpadGestureView(
            onMove: { dx, dy in handleMove(dx: dx, dy: dy) },
            onScroll: { vertical, horizontal in handleScroll(vertical: vertical, horizontal: horizontal) },
            onTap: { handleTap() },
            onTwoFingerTap: { handleRightClick() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Touchpad area")
        .accessibilityHint("Drag with one finger to move cursor, two fingers to scroll, tap to click, two-finger tap for right click")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    // MARK: - Click Buttons

    private var clickButtons: some View {
        HStack(spacing: Spacing.lg) {
            Button {
                handleLeftClick()
            } label: {
                Text("LEFT CLICK")
            }
            .buttonStyle(TouchpadClickButtonStyle())
            .accessibilityLabel("Left click")
            .accessibilityHint("Double-tap to perform a left click")

            Button {
                handleRightClick()
            } label: {
                Text("RIGHT CLICK")
            }
            .buttonStyle(TouchpadClickButtonStyle())
            .accessibilityLabel("Right click")
            .accessibilityHint("Double-tap to perform a right click")
        }
    }

    // MARK: - Gesture Handlers

    private func handleMove(dx: Int8, dy: Int8) {
        guard device.isConnected else { return }
        device.sendMouseMove(dx: dx, dy: dy)
    }

    private func handleScroll(vertical: Int8, horizontal: Int8) {
        guard device.isConnected else { return }
        device.sendMouseScroll(vertical: vertical, horizontal: horizontal)
    }

    private func handleTap() {
        handleLeftClick()
    }

    private func handleLeftClick() {
        guard device.isConnected else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        device.sendMouseClick(button: .left)
    }

    private func handleRightClick() {
        guard device.isConnected else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        device.sendMouseClick(button: .right)
    }
}

private struct TouchpadClickButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(buttonBackground)
            .overlay(buttonInnerPlasticity)
            .overlay(buttonBorder)
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.extraLarge, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? OpacityLevel.pressed : 1)
            .animation(.easeInOut(duration: Motion.quick), value: configuration.isPressed)
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: CornerRadius.extraLarge, style: .continuous)
            .fill(Color(uiColor: .touchpadButtonFill))
            .shadow(
                color: Color.black.opacity(OpacityLevel.subtleFill),
                radius: Spacing.xxs,
                y: BorderWidth.thick
            )
    }

    private var buttonInnerPlasticity: some View {
        RoundedRectangle(cornerRadius: CornerRadius.extraLarge, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(OpacityLevel.disabled),
                        .clear,
                        .black.opacity(OpacityLevel.subtleFill)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: Spacing.xs
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.extraLarge, style: .continuous))
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: CornerRadius.extraLarge, style: .continuous)
            .stroke(Color(uiColor: .touchpadStroke), lineWidth: BorderWidth.thin)
    }
}

extension UIColor {
    static let touchpadSurfaceFill = UIColor(red: 229 / 255, green: 229 / 255, blue: 235 / 255, alpha: 1)
    static let touchpadButtonFill = UIColor(red: 240 / 255, green: 240 / 255, blue: 245 / 255, alpha: 1)
    static let touchpadStroke = UIColor(red: 200 / 255, green: 208 / 255, blue: 218 / 255, alpha: 1)
}

// MARK: - Preview

#Preview {
    MouseView(device: .preview)
}
