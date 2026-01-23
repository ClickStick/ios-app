//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

enum TextPreset: String, CaseIterable, Identifiable {
    case hello = "hello"
    case email = "email"
    case password = "password"
    case lorem = "lorem"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hello: String(localized: "Hello World", comment: "Text preset name")
        case .email: String(localized: "Sample Email", comment: "Text preset name")
        case .password: String(localized: "Test Password", comment: "Text preset name")
        case .lorem: String(localized: "Lorem Ipsum", comment: "Text preset name")
        }
    }

    var text: String {
        switch self {
        case .hello:
            "Hello, World!"
        case .email:
            "user@example.com"
        case .password:
            "P@ssw0rd123!"
        case .lorem:
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
        }
    }
}
