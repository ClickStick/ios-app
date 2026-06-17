//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import DesignSystem
import SwiftUI

/// Warning shown when a device's session data failed to validate (possible tampering).
/// A native bottom sheet (sized to its content) presented when the user taps a
/// "Security warning" row in the Devices list.
struct CompromisedDeviceSheet: View {
    let deviceName: String
    let onRemove: () -> Void
    let onConnectAnyway: () -> Void

    @State private var contentHeight: CGFloat = 420

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.clickStickDestructive.opacity(OpacityLevel.tintedFill))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(Color.clickStickDestructive)
            }
            .padding(.top, Spacing.xl)
            .accessibilityHidden(true)

            Text("Device compromised")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, Spacing.md)

            Text("\(deviceName) may have been modified while unattended. Connecting could expose your data.")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
                .padding(.top, Spacing.sm)

            VStack(spacing: Spacing.sm) {
                Button(action: onRemove) {
                    Text("Remove device")
                        .font(.clickStickBodyEmphasized)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: ComponentSize.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.pill, style: .continuous)
                                .fill(Color.clickStickDestructive)
                        )
                }
                .buttonStyle(.plain)

                Button("Connect anyway", action: onConnectAnyway)
                    .buttonStyle(.secondary(tint: .primary))
            }
            .padding(.top, Spacing.xl)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.size.height, initial: true) { _, height in
                        contentHeight = height
                    }
            }
        }
        .presentationDetents([.height(contentHeight)])
        .presentationBackground(Color.clickStickElevatedBackground)
        .accessibilityElement(children: .contain)
    }
}

#Preview("Device Compromised") {
    Color.clickStickGroupedBackground
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            CompromisedDeviceSheet(
                deviceName: "ClickStick 9F8C",
                onRemove: {},
                onConnectAnyway: {}
            )
        }
}
