# ClickStick iOS Companion App

iOS companion app for [ClickStick](https://clickstick.io) -- a USB HID dongle that emulates a keyboard and mouse. Pair the dongle with your phone over Bluetooth, then type text or control the mouse from the app.

## Features

- **Device Management**: Scan for ClickStick dongles via Bluetooth LE, pair with QR/manual key setup, and manage multiple devices.
- **Text Typing**: Send text to the connected computer through the dongle. Supports US QWERTY, German QWERTZ, and French AZERTY keyboard layouts with automatic locale detection.
- **Mouse Control**: Touchpad-style gestures for cursor movement, clicks (left/right), and scrolling.
- **Onboarding and Demo Mode**: First-run onboarding can start hardware pairing or enable demo devices for exploring without hardware.
- **Share Extension**: Placeholder extension target retained for future redesign.
- **Settings**: Auto-select the last used device and keep the screen awake while connected.
- **Accessibility**: VoiceOver, Dynamic Type, and Voice Control-friendly UI patterns.

## How It Works

1. Plug the ClickStick dongle into a computer's USB port. The computer sees it as a standard USB keyboard and mouse.
2. Open the ClickStick app on your iPhone. The app discovers nearby dongles over Bluetooth LE.
3. Pair with the dongle (one-time setup with on-device key exchange).
4. Type text or control the mouse from the app. Commands are sent over BLE to the dongle, which replays them as USB HID events on the computer.

## Architecture

| Module | Description |
|--------|-------------|
| `ClickStick/` | Main SwiftUI app target (iOS 17+, Mac Catalyst supported) |
| `ShareExtension/` | iOS share extension for sending text from other apps |
| `ClickStickKit/` | Local Swift package: BLE communication, device commands, keyboard mapping, crypto, session management, keychain-backed device settings |
| `Tests/` | Unit tests (Swift Testing) |

The app follows a SwiftUI + `@Observable` ViewModel architecture. Device features (text entry, snippets placeholder, touchpad) are presented as tabs within the device detail view. BLE and protocol logic stays in `ClickStickKit`; the app layer handles UI, onboarding, settings, navigation, and share-extension placeholder flow.

## Demo Mode

ClickStick can be explored without hardware by enabling demo mode during onboarding. Demo mode adds mock devices through `CSManager.isDemoMode`; these devices behave like known devices and use a demo authentication key. This keeps the UI flows testable without requiring a physical dongle.

## Build

Requires Xcode with Swift 6.2 support and the iOS 17+ SDK. CI currently uses Xcode 26.2.

```bash
set -o pipefail
xcodebuild -project ClickStick.xcodeproj -scheme ClickStick -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | xcsift
```

## Test

```bash
set -o pipefail
xcodebuild -project ClickStick.xcodeproj -scheme ClickStick -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | xcsift
```

Mac Catalyst validation:

```bash
set -o pipefail
xcodebuild \
  -project ClickStick.xcodeproj \
  -scheme ClickStick \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  test 2>&1 | xcsift
```

---

## Security

- Text is never persisted to disk
- Device pairing uses on-device key exchange (keys stored in Keychain)
- App and share extension use shared app/keychain groups for paired-device access
- No secrets, keys, or provisioning artifacts in the repository

---

## License

Copyright 2026 KeePassium Labs.
