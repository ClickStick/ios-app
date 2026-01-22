//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Foundation

enum TextPreset: String, CaseIterable, Identifiable {
    case hello = "hello"
    case email = "email"
    case password = "password"
    case lorem = "lorem"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hello: "Hello World"
        case .email: "Sample Email"
        case .password: "Test Password"
        case .lorem: "Lorem Ipsum"
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
