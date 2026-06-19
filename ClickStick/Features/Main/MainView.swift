//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI
import UIKit

struct MainView: View {
    @Bindable var viewModel: DeviceListViewModel
    @Binding private var deviceListStartupAction: DeviceListStartupAction?
    @Environment(\.appRouter) private var router
    @State private var navigationPath: [UUID] = []

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
        NavigationStack(path: $navigationPath) {
            DeviceListView(
                viewModel: viewModel,
                startupAction: $deviceListStartupAction
            )
            .navigationDestination(for: UUID.self) { deviceID in
                if let device = viewModel.device(for: deviceID) {
                    DeviceDetailView(device: device)
                } else {
                    NoDeviceSelectedView()
                }
            }
        }
        .tint(.accentBlue)
        .sheet(item: Binding(
            get: { router.presentedSheet },
            set: { router.presentedSheet = $0 }
        )) { sheet in
            sheetContent(for: sheet)
        }
        .task {
            if viewModel.hasSavedDevices && !viewModel.isScanning {
                viewModel.startScanning()
            }
            autoSelectLastDeviceIfNeeded()
        }
        .onChange(of: deviceIDs) { _, _ in
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
        .onChange(of: shouldKeepScreenOn, initial: true) { _, keepOn in
            UIApplication.shared.isIdleTimerDisabled = keepOn
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var deviceIDs: [UUID] {
        viewModel.devices.map(\.id)
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
