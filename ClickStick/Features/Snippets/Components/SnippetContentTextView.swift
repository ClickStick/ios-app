//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI
import UIKit

/// A `UITextView`-backed editor for snippet content. Text is typed inline and special keys are
/// inserted at the caret as pill-shaped text attachments, so text and keys mix freely and stay
/// fully editable — matching the "type text, insert keys inline" design.
struct SnippetContentTextView: UIViewRepresentable {
    @Binding var tokens: [SnippetToken]
    @Binding var isEditing: Bool
    let controller: SnippetContentController
    let placeholder: String
    /// Called when the toolbar's Cursor button is tapped (SwiftUI presents the cursor-key screen).
    let onRequestCursor: () -> Void
    /// Called when the toolbar's Fn button is tapped (SwiftUI presents the function-key screen).
    let onRequestFunctionKeys: () -> Void
    /// Called when the toolbar's Delay button is tapped (SwiftUI presents the delay sheet).
    let onRequestDelay: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.delegate = context.coordinator
        textView.typingAttributes = context.coordinator.defaultAttributes(font: textView.font)

        // Snippet content is literal (usernames, passwords, commands): keep the keyboard from
        // rewriting it or drawing predictive/spell-check underlines mid-text.
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no

        textView.inputAccessoryView = context.coordinator.makeKeyToolbar()

        let placeholderLabel = UILabel()
        placeholderLabel.font = textView.font
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor)
        ])

        context.coordinator.textView = textView
        context.coordinator.placeholderLabel = placeholderLabel
        controller.coordinator = context.coordinator

        textView.attributedText = context.coordinator.attributedString(from: tokens, font: textView.font)
        context.coordinator.updatePlaceholder()
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.placeholderLabel?.text = placeholder
        context.coordinator.updatePlaceholder()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SnippetContentTextView
        weak var textView: UITextView?
        weak var placeholderLabel: UILabel?
        /// Retained so the SwiftUI-hosted input accessory isn't deallocated.
        private var accessoryHost: UIViewController?

        init(_ parent: SnippetContentTextView) {
            self.parent = parent
        }

        // MARK: Input accessory (key toolbar)

        /// Builds the key toolbar as a keyboard input accessory view. Being attached to the text
        /// view, it reappears whenever the field regains focus — including after returning from the
        /// function-key screen — so navigation can't strand it.
        func makeKeyToolbar() -> UIView {
            let toolbar = SnippetKeyToolbar(
                onInsert: { [weak self] token in self?.insert(token) },
                onCursor: { [weak self] in self?.requestCursor() },
                onFunctionKeys: { [weak self] in self?.requestFunctionKeys() },
                onDelay: { [weak self] in self?.requestDelay() }
            )
            let host = UIHostingController(rootView: toolbar)
            host.view.backgroundColor = .clear
            host.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 58)
            host.view.autoresizingMask = .flexibleWidth
            accessoryHost = host
            return host.view
        }

        private func requestCursor() {
            textView?.resignFirstResponder()
            parent.onRequestCursor()
        }

        private func requestFunctionKeys() {
            textView?.resignFirstResponder()
            parent.onRequestFunctionKeys()
        }

        private func requestDelay() {
            textView?.resignFirstResponder()
            parent.onRequestDelay()
        }

        func defaultAttributes(font: UIFont?) -> [NSAttributedString.Key: Any] {
            [
                .font: font ?? UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label
            ]
        }

        // MARK: Inserting keys

        /// Inserts a key token as an attachment at the current caret position.
        func insert(_ token: SnippetToken) {
            guard let textView else { return }
            let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
            guard let image = chipImage(for: token, font: font, traits: textView.traitCollection) else { return }

            let attachment = KeyTextAttachment(token: token, image: image, font: font)
            let attachmentString = NSMutableAttributedString(attachment: attachment)
            attachmentString.addAttributes(
                defaultAttributes(font: font),
                range: NSRange(location: 0, length: attachmentString.length)
            )

            let updated = NSMutableAttributedString(attributedString: textView.attributedText)
            let range = textView.selectedRange
            updated.replaceCharacters(in: range, with: attachmentString)

            textView.attributedText = updated
            textView.selectedRange = NSRange(location: range.location + attachmentString.length, length: 0)
            textView.typingAttributes = defaultAttributes(font: font)
            textView.becomeFirstResponder()

            syncTokens()
            updatePlaceholder()
        }

        // MARK: Conversion

        func attributedString(from tokens: [SnippetToken], font: UIFont?) -> NSAttributedString {
            let resolvedFont = font ?? UIFont.preferredFont(forTextStyle: .body)
            let result = NSMutableAttributedString()
            for token in tokens {
                switch token {
                case .text(let value):
                    result.append(NSAttributedString(string: value, attributes: defaultAttributes(font: resolvedFont)))
                default:
                    let image = chipImage(for: token, font: resolvedFont, traits: textView?.traitCollection ?? .current)
                    let attachment = KeyTextAttachment(token: token, image: image, font: resolvedFont)
                    let attachmentString = NSMutableAttributedString(attachment: attachment)
                    attachmentString.addAttributes(
                        defaultAttributes(font: resolvedFont),
                        range: NSRange(location: 0, length: attachmentString.length)
                    )
                    result.append(attachmentString)
                }
            }
            return result
        }

        private func tokens(from attributed: NSAttributedString) -> [SnippetToken] {
            var tokens: [SnippetToken] = []
            var pendingText = ""
            attributed.enumerateAttribute(
                .attachment,
                in: NSRange(location: 0, length: attributed.length),
                options: []
            ) { value, range, _ in
                if let attachment = value as? KeyTextAttachment {
                    if !pendingText.isEmpty {
                        tokens.append(.text(pendingText))
                        pendingText = ""
                    }
                    tokens.append(attachment.token)
                } else {
                    pendingText += attributed.attributedSubstring(from: range).string
                }
            }
            if !pendingText.isEmpty {
                tokens.append(.text(pendingText))
            }
            return tokens
        }

        private func syncTokens() {
            guard let textView else { return }
            parent.tokens = tokens(from: textView.attributedText)
        }

        func updatePlaceholder() {
            placeholderLabel?.isHidden = !(textView?.attributedText.length == 0)
        }

        // MARK: UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            syncTokens()
            updatePlaceholder()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isEditing = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isEditing = false
        }
    }
}

