//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI
import UIKit

struct MainView: View {
    @Bindable var viewModel: DeviceListViewModel
    @Binding private var deviceListStartupAction: DeviceListStartupAction?
    @Environment(\.appRouter) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var navigationPath: [UUID] = []
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

    @AppStorage(SettingsStorage.autoSelectLastDevice) private var autoSelectLastDevice = true
    @AppStorage(SettingsStorage.keepScreenOn) private var keepScreenOn = true
    @AppStorage(SettingsStorage.lastSelectedDeviceID) private var lastSelectedDeviceID = ""
    @State private var didAttemptAutoSelect = false

    init(
        viewModel: DeviceListViewModel,
        startupAction: Binding<DeviceListStartupAction?> = .constant(nil)
    ) {
        self.viewModel = viewModel
        _deviceListStartupAction = startupAction
    }

    var body: some View {
        @Bindable var router = router
        content
        .tint(.accentBlue)
        .sheet(item: $router.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .task {
            if viewModel.hasSavedDevices && !viewModel.isScanning {
                viewModel.startScanning()
            }
            autoSelectLastDeviceIfNeeded()
        }
        .onChange(of: deviceAvailabilitySnapshots) { _, _ in
            autoSelectLastDeviceIfNeeded()
        }
        .onChange(of: router.selectedDeviceID) { _, id in
            // Remember the last device the user picked so we can restore it on launch.
            if let id {
                lastSelectedDeviceID = id.uuidString
                if navigationPath.last != id {
                    navigationPath = [id]
                }
            } else if !navigationPath.isEmpty {
                navigationPath = []
            }
        }
        .onChange(of: navigationPath) { _, path in
            if let id = path.last {
                if router.selectedDeviceID != id {
                    router.selectedDeviceID = id
                }
            } else if router.selectedDeviceID != nil {
                router.deselectDevice()
            }
        }
        .modifier(ScreenWakeModifier(viewModel: viewModel, keepScreenOn: keepScreenOn))
    }

    @ViewBuilder
    private var content: some View {
        if horizontalSizeClass == .regular {
            splitViewContent
        } else {
            stackContent
        }
    }

    private var stackContent: some View {
        NavigationStack(path: $navigationPath) {
            deviceList
                .navigationDestination(for: UUID.self) { deviceID in
                    if let device = viewModel.device(for: deviceID) {
                        DeviceDetailView(device: device)
                    } else {
                        NoDeviceSelectedView()
                    }
                }
        }
    }

    private var splitViewContent: some View {
        NavigationSplitView(columnVisibility: $splitViewVisibility) {
            deviceList
        } detail: {
            selectedDeviceDetail
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var deviceList: some View {
        DeviceListView(
            viewModel: viewModel,
            startupAction: $deviceListStartupAction
        )
    }

    @ViewBuilder
    private var selectedDeviceDetail: some View {
        if let selectedDeviceID = router.selectedDeviceID,
           let device = viewModel.device(for: selectedDeviceID) {
            DeviceDetailView(device: device)
        } else {
            NoDeviceSelectedView()
        }
    }

    private var deviceAvailabilitySnapshots: [DeviceAvailabilitySnapshot] {
        viewModel.devices.map { device in
            DeviceAvailabilitySnapshot(
                id: device.id,
                isConnectable: device.isConnectable,
                isConnecting: device.isConnecting,
                isConnected: device.isConnected
            )
        }
    }

    /// On launch, restore and connect the last used device when the setting is enabled.
    private func autoSelectLastDeviceIfNeeded() {
        guard !didAttemptAutoSelect else { return }

        guard autoSelectLastDevice,
              router.selectedDeviceID == nil,
              let uuid = UUID(uuidString: lastSelectedDeviceID) else {
            didAttemptAutoSelect = true
            return
        }

        guard let device = viewModel.device(for: uuid), device.isKnownDevice else {
            // The manager may not have rediscovered the saved peripheral yet. Keep this
            // eligible so discovery can auto-select once scanning finds it.
            return
        }

        guard device.isConnectable || device.isConnecting || device.isConnected else {
            // Saved devices are shown immediately as not in range, but we can only
            // auto-connect once BLE scanning discovers the actual peripheral.
            return
        }

        didAttemptAutoSelect = true
        router.selectedDeviceID = uuid
        _ = viewModel.connectDevice(device)
    }

    @ViewBuilder
    private func sheetContent(for sheet: AppRouter.Sheet) -> some View {
        switch sheet {
        case .deviceSetup(let device):
            // Save and start connecting; the sheet itself owns dismissal so the QR
            // scanner can stay open to observe whether authentication actually succeeds.
            // On failure the unverified key is rolled back so it isn't left persisted.
            DeviceSetupSheet(
                device: device,
                onComplete: { authKey, alias in
                    viewModel.saveDeviceSettings(device: device, authKey: authKey, alias: alias)
                },
                onAuthenticationFailure: {
                    viewModel.discardDeviceSettings(for: device)
                }
            )
        }
    }

}

// MARK: - Screen Wake Modifier

/// Keeps the screen awake while a device is connected and the setting is enabled.
/// Isolated into a ViewModifier so MainView's body isn't forced to read the full
/// device list on every state change unrelated to connectivity.
private struct ScreenWakeModifier: ViewModifier {
    let viewModel: DeviceListViewModel
    let keepScreenOn: Bool

    private var shouldKeepOn: Bool {
        keepScreenOn && viewModel.devices.contains { $0.isConnected }
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: shouldKeepOn, initial: true) { _, keepOn in
                UIApplication.shared.isIdleTimerDisabled = keepOn
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
    }
}

private struct DeviceAvailabilitySnapshot: Equatable {
    let id: UUID
    let isConnectable: Bool
    let isConnecting: Bool
    let isConnected: Bool
}

// MARK: - Preview

#Preview {
    MainView(viewModel: DeviceListViewModel(
        service: ClickStickService(),
        urlOpener: URLOpener()
    ))
}
