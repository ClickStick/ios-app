//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

@main
struct ClickStickApp: App {
    @State private var clickStickService = ClickStickService()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.clickStickService, clickStickService)
        }
    }
}
