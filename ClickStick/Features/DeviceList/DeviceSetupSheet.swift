//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI
import VisionKit

private enum AuthAttemptSource {
    case scanner
    case manual
}

struct DeviceSetupSheet: View {
    let device: DeviceModel
    let onComplete: (CSAppAuthKey, String?) -> Bool
    /// Called when a key that was saved during setup fails to authenticate, so the
    /// caller can roll back the unverified settings.
    var onAuthenticationFailure: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var authKeyText: String = ""
    @State private var showingScanner: Bool = false
    @State private var validationError: String?
    @State private var didRequestInitialScan = false

    /// True while a saved key is connecting and we're waiting to learn whether
    /// authentication succeeded before keeping the settings or dismissing setup.
    @State private var awaitingAuth = false
    @State private var authAttemptSource: AuthAttemptSource?
    @State private var scannerShowsFailure = false

    private var isCameraScanningAvailable: Bool {
#if targetEnvironment(macCatalyst)
        return false
#else
        return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
#endif
    }

    private var canShowScanner: Bool {
#if targetEnvironment(macCatalyst)
        return false
#else
        return true
#endif
    }

    private var shouldAutoScan: Bool {
        !device.isDemoDevice && isCameraScanningAvailable
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    deviceInformationSection
                    authenticationKeySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 32)
            }
            .background(Color.groupedBackground)
            .safeAreaInset(edge: .bottom) {
                connectButton
            }
            .navigationTitle("Setup Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(awaitingAuth)
                    .accessibilityLabel("Cancel device setup")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.groupedBackground)
#if !targetEnvironment(macCatalyst)
        .sheet(isPresented: $showingScanner) {
            QRScannerSheet(
                onScan: handleScannedKey,
                onManualEntry: {
                    showingScanner = false
                },
                isVerifying: $awaitingAuth,
                showsSetupFailure: $scannerShowsFailure
            )
        }
