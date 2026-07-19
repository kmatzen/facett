#!/bin/bash
# Run FacettTests without xcodebuild.
#
# Why this exists: `xcodebuild test` reports zero eligible destinations on a
# machine where the iOS platform support matching the Xcode SDK is not installed
# ("iOS 26.5 is not installed. Please download and install the platform from
# Xcode > Settings > Components"). That gates simulator destinations too, not
# just device ones, so the whole suite becomes unrunnable -- even though a
# perfectly usable simulator runtime is installed.
#
# `xcodebuild -downloadPlatform iOS` fails with "Unable to connect to simulator"
# and exits 0 without downloading anything, so it cannot be fixed from the CLI.
# Install the platform from Xcode > Settings > Components and prefer the standard
# invocation in CONTRIBUTING.md; this script is the fallback until then.
#
# It compiles the app and test sources as a single module (so `@testable import
# Facett` is unnecessary and stripped), links an .xctest bundle against the
# simulator XCTest, and runs it on an already-installed runtime via simctl.

set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="${TMPDIR:-/tmp}/facett-tests-$$"
DEV="$(xcode-select -p)/Platforms/iPhoneSimulator.platform/Developer"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
XCTEST_AGENT="$DEV/Library/Xcode/Agents/xctest"
BUNDLE="$BUILD_DIR/FacettTests.xctest"

cleanup() { rm -rf "$BUILD_DIR"; }
trap cleanup EXIT

mkdir -p "$BUILD_DIR/src" "$BUNDLE"

# Pick any available iPhone simulator and boot it if needed.
UDID="$(xcrun simctl list devices available -j \
    | python3 -c 'import json,sys
d=json.load(sys.stdin)["devices"]
for runtime, devices in d.items():
    for dev in devices:
        if "iPhone" in dev["name"]:
            print(dev["udid"]); raise SystemExit')"

if [ -z "$UDID" ]; then
    echo "No iPhone simulator available." >&2
    exit 1
fi

echo "Using simulator $UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID" || true

# App sources, minus the @main attribute (a test bundle must not define an entry point).
for f in Facett/*.swift; do
    sed 's/^@main$//' "$f" > "$BUILD_DIR/src/$(basename "$f")"
done

# Test sources join the same module, so the @testable import is redundant.
for f in FacettTests/*.swift; do
    sed 's/^@testable import Facett$//' "$f" > "$BUILD_DIR/src/T_$(basename "$f")"
done

cat > "$BUNDLE/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>FacettTests</string>
    <key>CFBundleIdentifier</key><string>com.kmatzen.FacettTests</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>FacettTests</string>
    <key>CFBundlePackageType</key><string>BNDL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
</dict>
</plist>
PLIST

echo "Building test bundle..."
xcrun --sdk iphonesimulator swiftc \
    -emit-library -Xlinker -bundle \
    -sdk "$SDK" -target arm64-apple-ios16.6-simulator \
    -F "$DEV/Library/Frameworks" -I "$DEV/usr/lib" -L "$DEV/usr/lib" \
    -framework XCTest -lXCTestSwiftSupport \
    -Xlinker -rpath -Xlinker "$DEV/Library/Frameworks" \
    -Xlinker -rpath -Xlinker "$DEV/usr/lib" \
    -o "$BUNDLE/FacettTests" \
    "$BUILD_DIR"/src/*.swift

echo "Running tests..."
# Pass a test class name as $1 to run only that suite.
if [ $# -gt 0 ]; then
    xcrun simctl spawn "$UDID" "$XCTEST_AGENT" -XCTest "$1" "$BUNDLE"
else
    xcrun simctl spawn "$UDID" "$XCTEST_AGENT" "$BUNDLE"
fi
