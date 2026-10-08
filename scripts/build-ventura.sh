#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
if ! xcodebuild -version > /dev/null 2>&1; then
    echo 'Build blocked: full Xcode 26 or later is required. Command Line Tools alone are insufficient.' >&2
    exit 2
fi
xcode_version="$(xcodebuild -version | awk '/^Xcode / { print $2 }')"
if [ "${xcode_version%%.*}" -lt 26 ]; then
    echo "Build blocked: Xcode ${xcode_version} is selected; this source port requires Xcode 26 or later." >&2
    exit 2
fi
build_root="$project_root/work/ventura-build"
app_output="$project_root/dist/Compositor-Ventura-1.4.6-preview.app"
if [ -e "$app_output" ]; then
    echo "Refusing to overwrite the existing app: $app_output" >&2
    exit 2
fi
mkdir -p "$project_root/dist" "$build_root"
xcodebuild -project "$project_root/Compositor.xcodeproj" -scheme Compositor \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$build_root" \
    MACOSX_DEPLOYMENT_TARGET=13.0 ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    SWIFT_OPTIMIZATION_LEVEL=-Onone SWIFT_COMPILATION_MODE=singlefile \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build \
    > "$build_root/build.log" 2>&1 || {
        echo "Build failed. See $build_root/build.log" >&2
        tail -n 50 "$build_root/build.log" >&2
        exit 1
    }
source_app="$build_root/Build/Products/Release/Compositor.app"
test -d "$source_app"
ditto "$source_app" "$app_output"
codesign --force --sign - --entitlements "$project_root/Config/Compositor.entitlements" "$app_output"
codesign --verify --deep --strict "$app_output"
minimum_os="$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$app_output/Contents/Info.plist")"
if [ "${minimum_os%%.*}" -gt 13 ]; then
    echo "Verification failed: bundle requires macOS $minimum_os" >&2
    exit 1
fi
lipo "$app_output/Contents/MacOS/Compositor" -verify_arch arm64
echo "Built and ad-hoc signed: $app_output"
echo 'The app still needs launch, rendering, save/reopen, and export verification on macOS 13.'
