//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation
import SwiftUI

enum DeviceListStartupAction: Equatable {
    case startAddDeviceScan
}

struct DeviceListView: View {
    @Bindable var viewModel: DeviceListViewModel
    @Binding private var startupAction: DeviceListStartupAction?

    @Environment(\.appRouter) private var router
    @State private var deviceToForget: DeviceModel?
    @State private var isConfirmingForget = false
    @State private var isShowingSettings = false
    @State private var addDeviceStage: AddDeviceStage?
    @State private var pendingStage: AddDeviceStage?
    @State private var compromisedDevice: DeviceModel?
    @State private var reauthPendingDevice: DeviceModel?
    @State private var pendingConnectedDeviceID: UUID?

    init(
        viewModel: DeviceListViewModel,
        startupAction: Binding<DeviceListStartupAction?> = .constant(nil)
    ) {
        self.viewModel = viewModel
        _startupAction = startupAction
    }

    var body: some View {
        ZStack {
            Color.groupedBackground
                .ignoresSafeArea()

            if viewModel.devices.isEmpty {
                DeviceListEmptyState(
                    onScan: presentAddDevice,
                    onGettingStarted: viewModel.openGettingStarted
                )
            } else {
                DeviceListContent(
                    connectedDevices: viewModel.connectedDevices,
                    availableDevices: viewModel.availableDevices,
                    outOfRangeDevices: viewModel.outOfRangeDevices,
                    selectedDeviceID: router.selectedDeviceID,
                    onSelect: handleDeviceTap,
                    onForget: { device in
                        deviceToForget = device
                        isConfirmingForget = true
                    },
                    onDisconnect: disconnectDevice
                )
            }
        }
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !viewModel.devices.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(CircularToolbarButtonStyle(role: .neutral))
                    .accessibilityLabel("Settings")
                }
                .appHiddenSharedToolbarBackground()

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentAddDevice()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(CircularToolbarButtonStyle(role: .prominent))
                    .accessibilityLabel("Add device")
                }
                .appHiddenSharedToolbarBackground()
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(item: $addDeviceStage, onDismiss: handleAddDeviceDismiss) { stage in
            switch stage {
            case .scanning:
                AddDeviceScanSheet(viewModel: viewModel) {
                    addDeviceStage = nil
                }
            case .found:
                FoundDevicesSheet(
                    viewModel: viewModel,
                    previewRows: nil,
                    onConnect: connectFromFound,
                    onStop: { addDeviceStage = nil }
                )
            }
        }
        .sheet(item: $compromisedDevice, onDismiss: handleCompromisedDismiss) { device in
            CompromisedDeviceSheet(
                deviceName: device.displayName,
                onRemove: {
                    if viewModel.forgetDevice(device, selectedDeviceID: router.selectedDeviceID) {
                        router.deselectDevice()
                    }
                    compromisedDevice = nil
                },
                onConnectAnyway: {
                    device.clearCompromiseWarning()
                    reauthPendingDevice = device
                    compromisedDevice = nil
                }
            )
        }
        .onChange(of: viewModel.devices.count) { oldCount, newCount in
            // A new device appeared during the add-device scan → swap to the found sheet.
            if addDeviceStage == .scanning, viewModel.isScanning, newCount > oldCount, newCount > 0 {
                presentFoundDevices()
            }
        }
        .onChange(of: startupAction, initial: true) { _, action in
            handleStartupAction(action)
        }
        .modifier(DeviceUIStateObserver(viewModel: viewModel, onStateChange: handleDeviceStateChange))
        .errorAlert($viewModel.alertError)
        .confirmationDialog(
            "Forget Device",
            isPresented: $isConfirmingForget,
            titleVisibility: .visible
        ) {
            Button("Forget Device", role: .destructive, action: forgetPendingDevice)
        } message: {
            Text("This will remove the saved authentication key. You'll need to set up the device again to reconnect.")
        }
        .onChange(of: isConfirmingForget) { _, showing in
            if !showing { deviceToForget = nil }
        }
    }

    // MARK: - Add Device Flow

    private enum AddDeviceStage: Int, Identifiable {
        case scanning
        case found
        var id: Int { rawValue }
    }

    private func presentAddDevice() {
        pendingStage = nil
        viewModel.startScanning()
        addDeviceStage = .scanning
    }

    /// Dismisses the scanning sheet and queues the found sheet to present once it's gone.
    private func presentFoundDevices() {
        pendingStage = .found
        addDeviceStage = nil
    }

    private func handleAddDeviceDismiss() {
        guard let nextStage = pendingStage else {
            viewModel.stopScanning()
            return
        }

        pendingStage = nil
        addDeviceStage = nextStage
    }

    /// After the compromised sheet closes, if the user chose "Connect anyway" we
    /// re-pair the device (open setup) — done in onDismiss so sheets don't overlap.
    private func handleCompromisedDismiss() {
        guard let device = reauthPendingDevice else { return }
        reauthPendingDevice = nil
        viewModel.prepareDeviceForSetup(device)
        router.showDeviceSetup(for: device)
    }

    private func forgetPendingDevice() {
        guard let device = deviceToForget else { return }
        if viewModel.forgetDevice(device, selectedDeviceID: router.selectedDeviceID) {
            router.deselectDevice()
        }
    }

    private func disconnectDevice(_ device: DeviceModel) {
        if router.selectedDeviceID == device.id {
            router.deselectDevice()
        }
        device.disconnect()
    }

    private func handleDeviceTap(_ device: DeviceModel) {
        switch device.uiState {
        case .connected:
            router.selectDevice(device)
        case .available, .weakSignal:
            _ = viewModel.connectDevice(device)
            // Wait for asynchronous state update before navigating.
            pendingConnectedDeviceID = device.id
        case .newDevice:
            _ = viewModel.connectDevice(device)
        case .connecting, .authorizing:
            pendingConnectedDeviceID = device.id
        case .setupRequired:
            viewModel.prepareDeviceForSetup(device)
            router.showDeviceSetup(for: device)
        case .compromised:
            compromisedDevice = device
        case .outOfRange, .failed:
            break
        }
    }

    private func handleDeviceStateChange() {
        resolvePendingConnectedDeviceSelection()
        handleDeviceRequiringAuthentication()
    }

    private func handleDeviceRequiringAuthentication() {
        guard let device = viewModel.deviceRequiringAuthentication,
              router.presentedSheet == nil else { return }
        pendingConnectedDeviceID = nil
        viewModel.prepareDeviceForSetup(device)
        router.showDeviceSetup(for: device)
    }

    private func resolvePendingConnectedDeviceSelection() {
        guard let pendingConnectedDeviceID else { return }

        guard let device = viewModel.device(for: pendingConnectedDeviceID) else {
            self.pendingConnectedDeviceID = nil
            return
        }

        switch device.uiState {
        case .connected:
            router.selectDevice(device)
            self.pendingConnectedDeviceID = nil
        case .connecting, .authorizing:
            break
        default:
            self.pendingConnectedDeviceID = nil
        }
    }

    /// Connecting from the add-device sheet reuses the same pending-selection flow as a
    /// normal row tap, so the device only navigates to detail once it's actually connected
    /// rather than jumping there while still connecting.
    private func connectFromFound(_ device: DeviceModel) {
        addDeviceStage = nil
        handleDeviceTap(device)
    }

    private func handleStartupAction(_ action: DeviceListStartupAction?) {
        guard let action else { return }

        switch action {
        case .startAddDeviceScan:
            presentAddDevice()
        }

        startupAction = nil
    }
}

