//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

#if !targetEnvironment(macCatalyst)
import AVFoundation
import SwiftUI
import VisionKit
internal import Vision

struct QRScannerSheet: View {
    let onScan: (String) -> Void
    let onManualEntry: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var alertError: AlertError?
    @State private var cameraAuthorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var isTorchOn = false
    /// Bumped to remount the scanner and resume detection after a "Try again".
    @State private var scanGeneration = 0
    @Binding private var isVerifying: Bool
    @Binding private var showsSetupFailure: Bool

    init(
        onScan: @escaping (String) -> Void,
        onManualEntry: @escaping () -> Void = {},
        isVerifying: Binding<Bool> = .constant(false),
        showsSetupFailure: Binding<Bool> = .constant(false)
    ) {
        self.onScan = onScan
        self.onManualEntry = onManualEntry
        _isVerifying = isVerifying
        _showsSetupFailure = showsSetupFailure
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            scannerContent

            if shouldShowScannerChrome {
                QRScannerChrome(
                    isTorchOn: isTorchOn,
                    canToggleTorch: canToggleTorch,
                    onCancel: { dismiss() },
                    onToggleTorch: { toggleTorch() }
                )
            }

            if isVerifying && !showsSetupFailure {
                verifyingOverlay
            }

            if showsSetupFailure {
                setupFailureOverlay
            }
        }
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(isVerifying)
        .errorAlert($alertError)
        .task {
            if cameraAuthorizationStatus == .notDetermined {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                cameraAuthorizationStatus = granted ? .authorized : .denied
            }
        }
        .onDisappear {
            setTorch(on: false)
        }
    }

    private var scannerContent: some View {
        Group {
            if cameraAuthorizationStatus == .authorized, isScannerAvailable {
                QRCodeScannerView(
                    onScan: onScan,
                    onStartError: { error in
                        alertError = AlertError(
                            title: String(localized: "Scanner Error", comment: "QR scanner error title"),
                            error: error
                        )
                    }
                )
                .id(scanGeneration)
                .ignoresSafeArea()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Camera viewfinder for scanning QR code")
                .accessibilityHint("Point the camera at the QR code on your ClickStick's screen")
            } else if cameraAuthorizationStatus == .notDetermined {
                Color.black
                    .ignoresSafeArea()
            } else {
                CameraPermissionDeniedView(
                    title: cameraAuthorizationStatus == .denied ? "Camera Access Required" : "Camera Unavailable",
                    message: cameraAuthorizationStatus == .denied
                        ? "To scan the QR code, allow ClickStick to access your camera in Settings."
                        : "Enter the authentication key manually, or try again on a device with camera scanning support."
                )
            }
        }
    }

    private var verifyingOverlay: some View {
        ZStack {
            Color.black
                .opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)

                Text("Verifying…")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
            }
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Verifying device")
    }

    private var setupFailureOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .opacity(0.35)
                .ignoresSafeArea()

            SetupFailurePanel(
                onHelpArticle: {
                    URLOpener().openGettingStartedPage()
                },
                onManualEntry: {
                    showsSetupFailure = false
                    onManualEntry()
                    dismiss()
                },
                onTryAgain: {
                    showsSetupFailure = false
                    // Remount the scanner so detection resumes for a fresh attempt.
                    scanGeneration += 1
                }
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .transition(.opacity)
    }

    private var shouldShowScannerChrome: Bool {
        cameraAuthorizationStatus == .authorized && isScannerAvailable && !showsSetupFailure && !isVerifying
    }

    private var isScannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    private var canToggleTorch: Bool {
        AVCaptureDevice.default(for: .video)?.hasTorch == true
    }

    private func toggleTorch() {
        setTorch(on: !isTorchOn)
    }

    private func setTorch(on: Bool) {
        guard let captureDevice = AVCaptureDevice.default(for: .video), captureDevice.hasTorch else { return }

        do {
            try captureDevice.lockForConfiguration()
            defer { captureDevice.unlockForConfiguration() }
            if on {
                try captureDevice.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                captureDevice.torchMode = .off
            }
            isTorchOn = on
        } catch {
            alertError = AlertError(title: String(localized: "Flashlight Error"), error: error)
        }
    }
}

// MARK: - Scanner Chrome

private struct QRScannerChrome: View {
    let isTorchOn: Bool
    let canToggleTorch: Bool
    let onCancel: () -> Void
    let onToggleTorch: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            scannerHeader

            Spacer(minLength: 40)

            QRFocusFrame()
                .frame(width: 272, height: 272)

            Spacer(minLength: 40)

            Text("Point your camera at the QR code\non your ClickStick")
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.45), radius: 4, y: 1)

            ScannerHelpCard()
                .padding(.top, 40)

            Spacer(minLength: 32)

            Button(action: onToggleTorch) {
                Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canToggleTorch)
            .opacity(canToggleTorch ? 1 : 0.5)
            .accessibilityLabel(isTorchOn ? "Turn flashlight off" : "Turn flashlight on")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
        // The scanner chrome floats over the camera feed and always renders in a
        // light appearance, regardless of the system color scheme.
        .environment(\.colorScheme, .light)
    }

    private var scannerHeader: some View {
        ZStack {
            Text("Add Device")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                .frame(maxWidth: .infinity)

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .font(.body)
                .foregroundStyle(.primary)
                .frame(minWidth: 96, minHeight: 44)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.78))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                }
                .accessibilityLabel("Cancel scanning")

                Spacer()
            }
        }
    }
}

