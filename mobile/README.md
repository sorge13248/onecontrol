# OneControl Mobile (Flutter) 📱

The official mobile client for **OneControl**, providing low-latency remote keyboard and mouse input over the local network (LAN).

---

## Features

- **Multi-Touch Trackpad**:
  - 1-finger drag for smooth mouse cursor movement with configurable acceleration and sensitivity (persisted per host).
  - 1-finger tap for left click.
  - 2-finger tap for right click.
  - 2-finger scroll for vertical scrolling.
  - Dedicated virtual physical buttons: Left Click, Middle Click (Wheel), and Right Click.
- **Keyboard Input**:
  - Live keyboard synchronization with multi-line text input and instant typing.
  - Modifier toggles with sticky states: `CTRL`, `SUPER` (Windows/Cmd key), `ALT`, `SHIFT`.
  - Essential quick keys: `TAB`, `ESC`, `STAMP` (PrintScreen), `ENTER`, `BACKSPACE`, and arrow keys (`LEFT`, `UP`, `DOWN`, `RIGHT`).
  - Expandable **`FN`** bar providing `F1`-`F12`, media controls (`Mute`, `Vol-`, `Vol+`, `Play/Pause`), and navigation keys (`Home`, `End`, `PgUp`, `PgDn`).
- **Zero-Config LAN Discovery**:
  - Automatic host detection via UDP broadcasts (`53842/udp`).
  - Manual connection option with custom IP and port.
- **PIN-Based Secure Pairing**:
  - Prompts for a one-time 6-digit PIN displayed on the PC.
  - Saves an authentication token securely for instant reconnects.

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/) (>= 3.13.7)
- Android SDK (for Android build) / Xcode (for iOS build)

### Running in Development

```bash
cd mobile
flutter pub get
flutter run
```

### Running Tests

```bash
flutter test
```

### Building APK

```bash
# Universal release APK
flutter build apk --release

# Per-ABI split APKs
flutter build apk --split-per-abi
```