// MARK: - Empty State

private struct DeviceListEmptyState: View {
    let onScan: () -> Void
    let onGettingStarted: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            VStack(spacing: 40) {
                VStack(spacing: 16) {
                    emptyStateIcon

                    VStack(spacing: 8) {
                        Text("No devices found")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Make sure your ClickStick is plugged in and Bluetooth is on")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 300)
                }

                Button {
                    onGettingStarted()
                } label: {
                    Text("How does ClickStick work?")
                        .font(.body)
                        .foregroundStyle(Color.accentBlue)
                }
                .buttonStyle(.plain)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("No devices found. Make sure your ClickStick is plugged in and Bluetooth is on")

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .safeAreaInset(edge: .bottom) {
            Button("Scan for devices", action: onScan)
                .buttonStyle(AppPrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    private var emptyStateIcon: some View {
        ZStack {
            Circle()
                .fill(Color.accentBlue.opacity(0.14))

            Image(systemName: "antenna.radiowaves.left.and.right")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 80 * 0.42, weight: .semibold))
                .foregroundStyle(Color.accentBlue)
        }
        .frame(width: 80, height: 80)
        .accessibilityHidden(true)
    }
}

// MARK: - Device List

private struct DeviceListContent: View {
    let connectedDevices: [DeviceModel]
    let availableDevices: [DeviceModel]
    let outOfRangeDevices: [DeviceModel]
    let selectedDeviceID: UUID?
    let onSelect: (DeviceModel) -> Void
    let onForget: (DeviceModel) -> Void
    let onDisconnect: (DeviceModel) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !connectedDevices.isEmpty {
                    DeviceListSection(
                        title: "Connected",
                        devices: connectedDevices,
                        selectedDeviceID: selectedDeviceID,
                        onSelect: onSelect,
                        onForget: onForget,
                        onDisconnect: onDisconnect
                    )
                }

                if !availableDevices.isEmpty {
                    DeviceListSection(
                        title: "Available",
                        devices: availableDevices,
                        selectedDeviceID: selectedDeviceID,
                        onSelect: onSelect,
                        onForget: onForget,
                        onDisconnect: onDisconnect
                    )
                }

                if !outOfRangeDevices.isEmpty {
                    DeviceListSection(
                        title: "Not in range",
                        devices: outOfRangeDevices,
                        selectedDeviceID: selectedDeviceID,
                        onSelect: onSelect,
                        onForget: onForget,
                        onDisconnect: onDisconnect
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
}

private struct DeviceListSection: View {
    let title: LocalizedStringKey
    let devices: [DeviceModel]
    let selectedDeviceID: UUID?
    let onSelect: (DeviceModel) -> Void
    let onForget: (DeviceModel) -> Void
    let onDisconnect: (DeviceModel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            VStack(spacing: 12) {
                ForEach(devices) { device in
                    DeviceListRowCard(
                        device: device,
                        isSelected: selectedDeviceID == device.id,
                        onTap: { onSelect(device) },
                        onForget: { onForget(device) },
                        onDisconnect: device.isConnected ? { onDisconnect(device) } : nil
                    )
                }
            }
        }
    }
}

// A compromised device is not its own section — it belongs in the section
// matching its connection status and is simply rendered red (see DeviceRowView).

private struct DeviceListRowCard: View {
    let device: DeviceModel
    let isSelected: Bool
    let onTap: () -> Void
    let onForget: () -> Void
    let onDisconnect: (() -> Void)?

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                onTap()
            } label: {
                DeviceRowView(
                    device: device,
                    isSelected: isSelected,
                    showsMenuIndicator: false
                )
            }
            .buttonStyle(.plain)

            Menu {
                Button(role: .destructive) {
                    onForget()
                } label: {
                    Label(String(localized: "Forget Device"), systemImage: "trash")
                }
                .tint(.red)
                .disabled(!device.isKnownDevice || device.isDemoDevice)

                if let onDisconnect {
                    Button {
                        onDisconnect()
                    } label: {
                        Label(String(localized: "Disconnect"), systemImage: "cable.connector.horizontal")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Device options", comment: "Accessibility label for device row menu button"))
            .accessibilityHint(String(localized: "Shows actions for this device", comment: "Accessibility hint for device row menu button"))
            .padding(.trailing, 6)
        }
    }
}

// MARK: - Device UI State Observer

/// Isolates the `deviceUIStateSnapshots` onChange side effect so it doesn't add a
/// collection-read dependency to DeviceListView's own body.
private struct DeviceUIStateObserver: ViewModifier {
    let viewModel: DeviceListViewModel
    let onStateChange: () -> Void

    private var snapshots: [DeviceUIStateSnapshot] {
        viewModel.devices.map { DeviceUIStateSnapshot(device: $0) }
    }

    func body(content: Content) -> some View {
        content.onChange(of: snapshots) { _, _ in
            onStateChange()
        }
    }
}

private struct DeviceUIStateSnapshot: Equatable {
    let id: UUID
    let uiState: DeviceUIState
    let lastErrorTimestamp: Date? // separate field so distinct errors still fire onChange

    init(device: DeviceModel) {
        self.id = device.id
        self.uiState = device.uiState
        self.lastErrorTimestamp = device.lastErrorTimestamp
    }
}

// MARK: - Previews

#if DEBUG
@MainActor
private enum DeviceListPreviewFactory {
    static func empty() -> DeviceListViewModel {
        let service = ClickStickService(manager: PreviewManager())
        service.setPreviewScanning(false)
        let viewModel = DeviceListViewModel(service: service, urlOpener: URLOpener())
        viewModel.hasShownWelcome = true
        viewModel.hasDismissedDemoPrompt = true
        return viewModel
    }

    /// A device in every section: connected, available (incl. a weak-signal and a
    /// connecting device), and not-in-range — plus one compromised device shown red
    /// within its own status section.
    static func populated() -> DeviceListViewModel {
        let devices: [CSDevice] = [
            .makePreview(name: "ClickStick 9F8C", state: .connected),
            .makePreview(name: "TV Room", state: .available),
            .makePreview(name: "ClickStick A2A1", state: .weakSignal),
            .makePreview(name: "ClickStick B3D2", state: .connecting),
            .makePreview(name: "Home Router", state: .outOfRange),
            .makePreview(name: "ClickStick 107C", state: .outOfRange)
        ]
        let service = ClickStickService(manager: PreviewManager(devices: devices))
        let viewModel = DeviceListViewModel(service: service, urlOpener: URLOpener())
        viewModel.hasShownWelcome = true
        viewModel.hasDismissedDemoPrompt = true

        // Flag one device as compromised so it renders red inside "Not in range".
        if let compromised = viewModel.devices.first(where: { $0.displayName == "ClickStick 107C" }) {
            compromised.deviceDidDetectTampering(compromised.device)
        }
        return viewModel
    }

    private final class PreviewManager: CSManaging {
        var isDemoMode: Bool = false
        weak var delegate: CSManagerDelegate?
        private let devices: [CSDevice]

        init(devices: [CSDevice] = []) {
            self.devices = devices
        }

        func startScanning() {}
        func stopScanning() {}
        func knownDevices() -> [CSDevice] { devices }
    }
}
#endif

#Preview("No Devices Found") {
    NavigationStack {
        DeviceListView(viewModel: DeviceListPreviewFactory.empty())
    }
}

#Preview("Device List") {
    NavigationStack {
        DeviceListView(viewModel: DeviceListPreviewFactory.populated())
    }
}

#Preview("Device List Sidebar") {
    NavigationSplitView {
        DeviceListView(viewModel: DeviceListPreviewFactory.populated())
    } detail: {
        NoDeviceSelectedView()
    }
}
