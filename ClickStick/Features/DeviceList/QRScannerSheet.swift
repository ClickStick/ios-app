//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

#if !targetEnvironment(macCatalyst)
import AVFoundation
import DesignSystem
import SwiftUI
import VisionKit
internal import Vision

struct QRScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var alertError: AlertError?
    @State private var cameraAuthorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            Group {
                if cameraAuthorizationStatus == .authorized {
                    QRCodeScannerView(
                        onScan: onScan,
                        onStartError: { error in
                            alertError = AlertError(
                                title: String(localized: "Scanner Error", comment: "QR scanner error title"),
                                error: error
                            )
                        }
                    )
                    .ignoresSafeArea()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Camera viewfinder for scanning QR code")
                    .accessibilityHint("Point the camera at the QR code on your ClickStick's screen")
                } else if cameraAuthorizationStatus == .notDetermined {
                    Color.clear
                } else {
                    CameraPermissionDeniedView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if cameraAuthorizationStatus == .authorized {
                        Text("Scan QR Code")
                            .font(.headline)
                            .foregroundStyle(Color.white)
                            .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
                    } else {
                        Text("Scan QR Code")
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if cameraAuthorizationStatus == .authorized {
                        Button("Cancel") {
                            dismiss()
                        }
                        .accessibilityLabel("Cancel scanning")
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                        .accessibilityLabel("Cancel scanning")
                    }
                }
            }
        }
        .errorAlert($alertError)
        .task {
            if cameraAuthorizationStatus == .notDetermined {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                cameraAuthorizationStatus = granted ? .authorized : .denied
            }
        }
    }
}

// MARK: - Camera Permission Denied View

private struct CameraPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: IconSize.extraLarge))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.xs) {
                Text(String(localized: "Camera Access Required", comment: "Camera permission denied title"))
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text(String(localized: "To scan the QR code, allow ClickStick to access your camera in Settings.", comment: "Camera permission denied message"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(String(localized: "Open Settings", comment: "Button to open iOS Settings app")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.primary)
            .accessibilityHint(String(localized: "Opens the iOS Settings app to allow camera access", comment: "Accessibility hint for Open Settings button"))
        }
        .padding(Spacing.xl)
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
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
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
                .replacingOccurrences(of: "clickstick://", with: "")
                .replacingOccurrences(of: "key=", with: "")
                .replacingOccurrences(of: " ", with: "")
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

// MARK: - Preview

#Preview {
    QRScannerSheet { scannedKey in
        print("Scanned: \(scannedKey)")
    }
}
#endif
