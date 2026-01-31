//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

/// Sheet presented when the app receives a deep link request to type text
struct DeepLinkTypeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let request: TypeRequest
    let service: ClickStickService
    let deepLinkHandler: DeepLinkHandler

    @State private var viewModel: DeepLinkTypeViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    TypeTextContentView(viewModel: viewModel, onDismiss: { dismiss() }) {
                        sourceAppHeader(viewModel: viewModel)
                    }
                } else {
                    ProgressView()
                        .onAppear {
                            viewModel = DeepLinkTypeViewModel(
                                request: request,
                                service: service,
                                deepLinkHandler: deepLinkHandler
                            )
                        }
                }
            }
            .navigationTitle("Type Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel?.cancel()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Source App Header

    private func sourceAppHeader(viewModel: DeepLinkTypeViewModel) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "arrow.down.app")
                .font(.title2)
                .foregroundStyle(Color.clickStickBlue)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("\(viewModel.sourceAppName) wants to type:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.clickStickBlue.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Request from \(viewModel.sourceAppName)")
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var service = ClickStickService()
    @Previewable @State var handler = DeepLinkHandler(urlOpener: URLOpener())

    DeepLinkTypeSheet(
        request: TypeRequest(
            text: "MySecretPassword123!@#",
            layout: .usQWERTY,
            deviceIdentifier: nil,
            sourceApp: "KeePassium",
            successURL: nil,
            errorURL: nil,
            cancelURL: nil
        ),
        service: service,
        deepLinkHandler: handler
    )
}
