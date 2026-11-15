#!/bin/bash
# Builds VPN (Mantra).app. Run by GitHub Actions only (MANTRA_MANIFEST modules/compile-on-github.md): SIGN=- NO_INSTALL=1.
# On the Mac the release zip is downloaded and signed "Mantra Apps" (TAKEOVER.md, Install).
set -euo pipefail
cd "$(dirname "$0")"
V=$(sed -n 's/^let VERSION = \([0-9]*\)/\1/p' Sources/Version.swift)
NAME="VPN (Mantra)"
APP="build/$NAME.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -target arm64-apple-macos13 Sources/*.swift -framework AppKit -framework SwiftUI -o build/VPN-arm64
swiftc -O -swift-version 5 -target x86_64-apple-macos13 Sources/*.swift -framework AppKit -framework SwiftUI -o build/VPN-x86_64
lipo -create build/VPN-arm64 build/VPN-x86_64 -output "$APP/Contents/MacOS/VPN"
sed "s/__VERSION__/$V/g" Resources/Info.plist > "$APP/Contents/Info.plist"
swift Tools/make_icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force -s "${SIGN:-Mantra Apps}" -i com.mantraproductions.vpn "$APP"
codesign --verify --deep "$APP"
echo "built v$V"
if [ -n "${NO_INSTALL:-}" ]; then exit 0; fi
ditto "$APP" "/Applications/$NAME.app"
