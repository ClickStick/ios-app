//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

/// The fixed set of icons a snippet can use, shown in the "Choose icon" picker.
///
/// Each icon carries its SF Symbol and tile color. Colors are derived from the system palette
/// (rather than bespoke asset catalog colorsets) so they stay adaptive in light/dark mode.
enum SnippetIcon: String, Codable, CaseIterable, Identifiable {
    case `default`
    case password
    case login
    case server
    case network
    case home
    case work
    case scripts
    case media
    case keys
    case favorites
    case email

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .default: "lock.fill"
        case .password: "ellipsis.message.fill"
        case .login: "person.fill"
        case .server: "server.rack"
        case .network: "antenna.radiowaves.left.and.right"
        case .home: "house.fill"
        case .work: "briefcase.fill"
        case .scripts: "terminal.fill"
        case .media: "display"
        case .keys: "key.fill"
        case .favorites: "star.fill"
        case .email: "envelope.fill"
        }
    }

    var tileColor: Color {
        switch self {
        case .default: Color(red: 99 / 255, green: 99 / 255, blue: 102 / 255)
        case .password: Color(uiColor: .systemRed)
        case .login: Color(uiColor: .systemBlue)
        case .server: Color(red: 94 / 255, green: 92 / 255, blue: 230 / 255)
        case .network: Color(uiColor: .systemGreen)
        case .home: Color(uiColor: .systemOrange)
        case .work: Color(red: 50 / 255, green: 173 / 255, blue: 230 / 255)
        case .scripts: Color(uiColor: .systemPurple)
        case .media: Color(red: 255 / 255, green: 45 / 255, blue: 85 / 255)
        case .keys: Color(red: 255 / 255, green: 204 / 255, blue: 0 / 255)
        case .favorites: Color(red: 255 / 255, green: 149 / 255, blue: 0 / 255)
        case .email: Color(red: 90 / 255, green: 200 / 255, blue: 250 / 255)
        }
    }

    /// User-facing label shown under the tile in the icon picker.
    var title: LocalizedStringKey {
        switch self {
        case .default: "Default"
        case .password: "Password"
        case .login: "Login"
        case .server: "Server"
        case .network: "Network"
        case .home: "Home"
        case .work: "Work"
        case .scripts: "Scripts"
        case .media: "Media"
        case .keys: "Keys"
        case .favorites: "Favorites"
        case .email: "Email"
        }
    }
}
