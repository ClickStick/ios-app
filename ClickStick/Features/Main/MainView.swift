//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import DesignSystem
import SwiftUI

struct MainView: View {
    @Bindable var viewModel: DeviceListViewModel
    @Environment(\.appRouter) private var router
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            DeviceListView(viewModel: viewModel)
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
        .onAppear {
            viewModel.startScanning()
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: AppRouter.Sheet) -> some View {
        switch sheet {
        case .deviceSetup(let device):
            DeviceSetupSheet(device: device) { authKey, alias in
                if viewModel.saveDeviceSettings(device: device, authKey: authKey, alias: alias) {
                    router.dismissSheet()
                }
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
