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
            .buttonStyle(touchpadClickButtonStyle)
            .accessibilityLabel("Left click")
            .accessibilityHint("Double-tap to perform a left click")

            Button {
                viewModel.handleRightClick()
            } label: {
                Text("RIGHT CLICK")
            }
            .buttonStyle(touchpadClickButtonStyle)
            .accessibilityLabel("Right click")
            .accessibilityHint("Double-tap to perform a right click")
        }
    }

    // Applied directly via `.buttonStyle` (not through a wrapper's makeBody) so that
    // RaisedKeyButtonStyle's @Environment(\.colorScheme) is injected and dark mode renders.
    private var touchpadClickButtonStyle: RaisedKeyButtonStyle {
        RaisedKeyButtonStyle(height: 58, cornerRadius: 22)
    }
}

// MARK: - Preview

#Preview {
    MouseView(viewModel: MouseViewModel(device: DeviceModel.preview))
}
