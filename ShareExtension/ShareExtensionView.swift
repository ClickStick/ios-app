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
        .onChange(of: viewModel.connectionError) { _, error in
            if error != nil {
                showConnectionError = true
            }
        }
        .alert(
            String(localized: "Connection Error", comment: "Share extension error alert title"),
            isPresented: $showConnectionError
        ) {
            Button(String(localized: "OK", comment: "Alert dismiss button")) {}
        } message: {
            if let error = viewModel.connectionError {
                Text(error)
            }
        }
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
