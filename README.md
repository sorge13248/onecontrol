# OneControl 🎮

**OneControl** is a modular, ultra-low-latency platform for remote keyboard and mouse control over the local network (LAN).

- **Host (PC)**: Compact, high-performance daemon written in **Rust**, which emulates HID devices at kernel level via `/dev/uinput` (natively compatible with **Linux Wayland** and **X11**, architected for easy extension to Windows and macOS).
- **Client (Smartphone)**: Mobile application built with **Flutter** (ready for Android, architected for iOS) featuring a multi-touch trackpad, software keyboard, and special modifier keys (`CTRL`, `SUPER`, `ALT`, `SHIFT`, `FN`, `TAB`, `ESC`, `STAMP`).

---

## Key Features

- 🚀 **Sub-Millisecond Latency**: TCP communication with `TCP_NODELAY` (binary WebSocket).
- 🖱️ **Advanced Multi-Touch Trackpad**:
  - 1-finger drag for smooth cursor movement with acceleration and configurable sensitivity (saved automatically per `ip-hostname` host).
  - 1-finger tap for Left Click.
  - 2-finger tap for Right Click.
  - 2-finger scroll (vertical and horizontal scroll wheel emulation).
  - Dedicated virtual physical buttons: Left Click, Middle Click (Wheel), and Right Click.
- ⌨️ **Keyboard & Modifier Keys**:
  - Type directly from smartphone keyboard with instant synchronization and multi-line support (up to 4 dynamically expanding lines and vertical scrolling).
  - Modifiers with active/sticky state: `CTRL`, `SUPER` (Windows / Cmd key), `ALT`, `SHIFT`.
  - Essential quick keys: `TAB`, `ESC`, `STAMP` (PrintScreen), `ENTER`, `BACKSPACE`, and arrow keys.
  - Expandable **`FN`** bar to access `F1`-`F12`, media controls (`Mute`, `Vol-`, `Vol+`, `Play/Pause`), and navigation keys (`Home`, `End`, `PgUp`, `PgDn`).
- 📡 **Zero-Config LAN Discovery**: Automatic PC discovery on the local network via UDP broadcast/beacon (with support for manual IP and port input).
- 🔒 **Secure Pairing (PIN Protection)**: Protection against unauthorized Wi-Fi access. On first connection, the PC displays a desktop notification with a temporary 6-digit PIN to confirm on the phone. The resulting token is securely stored for instant subsequent connections.
- 🌐 **Automatic Bilingual Support (EN / IT)**: Native auto-detection of English and Italian following OS standards on both Android (via `flutter_localizations` system locale) and Linux (POSIX `LC_ALL`, `LC_MESSAGES`, `LANG` for daemon notifications, server messages, and `./onecontrol` CLI).
- 🛡️ **Safety Key Release**: Upon client disconnect or app shutdown, any pressed keys or mouse buttons are immediately released at kernel level to avoid stuck keys.

---

## Project Structure

```
onecontrol/
├── onecontrol                  # Unified CLI script (executable)
├── onecontrol.sh               # Symlink for shell convenience
├── daemon/                     # Host daemon in Rust
│   ├── Cargo.toml
│   ├── src/                    # uinput kernel input, WebSocket, discovery, pairing PIN
│   ├── tests/                  # Protocol integration tests
│   └── onecontrol.service      # Systemd user service unit file
├── mobile/                     # Flutter mobile application
│   ├── pubspec.yaml
│   ├── android/                # Android configuration and manifest
│   ├── lib/                    # UI, trackpad, keyboard, network discovery
│   └── test/                   # Automated Flutter widget & unit tests
└── docs/                       # Comprehensive technical documentation
    ├── BUILD_LINUX.md          # Manual Linux build and run guide
    ├── BUILD_ANDROID.md        # Manual Flutter build and APK packaging guide
    ├── ARCHITECTURE.md         # WebSocket protocol specifications and flow diagrams
    ├── FIREWALL.md             # Firewall configuration with firewall-cmd or UFW
    └── OBTAINIUM.md            # Obtainium Android setup, auto-updates & keystore signing
```

---

## Unified Management via CLI (`./onecontrol`)

All project tasks (diagnostics, build, install, systemd service management, testing, and APK deployment) are handled through the executable script **`./onecontrol`** (or `./onecontrol.sh`).

> [!TIP]
> Run `./onecontrol help` at any time for an interactive overview of all supported commands.

### 1. System Diagnostics and Setup

