//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI

struct MouseView: View {
    let device: DeviceModel

    @State private var alertError: AlertError?

    var body: some View {
        VStack(spacing: Spacing.md) {
            instructionsHeader

            TouchpadGestureView(
                onMove: handleMove,
                onScroll: handleScroll,
                onTap: handleTap,
                onTwoFingerTap: handleRightClick
            )
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Touchpad area")
            .accessibilityHint("Drag with one finger to move cursor, two fingers to scroll, tap to click, two-finger tap for right click")
            .accessibilityAddTraits(.allowsDirectInteraction)

            clickButtons
                .disabled(!device.isConnected)

            hintText

            if !device.isConnected && !device.isConnecting {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "cable.connector.horizontal")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Device disconnected")
                        .font(.subheadline.weight(.medium))
                    Text("Touchpad gestures are paused.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.clickStickOrange.opacity(OpacityLevel.subtleFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.clickStickOrange.opacity(OpacityLevel.subtleBorder), lineWidth: BorderWidth.thin)
                )
                .accessibilityElement(children: .combine)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .errorAlert($alertError)
    }

    // MARK: - Instructions Header

    private var instructionsHeader: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "hand.draw")
                    .font(.headline)
                    .foregroundStyle(Color.clickStickBlue)
                    .accessibilityHidden(true)
                Text("Touchpad")
                    .font(.headline)
            }
            .accessibilityAddTraits(.isHeader)

            HStack(spacing: Spacing.lg) {
                instructionItem(icon: "hand.point.up.left", text: "Drag")
                instructionItem(icon: "hand.tap", text: "Tap")
                instructionItem(icon: "rectangle.portrait.arrowtriangle.2.outward", text: "2-finger scroll")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, Spacing.xs)
    }

    private func instructionItem(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .accessibilityHidden(true)
            Text(text)
        }
    }

    // MARK: - Click Buttons

    private var clickButtons: some View {
        HStack(spacing: Spacing.md) {
            Button {
                handleLeftClick()
            } label: {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "hand.tap.fill")
                        .font(.title2)
                    Text("Left Click")
                        .font(.caption.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.tintedOutline(color: .clickStickBlue))
            .accessibilityLabel("Left click button")
            .accessibilityHint("Double-tap to perform a left click")

            Button {
                handleRightClick()
            } label: {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "hand.tap.fill")
                        .font(.title2)
                    Text("Right Click")
                        .font(.caption.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.tintedOutline(color: .clickStickTeal))
            .accessibilityLabel("Right click button")
            .accessibilityHint("Double-tap to perform a right click")
        }
    }

    // MARK: - Hint Text

    private var hintText: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Color.clickStickOrange)
                .accessibilityHidden(true)
            Text("Two-finger tap on touchpad = right click")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.clickStickOrange.opacity(OpacityLevel.subtleFill))
        )
    }

    // MARK: - Gesture Handlers

    private func handleMove(dx: Int8, dy: Int8) {
        guard device.isConnected else { return }
        device.sendMouseMove(dx: dx, dy: dy) { result in
            if case .failure(let error) = result {
                alertError = AlertError(error: error)
            }
        }
    }

    private func handleScroll(vertical: Int8, horizontal: Int8) {
        guard device.isConnected else { return }
        device.sendMouseScroll(vertical: vertical, horizontal: horizontal) { result in
            if case .failure(let error) = result {
                alertError = AlertError(error: error)
            }
        }
    }

    private func handleTap() {
        handleLeftClick()
    }

    private func handleLeftClick() {
        guard device.isConnected else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        device.sendMouseClick(button: .left) { result in
            if case .failure(let error) = result {
                alertError = AlertError(error: error)
            }
        }
    }

    private func handleRightClick() {
        guard device.isConnected else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        device.sendMouseClick(button: .right) { result in
            if case .failure(let error) = result {
                alertError = AlertError(error: error)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MouseView(device: .preview)
}
