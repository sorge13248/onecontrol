---
description: Mandatory testing rules for Rust daemon and Flutter mobile client
trigger: always_on
---

# Mandatory Testing Rules

Whenever code in this repository is modified:
1. **Rust Daemon (`daemon/`)**:
   - Run tests: `cargo test --manifest-path daemon/Cargo.toml` or `./onecontrol test rust`
   - Run linting: `cargo clippy --manifest-path daemon/Cargo.toml --all-targets -- -D warnings`
   - Run formatting: `cargo fmt --manifest-path daemon/Cargo.toml --all -- --check`
2. **Flutter App (`mobile/`)**:
   - Run tests: `cd mobile && /mnt/hdd3-linux-data/flutter/bin/flutter test --no-pub --coverage` or `./onecontrol test flutter`
   - Run analysis: `cd mobile && /mnt/hdd3-linux-data/flutter/bin/flutter analyze --no-fatal-infos`
   - Run formatting: `cd mobile && /mnt/hdd3-linux-data/flutter/bin/dart format --output=none --set-exit-if-changed .`
   - Check timer leaks: Ensure all `Timer` instances, `Future.delayed`, sockets, and streams are cancelled upon disposal.
3. **Both / Shared Protocols**:
   - Run `./onecontrol test all`
4. **Never complete a task or push code with failing tests.**
