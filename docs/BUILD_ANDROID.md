# Guide: Building and Running on Android (Mobile App)

This guide explains how to set up the Flutter environment, build the **OneControl** Android application, generate APK packages, and install them on your smartphone.

---

## 1. Prerequisites

### 1.1 Flutter SDK
Verify that the `flutter` command is available in your terminal:
```bash
flutter --version
```
> [!NOTE]
> If Flutter is not in your `$PATH`, add it to your `~/.bashrc` or `~/.profile`:
> ```bash
> export PATH="/path/to/flutter/bin:$PATH"
> ```

### 1.2 Android SDK & Java
Check overall environment status with:
```bash
flutter doctor
```
Ensure that the Android toolchain is marked as ready. If Android licenses need to be accepted:
```bash
flutter doctor --android-licenses
```

---

## 2. Project Setup

Navigate to the `mobile` directory:
```bash
cd mobile
```

Fetch project dependencies:
```bash
flutter pub get
```

Run automated unit tests:
```bash
flutter test
```

---

## 3. Direct Execution on Device (Development Mode)

If your Android smartphone is connected via USB cable with **USB Debugging enabled**:

1. Check that the device is detected:
   ```bash
   flutter devices
   ```
2. Start the app in real-time (with Hot Reload support by pressing `r` in the terminal):
   ```bash
   flutter run
   ```

---

## 4. Generating APK Packages

To install the app permanently without keeping the phone connected to your PC:

### 4.1 Universal Release APK (Recommended)
Generates a single `.apk` package compatible with all Android architectures (ARM64, ARMv7, x86_64):
```bash
flutter build apk --release
```
The resulting APK will be located at:
📁 **`build/app/outputs/flutter-apk/app-release.apk`**

---

### 4.2 Split-Per-ABI Release APK (Smaller Download Size)
Split mode generates architecture-specific APKs. For modern smartphones (ARM64):
```bash
flutter build apk --split-per-abi
```
The individual APKs will be located at:
📁 **`build/app/outputs/flutter-apk/`**
- `app-arm64-v8a-release.apk` *(Recommended for 99% of modern smartphones: ~15-20 MB)*
- `app-armeabi-v7a-release.apk` *(For older 32-bit smartphones)*
- `app-x86_64-release.apk` *(For PC emulators)*

---

### 4.3 Debug APK (Fast Build for Testing)
To quickly produce a test build without release optimizations:
```bash
flutter build apk --debug
```
The file will be located at:
📁 **`build/app/outputs/flutter-apk/app-debug.apk`**

---

## 5. Installing the APK on Smartphone

You can install the generated APK on your phone in two ways:

### Method A: Via USB Cable & ADB (Instant)
If your smartphone is connected via USB with debugging enabled:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
*(Or `app-arm64-v8a-release.apk`)*

### Method B: File Transfer
1. Send the `.apk` file to your smartphone using:
   - **KDE Connect** (if using KDE Plasma)
   - USB cable (MTP file transfer)
   - Telegram (sending to "Saved Messages")
   - Google Drive / Nextcloud
2. On your phone, open the **Files** app (or tap the received file in your chat app).
3. Tap the `.apk` file and select **Install**.
   *(If prompted by Android, grant permission to "Install from unknown sources" for the file manager app).*

---

## 6. Troubleshooting

1. **Phone does not discover the PC during scanning**:
   - Ensure the smartphone and PC are connected to the **same Wi-Fi network**.
   - Check that "AP Isolation" / "Client Isolation" is disabled on your Wi-Fi router (which prevents wireless devices from talking to each other).
   - Ensure UDP port `53842` is open in the PC firewall.
   - **Quick solution**: Tap the link icon in the top-right corner of the app ("Add PC Manually") and enter your PC's local IP address (e.g. `192.168.1.100`).

2. **PC rejects connection or does not accept PIN**:
   - Make sure `onecontrol-daemon` is running on the PC.
   - Check the PIN shown in the desktop notification or PC terminal logs, and enter it before it expires.
