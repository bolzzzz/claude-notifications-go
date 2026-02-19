#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$PROJECT_DIR")"

BINARY_NAME="terminal-notifier-modern"
APP_BUNDLE_NAME="ClaudeNotifier"
BUILD_DIR="${PROJECT_DIR}/.build"
APP_BUNDLE="${PROJECT_DIR}/${APP_BUNDLE_NAME}.app"
ICON_SRC="${REPO_ROOT}/claude_icon.png"
ENTITLEMENTS="${PROJECT_DIR}/entitlements.plist"

# Parse arguments
CI_MODE=false
SKIP_NOTARIZE=false
for arg in "$@"; do
    case "$arg" in
        --ci) CI_MODE=true ;;
        --skip-notarize) SKIP_NOTARIZE=true ;;
    esac
done

echo "Building ${BINARY_NAME}..."
if [ "$CI_MODE" = true ]; then
    echo "  Mode: CI (Developer ID Application + notarization)"
else
    echo "  Mode: Local"
fi

# Build universal binary (arm64 + x86_64) for both Apple Silicon and Intel Macs
cd "$PROJECT_DIR"

echo "Building for arm64..."
swift build -c release --arch arm64 2>&1
ARM64_BINARY="${BUILD_DIR}/release/${BINARY_NAME}"
if [ ! -f "$ARM64_BINARY" ]; then
    echo "Error: arm64 binary not found at ${ARM64_BINARY}"
    exit 1
fi

echo "Building for x86_64..."
swift build -c release --arch x86_64 2>&1
X86_BINARY="${BUILD_DIR}/release/${BINARY_NAME}"
if [ ! -f "$X86_BINARY" ]; then
    echo "Error: x86_64 binary not found at ${X86_BINARY}"
    exit 1
fi

# Merge into universal binary
BINARY="${BUILD_DIR}/${BINARY_NAME}-universal"
lipo -create \
    "${BUILD_DIR}/arm64-apple-macosx/release/${BINARY_NAME}" \
    "${BUILD_DIR}/x86_64-apple-macosx/release/${BINARY_NAME}" \
    -output "$BINARY"

echo "Universal binary built successfully: ${BINARY}"
file "$BINARY"

# Assemble .app bundle
echo "Assembling .app bundle..."

rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "$BINARY" "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}"

# Copy Info.plist
cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/"

# Generate app icon if source PNG exists
if [ -f "$ICON_SRC" ]; then
    echo "Generating app icon..."
    ICONSET_DIR=$(mktemp -d)/AppIcon.iconset
    mkdir -p "$ICONSET_DIR"

    sips -z 16 16 "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16.png" 2>/dev/null || true
    sips -z 32 32 "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16@2x.png" 2>/dev/null || true
    sips -z 32 32 "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32.png" 2>/dev/null || true
    sips -z 64 64 "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32@2x.png" 2>/dev/null || true
    sips -z 128 128 "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128.png" 2>/dev/null || true
    sips -z 256 256 "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128@2x.png" 2>/dev/null || true
    sips -z 256 256 "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256.png" 2>/dev/null || true
    sips -z 512 512 "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256@2x.png" 2>/dev/null || true
    sips -z 512 512 "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512.png" 2>/dev/null || true

    ICNS_PATH="${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    if iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH" 2>/dev/null; then
        echo "App icon generated successfully"
    else
        echo "Warning: could not generate app icon (iconutil failed)"
    fi

    rm -rf "$(dirname "$ICONSET_DIR")"
else
    echo "Warning: icon source not found at ${ICON_SRC}, skipping icon generation"
fi

# Code signing
CODESIGN_FLAGS=(--force --timestamp)

if [ "$CI_MODE" = true ]; then
    # CI: use Developer ID Application for distribution
    SIGNING_IDENTITY="Developer ID Application"
    CODESIGN_FLAGS+=(--options runtime)
    if [ -f "$ENTITLEMENTS" ]; then
        CODESIGN_FLAGS+=(--entitlements "$ENTITLEMENTS")
    fi
    echo "Code signing with: ${SIGNING_IDENTITY} (hardened runtime)"
    codesign "${CODESIGN_FLAGS[@]}" --sign "${SIGNING_IDENTITY}" "${APP_BUNDLE}"
    echo "Code signing successful"

    # Verify signature
    codesign --verify --verbose "${APP_BUNDLE}"
    echo "Signature verified"
