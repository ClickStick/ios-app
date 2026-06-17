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

            content
        }
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !viewModel.devices.isEmpty {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    HeaderIconButton(
                        systemName: "gearshape",
                        foreground: .primary,
                        background: .mutedFill,
                        accessibilityLabel: "Settings"
                    ) {
                        isShowingSettings = true
                    }

                    HeaderIconButton(
                        systemName: "plus",
                        foreground: .white,
                        background: .accentBlue,
                        accessibilityLabel: "Add device"
                    ) {
                        presentAddDevice()
                    }
                }
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
        .onChange(of: viewModel.deviceRequiringAuthentication) { _, device in
            if let device, router.presentedSheet == nil {
                pendingConnectedDeviceID = nil
                viewModel.prepareDeviceForSetup(device)
                router.showDeviceSetup(for: device)
            }
        }
        .onChange(of: deviceConnectionSnapshots) { _, _ in
            resolvePendingConnectedDeviceSelection()
        }
        .onChange(of: startupAction, initial: true) { _, action in
            handleStartupAction(action)
        }
        .errorAlert($viewModel.alertError)
        .confirmationDialog(
            "Forget Device",
            isPresented: Binding(
                get: { deviceToForget != nil },
                set: { if !$0 { deviceToForget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Forget Device", role: .destructive) {
                if let device = deviceToForget {
                    if viewModel.forgetDevice(device, selectedDeviceID: router.selectedDeviceID) {
                        router.deselectDevice()
                    }
                    deviceToForget = nil
                }
            }
        } message: {
            Text("This will remove the saved authentication key. You'll need to set up the device again to reconnect.")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.devices.isEmpty {
            emptyStateScreen
        } else {
            deviceListScreen
        }
    }

    // A compromised device is not its own section — it belongs in the section
    // matching its connection status and is simply rendered red (see DeviceRowView).

    private var connectedDevices: [DeviceModel] {
        viewModel.devices.filter { $0.isConnected }
    }

    /// Disconnected devices that are currently advertising and can be connected to.
    /// A connecting device stays here too; only its row subtitle changes to "Connecting...".
    private var availableDevices: [DeviceModel] {
        viewModel.devices.filter { device in
            !device.isConnected && (device.isConnectable || device.isConnecting)
        }
    }

    /// Disconnected devices that are no longer advertising (out of range).
    private var outOfRangeDevices: [DeviceModel] {
        viewModel.devices.filter { device in
            !device.isConnected && !device.isConnecting && !device.isConnectable
        }
    }

    private var deviceConnectionSnapshots: [DeviceConnectionSnapshot] {
        viewModel.devices.map { device in
            DeviceConnectionSnapshot(
                id: device.id,
                isConnected: device.isConnected,
                isConnecting: device.isConnecting,
                needsAuthentication: device.needsAuthentication,
                isCompromised: device.isCompromised,
                lastErrorTimestamp: device.lastErrorTimestamp
            )
        }
    }

    // MARK: - Empty State

    private var emptyStateScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            emptyState
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .safeAreaInset(edge: .bottom) {
            Button("Scan for devices") { presentAddDevice() }
                .buttonStyle(AppPrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    private var emptyState: some View {
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
                viewModel.openGettingStarted()
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

    // MARK: - Device List

    private var deviceListScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !connectedDevices.isEmpty {
                    deviceSection(title: String(localized: "Connected"), devices: connectedDevices)
                }

                if !availableDevices.isEmpty {
                    deviceSection(title: String(localized: "Available"), devices: availableDevices)
                }

                if !outOfRangeDevices.isEmpty {
                    deviceSection(title: String(localized: "Not in range"), devices: outOfRangeDevices)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    private func deviceSection(title: String, devices: [DeviceModel]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            VStack(spacing: 12) {
                ForEach(devices) { device in
                    Button {
                        onSelect(device)
                    } label: {
                        DeviceRowView(
                            device: device,
                            isSelected: router.selectedDeviceID == device.id
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        deviceContextMenu(for: device)
                    }
                }
            }
        }
    }

    /// A compromised device opens the warning sheet instead of connecting,
    /// regardless of which status section it appears in.
    private func onSelect(_ device: DeviceModel) {
        if device.isCompromised {
            compromisedDevice = device
        } else {
            handleDeviceTap(device)
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
        if let next = pendingStage {
            // Sequential swap: present the queued sheet now that the previous one is gone.
            pendingStage = nil
            addDeviceStage = next
        } else {
            // The user fully exited the add-device flow.
            viewModel.stopScanning()
        }
    }

    /// After the compromised sheet closes, if the user chose "Connect anyway" we
    /// re-pair the device (open setup) — done in onDismiss so sheets don't overlap.
    private func handleCompromisedDismiss() {
        guard let device = reauthPendingDevice else { return }
        reauthPendingDevice = nil
        viewModel.prepareDeviceForSetup(device)
        router.showDeviceSetup(for: device)
    }

    private func handleDeviceTap(_ device: DeviceModel) {
        switch device.connectionState {
        case .connectedAuthorized:
            router.selectDevice(device)
        case .disconnected:
            viewModel.connectDevice(device)
            if device.isKnownDevice {
                pendingConnectedDeviceID = device.id
                resolvePendingConnectedDeviceSelection()
            }
        case .serviceDiscovery:
            pendingConnectedDeviceID = device.id
        case .connectedUnauthorized:
            if device.needsAuthentication {
                pendingConnectedDeviceID = nil
                viewModel.prepareDeviceForSetup(device)
                router.showDeviceSetup(for: device)
            } else {
                pendingConnectedDeviceID = device.id
            }
        }
    }

    private func resolvePendingConnectedDeviceSelection() {
        guard let pendingConnectedDeviceID else { return }

        guard let device = viewModel.device(for: pendingConnectedDeviceID) else {
            self.pendingConnectedDeviceID = nil
            return
        }

        if device.isConnected {
            router.selectDevice(device)
            self.pendingConnectedDeviceID = nil
        } else if device.connectionState == .disconnected
            || device.needsAuthentication
            || device.isCompromised
            || device.lastError != nil {
            self.pendingConnectedDeviceID = nil
        }
    }

    private func connectFromFound(_ device: DeviceModel) {
        if viewModel.connectDevice(device) {
            router.selectDevice(device)
        }
        addDeviceStage = nil
    }

    private func handleStartupAction(_ action: DeviceListStartupAction?) {
        guard let action else { return }

        switch action {
        case .startAddDeviceScan:
            presentAddDevice()
        }

        startupAction = nil
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func deviceContextMenu(for device: DeviceModel) -> some View {
        Button(role: .destructive) {
            deviceToForget = device
        } label: {
            Label(String(localized: "Forget Device"), systemImage: "trash")
        }
        .disabled(!device.isKnownDevice || device.isDemoDevice)

        if device.isConnected {
            Button {
                device.disconnect()
            } label: {
                Label(String(localized: "Disconnect"), systemImage: "cable.connector.horizontal")
            }
        }
    }
}

private struct DeviceConnectionSnapshot: Equatable {
    let id: UUID
    let isConnected: Bool
    let isConnecting: Bool
    let needsAuthentication: Bool
    let isCompromised: Bool
    let lastErrorTimestamp: Date?
}

private struct HeaderIconButton: View {
    let systemName: String
    let foreground: Color
    let background: Color
    let accessibilityLabel: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: 36, height: 36)
                .background(Circle().fill(background))
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(accessibilityLabel)
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
