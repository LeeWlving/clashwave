#!/bin/sh
set -eu

version="1.19.31"
arch="$(uname -m)"
case "$arch" in
  x86_64) asset_arch="amd64" ;;
  aarch64|arm64) asset_arch="arm64" ;;
  *) echo "Unsupported Linux architecture: $arch" >&2; exit 1 ;;
esac

archive="linux/core/mihomo.gz"
target="linux/core/mihomo"
mkdir -p linux/core
curl -fL --retry 3 \
  "https://github.com/MetaCubeX/mihomo/releases/download/v${version}/mihomo-linux-${asset_arch}-v${version}.gz" \
  -o "$archive"
gzip -dc "$archive" > "$target"
rm -f "$archive"
chmod 755 "$target"
