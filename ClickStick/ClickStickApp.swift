//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

@main
struct ClickStickApp: App {
    @State private var router = AppRouter()
    @State private var deepLinkHandler: DeepLinkHandler
    private let service = ClickStickService()
    private let premiumService = PremiumService()
    private let urlOpener: URLOpening

    init() {
        urlOpener = URLOpener()
        deepLinkHandler = DeepLinkHandler(urlOpener: urlOpener)
    }

    var body: some Scene {
        WindowGroup {
            MainView(
                viewModel: DeviceListViewModel(
                    service: service,
                    urlOpener: URLOpener()
                )
            )
            .environment(\.appRouter, router)
            .environment(\.premiumService, premiumService)
            .onOpenURL { url in
                deepLinkHandler.handle(url: url)
            }
            .sheet(item: $deepLinkHandler.pendingTypeRequest) { request in
                DeepLinkTypeSheet(
                    request: request,
                    service: service,
                    deepLinkHandler: deepLinkHandler
                )
            }
            .alert(
                "Deep Link Error",
                isPresented: Binding(
                    get: { deepLinkHandler.parsingError != nil },
                    set: { if !$0 { deepLinkHandler.clearParsingError() } }
                ),
                presenting: deepLinkHandler.parsingError
            ) { _ in
                Button("OK") {
                    deepLinkHandler.clearParsingError()
                }
            } message: { error in
                Text(error.code.message)
            }
        }
    }
}
