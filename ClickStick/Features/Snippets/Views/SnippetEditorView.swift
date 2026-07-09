//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// Create/edit screen for a snippet: icon, name, and a token-based content editor with a toolbar
/// for inserting special keys and delays.
struct SnippetEditorView: View {
    @State private var viewModel: SnippetEditorViewModel
    let onCancel: () -> Void
    let onSave: (Snippet) -> Void

    @State private var contentController = SnippetContentController()
    @State private var route: EditorRoute?
    @State private var showDelaySheet = false
    @State private var delaySheetHeight: CGFloat = .zero

    private enum EditorRoute: Hashable {
        case icon
        case cursor
        case functionKeys
    }

    init(viewModel: SnippetEditorViewModel, onCancel: @escaping () -> Void, onSave: @escaping (Snippet) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SnippetIconButtonSection(icon: viewModel.icon) { route = .icon }

                    SnippetNameSection(name: $viewModel.name)

                    SnippetContentSection(
                        tokens: $viewModel.tokens,
                        controller: contentController,
                        onRequestCursor: { route = .cursor },
                        onRequestFunctionKeys: { route = .functionKeys },
                        onRequestDelay: { showDelaySheet = true }
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
            .background(Color.groupedBackground.ignoresSafeArea())
            .navigationTitle(viewModel.isEditing ? "Edit Snippet" : "New Snippet")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $route) { route in
                switch route {
                case .icon:
                    IconPickerView(selected: viewModel.icon) { viewModel.icon = $0 }
                case .cursor:
                    CursorKeysView { contentController.insert(.cursor($0)) }
                case .functionKeys:
                    FunctionKeysView { contentController.insert(.functionKey($0)) }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SnippetCancelButton(onCancel: onCancel)
                }
                .appHiddenSharedToolbarBackground()
                ToolbarItem(placement: .primaryAction) {
                    SnippetSaveButton(canSave: viewModel.canSave) { onSave(viewModel.build()) }
                }
                .appHiddenSharedToolbarBackground()
            }
            .tint(.accentBlue)
        }
        .sheet(isPresented: $showDelaySheet) {
            AddDelaySheet(
                onCancel: { showDelaySheet = false },
                onAdd: { seconds in
                    contentController.insert(.delay(seconds: seconds))
                    showDelaySheet = false
                }
            )
            .measureHeight($delaySheetHeight)
            .presentationBackground(Color(uiColor: .systemBackground))
            .presentationDetents(sheetDetents(for: delaySheetHeight))
        }
    }
}

// MARK: - Toolbar buttons

private struct SnippetCancelButton: View {
    let onCancel: () -> Void

    var body: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule(style: .continuous).fill(Color.cardBackground))
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}

private struct SnippetSaveButton: View {
    let canSave: Bool
    let onSave: () -> Void

    var body: some View {
        Button(action: onSave) {
            Image(systemName: "checkmark")
        }
        .buttonStyle(CircularToolbarButtonStyle(role: .prominent))
        .disabled(!canSave)
        .accessibilityLabel(String(localized: "Save snippet", comment: "Save snippet button accessibility"))
    }
}

// MARK: - Sections

private struct SnippetIconButtonSection: View {
    let icon: SnippetIcon
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            SnippetIconTile(icon: icon, size: 64)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Choose icon", comment: "Choose icon button accessibility"))
        .frame(maxWidth: .infinity)
    }
}

private struct SnippetNameSection: View {
    @Binding var name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Name")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            TextField(text: $name) {
                Text("e.g. Work Server, Netflix Login")
                    .foregroundStyle(.secondary)
            }
            .font(.body)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

/// Owns its own editing-focus state so typing/inserting keys doesn't invalidate the rest of
/// `SnippetEditorView` (icon, name field, toolbar) — only this section's focus ring redraws.
private struct SnippetContentSection: View {
    @Binding var tokens: [SnippetToken]
    let controller: SnippetContentController
    let onRequestCursor: () -> Void
    let onRequestFunctionKeys: () -> Void
    let onRequestDelay: () -> Void

    @State private var contentEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Snippet content")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 8) {
                SnippetContentTextView(
                    tokens: $tokens,
                    isEditing: $contentEditing,
                    controller: controller,
                    placeholder: String(localized: "Type your text here, then add special keys below", comment: "Snippet content placeholder"),
                    onRequestCursor: onRequestCursor,
                    onRequestFunctionKeys: onRequestFunctionKeys,
                    onRequestDelay: onRequestDelay
                )
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .padding(16)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(contentEditing ? Color.accentBlue : Color.clear, lineWidth: 2)
                }

                Text("Type text and use the toolbar to insert keys or delays.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

#Preview("New Snippet") {
    SnippetEditorView(
        viewModel: SnippetEditorViewModel(snippet: nil),
        onCancel: {},
        onSave: { _ in }
    )
}

#Preview("Edit Snippet") {
    SnippetEditorView(
        viewModel: SnippetEditorViewModel(snippet: .previewFilled),
        onCancel: {},
        onSave: { _ in }
    )
}
