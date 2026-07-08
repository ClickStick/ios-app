//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import Observation

/// Drives the "Sent to <device>" toast's visibility: shows it, then hides it after a fixed delay.
/// Shared by text entry and snippets so both use identical show/dismiss timing.
@Observable
@MainActor
final class SentToastTimer {
    private(set) var isVisible = false
    private var dismissTask: Task<Void, Never>?

    func flash() {
        isVisible = true
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self else { return }
            self.isVisible = false
            self.dismissTask = nil
        }
    }

    func cancel() {
        dismissTask?.cancel()
    }

#if DEBUG
    func setVisibleForPreview(_ visible: Bool) {
        isVisible = visible
    }
#endif
}
