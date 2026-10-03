#!/bin/sh
set -eu

version="1.19.31"
arch="$(uname -m)"
case "$arch" in
  x86_64)
    asset_arch="amd64"
    digest="d5e74bbddbdfff49a1aef7775bf5911da59f0d7196ed509a0ac914b3653dd5f1"
    ;;
  aarch64|arm64)
    asset_arch="arm64"
    digest="9e0f11afbf38426b8bd88fdc594678f8161c57eccb4e1b77acb12b493904f1d4"
    ;;
  *) echo "Unsupported Linux architecture: $arch" >&2; exit 1 ;;
esac

archive="linux/core/mihomo.gz"
target="linux/core/mihomo"
mkdir -p linux/core
curl -fL --retry 3 \
  "https://github.com/MetaCubeX/mihomo/releases/download/v${version}/mihomo-linux-${asset_arch}-v${version}.gz" \
  -o "$archive"
echo "$digest  $archive" | sha256sum --check --strict
gzip -dc "$archive" > "$target"
rm -f "$archive"
chmod 755 "$target"
