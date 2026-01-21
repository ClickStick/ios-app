//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>
//  All rights reserved.

import CoreBluetooth
import Foundation

public enum CSError: LocalizedError {
    /// Bluetooth is not supported, disable, or forbidden
    case bluetoothUnavailable(reason: BluetoothUnavailableReason)

    /// Connection to peripheral failed
    case connectionFailed(error: Error?)

    /// Service discovery or value update error
    case peripheralError(Error)

    /// Error while preparing/sending a command
    case commandError(CommandError)

    public var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is not available."
        case .connectionFailed(error: let error):
            let description = getConnectionErrorDescription(error)
            return description
        case .peripheralError(let error):
            return "Peripheral error: \(error)"
        case .commandError(let error):
            return "Command error: \(error)"
        }
    }
    public var failureReason: String? {
        switch self {
        case .bluetoothUnavailable(let reason):
            return reason.description
        case .peripheralError(let error):
            return (error as NSError).localizedFailureReason
        default:
            return nil
        }
    }

    private func getConnectionErrorDescription(_ error: Error?) -> String {
        guard let error else {
            return "Unknown connection error"
        }
        let nsError = error as NSError
        switch nsError {
        case CBError.peerRemovedPairingInformation:
            return "ClickStick is no longer paired to this device. Open Bluetooth settings, select 'Forget Device' and try again."
        default:
            return nsError.localizedDescription
        }
    }
}

extension CSError {
    public enum BluetoothUnavailableReason: CustomStringConvertible {
        case unsupported
        case poweredOff
        case permissionDenied
        case unknown

        public var description: String {
            switch self {
            case .unsupported:
                return "Bluetooth is not supported on this device."
            case .poweredOff:
                return "Bluetooth module is turned off."
            case .permissionDenied:
                return "Bluetooth permission not granted."
            case .unknown:
                return "Reason unknown."
            }
        }
    }

    public enum CommandError: LocalizedError {
        /// Command execution was not confirmed in time.
        case timeout
        /// Failure to encrypt/decrypt something.
        case cryptographyError(_ cause: Error)
        /// Internal inconsistency: missing session key, unexpected device state…
        case internalError(_ description: String)

        public var errorDescription: String? {
            switch self {
            case .timeout:
                "Command execution timed out."
            case .cryptographyError(let cause):
                "Cryptography error: \(cause)"
            case .internalError(let description):
                "Internal error: \(description)"
            }
        }
    }
}

