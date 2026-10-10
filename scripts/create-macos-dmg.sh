#!/bin/bash
set -euo pipefail

version="${1:?Usage: bash scripts/create-macos-dmg.sh VERSION}"
app='build/macos/Build/Products/Release/ClashWave.app'
output="dist/ClashWave-${version}-macos-universal.dmg"

if [[ ! -d "$app" || ! -x "$app/Contents/MacOS/mihomo" ]]; then
  echo 'ClashWave.app with its executable Mihomo core is required.' >&2
  exit 1
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/clashwave-dmg.XXXXXX")"
mounted=false
cleanup() {
  if [[ "$mounted" == true ]]; then
    hdiutil detach "$work_dir/mounted" -quiet || true
  fi
  rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p dist "$work_dir/staging" "$work_dir/mounted"
ditto "$app" "$work_dir/staging/ClashWave.app"
ln -s /Applications "$work_dir/staging/Applications"
hdiutil create -volname ClashWave -srcfolder "$work_dir/staging" \
  -fs HFS+ -format UDZO -ov "$output"
hdiutil verify "$output"

hdiutil attach "$output" -readonly -nobrowse -mountpoint "$work_dir/mounted" -quiet
mounted=true
test -f "$work_dir/mounted/ClashWave.app/Contents/Info.plist"
test -x "$work_dir/mounted/ClashWave.app/Contents/MacOS/mihomo"
test "$(readlink "$work_dir/mounted/Applications")" = /Applications
hdiutil detach "$work_dir/mounted" -quiet
mounted=false
printf 'Created and verified %s\n' "$output"
