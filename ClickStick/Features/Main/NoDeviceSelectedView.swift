//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct NoDeviceSelectedView: View {
    var body: some View {
        ContentUnavailableView(
            "Select a Device",
            image: "dongle.usb",
            description: Text("Choose a connected ClickStick from the devices list.")
        )
        .background(Color.groupedBackground.ignoresSafeArea())
    }
}

#Preview {
    NoDeviceSelectedView()
}
