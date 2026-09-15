#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="$PWD/希久提醒.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -swift-version 5 -target arm64-apple-macos13.0 -O -framework AppKit -framework QuartzCore Sources/Schedule.swift Sources/main.swift -o "$APP/Contents/MacOS/Xijiu"
cp Resources/schedule.json "$APP/Contents/Resources/schedule.json"
cp Resources/spritesheet.png "$APP/Contents/Resources/spritesheet.png"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Xijiu</string>
<key>CFBundleIdentifier</key><string>local.xijiu.companion</string>
<key>CFBundleName</key><string>希久提醒</string>
<key>CFBundleDisplayName</key><string>希久提醒</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
PLIST
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"; fi
codesign --force --deep --sign - "$APP"
