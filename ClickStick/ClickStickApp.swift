//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

@main
struct ClickStickApp: App {
    @State private var router = AppRouter()
    @State private var deepLinkHandler: DeepLinkHandler
    private let service = ClickStickService()
    private let premiumService = PremiumService(
        defaults: {
#if targetEnvironment(macCatalyst)
            return .standard
#else
            return UserDefaults(suiteName: PremiumService.appGroupID) ?? .standard
#endif
        }()
    )
    private let urlOpener: URLOpener

    init() {
        urlOpener = URLOpener()
        deepLinkHandler = DeepLinkHandler(urlOpener: urlOpener)
#if targetEnvironment(macCatalyst)
        UITextField.appearance().focusEffect = nil
#endif
    }

    var body: some Scene {
        WindowGroup {
            MainView(
                viewModel: DeviceListViewModel(
                    service: service,
                    urlOpener: urlOpener
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
                    deepLinkHandler: deepLinkHandler,
                    premiumService: premiumService
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