#endif
        .onChange(of: device.connectionState) { _, state in
            guard awaitingAuth else { return }
            switch state {
            case .connectedAuthorized:
                // Authentication succeeded — close the scanner and the setup sheet.
                awaitingAuth = false
                authAttemptSource = nil
                showingScanner = false
                dismiss()
            case .disconnected:
                reportAuthFailure()
            default:
                break
            }
        }
        .onChange(of: device.needsAuthentication) { _, needsAuthentication in
            // The device rejected the saved key and is asking for credentials again.
            if awaitingAuth, needsAuthentication {
                reportAuthFailure()
            }
        }
        .onChange(of: device.lastErrorTimestamp) { _, _ in
            if awaitingAuth, device.lastError != nil {
                reportAuthFailure()
            }
        }
        .onChange(of: showingScanner) { _, isShowing in
            guard !isShowing else { return }
            scannerShowsFailure = false

            // If the scanner is dismissed while a scanned key is being verified, roll
            // back the unverified key instead of leaving it persisted.
            if awaitingAuth, authAttemptSource == .scanner {
                reportAuthFailure()
            }
        }
        .interactiveDismissDisabled(awaitingAuth)
        .onAppear {
            guard !didRequestInitialScan else { return }
            didRequestInitialScan = true
            if shouldAutoScan {
                showingScanner = true
            }
        }
    }

    /// Handles a key scanned from the QR scanner: validates it, starts connecting, and
    /// keeps the scanner open so the auth outcome can surface the failure panel inline.
    private func handleScannedKey(_ scannedKey: String) {
        authKeyText = scannedKey
        validationError = nil

        guard let authKey = CSAppAuthKey.fromHexString(scannedKey) else {
            scannerShowsFailure = true
            return
        }

        if onComplete(authKey, nil) {
            authAttemptSource = .scanner
            awaitingAuth = true
        } else {
            scannerShowsFailure = true
        }
    }

    private func reportAuthFailure() {
        let source = authAttemptSource
        awaitingAuth = false
        authAttemptSource = nil

        // Roll back the key we persisted before authentication so it isn't left behind.
        onAuthenticationFailure()

        switch source {
        case .scanner:
            scannerShowsFailure = true
        case .manual:
            validationError = String(
                localized: "Could not authenticate this device. Check the key and try again.",
                comment: "Manual authentication failure message"
            )
        case nil:
            break
        }
    }

    // MARK: - Sections

    private var deviceInformationSection: some View {
        setupSection(title: "Device Information") {
            VStack(spacing: 0) {
                SetupInfoRow(title: "Device Name", value: device.name)

                Divider()
                    .padding(.leading, 16)

                SetupInfoRow(
                    title: "Device ID",
                    value: abbreviatedDeviceID,
                    accessibilityValue: device.id.uuidString
                )
            }
        }
    }

    private var authenticationKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            setupSection(title: "Authentication Key") {
                HStack(spacing: 12) {
                    TextField("Enter 32-character hex key", text: $authKeyText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textContentType(.oneTimeCode)
                        .keyboardType(.asciiCapable)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                        .accessibilityLabel("Authentication key input")
                        .accessibilityHint("Enter the 32-character hex key from your ClickStick")
                        .onChange(of: authKeyText) { _, _ in
                            validationError = nil
                        }

                    if canShowScanner {
                        Button {
                            showingScanner = true
                        } label: {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.accentBlue)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Scan QR code")
                        .accessibilityHint("Opens camera to scan the QR code from your ClickStick")
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, canShowScanner ? 8 : 16)
                .frame(minHeight: 60)
            }

            if let validationError {
                Text(validationError)
                    .font(.footnote)
                    .foregroundStyle(Color(.systemRed))
                    .accessibilityLabel("Error: \(validationError)")
            }

            Text("Scan the QR code on your ClickStick's screen or enter the 32-character hex key manually.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func setupSection<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            content()
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.cardBackground)
                )
        }
    }

    private var connectButton: some View {
        Button {
            submitAuthKey()
        } label: {
            if awaitingAuth, authAttemptSource == .manual {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                        .accessibilityHidden(true)
                    Text("Verifying…")
                }
            } else {
                Text("Connect")
            }
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .disabled(!isValidAuthKey || awaitingAuth)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .accessibilityLabel(awaitingAuth && authAttemptSource == .manual ? "Verifying device" : "Connect to device")
        .accessibilityHint(isValidAuthKey
            ? String(localized: "Double-tap to connect", comment: "Accessibility hint")
            : String(localized: "Enter a valid authentication key first", comment: "Accessibility hint"))
    }

    // MARK: - Validation

    private var abbreviatedDeviceID: String {
        String(device.id.uuidString.prefix(8)) + "..."
    }

    private var isValidAuthKey: Bool {
        CSAppAuthKey.fromHexString(authKeyText) != nil
    }

    private func submitAuthKey() {
        guard let authKey = CSAppAuthKey.fromHexString(authKeyText) else {
            validationError = String(localized: "Invalid key format. Please enter a 32-character hex string.", comment: "Error message")
            return
        }

        validationError = nil
        if onComplete(authKey, nil) {
            authAttemptSource = .manual
            awaitingAuth = true
        } else {
            validationError = String(
                localized: "Could not save device settings. Try again.",
                comment: "Device setup save failure message"
            )
        }
    }
}

private struct SetupInfoRow: View {
    let title: LocalizedStringKey
    let value: String
    var accessibilityValue: String?

    private var combinedAccessibilityLabel: Text {
        let displayValue = accessibilityValue ?? value
        let valueSuffix = Text(verbatim: ", \(displayValue)")
        return Text("\(Text(title))\(valueSuffix)")
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer(minLength: 16)

            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(minHeight: 50)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(combinedAccessibilityLabel)
    }
}

// MARK: - Preview

#Preview {
    DeviceSetupSheet(device: .previewDisconnected) { _, _ in true }
}
