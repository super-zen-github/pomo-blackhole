#!/bin/zsh
set -euo pipefail

PROJECT_ROOT=${0:A:h:h}
cd "$PROJECT_ROOT"
swift build -c release

APP_DIR="$PROJECT_ROOT/.build/BlackHolePomodoro.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$PROJECT_ROOT/.build/release/PomoBlackHole" "$MACOS_DIR/PomoBlackHole"
cp "$PROJECT_ROOT/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp -R "$PROJECT_ROOT/Resources/en.lproj" "$PROJECT_ROOT/Resources/zh-Hans.lproj" "$RESOURCES_DIR/"
codesign \
    --force \
    --deep \
    --sign - \
    --requirements '=designated => identifier "local.pomo.blackhole"' \
    "$APP_DIR"
echo "$APP_DIR"
