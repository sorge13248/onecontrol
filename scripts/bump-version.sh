#!/usr/bin/env bash
# ==============================================================================
# OneControl - Version Bumping Script
# ==============================================================================
# Sincronizza e incrementa la versione sia del daemon Rust che dell'app Flutter.
# Uso:
#   ./scripts/bump-version.sh patch
#   ./scripts/bump-version.sh minor
#   ./scripts/bump-version.sh major
#   ./scripts/bump-version.sh custom 1.2.0
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BUMP_TYPE="${1:-patch}"
CUSTOM_VER="${2:-}"

CARGO_TOML="$ROOT_DIR/daemon/Cargo.toml"
PUBSPEC_YAML="$ROOT_DIR/mobile/pubspec.yaml"

if [[ ! -f "$CARGO_TOML" ]]; then
    echo "Errore: $CARGO_TOML non trovato!" >&2
    exit 1
fi

if [[ ! -f "$PUBSPEC_YAML" ]]; then
    echo "Errore: $PUBSPEC_YAML non trovato!" >&2
    exit 1
fi

# 1. Estrazione versione corrente da Cargo.toml
CURRENT_VERSION=$(grep -m1 '^version =' "$CARGO_TOML" | sed -E 's/version = "(.*)"/\1/')
if [[ -z "$CURRENT_VERSION" ]]; then
    echo "Errore: Impossibile leggere la versione da $CARGO_TOML" >&2
    exit 1
fi

echo "Current Project Version: $CURRENT_VERSION"

# 2. Calcolo nuova versione SemVer
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case "$BUMP_TYPE" in
    patch)
        PATCH=$((PATCH + 1))
        NEW_VERSION="$MAJOR.$MINOR.$PATCH"
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        NEW_VERSION="$MAJOR.$MINOR.$PATCH"
        ;;
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        NEW_VERSION="$MAJOR.$MINOR.$PATCH"
        ;;
    custom)
        if [[ -z "$CUSTOM_VER" ]]; then
            echo "Errore: specificare la versione per l'opzione 'custom' (es. ./scripts/bump-version.sh custom 1.2.0)" >&2
            exit 1
        fi
        NEW_VERSION="${CUSTOM_VER#v}"
        ;;
    *)
        echo "Errore: tipo di bump sconosciuto '$BUMP_TYPE'. Validi: patch, minor, major, custom." >&2
        exit 1
        ;;
esac

echo "Target New Version: $NEW_VERSION"

# 3. Estrazione e incremento del build number (versionCode) da pubspec.yaml
CURRENT_PUBSPEC_LINE=$(grep '^version:' "$PUBSPEC_YAML")
CURRENT_BUILD_NUM=$(echo "$CURRENT_PUBSPEC_LINE" | sed -nE 's/.*[+]([0-9]+).*/\1/p')

if [[ -z "$CURRENT_BUILD_NUM" ]]; then
    NEW_BUILD_NUM=1
else
    NEW_BUILD_NUM=$((CURRENT_BUILD_NUM + 1))
fi

echo "New Build Number (versionCode): $NEW_BUILD_NUM"

# 4. Aggiornamento daemon/Cargo.toml
# Sostituisce solo la versione all'interno del blocco [package]
sed -i -E "0,/^version = \".*\"/s//version = \"$NEW_VERSION\"/" "$CARGO_TOML"

# Sincronizza daemon/Cargo.lock se cargo è installato
if command -v cargo &>/dev/null; then
    (cd "$ROOT_DIR/daemon" && cargo check --quiet)
fi

# 5. Aggiornamento mobile/pubspec.yaml
sed -i -E "s/^version: .*/version: $NEW_VERSION+$NEW_BUILD_NUM/" "$PUBSPEC_YAML"

echo "✔ Updated $CARGO_TOML -> $NEW_VERSION"
echo "✔ Updated $PUBSPEC_YAML -> $NEW_VERSION+$NEW_BUILD_NUM"

# 6. Esporta variabili se eseguito in ambiente GitHub Actions
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "version=$NEW_VERSION" >> "$GITHUB_OUTPUT"
    echo "tag=v$NEW_VERSION" >> "$GITHUB_OUTPUT"
    echo "build_number=$NEW_BUILD_NUM" >> "$GITHUB_OUTPUT"
fi