// MARK: - Attachment

/// A text attachment that carries the `SnippetToken` it represents so content can be parsed back
/// out of the text view, and renders a pill image vertically centered on the text line.
final class KeyTextAttachment: NSTextAttachment {
    let token: SnippetToken

    init(token: SnippetToken, image: UIImage?, font: UIFont) {
        self.token = token
        super.init(data: nil, ofType: nil)
        self.image = image
        if let image {
            let height = image.size.height
            bounds = CGRect(
                x: 0,
                y: (font.capHeight - height) / 2,
                width: image.size.width,
                height: height
            )
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Chip image

/// Renders a `KeyChipLabel` to an image for use as an inline text attachment.
@MainActor
private func chipImage(for token: SnippetToken, font: UIFont, traits: UITraitCollection) -> UIImage? {
    guard let label = KeyChipLabel(token: token) else { return nil }
    let renderer = ImageRenderer(
        content: label.environment(\.colorScheme, traits.userInterfaceStyle == .dark ? .dark : .light)
    )
    renderer.scale = traits.displayScale > 0 ? traits.displayScale : UIScreen.main.scale
    return renderer.uiImage
}

/// A handle the SwiftUI toolbar uses to insert keys into the active text view.
@MainActor
final class SnippetContentController {
    fileprivate weak var coordinator: SnippetContentTextView.Coordinator?

    func insert(_ token: SnippetToken) {
        coordinator?.insert(token)
    }
}
