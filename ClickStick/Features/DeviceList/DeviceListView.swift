//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI

struct DeviceListView: View {
    @Bindable var viewModel: DeviceListViewModel
    @Environment(\.appRouter) private var router

    var body: some View {
        List(selection: Binding(
            get: { router.selectedDeviceID },
            set: { router.selectedDeviceID = $0 }
        )) {
            if viewModel.hasAnnouncements {
                announcementsSection
            }
            if !viewModel.devices.isEmpty {
                devicesSection
            }
        }
        .overlay {
            if viewModel.isEmpty {
                emptyStateContent
            }
        }
        .refreshable {
            viewModel.startScanning()
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                scanButton
            }
        }
        .onChange(of: viewModel.deviceRequiringAuthentication) { _, device in
            if let device, router.presentedSheet == nil {
                viewModel.prepareDeviceForSetup(device)
                router.showDeviceSetup(for: device)
            }
        }
        .errorAlert($viewModel.alertError)
    }

    // MARK: - Announcements

    @ViewBuilder
    private var announcementsSection: some View {
        Section {
            if let error = viewModel.bluetoothError {
                AnnouncementBannerView(
                    configuration: .bluetoothError(error: error),
                    onAction: { viewModel.openBLESettings() },
                    onDismiss: nil
                )
                .announcementRow(id: "bluetooth-error")
            }

            if !viewModel.hasShownWelcome {
                AnnouncementBannerView(
                    configuration: .welcome,
                    onAction: { viewModel.openGettingStarted() },
                    onDismiss: { viewModel.dismissWelcome() }
                )
                .announcementRow(id: "welcome")
            }

            if viewModel.showDemoPrompt {
                AnnouncementBannerView(
                    configuration: .demo,
                    onAction: { viewModel.enableDemoMode() },
                    onDismiss: { viewModel.dismissDemoPrompt() }
                )
                .announcementRow(id: "demo")
            }
        }
    }

    // MARK: - Devices Section

    @ViewBuilder
    private var devicesSection: some View {
        Section {
            ForEach(viewModel.devices) { device in
                DeviceRowView(device: device)
                    .tag(device.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if viewModel.connectDevice(device) {
                            router.selectDevice(device)
                        }
                    }
                    .contextMenu {
                        deviceContextMenu(for: device)
                    }
            }
        } header: {
            Text("Devices")
        }
    }

    // MARK: - Empty State

    private var emptyStateContent: some View {
        ContentUnavailableView {
            VStack(spacing: Spacing.md) {
                FeatureIcon(systemName: "antenna.radiowaves.left.and.right")
                Text("Welcome")
                    .font(.title2.weight(.semibold))
            }
        } description: {
            Text("Plug in your ClickStick to get started.")
        } actions: {
            VStack(spacing: Spacing.sm) {
                Button {
                    viewModel.openGettingStarted()
                } label: {
                    Label(String(localized: "Getting Started"), systemImage: "hand.wave")
                }
                .buttonStyle(.primary)

                Button(String(localized: "Try in Demo Mode")) {
                    viewModel.enableDemoMode()
                }
                .buttonStyle(.secondary)
            }
            .padding(.horizontal, Spacing.xxl)
        }
    }

    // MARK: - Scan Button

    private var scanButton: some View {
        Button {
            viewModel.toggleScanning()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning")
                } else {
                    Image(systemName: "arrow.clockwise")
                    Text("Scan")
                }
            }
        }
        .animation(.default, value: viewModel.isScanning)
        .accessibilityLabel(viewModel.isScanning
            ? String(localized: "Stop scanning")
            : String(localized: "Scan for devices"))
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func deviceContextMenu(for device: DeviceModel) -> some View {
        Button(role: .destructive) {
            if viewModel.forgetDevice(device, selectedDeviceID: router.selectedDeviceID) {
                router.deselectDevice()
            }
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

#Preview("With Announcements") {
    NavigationStack {
        DeviceListView(viewModel: DeviceListViewModel(
            service: ClickStickService(),
            urlOpener: URLOpener()
        ))
    }
}

#Preview("With Devices") {
    NavigationStack {
        DeviceListView(viewModel: DeviceListViewModel(
            service: ClickStickService(),
            urlOpener: URLOpener()
        ))
    }
}
