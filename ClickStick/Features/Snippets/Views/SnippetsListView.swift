//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// The Snippets tab content: a list of snippet rows, or an empty state when there are none.
/// Presents the create/edit editor as a sheet.
struct SnippetsListView: View {
    @Bindable var viewModel: SnippetsViewModel
    @State private var unsupportedSheetHeight: CGFloat = .zero

    var body: some View {
        Group {
            if viewModel.snippets.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.groupedBackground.ignoresSafeArea())
        .overlay(alignment: .center) {
            if viewModel.showSentToast {
                SentToastView(deviceName: viewModel.deviceName)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showSentToast)
        .sheet(item: $viewModel.editorTarget) { target in
            SnippetEditorView(
                viewModel: SnippetEditorViewModel(snippet: target.snippet),
                onCancel: { viewModel.editorTarget = nil },
                onSave: { viewModel.commit($0) }
            )
        }
        .sheet(isPresented: $viewModel.isShowingUnsupportedPrompt) {
            unsupportedCharactersSheet
                .measureHeight($unsupportedSheetHeight)
                .presentationBackground(Color(uiColor: .systemBackground))
                .presentationDetents(sheetDetents(for: unsupportedSheetHeight))
                .presentationBackgroundInteraction(.disabled)
        }
        .errorAlert($viewModel.alertError)
    }

    private var unsupportedCharactersSheet: some View {
        TextEntryWarningSheet(
            title: "Unsupported characters",
            message: viewModel.unsupportedPromptMessage ?? "Some characters can't be typed with the selected layout.",
            secondaryTitle: "Close",
            secondaryAction: viewModel.dismissUnsupportedPrompt,
            primaryTitle: "Edit snippet",
            primaryAction: viewModel.editUnsupportedSnippet
        )
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.snippets) { snippet in
                    SnippetRowView(
                        snippet: snippet,
                        isRunning: viewModel.runningSnippetID == snippet.id,
                        onRun: { viewModel.run(snippet) },
                        onEdit: { viewModel.edit(snippet) },
                        onDelete: { viewModel.delete(snippet) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No snippets yet")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text("Tap + to create your first snippet")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Snippets List") {
    SnippetsListView(viewModel: SnippetsViewModel(previewSnippets: Snippet.previews))
}

#Preview("Snippets Empty") {
    SnippetsListView(viewModel: SnippetsViewModel(previewSnippets: []))
}
