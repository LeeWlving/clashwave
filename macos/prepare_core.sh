#!/bin/sh
# Pinned official Mihomo release; builds one executable for both Mac architectures.
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/mihomo-download macos/Frameworks
download_core() {
  arch="$1"
  digest="$2"
  archive="build/mihomo-download/mihomo-${arch}.gz"
  curl -fL --retry 3 "https://github.com/MetaCubeX/mihomo/releases/download/v1.19.31/mihomo-darwin-${arch}-v1.19.31.gz" -o "$archive"
  echo "$digest  $archive" | shasum -a 256 -c -
  gzip -dc "$archive" > "build/mihomo-download/mihomo-${arch}"
}
download_core arm64 d131f44b3deb2a8356f7ac75048ad67a10d53243323951c4f3cda7b672922963
download_core amd64-compatible fb6fca0e105b4310a21eaacd3a8d3853d3d8b87fa4c69737bea52a30a435aac7
lipo -create build/mihomo-download/mihomo-arm64 build/mihomo-download/mihomo-amd64-compatible -output macos/Frameworks/mihomo
chmod 755 macos/Frameworks/mihomo