else
    # Local: try Developer ID Application first, then Apple Development, then ad-hoc
    SIGNING_IDENTITY=""

    # Try Developer ID Application
    DEV_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/' || true)
    if [ -n "$DEV_ID" ]; then
        SIGNING_IDENTITY="$DEV_ID"
        CODESIGN_FLAGS+=(--options runtime)
        if [ -f "$ENTITLEMENTS" ]; then
            CODESIGN_FLAGS+=(--entitlements "$ENTITLEMENTS")
        fi
        echo "Code signing with: ${SIGNING_IDENTITY} (hardened runtime)"
    fi

    # Try Apple Development
    if [ -z "$SIGNING_IDENTITY" ]; then
        APPLE_DEV=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)"/\1/' || true)
        if [ -n "$APPLE_DEV" ]; then
            SIGNING_IDENTITY="$APPLE_DEV"
            echo "Code signing with: ${SIGNING_IDENTITY}"
        fi
    fi

    if [ -n "$SIGNING_IDENTITY" ]; then
        codesign "${CODESIGN_FLAGS[@]}" --sign "${SIGNING_IDENTITY}" "${APP_BUNDLE}" 2>/dev/null || {
            echo "Developer signing failed, falling back to ad-hoc..."
            codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || {
                echo "Warning: code signing failed (notifications may require manual permission)"
            }
        }
    else
        echo "Code signing .app bundle (ad-hoc)..."
        codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || {
            echo "Warning: code signing failed (notifications may require manual permission)"
        }
    fi
fi

# Notarization (CI mode only, unless --skip-notarize)
if [ "$CI_MODE" = true ] && [ "$SKIP_NOTARIZE" != true ]; then
    echo ""
    echo "Notarizing ${APP_BUNDLE_NAME}.app..."

    # Zip for notarization submission
    NOTARIZE_ZIP="${BUILD_DIR}/${APP_BUNDLE_NAME}-notarize.zip"
    ditto -c -k --keepParent "${APP_BUNDLE}" "${NOTARIZE_ZIP}"

    # Submit for notarization
    # Requires APPLE_ID, APPLE_PASSWORD (app-specific), APPLE_TEAM_ID env vars
    if [ -z "$APPLE_ID" ] || [ -z "$APPLE_PASSWORD" ] || [ -z "$APPLE_TEAM_ID" ]; then
        echo "Error: APPLE_ID, APPLE_PASSWORD, and APPLE_TEAM_ID must be set for notarization"
        exit 1
    fi

    xcrun notarytool submit "${NOTARIZE_ZIP}" \
        --apple-id "${APPLE_ID}" \
        --password "${APPLE_PASSWORD}" \
        --team-id "${APPLE_TEAM_ID}" \
        --wait

    rm -f "${NOTARIZE_ZIP}"

    # Staple the notarization ticket
    echo "Stapling notarization ticket..."
    xcrun stapler staple "${APP_BUNDLE}"

    echo "Notarization complete!"

    # Final verification
    echo "Verifying notarized bundle..."
    codesign --verify --verbose "${APP_BUNDLE}"
    spctl --assess --type execute --verbose "${APP_BUNDLE}" || true
fi

# Register with Launch Services (makes macOS aware of the app and its icon)
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -f "$APP_BUNDLE" 2>/dev/null || true
    echo "Registered with Launch Services"
fi

echo ""
echo "Build complete!"
echo "  Binary: ${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}"
echo "  Bundle: ${APP_BUNDLE}"
echo ""
if [ "$CI_MODE" = true ]; then
    echo "  Signed: Developer ID Application (hardened runtime)"
    if [ "$SKIP_NOTARIZE" != true ]; then
        echo "  Notarized: yes"
    fi
fi
echo ""
echo "To install into plugin bin/:"
echo "  cp -R ${APP_BUNDLE} ${REPO_ROOT}/bin/"
