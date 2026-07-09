//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import Foundation

// Snippet execution lives here (not in the shared DeviceModel.swift) so it isn't pulled into the
// ShareExtension target, which shares DeviceModel but not the snippets feature.
extension DeviceModel: SnippetRunningDevice {
    func sendSpecialKey(_ key: CSSpecialKey) async throws {
        guard isConnected else { throw CSError.connectionFailed(error: nil) }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard isConnected else {
                continuation.resume(throwing: CSError.connectionFailed(error: nil))
                return
            }
            device.sendSpecialKey(key) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
