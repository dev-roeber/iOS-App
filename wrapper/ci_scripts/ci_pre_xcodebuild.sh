#!/bin/sh
# ci_pre_xcodebuild.sh — Xcode Cloud pre-xcodebuild hook
#
# WICHTIG: Xcode Cloud erkennt NUR diese offiziellen Skriptnamen:
#   ci_post_clone.sh, ci_pre_xcodebuild.sh, ci_post_xcodebuild.sh
# ci_pre_build.sh ist KEIN gültiger Name und wird ignoriert.
#
# Injects CI build number into CFBundleVersion so every Xcode Cloud build
# gets a unique, monotonically increasing build number.
# MARKETING_VERSION (e.g. 1.0) stays unchanged.
#
# Xcode Cloud sets CI_BUILD_NUMBER automatically for every build.
# App Store Connect requires unique (version, build) tuples per upload.

set -e

if [ -z "$CI_BUILD_NUMBER" ]; then
    echo "ci_pre_xcodebuild: CI_BUILD_NUMBER not set, skipping version injection (local build)"
    exit 0
fi

PLIST_APP="$CI_WORKSPACE/wrapper/Config/Info.plist"
PLIST_WIDGET="$CI_WORKSPACE/wrapper/LH2GPXWidget/Info.plist"

inject_build_number() {
    local plist="$1"
    if [ -f "$plist" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CI_BUILD_NUMBER" "$plist"
        echo "ci_pre_xcodebuild: set CFBundleVersion=$CI_BUILD_NUMBER in $plist"
    else
        echo "ci_pre_xcodebuild: WARN plist not found: $plist"
    fi
}

inject_build_number "$PLIST_APP"
inject_build_number "$PLIST_WIDGET"

echo "ci_pre_xcodebuild: build number injection complete (CI_BUILD_NUMBER=$CI_BUILD_NUMBER)"
