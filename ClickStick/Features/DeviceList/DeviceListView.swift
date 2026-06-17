//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
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

    init(
        viewModel: DeviceListViewModel,
        startupAction: Binding<DeviceListStartupAction?> = .constant(nil)
    ) {
        self.viewModel = viewModel
        _startupAction = startupAction
    }

    var body: some View {
        ZStack {
            Color.clickStickGroupedBackground
                .ignoresSafeArea()

            content
        }
        .toolbar(.hidden, for: .navigationBar)
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
                viewModel.prepareDeviceForSetup(device)
                router.showDeviceSetup(for: device)
            }
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
            DiscoveryScreen {
                standardHeader(showsActions: false)
            } center: {
                emptyState
            } bottom: {
                Button("Scan for devices") { presentAddDevice() }
                    .buttonStyle(.primary)
            }
        } else {
            deviceListScreen
        }
    }

    private var connectedDevices: [DeviceModel] {
        viewModel.devices.filter { $0.isConnected && !$0.isCompromised }
    }

    /// Disconnected devices that are currently advertising and can be connected to.
    private var availableDevices: [DeviceModel] {
        viewModel.devices.filter { !$0.isConnected && $0.isConnectable && !$0.isCompromised }
    }

    /// Disconnected devices that are no longer advertising (out of range).
    private var outOfRangeDevices: [DeviceModel] {
        viewModel.devices.filter { !$0.isConnected && !$0.isConnectable && !$0.isCompromised }
    }

    /// Devices that failed session validation and may be compromised.
    private var compromisedDevices: [DeviceModel] {
        viewModel.devices.filter(\.isCompromised)
    }

    // MARK: - Header

    private func standardHeader(showsActions: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Spacer()

                if showsActions {
                    HeaderIconButton(
                        systemName: "gearshape",
                        foreground: .primary,
                        background: .clickStickMutedFill,
                        accessibilityLabel: "Settings"
                    ) {
                        isShowingSettings = true
                    }

                    HeaderIconButton(
                        systemName: "plus",
                        foreground: .white,
                        background: .clickStickBlue,
                        accessibilityLabel: "Add device"
                    ) {
                        presentAddDevice()
                    }
                }
            }
            .frame(height: ComponentSize.iconButton)

            Text("Devices")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.136)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.xxxl) {
            VStack(spacing: Spacing.md) {
                RadioWaveIconView(tint: .clickStickBlue, size: 80)

                VStack(spacing: Spacing.xs) {
                    Text("No devices found")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Make sure your ClickStick is plugged in and Bluetooth is on")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 300)
            }

            Button {
                viewModel.openGettingStarted()
            } label: {
                Text("How does ClickStick work?")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.clickStickBlue)
            }
            .buttonStyle(.plain)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No devices found. Make sure your ClickStick is plugged in and Bluetooth is on")
    }

    // MARK: - Device List

    private var deviceListScreen: some View {
        VStack(spacing: 0) {
            standardHeader(showsActions: true)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl + Spacing.xxs) {
                    if !connectedDevices.isEmpty {
                        deviceSection(title: String(localized: "Connected"), devices: connectedDevices)
                    }

                    if !availableDevices.isEmpty {
                        deviceSection(title: String(localized: "Available"), devices: availableDevices)
                    }

                    if !outOfRangeDevices.isEmpty {
                        deviceSection(title: String(localized: "Not in range"), devices: outOfRangeDevices)
                    }

                    if !compromisedDevices.isEmpty {
                        compromisedSection
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xxl)
            }
        }
    }

    /// Compromised devices render as standalone red "Security warning" cards (no header);
    /// tapping one opens the compromised-device warning sheet.
    private var compromisedSection: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(compromisedDevices) { device in
                Button {
                    compromisedDevice = device
                } label: {
                    DeviceRowView(device: device)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    deviceContextMenu(for: device)
                }
            }
        }
    }

    private func deviceSection(title: String, devices: [DeviceModel]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.xs)

            VStack(spacing: Spacing.sm) {
                ForEach(devices) { device in
                    Button {
                        if viewModel.connectDevice(device) {
                            router.selectDevice(device)
                        }
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

// MARK: - Discovery Scaffold

/// Shared layout for the empty state: a top header, vertically centered content,
/// and a caller-provided bottom action button pinned above the safe area.
private struct DiscoveryScreen<Header: View, Center: View, Bottom: View>: View {
    @ViewBuilder let header: Header
    @ViewBuilder let center: Center
    @ViewBuilder let bottom: Bottom

    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder center: () -> Center,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.header = header()
        self.center = center()
        self.bottom = bottom()
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: Spacing.lg)
            center
            Spacer(minLength: Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom) {
            bottom
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.sm)
        }
    }
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
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(foreground)
                .frame(width: ComponentSize.iconButton, height: ComponentSize.iconButton)
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

    static func deviceList() -> DeviceListViewModel {
        let service = ClickStickService()
        service.isDemoMode = true
        let viewModel = DeviceListViewModel(service: service, urlOpener: URLOpener())
        viewModel.hasShownWelcome = true
        viewModel.hasDismissedDemoPrompt = true
        return viewModel
    }

    static func deviceListWithCompromised() -> DeviceListViewModel {
        let viewModel = deviceList()
        if let device = viewModel.devices.first {
            device.deviceDidDetectTampering(device.device)
        }
        return viewModel
    }

    private final class PreviewManager: CSManaging {
        var isDemoMode: Bool = false
        weak var delegate: CSManagerDelegate?

        func startScanning() {}
        func stopScanning() {}
        func knownDevices() -> [CSDevice] { [] }
    }
}
#endif

#Preview("No Devices Found") {
    DeviceListView(viewModel: DeviceListPreviewFactory.empty())
}

#Preview("Device List") {
    DeviceListView(viewModel: DeviceListPreviewFactory.deviceList())
}


#Preview("Compromised in List") {
    DeviceListView(viewModel: DeviceListPreviewFactory.deviceListWithCompromised())
}
