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
    @State private var isShowingParsingError = false

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
                .sheet(item: $deepLinkHandler.pendingTypeRequest) { _ in
                    DeepLinkTypeSheet()
                }
                .onChange(of: deepLinkHandler.parsingError) { _, newError in
                    isShowingParsingError = newError != nil
                }
                .alert(
                    "Deep Link Error",
                    isPresented: $isShowingParsingError,
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

    private var rootContent: some View {
        ZStack {
            if hasCompletedOnboarding {
                MainView(
                    viewModel: deviceListViewModel,
                    startupAction: $pendingDeviceListStartupAction
                )
                .transition(.opacity)
            } else {
                OnboardingPresentationView(
                    onComplete: completeOnboarding,
                    onGetClickStick: { urlOpener.openGettingStartedPage() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
    }

    private func completeOnboarding(_ action: OnboardingCompletionAction) {
        let startupAction: DeviceListStartupAction?

        switch action {
        case .addDevice:
            isDemoModeEnabled = false
            deviceListViewModel.completeOnboarding(enableDemoMode: false)
            startupAction = .startAddDeviceScan
        case .demoMode:
            isDemoModeEnabled = true
            deviceListViewModel.completeOnboarding(enableDemoMode: true)
            startupAction = nil
        }

        withAnimation(.easeInOut(duration: 0.35), completionCriteria: .logicallyComplete) {
            hasCompletedOnboarding = true
        } completion: {
            pendingDeviceListStartupAction = startupAction
        }
    }
}
