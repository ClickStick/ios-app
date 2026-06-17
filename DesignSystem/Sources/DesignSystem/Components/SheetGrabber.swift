//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

public struct SheetGrabber: View {
    private let color: Color

    public init(color: Color = .clickStickSeparator) {
        self.color = color
    }

    public var body: some View {
        Capsule()
            .fill(color)
            .frame(width: ComponentSize.sheetGrabberWidth, height: ComponentSize.sheetGrabberHeight)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack {
        SheetGrabber()
    }
    .padding()
    .background(Color.clickStickCardBackground)
}
