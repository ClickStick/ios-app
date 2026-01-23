//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
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

            hintText

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
        HStack(spacing: 4) {
            Image(systemName: icon)
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
            .buttonStyle(ClickButtonStyle(color: .clickStickBlue))
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
            .buttonStyle(ClickButtonStyle(color: .clickStickTeal))
            .accessibilityLabel("Right click button")
            .accessibilityHint("Double-tap to perform a right click")
        }
    }

    // MARK: - Hint Text

    private var hintText: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Color.clickStickOrange)
            Text("Two-finger tap on touchpad = right click")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(Color.clickStickOrange.opacity(0.1))
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
        device.sendMouseClick(button: .left) { result in
            if case .failure(let error) = result {
                alertError = AlertError(error: error)
            }
        }
    }

    private func handleRightClick() {
        guard device.isConnected else { return }
        device.sendMouseClick(button: .right) { result in
            if case .failure(let error) = result {
                alertError = AlertError(error: error)
            }
        }
    }
}

// MARK: - Click Button Style

struct ClickButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(color)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    MouseView(device: .preview)
}

