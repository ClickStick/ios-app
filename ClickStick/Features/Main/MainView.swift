//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import DesignSystem
import SwiftUI
import UIKit

struct MainView: View {
    @Bindable var viewModel: DeviceListViewModel
    @Binding private var deviceListStartupAction: DeviceListStartupAction?
    @Environment(\.appRouter) private var router
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

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

    /// Keep the screen awake only while the setting is on *and* a device is connected.
    private var shouldKeepScreenOn: Bool {
        keepScreenOn && viewModel.devices.contains { $0.isConnected }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            DeviceListView(
                viewModel: viewModel,
                startupAction: $deviceListStartupAction
            )
        } detail: {
            if let deviceID = router.selectedDeviceID,
               let device = viewModel.device(for: deviceID) {
                DeviceDetailView(device: device)
            } else {
                NoDeviceSelectedView(
                    isScanning: viewModel.isScanning,
                    hasDevices: !viewModel.devices.isEmpty,
                    onStartScanning: { viewModel.startScanning() }
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.clickStickBlue)
        .sheet(item: Binding(
            get: { router.presentedSheet },
            set: { router.presentedSheet = $0 }
        )) { sheet in
            sheetContent(for: sheet)
        }
        .onAppear(perform: autoSelectLastDeviceIfNeeded)
        .onChange(of: router.selectedDeviceID) { _, id in
            // Remember the last device the user picked so we can restore it on launch.
            if let id {
                lastSelectedDeviceID = id.uuidString
            }
        }
        .onChange(of: shouldKeepScreenOn, initial: true) { _, keepOn in
            UIApplication.shared.isIdleTimerDisabled = keepOn
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    /// On launch, restore and connect the last used device when the setting is enabled.
    private func autoSelectLastDeviceIfNeeded() {
        guard !didAttemptAutoSelect else { return }
        didAttemptAutoSelect = true

        guard autoSelectLastDevice,
              router.selectedDeviceID == nil,
              let uuid = UUID(uuidString: lastSelectedDeviceID),
              let device = viewModel.device(for: uuid),
              device.isKnownDevice else { return }

        router.selectedDeviceID = uuid
        _ = viewModel.connectDevice(device)
    }

    @ViewBuilder
    private func sheetContent(for sheet: AppRouter.Sheet) -> some View {
        switch sheet {
        case .deviceSetup(let device):
            DeviceSetupSheet(device: device) { authKey, alias in
                let didSave = viewModel.saveDeviceSettings(device: device, authKey: authKey, alias: alias)
                if didSave {
                    router.dismissSheet()
                }
                return didSave
            }
        }
    }

}

// MARK: - Preview

#Preview {
    MainView(viewModel: DeviceListViewModel(
        service: ClickStickService(),
        urlOpener: URLOpener()
    ))
}
