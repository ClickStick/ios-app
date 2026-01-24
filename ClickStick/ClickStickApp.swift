//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

@main
struct ClickStickApp: App {
    @State private var router = AppRouter()
    @State private var viewModel = DeviceListViewModel(
        service: ClickStickService(),
        urlOpener: URLOpener()
    )

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .environment(\.appRouter, router)
        }
    }
}
