# ClickStick iOS Companion App

iOS companion app for [ClickStick](https://clickstick.io) -- a USB HID dongle that emulates a keyboard and mouse. Pair the dongle with your phone over Bluetooth, then type text or control the mouse from the app.

## Features

- **Device Management**: Scan for ClickStick dongles via Bluetooth LE, pair, and manage multiple devices.
- **Text Typing**: Send text to the connected computer through the dongle. Supports US QWERTY, German QWERTZ, and French AZERTY keyboard layouts with automatic locale detection.
- **Mouse Control**: Touchpad-style gestures for cursor movement, clicks (left/middle/right), and scrolling.
- **Share Extension**: Send text from any app (password managers, notes, browsers) to ClickStick without switching apps.
- **URL Scheme**: Automate typing via [x-callback-url](#url-scheme-integration) for integration with Shortcuts, password managers, and other apps.
- **Accessibility**: Full VoiceOver, Dynamic Type, and Voice Control support.

## How It Works

1. Plug the ClickStick dongle into a computer's USB port. The computer sees it as a standard USB keyboard and mouse.
2. Open the ClickStick app on your iPhone. The app discovers nearby dongles over Bluetooth LE.
3. Pair with the dongle (one-time setup with on-device key exchange).
4. Type text or control the mouse from the app. Commands are sent over BLE to the dongle, which replays them as USB HID events on the computer.

## Architecture

| Module | Description |
|--------|-------------|
| `ClickStick/` | Main iOS app target (SwiftUI, iOS 18+) |
| `ShareExtension/` | Share extension for sending text from other apps |
| `ClickStickKit/` | Local Swift package: BLE communication, device commands, crypto, session management |
| `DesignSystem/` | Local Swift package: shared UI styles, components, design tokens |
| `Tests/` | Unit tests (Swift Testing) |

The app follows a SwiftUI + `@Observable` ViewModel architecture. Device features (text entry, mouse control) are presented as tabs within the device detail view. BLE and protocol logic stays in `ClickStickKit`; the app layer handles UI and navigation.

## Premium Model

ClickStick uses a freemium model. The core value proposition is saving time: typing text character-by-character at human speed takes minutes, while instant bulk delivery takes seconds.

- **Free users**: Can type text at human speed (1 character/second). Fully functional, just slower.
- **Free quota**: 500 bytes of instant-speed typing granted on first launch for demo purposes.
- **One-time pack**: 1 KB of instant typing for $0.99 (consumable, no expiration).
- **Subscriptions**: Monthly plans with quota that resets each month:
  - Small (10 KB/month) -- $1.99/month
  - Large (50 KB/month) -- $4.99/month
  - Unlimited -- $9.99/month

Quota is checked per-send and only deducted after a successful send. Failed sends never consume quota. The paywall appears after a user exhausts their last free quota, at a natural moment rather than as a blocking gate.

Premium state is shared between the main app and the Share Extension via a shared `UserDefaults` suite.

## Build

Requires Xcode 16+ and iOS 18+ SDK.

```bash
xcodebuild -project ClickStick.xcodeproj -scheme ClickStick -sdk iphonesimulator build
```

## Test

```bash
xcodebuild -project ClickStick.xcodeproj -scheme ClickStick -sdk iphonesimulator test
```

---

# URL Scheme Integration

ClickStick supports [x-callback-url](http://x-callback-url.com/) for app integration.

## URL Format

```
clickstick://x-callback-url/type?text=<encoded>&layout=<us|de|fr>&x-source=<app>&x-success=<url>&x-error=<url>
```

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| text | Yes | Text to type (percent-encoded) |
| layout | No | us, de, or fr (default: auto) |
| device | No | Device name or UUID |
| x-source | No | Calling app name |
| x-success | No | URL on success |
| x-error | No | URL on error |
| x-cancel | No | URL on cancel |

## Encoding

Use URLComponents for automatic encoding:

```swift
var components = URLComponents(string: "clickstick://x-callback-url/type")!
components.queryItems = [
    URLQueryItem(name: "text", value: "P@ssw0rd!#"),
    URLQueryItem(name: "layout", value: "us"),
    URLQueryItem(name: "x-source", value: "MyApp")
]
UIApplication.shared.open(components.url!)
```

## Examples

```
clickstick://x-callback-url/type?text=Hello%20World
clickstick://x-callback-url/type?text=P%40ssw0rd%21&layout=de
```

## Error Codes

| Code | Description |
|------|-------------|
| invalid_url | Malformed URL |
| missing_text | No text parameter |
| no_device | No devices found |
| not_connected | Device not connected |
| typing_failed | Send failed |
| cancelled | User cancelled |

## Security

- Text is never persisted to disk
- User must confirm every deep link request
- Text is masked by default in the UI
- Device pairing uses on-device key exchange (keys stored in Keychain)
- No secrets, keys, or provisioning artifacts in the repository

---

## License

Copyright 2026 KeePassium Labs.
