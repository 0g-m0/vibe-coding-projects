#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/WaterReminder.app"
SRC=( "$ROOT/WaterReminderApp.swift" "$ROOT/AppDelegate.swift" "$ROOT/RemindersStore.swift" "$ROOT/SettingsView.swift" )
OUT="$ROOT/build/WaterReminder"
FLAGS=( -target arm64-apple-macos13 -framework AppKit -framework SwiftUI -framework UserNotifications -framework Combine )

rm -rf "$ROOT/build"
mkdir -p "$ROOT/build"

echo "Compiling..."
swiftc -O "${SRC[@]}" -o "$OUT" "${FLAGS[@]}"

echo "Bundling .app..."
mkdir -p "$APP/Contents/MacOS"
cp "$OUT" "$APP/Contents/MacOS/WaterReminder"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

echo "Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP" 2>&1 || echo "codesign warning"

# Register with LaunchServices so the system picks up the bundle id
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"

echo "Done: $APP"
open "$APP"