//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct DeviceSetupSheet: View {
    let device: DeviceModel
    let onComplete: (CSAppAuthKey, String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var authKeyText: String = ""
    @State private var deviceAlias: String = ""
    @State private var showingScanner: Bool = false
    @State private var validationError: String?

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
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        submitAuthKey()
                    }
                    .disabled(!isValidAuthKey)
                }
            }
            .sheet(isPresented: $showingScanner) {
                QRScannerSheet { scannedKey in
                    authKeyText = scannedKey
                    showingScanner = false
                }
            }
        }
    }

    // MARK: - Sections

    private var deviceInfoSection: some View {
        Section {
            LabeledContent("Device Name", value: device.name)
            LabeledContent("Device ID", value: device.id.uuidString.prefix(8) + "...")
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
                    .font(.system(.body, design: .monospaced))
                    .accessibilityLabel("Authentication key")

                Button {
                    showingScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Scan QR code")
            }

            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Authentication Key")
        } footer: {
            Text("Scan the QR code on your ClickStick or enter the 32-character hex key manually.")
        }
    }

    private var aliasSection: some View {
        Section {
            TextField("Device nickname (optional)", text: $deviceAlias)
                .accessibilityLabel("Device nickname")
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
            validationError = "Invalid key format. Please enter a 32-character hex string."
            return
        }

        validationError = nil
        let alias = deviceAlias.isEmpty ? nil : deviceAlias
        onComplete(authKey, alias)
    }
}
