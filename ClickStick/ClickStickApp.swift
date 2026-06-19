//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

@main
struct ClickStickApp: App {
    @AppStorage(OnboardingStorage.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(OnboardingStorage.isDemoModeEnabled) private var isDemoModeEnabled = false

    @State private var router = AppRouter()
    @State private var deepLinkHandler: DeepLinkHandler
    @State private var deviceListViewModel: DeviceListViewModel
    @State private var pendingDeviceListStartupAction: DeviceListStartupAction?

    private let service: ClickStickService
    private let urlOpener: URLOpener

    init() {
        let urlOpener = URLOpener()
        let service = ClickStickService()
        let isDemoModeEnabled = UserDefaults.standard.bool(forKey: OnboardingStorage.isDemoModeEnabled)
        service.isDemoMode = isDemoModeEnabled

        self.urlOpener = urlOpener
        self.service = service
        _deepLinkHandler = State(initialValue: DeepLinkHandler(urlOpener: urlOpener))
        _deviceListViewModel = State(initialValue: DeviceListViewModel(service: service, urlOpener: urlOpener))
#if targetEnvironment(macCatalyst)
        UITextField.appearance().focusEffect = nil
#endif
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .environment(\.appRouter, router)
                .onOpenURL { url in
                    deepLinkHandler.handle(url: url)
                }
                .sheet(item: $deepLinkHandler.pendingTypeRequest) { request in
                    DeepLinkTypeSheet()
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

    @ViewBuilder
    private var rootContent: some View {
        if hasCompletedOnboarding {
            MainView(
                viewModel: deviceListViewModel,
                startupAction: $pendingDeviceListStartupAction
            )
        } else {
            OnboardingView(
                onComplete: completeOnboarding,
                onGetClickStick: { urlOpener.openGettingStartedPage() }
            )
        }
    }

    private func completeOnboarding(_ action: OnboardingCompletionAction) {
        switch action {
        case .addDevice:
            isDemoModeEnabled = false
            deviceListViewModel.completeOnboarding(enableDemoMode: false)
            pendingDeviceListStartupAction = .startAddDeviceScan
        case .demoMode:
            isDemoModeEnabled = true
            deviceListViewModel.completeOnboarding(enableDemoMode: true)
            pendingDeviceListStartupAction = nil
        }
        hasCompletedOnboarding = true
    }
}
