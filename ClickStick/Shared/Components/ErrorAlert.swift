//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import ClickStickKit
import SwiftUI

struct AlertError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let dismissAction: (() -> Void)?

    init(
        title: String = String(localized: "Error", comment: "Alert title"),
        message: String,
        dismissAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.dismissAction = dismissAction
    }

    init(
        title: String = String(localized: "Error", comment: "Alert title"),
        error: Error,
        dismissAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = error.localizedDescription
        self.dismissAction = dismissAction
    }

    init(error: CSError, dismissAction: (() -> Void)? = nil) {
        let nsError = error as NSError
        self.title = nsError.localizedDescription
        self.message = nsError.localizedFailureReason ?? String(localized: "An unknown error occurred.", comment: "Default error message")
        self.dismissAction = dismissAction
    }
}

extension View {
    func errorAlert(_ error: Binding<AlertError?>) -> some View {
        alert(
            error.wrappedValue?.title ?? String(localized: "Error", comment: "Alert title"),
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil } }
            ),
            presenting: error.wrappedValue
        ) { alertError in
            Button(String(localized: "OK", comment: "Button title")) {
                alertError.dismissAction?()
            }
        } message: { alertError in
            Text(alertError.message)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var error: AlertError? = AlertError(
            title: "Connection Failed",
            message: "Unable to connect to the device. Please try again."
        )

        var body: some View {
            Button("Show Error") {
                error = AlertError(
                    title: "Connection Failed",
                    message: "Unable to connect to the device. Please try again."
                )
            }
            .errorAlert($error)
        }
    }

    return PreviewWrapper()
}
