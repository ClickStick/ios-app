# ClickStick iOS Companion App

iOS companion app for ClickStick – a USB HID dongle that emulates a keyboard and mouse.

## Features

- **Device Management**: Discover, pair, and manage ClickStick devices
- **Text Typing**: Multiple keyboard layouts (US QWERTY, DE QWERTZ, FR AZERTY)
- **Mouse Control**: Touchpad gestures, clicks, and scrolling
- **URL Scheme**: x-callback-url integration for other apps

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

- Text never persisted to disk
- User must confirm every request
- Text masked by default

---

Copyright 2026 KeePassium Labs.
