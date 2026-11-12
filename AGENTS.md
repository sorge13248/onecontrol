# Agent Guidelines & Rules: Mandatory Testing

This project consists of two core components:
1. **Rust Host Daemon** (`daemon/`)
2. **Flutter Mobile Application** (`mobile/`)

---

## ⚠️ MANDATORY RULE: Always Run Tests on Modified Code

Whenever you modify code in this repository, you **MUST ALWAYS** execute the relevant automated test suite(s) and static analysis checks before concluding your response or committing changes.

### 1. When Modifying Rust Code (`daemon/` or scripts)
Before finishing any task affecting the Rust daemon:
- **Run test suite**:
  ```bash
  cargo test --manifest-path daemon/Cargo.toml
  # or
  ./onecontrol test rust
  ```
- **Run linting & formatting checks**:
  ```bash
  cargo clippy --manifest-path daemon/Cargo.toml --all-targets -- -D warnings
  cargo fmt --manifest-path daemon/Cargo.toml --all -- --check
  ```
- **Requirement**: All unit tests, protocol tests, and clippy lints must pass cleanly with 0 errors and 0 warnings.

---

### 2. When Modifying Flutter Code (`mobile/`)
Before finishing any task affecting the Flutter app:
- **Run test suite**:
  ```bash
  cd mobile && /mnt/hdd3-linux-data/flutter/bin/flutter test --no-pub --coverage
  # or
  ./onecontrol test flutter
  ```
- **Run static analysis & formatting checks**:
  ```bash
  cd mobile && /mnt/hdd3-linux-data/flutter/bin/flutter analyze --no-fatal-infos
  cd mobile && /mnt/hdd3-linux-data/flutter/bin/dart format --output=none --set-exit-if-changed .
  ```
- **Requirement**:
  - All widget and unit tests must pass.
  - Zero analysis issues or formatting violations.
  - **Timer & Resource Leaks**: Always verify that async timers (`Timer`, `Future.delayed`), sockets, and subscriptions are cancelled upon `dispose()`, `stopDiscovery()`, and test teardowns to prevent `!timersPending` assertion failures.

---

### 3. When Modifying Shared Protocols or Multi-Component Changes
When changing shared communication schemas, protocol messages, or both components:
- **Run both test suites**:
  ```bash
  ./onecontrol test all
  ```
  or run both the Rust and Flutter commands specified above.

---

### 4. Non-Negotiable Verification
- Never assume changes work without running tests.
- If any test fails, diagnose and resolve the issue before declaring the task completed.
