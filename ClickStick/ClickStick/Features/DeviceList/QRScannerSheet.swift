//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI
import VisionKit
internal import Vision

struct QRScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable(onScan: onScan)
                        .ignoresSafeArea()
                } else {
                    ContentUnavailableView {
                        Label("Camera Not Available", systemImage: "camera.fill")
                    } description: {
                        Text("This device doesn't support camera scanning. Please enter the key manually.")
                    }
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - DataScanner Representable

struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

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
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        try? uiViewController.startScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var hasScanned = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
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
                let hexKey = extractHexKey(from: payload)
                if !hexKey.isEmpty {
                    hasScanned = true
                    scanner.stopScanning()
                    onScan(hexKey)
                }
            }
        }

        private func extractHexKey(from string: String) -> String {
            let cleaned = string
                .replacingOccurrences(of: "clickstick://", with: "")
                .replacingOccurrences(of: "key=", with: "")
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let hexCharacters = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
            if cleaned.unicodeScalars.allSatisfy({ hexCharacters.contains($0) }) {
                return cleaned
            }

            return string.replacingOccurrences(of: " ", with: "")
        }
    }
}
