#!/bin/zsh
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
TASK_OUTPUT="${FLOW_TRANSLATE_OUTPUT_DIR:-$TASK_ROOT/dist}"
TASK_OUTPUT="${TASK_OUTPUT:A}"
TASK_ARCH="${FLOW_TRANSLATE_ARCH:-$(uname -m)}"
[[ "$TASK_ARCH" == "arm64" || "$TASK_ARCH" == "x86_64" ]] || { print -u2 'Unsupported architecture'; exit 1; }
TASK_APP="$TASK_OUTPUT/Flow Translate.app"
assert_app_is_closed() {
    for TASK_PROCESS in "${(@f)$(/bin/ps -axo comm=)}"; do
        if [[ "$TASK_PROCESS" == "$TASK_APP/Contents/MacOS/FlowTranslate" ]]; then
            print -u2 -- "Quit Flow Translate before replacing: $TASK_APP"
            return 1
        fi
    done
}
assert_app_is_closed
# Avoid embedding the builder's local source directory in distributable binaries.
swift build -c release --arch "$TASK_ARCH" \
    -Xswiftc -debug-prefix-map -Xswiftc "$TASK_ROOT=." \
    -Xswiftc -file-prefix-map -Xswiftc "$TASK_ROOT=."
TASK_BIN="$(swift build -c release --arch "$TASK_ARCH" --show-bin-path)"
mkdir -p "$TASK_OUTPUT"
TASK_STAGE="$(mktemp -d "$TASK_OUTPUT/.FlowTranslate-build.XXXXXX")"
trap 'if [[ -d "$TASK_STAGE/previous.app" && ! -e "$TASK_APP" ]]; then mv "$TASK_STAGE/previous.app" "$TASK_APP"; fi; rm -rf "$TASK_STAGE"' EXIT
TASK_CANDIDATE="$TASK_STAGE/Flow Translate.app"
mkdir -p "$TASK_CANDIDATE/Contents/MacOS" "$TASK_CANDIDATE/Contents/Resources"
cp "$TASK_BIN/FlowTranslate" "$TASK_CANDIDATE/Contents/MacOS/FlowTranslate"
/usr/bin/strip -S "$TASK_CANDIDATE/Contents/MacOS/FlowTranslate"
cp "$TASK_ROOT/Resources/Info.plist" "$TASK_CANDIDATE/Contents/Info.plist"
TASK_BUILD_DATE="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
TASK_BUILD_HASH="$(shasum -a 256 "$TASK_CANDIDATE/Contents/MacOS/FlowTranslate")"
TASK_BUILD_ID="$(date -u '+%Y%m%d-%H%M%S')-${TASK_BUILD_HASH[1,8]}"
/usr/libexec/PlistBuddy -c "Add :FlowTranslateBuildDate string $TASK_BUILD_DATE" "$TASK_CANDIDATE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :FlowTranslateBuildID string $TASK_BUILD_ID" "$TASK_CANDIDATE/Contents/Info.plist"
swiftc -O "$TASK_ROOT/Sources/FlowTranslate/BrandArtwork.swift" "$TASK_ROOT/scripts/make-icon.swift" -o "$TASK_STAGE/make-icon"
"$TASK_STAGE/make-icon" "$TASK_STAGE/AppIcon.iconset"
iconutil --convert icns --output "$TASK_CANDIDATE/Contents/Resources/AppIcon.icns" "$TASK_STAGE/AppIcon.iconset"
TASK_IDENTITY="${FLOW_TRANSLATE_SIGN_IDENTITY:--}"
if [[ "$TASK_IDENTITY" == "-" ]]; then
    print -u2 -- 'Ad-hoc build: no Developer ID / notarization; Gatekeeper may require explicit user approval.'
    codesign --force --sign - --identifier io.github.xyizhan.FlowTranslate "$TASK_CANDIDATE"
else
    codesign --force --sign "$TASK_IDENTITY" --options runtime --timestamp --identifier io.github.xyizhan.FlowTranslate "$TASK_CANDIDATE"
fi
codesign --verify --deep --strict "$TASK_CANDIDATE"
assert_app_is_closed
if [[ -e "$TASK_APP" ]]; then mv "$TASK_APP" "$TASK_STAGE/previous.app"; fi
mv "$TASK_CANDIDATE" "$TASK_APP"
printf '%s\n' "$TASK_APP"
