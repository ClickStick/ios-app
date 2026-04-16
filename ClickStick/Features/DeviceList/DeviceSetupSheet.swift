//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import DesignSystem
import SwiftUI
import VisionKit

struct DeviceSetupSheet: View {
    let device: DeviceModel
    let onComplete: (CSAppAuthKey, String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var authKeyText: String = ""
    @State private var deviceAlias: String = ""
    @State private var showingScanner: Bool = false
    @State private var validationError: String?

    private var isCameraScanningAvailable: Bool {
#if targetEnvironment(macCatalyst)
        return false
#else
        return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
#endif
    }

    private var shouldAutoScan: Bool {
        !device.isDemoDevice && isCameraScanningAvailable
    }

    var body: some View {
        NavigationStack {
            Form {
                deviceInfoSection
                authKeySection
                aliasSection
            }
            .navigationTitle("Setup Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel device setup")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        submitAuthKey()
                    }
                    .disabled(!isValidAuthKey)
                    .accessibilityLabel("Connect to device")
                    .accessibilityHint(isValidAuthKey
                        ? String(localized: "Double-tap to connect", comment: "Accessibility hint")
                        : String(localized: "Enter a valid authentication key first", comment: "Accessibility hint"))
                }
            }
#if !targetEnvironment(macCatalyst)
            .sheet(isPresented: $showingScanner) {
                QRScannerSheet { scannedKey in
                    authKeyText = scannedKey
                    showingScanner = false
                    // Auto-submit if valid
                    if isValidAuthKey {
                        submitAuthKey()
                    }
                }
            }
#endif
            .onAppear {
                deviceAlias = device.name
                // Auto-open QR scanner for non-demo devices
                if shouldAutoScan {
                    showingScanner = true
                }
            }
        }
    }

    // MARK: - Sections

    private var deviceInfoSection: some View {
        Section {
            LabeledContent("Device Name", value: device.name)
                .accessibilityElement(children: .combine)
            LabeledContent("Device ID", value: String(device.id.uuidString.prefix(8)) + "...")
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Device ID: \(device.id.uuidString)")
        } header: {
            Text("Device Information")
        }
    }

    private var authKeySection: some View {
        Section {
            HStack {
                TextField("Enter 32-character hex key", text: $authKeyText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.oneTimeCode)
                    .keyboardType(.asciiCapable)
                    .font(.system(.body, design: .monospaced))
                    .accessibilityLabel("Authentication key input")
                    .accessibilityHint("Enter the 32-character hex key from your ClickStick")

                if isCameraScanningAvailable {
                    Button {
                        showingScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Scan QR code")
                    .accessibilityHint("Opens camera to scan the QR code from your ClickStick")
                }
            }

            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel(String(localized: "Error: \(error)", comment: "Accessibility label"))
            }
        } header: {
            Text("Authentication Key")
        } footer: {
            Text("Scan the QR code on your ClickStick's screen or enter the 32-character hex key manually.")
        }
    }

    private var aliasSection: some View {
        Section {
            TextField(String(localized: "Device nickname (optional)", comment: "Device alias placeholder"), text: $deviceAlias)
                .accessibilityLabel("Device nickname")
                .accessibilityHint("Optional friendly name for this device")
        } header: {
            Text("Nickname")
        } footer: {
            Text("Give your device a friendly name for easy identification.")
        }
    }

    // MARK: - Validation

    private var isValidAuthKey: Bool {
        CSAppAuthKey.fromHexString(authKeyText) != nil
    }

    private func submitAuthKey() {
        guard let authKey = CSAppAuthKey.fromHexString(authKeyText) else {
            validationError = String(localized: "Invalid key format. Please enter a 32-character hex string.", comment: "Error message")
            return
        }

        validationError = nil
        let alias = deviceAlias.isEmpty ? nil : deviceAlias
        onComplete(authKey, alias)
    }
}

// MARK: - Preview

#Preview {
    DeviceSetupSheet(device: .preview) { authKey, alias in
        print("Auth key: \(authKey), Alias: \(alias ?? "none")")
    }
}
