#!/bin/sh
set -eu
core_source="$PROJECT_DIR/Frameworks/mihomo"
core_destination="$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH/mihomo"
if [ ! -x "$core_source" ]; then
  echo 'error: Mihomo is missing. Run: sh macos/prepare_core.sh' >&2
  exit 1
fi
mkdir -p "$(dirname "$core_destination")"
cp "$core_source" "$core_destination"
chmod 755 "$core_destination"
if [ "$CODE_SIGNING_ALLOWED" != NO ]; then
  /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" "$core_destination"
fi
