//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Main view for the Share Extension - uses shared TypeTextContentView
struct ShareExtensionView: View {
    @Bindable var viewModel: ShareExtensionViewModel
    let onCancel: () -> Void
    let onComplete: () -> Void

    @State private var showConnectionError = false

    var body: some View {
        Text("Not implemented")
    }
}

// MARK: - Preview

#Preview {
    ShareExtensionView(
        viewModel: ShareExtensionViewModel(sharedText: "MySecretPassword123!@#"),
        onCancel: {},
        onComplete: {}
    )
}
