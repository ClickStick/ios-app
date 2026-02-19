//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import DesignSystem
import SwiftUI
import VisionKit
internal import Vision

struct QRScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var alertError: AlertError?

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
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
                } else {
                    ContentUnavailableView {
                        VStack(spacing: Spacing.md) {
                            FeatureIcon(systemName: "camera.fill")
                            Text("Camera Not Available")
                                .font(.title2.weight(.semibold))
                        }
                    } description: {
                        Text("This device doesn't support camera scanning. Please enter the key manually.")
                    } actions: {
                        Button("Dismiss") {
                            dismiss()
                        }
                        .buttonStyle(.primary)
                        .padding(.horizontal, Spacing.xxl)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel scanning")
                }
            }
        }
        .errorAlert($alertError)
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
