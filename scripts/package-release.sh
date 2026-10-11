#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_APP="${FLOW_TRANSLATE_OUTPUT_DIR:-$PWD/dist}/Flow Translate.app"
TASK_TAG="${1:-0.4.0-beta.1}"
[[ "$TASK_TAG" =~ '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$' ]] || { print -u2 'Invalid version'; exit 1; }
[[ -d "$TASK_APP" ]] || { print -u2 'Run scripts/build-app.sh first'; exit 1; }
codesign --verify --deep --strict "$TASK_APP"
TASK_ARCH="$(lipo -archs "$TASK_APP/Contents/MacOS/FlowTranslate")"
[[ "$TASK_ARCH" == "arm64" || "$TASK_ARCH" == "x86_64" ]] || { print -u2 'Unexpected architecture'; exit 1; }
TASK_STEM="Flow-Translate-$TASK_TAG-macos-$TASK_ARCH"
mkdir -p dist
[[ ! -e "dist/$TASK_STEM.zip" && ! -e "dist/$TASK_STEM.dmg" ]] || { print -u2 'Version artifacts already exist. Choose a new version or move them first.'; exit 1; }
TASK_STAGE="$(mktemp -d /tmp/FlowTranslate-package.XXXXXX)"
trap 'rm -rf "$TASK_STAGE"' EXIT
/usr/bin/ditto --norsrc --noextattr --noqtn "$TASK_APP" "$TASK_STAGE/Flow Translate.app"
cp LICENSE "$TASK_STAGE/LICENSE.txt"
cp docs/INSTALL.md "$TASK_STAGE/INSTALL.txt"
ln -s /Applications "$TASK_STAGE/Applications"
COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --noextattr --noqtn --keepParent "$TASK_STAGE/Flow Translate.app" "dist/$TASK_STEM.zip"
hdiutil create -quiet -volname 'Flow Translate' -srcfolder "$TASK_STAGE" -format UDZO "dist/$TASK_STEM.dmg"
hdiutil verify "dist/$TASK_STEM.dmg"
(cd dist && shasum -a 256 "$TASK_STEM.zip" "$TASK_STEM.dmg" > SHA256SUMS.txt)
print "Created dist/$TASK_STEM.dmg and .zip"
