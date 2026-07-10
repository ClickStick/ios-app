//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Grid of cursor-movement keys (arrows, Home, End). Selecting one inserts it and pops.
struct CursorKeysView: View {
    let onSelect: (CursorKey) -> Void

    var body: some View {
        KeyGridView(items: CursorKey.allCases, title: "Cursor", onSelect: onSelect) { key in
            if let systemImage = key.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 29, weight: .regular))
                    .foregroundStyle(.primary)
                    .accessibilityLabel(Text(key.title))
            } else {
                Text(key.title.uppercased())
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.primary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CursorKeysView(onSelect: { _ in })
    }
}
