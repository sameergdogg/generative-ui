#!/bin/bash
# capture.sh — Capture side-by-side screenshots from iOS Simulator and Android Emulator
# Usage: ./screenshots/capture.sh
#
# Prerequisites:
#   iOS simulator and Android emulator both running
#   xcodegen installed (brew install xcodegen)

set -euo pipefail
cd "$(dirname "$0")/.."

SCREENSHOTS_DIR="screenshots"
MULTIVIEW_DIR="$SCREENSHOTS_DIR/multiview"
mkdir -p "$MULTIVIEW_DIR"

export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools

echo "=== Generative UI DSL — Cross-Platform Screenshot Capture ==="
echo ""

# ── iOS ──────────────────────────────────────────────────────────
build_ios() {
    echo "📱 iOS: Building TransactionAI..."

    local DEVICE_ID
    DEVICE_ID=$(xcrun simctl list devices booted | grep "iPhone" | head -1 | grep -oE '[0-9A-F-]{36}')
    if [ -z "$DEVICE_ID" ]; then
        echo "  ❌ No booted iPhone simulator found. Skipping iOS."
        return 1
    fi
    echo "  Using simulator: $DEVICE_ID"

    # Generate Xcode project
    cd examples/transaction-ai
    if command -v xcodegen &>/dev/null; then
        xcodegen generate 2>&1 | tail -1
    fi

    # Build and install
    xcodebuild -project TransactionAI.xcodeproj -scheme TransactionAI \
        -destination "platform=iOS Simulator,id=$DEVICE_ID" \
        -derivedDataPath build/ios \
        build 2>&1 | tail -3

    local APP_PATH
    APP_PATH=$(find build/ios -name "TransactionAI.app" -path "*/Debug-iphonesimulator/*" | head -1)
    if [ -n "$APP_PATH" ]; then
        xcrun simctl install "$DEVICE_ID" "$APP_PATH"
        xcrun simctl launch "$DEVICE_ID" com.sameer.TransactionAI 2>/dev/null || true
        sleep 3
    fi
    cd ../..

    echo "  ✅ iOS app installed and launched"
    echo "$DEVICE_ID"
}

capture_ios() {
    local DEVICE_ID="$1"
    local NAME="$2"
    xcrun simctl io "$DEVICE_ID" screenshot "$MULTIVIEW_DIR/ios_${NAME}.png" 2>/dev/null
    echo "  📸 iOS: $MULTIVIEW_DIR/ios_${NAME}.png"
}

# ── Android ──────────────────────────────────────────────────────
build_android() {
    echo "🤖 Android: Building sample app..."

    if ! $ANDROID_HOME/platform-tools/adb devices 2>/dev/null | grep -q "emulator"; then
        echo "  ❌ No Android emulator running. Skipping Android."
        return 1
    fi

    cd examples/android-sample
    echo "sdk.dir=$ANDROID_HOME" > local.properties
    gradle :sample-app:installDebug 2>&1 | tail -3
    cd ../..

    # Launch
    $ANDROID_HOME/platform-tools/adb shell am start -n com.generativeui.sample/.MainActivity 2>/dev/null
    sleep 3

    echo "  ✅ Android app installed and launched"
}

capture_android() {
    local NAME="$1"
    $ANDROID_HOME/platform-tools/adb exec-out screencap -p > "$MULTIVIEW_DIR/android_${NAME}.png"
    echo "  📸 Android: $MULTIVIEW_DIR/android_${NAME}.png"
}

# ── Compare ──────────────────────────────────────────────────────
make_comparison() {
    local NAME="$1"
    local TITLE="$2"
    local ios_file="$MULTIVIEW_DIR/ios_${NAME}.png"
    local android_file="$MULTIVIEW_DIR/android_${NAME}.png"

    if [ ! -f "$ios_file" ] || [ ! -f "$android_file" ]; then
        echo "  ⚠️  Missing screenshot for $NAME, skipping comparison"
        return
    fi

    python3 - "$ios_file" "$android_file" "$SCREENSHOTS_DIR/comparison_${NAME}.png" "$TITLE" << 'PYEOF'
import sys
from PIL import Image, ImageDraw, ImageFont

ios = Image.open(sys.argv[1])
android = Image.open(sys.argv[2])
title = sys.argv[4]

# Resize to same height
target_h = max(ios.height, android.height)
if ios.height != target_h:
    ios = ios.resize((int(ios.width * target_h / ios.height), target_h), Image.LANCZOS)
if android.height != target_h:
    android = android.resize((int(android.width * target_h / android.height), target_h), Image.LANCZOS)

gap = 20
header = 40
combined = Image.new('RGB', (ios.width + android.width + gap, target_h + header), (255, 255, 255))
draw = ImageDraw.Draw(combined)

# Header labels
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 20)
    font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
except:
    font = ImageFont.load_default()
    font_small = font

# Title centered
tw = draw.textlength(title, font=font)
draw.text(((ios.width + android.width + gap - tw) / 2, 8), title, fill=(0, 0, 0), font=font)

# Platform labels
draw.text((ios.width // 2 - 30, 24), "iOS (SwiftUI)", fill=(0, 120, 255), font=font_small)
draw.text((ios.width + gap + android.width // 2 - 45, 24), "Android (Compose)", fill=(255, 120, 0), font=font_small)

combined.paste(ios, (0, header))
combined.paste(android, (ios.width + gap, header))
combined.save(sys.argv[3])
print(f"  ✅ Comparison: {sys.argv[3]}")
PYEOF
}

# ── Main ─────────────────────────────────────────────────────────
echo ""

# Build both apps
IOS_DEVICE=$(build_ios) || IOS_DEVICE=""
echo ""
build_android || true

if [ -z "$IOS_DEVICE" ]; then
    echo ""
    echo "❌ iOS build failed. Cannot capture screenshots."
    exit 1
fi

echo ""
echo "=== Apps are running. Capturing screenshots ==="
echo ""
echo "Navigate to each tab in both apps, then press Enter to capture."
echo "Available views: claude_response, financial_dashboard, grocery, weekly_spending, subscriptions, budget_status"
echo ""

VIEWS=("claude_response:McDonald's Spending Summary" "financial_dashboard:January Financial Dashboard" "grocery:Grocery Spending Breakdown" "weekly_spending:This Week's Spending" "subscriptions:Active Subscriptions" "budget_status:March Budget Status")

for entry in "${VIEWS[@]}"; do
    IFS=':' read -r name title <<< "$entry"
    echo "📋 Ready to capture: $title"
    echo "   Switch both apps to this view, then press Enter..."
    read -r

    capture_ios "$IOS_DEVICE" "$name"
    capture_android "$name"
    make_comparison "$name" "$title"
    echo ""
done

echo "=== Done! ==="
echo "Individual: $MULTIVIEW_DIR/"
echo "Comparisons: $SCREENSHOTS_DIR/comparison_*.png"
