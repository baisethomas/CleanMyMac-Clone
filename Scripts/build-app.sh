#!/bin/zsh
# Builds MacCleaner in release mode and assembles MacCleaner.app in the repo root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/MacCleaner.app"
ICONSET_DIR="$ROOT/.build/AppIcon.iconset"
ICNS="$ROOT/.build/AppIcon.icns"

echo "==> Building (release)…"
swift build -c release --package-path "$ROOT"
BIN="$(swift build -c release --package-path "$ROOT" --show-bin-path)/MacCleaner"

if [[ ! -f "$ICNS" ]]; then
    echo "==> Generating app icon…"
    PNG="$ROOT/.build/icon_1024.png"
    swift "$ROOT/Scripts/make-icon.swift" "$PNG"
    rm -rf "$ICONSET_DIR" && mkdir -p "$ICONSET_DIR"
    for s in 16 32 128 256 512; do
        sips -z $s $s "$PNG" --out "$ICONSET_DIR/icon_${s}x${s}.png" >/dev/null
        d=$((s * 2))
        sips -z $d $d "$PNG" --out "$ICONSET_DIR/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET_DIR" -o "$ICNS"
fi

echo "==> Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchAgents"
cp "$BIN" "$APP/Contents/MacOS/MacCleaner"
cp "$ROOT/Scripts/Info.plist" "$APP/Contents/Info.plist"
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"
# Scheduled background-scan agent, registered on demand via SMAppService.
cp "$ROOT/Scripts/dev.baisethomas.maccleaner.agent.plist" "$APP/Contents/Library/LaunchAgents/"

echo "==> Signing (ad-hoc)…"
codesign --force --deep --sign - "$APP"

echo "==> Done: $APP"
echo "    open \"$APP\""
