//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

@main
struct ClickStickApp: App {
    private static let hasLaunchedSinceInstallKey = "hasLaunchedSinceInstall"
    @AppStorage(OnboardingStorage.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(OnboardingStorage.isDemoModeEnabled) private var isDemoModeEnabled = false

    @Environment(\.scenePhase) private var scenePhase

    @State private var router = AppRouter()
    @State private var deviceListViewModel: DeviceListViewModel
    @State private var pendingDeviceListStartupAction: DeviceListStartupAction?

    private let service: ClickStickService
    private let urlOpener: URLOpener

    init() {
        Self.clearStaleDeviceSettingsOnFreshInstall()

        let urlOpener = URLOpener()
        let service = ClickStickService()
        let isDemoModeEnabled = UserDefaults.standard.bool(forKey: OnboardingStorage.isDemoModeEnabled)
        service.isDemoMode = isDemoModeEnabled

        self.urlOpener = urlOpener
        self.service = service
        _deviceListViewModel = State(initialValue: DeviceListViewModel(service: service, urlOpener: urlOpener))
#if targetEnvironment(macCatalyst)
        UITextField.appearance().focusEffect = nil
#endif
    }

    private static func clearStaleDeviceSettingsOnFreshInstall() {
        guard !UserDefaults.standard.bool(forKey: hasLaunchedSinceInstallKey) else { return }
        try? CSDeviceSettingsManager.deleteAllSettings()
        UserDefaults.standard.set(true, forKey: hasLaunchedSinceInstallKey)
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .environment(\.appRouter, router)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // Release the connection and stop scanning so the Share Extension (a separate
            // process) can use the device while the app is in the background.
            service.handleEnteredBackground()
        case .active:
            service.handleWillEnterForeground()
        case .inactive:
            break
        @unknown default:
            break
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
        .onOpenURL(perform: handleOpenURL)
    }

    private func handleOpenURL(_ url: URL) {
        guard let deepLink = AppDeepLink(url: url) else { return }

        switch deepLink {
        case .addDevice:
            openAddDeviceFlow()
        }
    }

    private func openAddDeviceFlow() {
        if hasCompletedOnboarding {
            isDemoModeEnabled = false
            deviceListViewModel.completeOnboarding(enableDemoMode: false)
            pendingDeviceListStartupAction = .startAddDeviceScan
        } else {
            completeOnboarding(.addDevice)
        }
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
