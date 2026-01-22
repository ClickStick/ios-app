//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct MouseView: View {
    let device: DeviceModel

    @State private var lastError: String?

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
            .accessibilityLabel("Touchpad area")
            .accessibilityHint("Drag to move cursor, two fingers to scroll, tap to click")

            clickButtons

            if let error = lastError {
                errorBanner(error)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Instructions Header

    private var instructionsHeader: some View {
        VStack(spacing: 4) {
            Text("Touchpad")
                .font(.headline)

            Text("Drag to move \u{2022} Two fingers to scroll \u{2022} Tap to click")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
            .accessibilityLabel("Left click")

            Button {
                handleRightClick()
            } label: {
                Label("Right Click", systemImage: "hand.tap.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityLabel("Right click")
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
            Spacer()
            Button("Dismiss") {
                lastError = nil
            }
            .font(.caption)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Gesture Handlers

    private func handleMove(dx: Int8, dy: Int8) {
        guard device.isConnected else { return }
        device.sendMouseMove(dx: dx, dy: dy) { result in
            if case .failure(let error) = result {
                lastError = error.localizedDescription
            }
        }
    }

    private func handleScroll(vertical: Int8, horizontal: Int8) {
        guard device.isConnected else { return }
        device.sendMouseScroll(vertical: vertical, horizontal: horizontal) { result in
            if case .failure(let error) = result {
                lastError = error.localizedDescription
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
                lastError = error.localizedDescription
            }
        }
    }

    private func handleRightClick() {
        guard device.isConnected else { return }
        device.sendMouseClick(button: .right) { result in
            if case .failure(let error) = result {
                lastError = error.localizedDescription
            }
        }
    }
}

