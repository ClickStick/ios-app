//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// The rounded, colored icon tile used in snippet rows, the editor, and the icon picker.
struct SnippetIconTile: View {
    let icon: SnippetIcon
    var size: CGFloat = 40

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.35, style: .continuous)
            .fill(icon.tileColor)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: icon.systemImage)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(), count: 4), spacing: 16) {
        ForEach(SnippetIcon.allCases) { icon in
            SnippetIconTile(icon: icon, size: 60)
        }
    }
    .padding()
    .background(Color.groupedBackground)
}
