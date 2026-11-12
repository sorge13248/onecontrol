# Agent Guidelines & Rules: Mandatory Testing & Code Formatting

This project consists of two core components:
1. **Rust Host Daemon** (`daemon/`)
2. **Flutter Mobile Application** (`mobile/`)

---

## ⚠️ MANDATORY RULE: Always Format Code and Run Tests on Modified Code

Whenever you modify code in this repository, you **MUST ALWAYS** execute the relevant formatting, automated test suite(s), and static analysis checks before concluding your response or committing changes. This ensures the CI/CD pipeline never fails due to formatting or regression bugs.

### 1. When Modifying Rust Code (`daemon/` or scripts)
Before finishing any task affecting the Rust daemon:
- **Format code & verify formatting**:
  ```bash
  cargo fmt --manifest-path daemon/Cargo.toml --all
  cargo fmt --manifest-path daemon/Cargo.toml --all -- --check
  ```
- **Run linting checks**:
  ```bash
  cargo clippy --manifest-path daemon/Cargo.toml --all-targets -- -D warnings
  ```
- **Run test suite**:
  ```bash
  cargo test --manifest-path daemon/Cargo.toml
  # or
  ./onecontrol test rust
  ```
- **Requirement**: All unit tests, protocol tests, and clippy lints must pass cleanly with 0 errors and 0 warnings, with zero formatting diffs.

---

### 2. When Modifying Flutter Code (`mobile/`)
Before finishing any task affecting the Flutter app:
- **Format code & verify formatting (MANDATORY)**:
  ```bash
  cd mobile && dart format .
  cd mobile && dart format --output=none --set-exit-if-changed .
  ```
- **Run static analysis**:
  ```bash
  cd mobile && flutter analyze --no-fatal-infos
  ```
- **Run test suite**:
  ```bash
  cd mobile && flutter test --no-pub --coverage
  # or
  ./onecontrol test flutter
  ```
- **Toolchain & Environment Requirement**:
  - The development environment must have `flutter` and `dart` available in `$PATH` (e.g. via `~/.local/bin/` symlinks, `~/.profile`, or `~/.bashrc`).
  - In sandboxed agent environments where external toolchains reside outside the workspace root, execute commands using sandbox bypass (`BypassSandbox: true`) so tools can access system binaries and toolchains.
  - **NEVER** skip Flutter checks, formatting, or tests due to environment or sandbox restrictions.
- **Requirement**:
  - All widget and unit tests must pass.
  - Zero analysis issues or formatting violations.
  - **Timer & Resource Leaks**: Always verify that async timers (`Timer`, `Future.delayed`), sockets, and subscriptions are cancelled upon `dispose()`, `stopDiscovery()`, and test teardowns to prevent `!timersPending` assertion failures.

---

### 3. When Modifying Shared Protocols or Multi-Component Changes
When changing shared communication schemas, protocol messages, or both components:
- **Run both test suites and formatting checks**:
  ```bash
  ./onecontrol test all
  ```
  and ensure all formatting commands above (both Rust and Flutter) are executed and clean.

---

### 4. Non-Negotiable Verification
- Never assume changes work without running tests and formatting checks.
- If any test or formatting check fails, diagnose and resolve the issue before declaring the task completed.