private struct QRFocusFrame: View {
    var body: some View {
        QRFocusCorners()
            .stroke(
                Color.white,
                style: StrokeStyle(
                    lineWidth: 6,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
            .accessibilityHidden(true)
    }
}

private struct QRFocusCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerLength = min(rect.width, rect.height) * 0.2
        let radius: CGFloat = 20
        var path = Path()

        // Top left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

        // Top right
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

        // Bottom right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))

        // Bottom left
        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))

        return path
    }
}

private struct ScannerHelpCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: 22, alignment: .center)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Find the QR code")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("It's displayed on your ClickStick screen")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.28))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SetupFailurePanel: View {
    let onHelpArticle: () -> Void
    let onManualEntry: () -> Void
    let onTryAgain: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            failureIcon
                .padding(.top, 40)

            VStack(spacing: 8) {
                Text("Setup failed")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Could not authenticate this device.\nMake sure you scanned the correct QR\ncode from your ClickStick.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 20)

            VStack(spacing: 12) {
                Button("Help article") {
                    onHelpArticle()
                }
                .buttonStyle(AppSecondaryButtonStyle())

                Button("Enter key manually") {
                    onManualEntry()
                }
                .buttonStyle(AppSecondaryButtonStyle())

                Button("Try again") {
                    onTryAgain()
                }
                .buttonStyle(AppPrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.cardBackground)
        )
        .accessibilityElement(children: .contain)
    }

    private var failureIcon: some View {
        ZStack {
            Circle()
                .fill(Color(.systemRed).opacity(0.12))
                .frame(width: 80, height: 80)

            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color(.systemRed))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Camera Permission Denied View

private struct CameraPermissionDeniedView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            deniedIcon

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 320)

            Button("Open Settings") {
                URLOpener().openCameraPermissions()
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .padding(.top, 12)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.groupedBackground.ignoresSafeArea())
    }

    private var deniedIcon: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 96, height: 96)

            Image(systemName: "camera.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - DataScanner Representable

struct QRCodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onStartError: (Error) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator

        do {
            try context.coordinator.startScannerIfNeeded {
                try scanner.startScanning()
            }
        } catch {
            onStartError(error)
        }
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        coordinator.stopScannerIfRunning {
            uiViewController.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private(set) var isScannerRunning = false
        private var hasScanned = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func startScannerIfNeeded(_ start: () throws -> Void) throws {
            guard !isScannerRunning else { return }
            try start()
            isScannerRunning = true
        }

        func stopScannerIfRunning(_ stop: () -> Void) {
            guard isScannerRunning else { return }
            stop()
            isScannerRunning = false
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            processItem(item, from: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned, let item = addedItems.first else { return }
            processItem(item, from: dataScanner)
        }

        private func processItem(_ item: RecognizedItem, from scanner: DataScannerViewController) {
            guard !hasScanned else { return }

            if case .barcode(let barcode) = item,
               let payload = barcode.payloadStringValue {
                if let hexKey = extractHexKey(from: payload) {
                    hasScanned = true
                    stopScannerIfRunning {
                        scanner.stopScanning()
                    }
                    onScan(hexKey)
                }
            }
        }

        private func extractHexKey(from string: String) -> String? {
            let cleaned = string
                .replacing("clickstick://", with: "")
                .replacing("key=", with: "")
                .replacing(" ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let hexCharacters = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
            guard cleaned.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }),
                  !cleaned.isEmpty else {
                return nil
            }
            return cleaned
        }
    }
}

// MARK: - Previews

private struct QRScannerPreview: View {
    @State private var isShowingSetupFailure: Bool

    init(showsSetupFailure: Bool = false) {
        _isShowingSetupFailure = State(initialValue: showsSetupFailure)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            QRScannerPreviewCameraView()
                .ignoresSafeArea()

            if !isShowingSetupFailure {
                QRScannerChrome(
                    isTorchOn: false,
                    canToggleTorch: true,
                    onCancel: {},
                    onToggleTorch: {}
                )
            }

            if isShowingSetupFailure {
                ZStack(alignment: .bottom) {
                    Color.black
                        .opacity(0.35)
                        .ignoresSafeArea()

                    SetupFailurePanel(
                        onHelpArticle: {},
                        onManualEntry: {},
                        onTryAgain: { isShowingSetupFailure = false }
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
    }
}

private struct QRScannerPreviewCameraView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.85),
                    Color.gray.opacity(0.55),
                    Color.black.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .frame(width: 280, height: 120)
                .rotationEffect(.degrees(12))
                .offset(x: 86, y: -254)

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(Color.white.opacity(0.32))
                .frame(width: 360, height: 140)
                .rotationEffect(.degrees(-18))
                .offset(x: -62, y: -116)
        }
    }
}

#Preview("Add Device QR Scanner") {
    QRScannerPreview()
}

#Preview("Setup Failed") {
    QRScannerPreview(showsSetupFailure: true)
}
#endif
