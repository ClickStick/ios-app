//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Grid of function keys F1–F12. Selecting one inserts it into the snippet and pops.
struct FunctionKeysView: View {
    let onSelect: (Int) -> Void

    var body: some View {
        KeyGridView(items: Array(1...12), title: "Function keys", onSelect: onSelect) { number in
            Text("F\(number)")
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    NavigationStack {
        FunctionKeysView(onSelect: { _ in })
    }
}
