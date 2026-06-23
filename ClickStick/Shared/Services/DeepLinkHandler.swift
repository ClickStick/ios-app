//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import Observation
import os.log
import SwiftUI
import UIKit

/// Handles incoming deep links (x-callback-url) and routes them to appropriate actions
@Observable
@MainActor
final class DeepLinkHandler {
    private let log = Logger(subsystem: "io.clickstick", category: "DeepLinkHandler")
    private let urlOpener: URLOpening

    // MARK: - State

    /// Pending type request waiting for user confirmation
    var pendingTypeRequest: TypeRequest?

    /// Error to display if URL parsing fails
    var parsingError: DeepLinkParsingError?

    // MARK: - Initialization

    init(urlOpener: URLOpening) {
        self.urlOpener = urlOpener
    }

    // MARK: - URL Handling

    /// Handles an incoming URL. Returns true if the URL was recognized and processed.
    @discardableResult
    func handle(url: URL) -> Bool {
        log.info("Received deep link: \(url.absoluteString, privacy: .private)")

        guard url.scheme?.lowercased() == "clickstick" else {
            log.debug("Unknown scheme: \(url.scheme ?? "nil")")
            return false
        }

        guard url.host?.lowercased() == "x-callback-url" else {
            log.debug("Unknown host: \(url.host ?? "nil")")
            return false
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let action = pathComponents.first?.lowercased() else {
            log.error("No action in URL path")
            parsingError = DeepLinkParsingError(code: .invalidURL, url: url)
            return false
        }

        switch action {
        case "type":
            return handleTypeAction(url: url)
        default:
            log.error("Unknown action: \(action)")
            parsingError = DeepLinkParsingError(code: .invalidURL, url: url)
            return false
        }
    }

    // MARK: - Type Action

    private func handleTypeAction(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            log.error("Failed to parse URL components")
            parsingError = DeepLinkParsingError(code: .invalidURL, url: url)
            return false
        }

        let queryItems = components.queryItems ?? []
        let params = Dictionary(queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        }, uniquingKeysWith: { _, last in last })

        // Required: text parameter
        guard let encodedText = params["text"] else {
            log.error("Missing required 'text' parameter")
            parsingError = DeepLinkParsingError(code: .missingText, url: url)
            callErrorURL(params: params, errorCode: .missingText)
            return false
        }

        // URLComponents already decodes query parameters (RFC 3986 percent encoding)
        let decodedText = encodedText
        guard !decodedText.isEmpty else {
            log.error("Empty text parameter")
            parsingError = DeepLinkParsingError(code: .emptyText, url: url)
            callErrorURL(params: params, errorCode: .emptyText)
            return false
        }

        // Optional: layout parameter
        let layout = CSKeyboardLayout(urlParameter: params["layout"])

        // Optional: device identifier (UUID or alias)
        let deviceIdentifier = params["device"]

        // x-callback-url standard parameters
        let sourceApp = params["x-source"]
        let successURL = params["x-success"].flatMap { URL(string: $0) }
        let errorURL = params["x-error"].flatMap { URL(string: $0) }
        let cancelURL = params["x-cancel"].flatMap { URL(string: $0) }

        let request = TypeRequest(
            text: decodedText,
            layout: layout,
            deviceIdentifier: deviceIdentifier,
            sourceApp: sourceApp,
            successURL: successURL,
            errorURL: errorURL,
            cancelURL: cancelURL
        )

        log.info("Parsed type request: \(request.text.count) chars, layout: \(request.effectiveLayout.description)")
        pendingTypeRequest = request
        return true
    }

    // MARK: - Callback Handling

    /// Calls the success URL to return to the source app
    func callSuccessURL(for request: TypeRequest) {
        defer { clearPendingRequest() }
        guard let successURL = request.successURL else {
            log.debug("No success URL to call")
            return
        }
        log.info("Calling success URL")
        urlOpener.open(successURL) { [weak self] success in
            self?.log.debug("Success URL opened: \(success)")
        }
    }

    /// Calls the error URL with error details
    func callErrorURL(for request: TypeRequest, errorCode: DeepLinkErrorCode, errorMessage: String? = nil) {
        guard let errorURL = request.errorURL else {
            log.debug("No error URL to call")
            return
        }
        callErrorURLInternal(errorURL: errorURL, errorCode: errorCode, errorMessage: errorMessage)
    }

    /// Calls the cancel URL to return to the source app
    func callCancelURL(for request: TypeRequest) {
        defer { clearPendingRequest() }
        guard let cancelURL = request.cancelURL else {
            log.debug("No cancel URL to call")
            return
        }
        log.info("Calling cancel URL")
        urlOpener.open(cancelURL) { [weak self] success in
            self?.log.debug("Cancel URL opened: \(success)")
        }
    }

    // MARK: - Private Helpers

    private func callErrorURL(params: [String: String], errorCode: DeepLinkErrorCode) {
        guard let errorURLString = params["x-error"],
              let errorURL = URL(string: errorURLString) else {
            return
        }
        callErrorURLInternal(errorURL: errorURL, errorCode: errorCode, errorMessage: nil)
    }

    private func callErrorURLInternal(errorURL: URL, errorCode: DeepLinkErrorCode, errorMessage: String?) {
        var components = URLComponents(url: errorURL, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "errorCode", value: errorCode.rawValue))
        queryItems.append(URLQueryItem(name: "errorMessage", value: errorMessage ?? errorCode.message))
        components?.queryItems = queryItems

        guard let finalURL = components?.url else {
            log.error("Failed to construct error URL")
            return
        }

        log.info("Calling error URL with code: \(errorCode.rawValue)")
        urlOpener.open(finalURL) { [weak self] success in
            self?.log.debug("Error URL opened: \(success)")
        }
    }

    /// Clears any pending request (for cleanup)
    func clearPendingRequest() {
        pendingTypeRequest = nil
    }

    /// Clears any parsing error
    func clearParsingError() {
        parsingError = nil
    }

    /// Resets all state
    func reset() {
        clearPendingRequest()
        clearParsingError()
    }
}

// MARK: - Parsing Error

struct DeepLinkParsingError: Identifiable, Equatable {
    let id = UUID()
    let code: DeepLinkErrorCode
    let url: URL
}

// MARK: - CSKeyboardLayout URL Extension

extension CSKeyboardLayout {
    /// Initialize from a URL parameter string
    init?(urlParameter: String?) {
        guard let param = urlParameter?.lowercased() else { return nil }
        switch param {
        case "us", "qwerty", "us-qwerty", "en":
            self = .usQWERTY
        case "de", "qwertz", "de-qwertz":
            self = .deQWERTZ
        case "fr", "azerty", "fr-azerty":
            self = .frAZERTY_Classic
        default:
            return nil
        }
    }

    /// URL parameter value for this layout
    var urlParameter: String {
        switch self {
        case .usQWERTY: "us"
        case .deQWERTZ: "de"
        case .frAZERTY_Classic: "fr"
        }
    }
}
