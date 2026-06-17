//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

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
                    .fill(Color(.systemRed).opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(Color(.systemRed))
            }
            .padding(.top, 24)
            .accessibilityHidden(true)

            Text("Device compromised")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.top, 16)

            Text("\(deviceName) may have been modified while unattended. Connecting could expose your data.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
                .padding(.top, 12)

            VStack(spacing: 12) {
                Button("Remove device", action: onRemove)
                    .buttonStyle(AppPrimaryButtonStyle(fill: Color(.systemRed)))

                Button("Connect anyway", action: onConnectAnyway)
                    .buttonStyle(AppSecondaryButtonStyle())
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
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
        .presentationBackground(Color(.secondarySystemGroupedBackground))
        .accessibilityElement(children: .contain)
    }
}

#Preview("Device Compromised") {
    Color.groupedBackground
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            CompromisedDeviceSheet(
                deviceName: "ClickStick 9F8C",
                onRemove: {},
                onConnectAnyway: {}
            )
        }
}

// Direct content preview (the sheet-presented preview above can't be snapshotted).
#Preview("Compromised content") {
    CompromisedDeviceSheet(
        deviceName: "ClickStick 9F8C",
        onRemove: {},
        onConnectAnyway: {}
    )
    .frame(maxHeight: .infinity, alignment: .bottom)
    .background(Color(.secondarySystemGroupedBackground).ignoresSafeArea())
}
