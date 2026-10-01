#!/bin/sh
# Keep the Dock icon identical to the canonical brand PNG.
set -eu
cd "$(dirname "$0")/.."
for size in 16 32 64 128 256 512 1024; do
  sips -z "$size" "$size" assets/icon.png \
    --out "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png" >/dev/null
done
