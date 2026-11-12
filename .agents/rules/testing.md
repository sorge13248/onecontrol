---
description: Mandatory testing and formatting rules for Rust daemon and Flutter mobile client
trigger: always_on
---

# Mandatory Testing & Formatting Rules

Whenever code in this repository is modified:
1. **Rust Daemon (`daemon/`)**:
   - Run format: `cargo fmt --manifest-path daemon/Cargo.toml --all`
   - Check format: `cargo fmt --manifest-path daemon/Cargo.toml --all -- --check`
   - Run linting: `cargo clippy --manifest-path daemon/Cargo.toml --all-targets -- -D warnings`
   - Run tests: `cargo test --manifest-path daemon/Cargo.toml` or `./onecontrol test rust`
2. **Flutter App (`mobile/`)**:
   - Run format: `cd mobile && dart format .`
   - Check format: `cd mobile && dart format --output=none --set-exit-if-changed .`
   - Run analysis: `cd mobile && flutter analyze --no-fatal-infos`
   - Run tests: `cd mobile && flutter test --no-pub --coverage` or `./onecontrol test flutter`
   - **Environment / Sandbox Note**: `flutter` and `dart` must be available in `$PATH`. In sandboxed agent environments where toolchains reside outside the workspace root, run with bypass sandbox so system toolchains are accessible. Never skip Flutter checks due to sandbox access restrictions.
   - Check timer leaks: Ensure all `Timer` instances, `Future.delayed`, sockets, and streams are cancelled upon disposal.
3. **Both / Shared Protocols**:
   - Run `./onecontrol test all` and run both formatting checks.
4. **Never complete a task or push code with failing tests or unformatted code.**
