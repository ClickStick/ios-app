//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import os.log
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Share Extension view controller that hosts SwiftUI content
@objc(ShareViewController)
class ShareViewController: UIViewController {
    private let log = Logger(subsystem: "io.clickstick", category: "ShareExtension")

    private var hostingController: UIHostingController<ShareExtensionView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        log.info("Share Extension loaded")

        extractSharedText { [weak self] text in
            guard let self else { return }

            if let text, !text.isEmpty {
                log.info("Received shared text with \(text.count) characters")
                self.presentShareUI(with: text)
            } else {
                log.warning("No text content found in share")
                self.showError(message: "No text content found to share.")
            }
        }
    }

    // MARK: - Text Extraction

    private func extractSharedText(completion: @escaping (String?) -> Void) {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProviders = extensionItem.attachments else {
            completion(nil)
            return
        }

        // Try to find a text item provider
        for provider in itemProviders {
            // Check for plain text
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                    DispatchQueue.main.async {
                        if let error {
                            self.log.error("Failed to load text: \(error.localizedDescription)")
                            completion(nil)
                            return
                        }

                        if let text = item as? String {
                            completion(text)
                        } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                            completion(text)
                        } else {
                            completion(nil)
                        }
                    }
                }
                return
            }

            // Check for URL (convert to string)
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                    DispatchQueue.main.async {
                        if let error {
                            self.log.error("Failed to load URL: \(error.localizedDescription)")
                            completion(nil)
                            return
                        }

                        if let url = item as? URL {
                            completion(url.absoluteString)
                        } else {
                            completion(nil)
                        }
                    }
                }
                return
            }
        }

        completion(nil)
    }

    // MARK: - UI Presentation

    private func presentShareUI(with text: String) {
        let viewModel = ShareExtensionViewModel(sharedText: text)

        let shareView = ShareExtensionView(
            viewModel: viewModel,
            onCancel: { [weak self] in
                self?.cancel()
            },
            onComplete: { [weak self] in
                self?.complete()
            }
        )

        let hostingController = UIHostingController(rootView: shareView)
        self.hostingController = hostingController

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    private func showError(message: String) {
        let alert = UIAlertController(
            title: "Cannot Share",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.cancel()
        })
        present(alert, animated: true)
    }

    // MARK: - Extension Lifecycle

    private func cancel() {
        log.info("Share Extension cancelled")
        extensionContext?.cancelRequest(withError: NSError(
            domain: "io.clickstick.ShareExtension",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "User cancelled"]
        ))
    }

    private func complete() {
        log.info("Share Extension completed successfully")
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
