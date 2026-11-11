# Guide: Building and Running on Linux (Host Daemon)

This step-by-step guide explains how to set up the environment, build, run, and configure the **OneControl** PC host daemon as an auto-starting system service on Linux (EndeavourOS, Arch, Ubuntu, Fedora, Debian, etc.).

---

## 1. Prerequisites

### 1.1 Rust Toolchain
Verify that `rustc` and `cargo` are installed on your system:
```bash
rustc --version
cargo --version
```
If not installed, install them using your package manager (e.g. `sudo pacman -S rust cargo` on Arch/EndeavourOS) or via [rustup](https://rustup.rs/):
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### 1.2 Permissions on `/dev/uinput`
The daemon creates virtual mouse and keyboard devices at kernel level via `/dev/uinput`.

Check current permissions:
```bash
ls -l /dev/uinput
getfacl /dev/uinput
```

If your user lacks read/write permissions, enable them in one of the following ways:

#### Option A: Udev Rule (Recommended & persistent across reboots)
Create `/etc/udev/rules.d/99-uinput.rules`:
```bash
echo 'KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/99-uinput.rules
```
Ensure your user belongs to the `input` group:
```bash
sudo usermod -aG input $USER
```
Reload udev rules:
```bash
sudo udevadm control --reload-rules && sudo udevadm trigger
```

#### Option B: Immediate ACL Permission
```bash
sudo setfacl -m u:$USER:rw /dev/uinput
```

---

## 2. Firewall Configuration

The daemon listens on port **53842** (TCP for WebSocket and UDP for LAN discovery).

If using **firewalld** (`firewall-cmd`):
```bash
sudo firewall-cmd --permanent --add-port=53842/tcp
sudo firewall-cmd --permanent --add-port=53842/udp
sudo firewall-cmd --reload
```

If using **UFW** (Ubuntu/Debian):
```bash
sudo ufw allow 53842/tcp
sudo ufw allow 53842/udp
```

---

## 3. Building

Navigate to the `daemon` directory:
```bash
cd daemon
```

### 3.1 Release Build (Optimized for maximum performance)
```bash
cargo build --release
```
The compiled binary will be located at:
📁 **`target/release/onecontrol-daemon`** (~4.6 MB, compact and free of external runtime dependencies).

### 3.2 Debug Build (For rapid development or testing)
```bash
cargo build
```
The binary will be located at: `target/debug/onecontrol-daemon`.

---

## 4. Manual Execution

Run the daemon directly in your terminal:
```bash
./target/release/onecontrol-daemon
```

### Verbose Logging
To inspect detailed packet traces and events:
```bash
RUST_LOG=debug ./target/release/onecontrol-daemon
```

---

## 5. Automatic Startup as User Service (Systemd)

> [!TIP]
> You can perform the entire compilation, installation, and service startup (including **hot-reloading updates**) with a single command from the repository root:
> ```bash
> ./onecontrol install
> ```
> To manage the service: `./onecontrol status`, `./onecontrol logs -f`, `./onecontrol restart`, `./onecontrol stop`.

If you prefer doing it manually:

### 5.1 Install the binary to user PATH
```bash
mkdir -p ~/.local/bin
cp target/release/onecontrol-daemon ~/.local/bin/
```

### 5.2 Install and enable the Systemd Unit
```bash
mkdir -p ~/.config/systemd/user
cp onecontrol.service ~/.config/systemd/user/

# Reload user systemd daemon
systemctl --user daemon-reload

# Enable automatic start and start immediately
systemctl --user enable --now onecontrol
```

### 5.3 Useful Service Management Commands
- **Check service status**:
  ```bash
  systemctl --user status onecontrol
  ```
- **View logs in real time**:
  ```bash
  journalctl --user -u onecontrol -f
  ```
- **Restart service**:
  ```bash
  systemctl --user restart onecontrol
  ```
- **Stop service**:
  ```bash
  systemctl --user stop onecontrol
  ```

---

## 6. Configuration & Authorized Devices

On first launch, the daemon automatically creates its configuration directory:
- **Configuration**: `~/.config/onecontrol/config.json`
  ```json
  {
    "port": 53842,
    "require_auth": true,
    "device_name": "Your-PC",
    "discovery_enabled": true
  }
  ```
- **Authorized clients with persistent tokens**: `~/.config/onecontrol/authorized_clients.json`
  *(Stores paired smartphone devices; to revoke access for all phones, delete this file or remove specific entries).*

---

## 7. Troubleshooting

1. **Error `Failed to initialize virtual input devices: No such file or directory` or `Permission denied`**:
   - Ensure the `uinput` kernel module is loaded:
     ```bash
     sudo modprobe uinput
     ```
   - Check permissions with `ls -l /dev/uinput`.

2. **No desktop notification displaying the pairing PIN**:
   - Ensure a notification daemon is active in your desktop environment (KDE Plasma, GNOME, Dunst, Mako).
   - In any case, the 6-digit PIN is **always printed to terminal logs / journalctl**.
