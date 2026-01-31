//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Main view for the Share Extension - uses shared TypeTextContentView
struct ShareExtensionView: View {
    @Bindable var viewModel: ShareExtensionViewModel
    let onCancel: () -> Void
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            TypeTextContentView(viewModel: viewModel, onDismiss: onComplete)
                .navigationTitle("Type Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            viewModel.stopScanning()
                            onCancel()
                        }
                    }
                }
                .onAppear {
                    viewModel.startScanning()
                }
                .onDisappear {
                    viewModel.stopScanning()
                }
        }
        .interactiveDismissDisabled()
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