Before building or starting the service, you can verify your environment (Rust, Flutter, Android SDK, `/dev/uinput` kernel permissions, and firewall):

```bash
# Complete prerequisite diagnostic check
./onecontrol doctor

# Automatically configure virtual mouse and keyboard permissions (/dev/uinput)
./onecontrol setup uinput

# Automatically open ports 53842 TCP and UDP in firewall (firewalld or UFW)
./onecontrol setup firewall
```

---

### 2. Compilation (Build)

The script supports building both the host daemon (Rust) and mobile app (Flutter Android) in release or debug mode:

```bash
# Build Rust Host Daemon in production mode (optimized release)
./onecontrol build rust production

# Build Rust Host Daemon in debug mode
./onecontrol build rust debug

# Build Android App (Flutter) universal release APK
./onecontrol build flutter android production

# Build Android App in debug mode
./onecontrol build flutter android debug

# Build Android App with split-per-ABI APKs (ARM64, ARMv7, x86_64)
./onecontrol build flutter android split

# Build both projects (Rust + Flutter)
./onecontrol build all production
```

---

### 3. Host Service Installation & Update (Systemd)

The `install` command builds the daemon in release mode, copies the binary into `~/.local/bin`, installs the user systemd unit, and immediately starts or restarts the service:

```bash
./onecontrol install
```

> [!NOTE]
> **Hot Update Support**: The `install` command handles updates seamlessly. Replacing the binary occurs atomically, preventing the `Text file busy` (ETXTBSY) error even when the daemon is currently running, reloading systemd and restarting the process without service interruption.

To completely uninstall the service and remove the binary:
```bash
./onecontrol uninstall
```

---

### 4. Service Management & Monitoring

Once installed, you can manage the background daemon using dedicated commands:

```bash
# Show service status, active process, port 53842, and paired clients
./onecontrol status

# View real-time logs
./onecontrol logs -f

# View the last 100 log lines
./onecontrol logs -n 100

# Restart the service
./onecontrol restart

# Stop or start the service
./onecontrol stop
./onecontrol start
```

---

### 5. Local Development and Testing

If you want to run the daemon or app directly in the foreground without systemd:

```bash
# Run Rust daemon in foreground with verbose logging (debug or production)
./onecontrol run rust debug

# Launch mobile app on connected smartphone or emulator
./onecontrol run flutter android

# Run automated test suites
./onecontrol test rust        # Rust daemon unit tests
./onecontrol test flutter     # Flutter app unit tests
./onecontrol test all         # Both test suites
```

---

### 6. Smartphone Deployment (ADB)

With your smartphone connected via USB cable and **USB Debugging** enabled:

```bash
# List connected devices detected by ADB and Flutter
./onecontrol devices

# Build (if necessary) and install the release APK directly to the phone
./onecontrol install-apk release
```

---

### 7. Clean Build Cache

```bash
# Clean target/ and build/ directories
./onecontrol clean rust
./onecontrol clean flutter
./onecontrol clean all
```

---

## First Use & Pairing

1. Ensure smartphone and PC are connected to the **same Wi-Fi / LAN**.
2. Start the PC daemon (`./onecontrol install` or `./onecontrol start`).
3. Launch the OneControl app on your phone: your PC will appear automatically (*"Searching for PCs on local network..."*).
4. Tap **Connect**:
   - A desktop notification with a **6-digit PIN** will pop up on the PC (also visible in `./onecontrol logs`).
   - Enter the PIN in the app and tap **Confirm PIN**.
5. The remote control screen opens:
   - Move the cursor by dragging on the touchpad area.
   - Use physical virtual buttons or multi-touch taps (1-finger left click, 2-finger right click / scroll).
   - Use modifier keys `CTRL`, `ALT`, `SUPER`, `SHIFT` and the `FN` button for extra keys (`F1`-`F12`, volume controls, navigation).
   - Type in the bottom input bar to send live keystrokes.

---

## Detailed Documentation

For manual low-level setup steps or in-depth protocol architecture details:

- [docs/BUILD_LINUX.md](docs/BUILD_LINUX.md) - Manual compilation and execution with `cargo` and `systemctl`.
- [docs/BUILD_ANDROID.md](docs/BUILD_ANDROID.md) - Manual Flutter compilation, Android SDK configuration, and APK transfer.
- [docs/FIREWALL.md](docs/FIREWALL.md) - Manual firewall rules with `firewall-cmd`, UFW, and LAN subnet filtering.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - WebSocket frame format, JSON payloads, and `/dev/uinput` pipeline.
