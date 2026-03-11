//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import SwiftUI

extension AnnouncementBannerView.Configuration {
    static var welcome: Self = .init(
        title: String(localized: "Welcome!"),
        message: String(localized: "Plug in your ClickStick to get started."),
        image: Image(systemName: "hand.wave.fill"),
        actionTitle: String(localized: "Getting Started"),
        style: .welcome
    )

    static var demo: Self = .init(
        title: nil,
        message: String(localized: "Just looking around?"),
        image: Image(systemName: "rectangle.inset.filled.and.person.filled"),
        actionTitle: String(localized: "Try in Demo Mode"),
        style: .info
    )

    static func bluetoothError(error: CSError) -> Self {
        let nsError = error as NSError
        let isPermissionError: Bool
        if case .bluetoothUnavailable(let reason) = error {
            isPermissionError = (reason == .permissionDenied)
        } else {
            isPermissionError = false
        }

        return .init(
            title: nsError.localizedDescription,
            message: nsError.localizedFailureReason,
            image: Image(.bluetooth),
            actionTitle: isPermissionError ? String(localized: "Open Settings") : nil,
            style: .warning
        )
    }
}
