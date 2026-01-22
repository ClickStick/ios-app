//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

// MARK: - Environment Keys

extension EnvironmentValues {
    @Entry var clickStickService: ClickStickService = ClickStickService()
}

// MARK: - View Extensions

extension View {
    func withClickStickService(_ service: ClickStickService) -> some View {
        environment(\.clickStickService, service)
    }
}
