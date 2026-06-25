//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

extension View {
    func measureHeight(_ height: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height.wrappedValue = $0 }
    }
}

func sheetDetents(for height: CGFloat) -> Set<PresentationDetent> {
    height > .zero ? [.height(height)] : [.medium]
}
