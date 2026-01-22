//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct MouseView: View {
    let device: DeviceModel

    @State private var alertError: AlertError?

    var body: some View {
        VStack(spacing: 20) {
            instructionsHeader

            TouchpadGestureView(
                onMove: handleMove,
                onScroll: handleScroll,
                onTap: handleTap,
                onTwoFingerTap: handleRightClick
            )
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Touchpad area")
            .accessibilityHint("Drag with one finger to move cursor, two fingers to scroll, tap to click, two-finger tap for right click")
            .accessibilityAddTraits(.allowsDirectInteraction)

            clickButtons

            hintText

            Spacer()
        }
        .padding()
        .errorAlert($alertError)
    }

    // MARK: - Instructions Header

    private var instructionsHeader: some View {
        VStack(spacing: 4) {
            Text("Touchpad")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text("Drag to move • Two fingers to scroll • Tap to click")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Instructions: Drag to move cursor, use two fingers to scroll, tap to click")
        }
    }

    // MARK: - Click Buttons

    private var clickButtons: some View {
        HStack(spacing: 16) {
            Button {
                handleLeftClick()
            } label: {
                Label("Left Click", systemImage: "hand.tap.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityLabel("Left click button")
            .accessibilityHint("Double-tap to perform a left click")

            Button {
                handleRightClick()
            } label: {
                Label("Right Click", systemImage: "hand.tap.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityLabel("Right click button",)
            .accessibilityHint("Double-tap to perform a right click")
        }
    }

    // MARK: - Hint Text

    private var hintText: some View {
        Text("Tip: Use two-finger tap on the touchpad for right click")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
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

// MARK: - Preview

#Preview {
    MouseView(device: .preview)
}

