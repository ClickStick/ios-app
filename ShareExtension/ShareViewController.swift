//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import os.log
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Share Extension entry point: extracts the shared text/URL and hosts the SwiftUI
/// "Send to ClickStick" card over a dimmed backdrop.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private let log = Logger(subsystem: "io.clickstick", category: "ShareExtension")
    private var viewModel: ShareExtensionViewModel?
    private var hostingController: UIHostingController<ShareExtensionView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false

        extractSharedText { [weak self] text in
            guard let self else { return }
            if let text, !text.isEmpty {
                log.info("Received shared text with \(text.count) characters")
                presentShareUI(with: text)
            } else {
                log.warning("No text content found to share")
                complete()
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        clearPresentationBackgrounds()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tearDownViewModel()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        tearDownViewModel()
    }

    deinit {
        Task { @MainActor [viewModel] in
            viewModel?.tearDown()
        }
    }

    private func clearPresentationBackgrounds() {
        // iOS may present the extension inside a UIKit-owned container that draws an
        // opaque background. On iOS 26 this can include a private `UIDropShadowView`
        // wrapper; clearing `isOpaque` as well as the background mirrors this workaround:
        // https://stackoverflow.com/a/79811577
        var current: UIView? = view
        while let presentationView = current {
            presentationView.backgroundColor = .clear
            presentationView.isOpaque = false
            current = presentationView.superview
        }

        view.window?.backgroundColor = .clear
        view.window?.isOpaque = false
    }

    // MARK: - Text extraction

    private func extractSharedText(completion: @escaping (String?) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = item.attachments else {
            completion(nil)
            return
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] loaded, error in
                    DispatchQueue.main.async {
                        if let error {
                            self?.log.error("Failed to load text: \(error.localizedDescription)")
                            completion(nil)
                        } else if let text = loaded as? String {
                            completion(text)
                        } else if let data = loaded as? Data {
                            completion(String(data: data, encoding: .utf8))
                        } else {
                            completion(nil)
                        }
                    }
                }
                return
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] loaded, error in
                    DispatchQueue.main.async {
                        if let error {
                            self?.log.error("Failed to load URL: \(error.localizedDescription)")
                            completion(nil)
                        } else {
                            completion((loaded as? URL)?.absoluteString)
                        }
                    }
                }
                return
            }
        }

        completion(nil)
    }

    // MARK: - UI

    private func presentShareUI(with text: String) {
        let viewModel = ShareExtensionViewModel(sharedText: text)
        self.viewModel = viewModel

        let rootView = ShareExtensionView(
            viewModel: viewModel,
            onCancel: { [weak self] in self?.cancel() },
            onComplete: { [weak self] in self?.complete() },
            onAddDevice: { [weak self] in self?.openMainApp() }
        )

        let hosting = UIHostingController(rootView: rootView)
        hosting.view.backgroundColor = .clear
        hosting.view.isOpaque = false
        self.hostingController = hosting

        // The extension is hosted by UIKit, so our SwiftUI hierarchy must fill the
        // provided container while the presentation backgrounds above stay clear.
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)
    }

    // MARK: - Lifecycle

    private func tearDownViewModel() {
        viewModel?.tearDown()
    }

    private func cancel() {
        tearDownViewModel()
        extensionContext?.cancelRequest(withError: NSError(
            domain: "io.clickstick.ShareExtension",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "User cancelled"]
        ))
    }

    private func complete() {
        tearDownViewModel()
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// Opens the containing app (e.g. to add a device).
    private func openMainApp() {
        guard let url = URL(string: "clickstick://add-device") else {
            complete()
            return
        }
        extensionContext?.open(url) { [weak self] success in
            if !success {
                self?.openURLViaResponder(url)
            }
            self?.complete()
        }
    }

    /// Fallback for opening a URL when `extensionContext.open` is unavailable.
    private func openURLViaResponder(_ url: URL) {
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        while let current = responder {
            if current.responds(to: selector), current !== self {
                _ = current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
    }
}
