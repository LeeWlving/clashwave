#!/usr/bin/env bash
set -euo pipefail

: "${ANDROID_KEYSTORE_BASE64:?ANDROID_KEYSTORE_BASE64 is required}"
: "${ANDROID_KEYSTORE_PASSWORD:?ANDROID_KEYSTORE_PASSWORD is required}"
: "${ANDROID_KEY_PASSWORD:?ANDROID_KEY_PASSWORD is required}"
: "${ANDROID_KEY_ALIAS:?ANDROID_KEY_ALIAS is required}"
: "${ANDROID_EXPECTED_SHA1:?ANDROID_EXPECTED_SHA1 is required}"

mkdir -p android/app
printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > android/app/release.jks
cat > android/key.properties <<EOF
storePassword=${ANDROID_KEYSTORE_PASSWORD}
keyPassword=${ANDROID_KEY_PASSWORD}
keyAlias=${ANDROID_KEY_ALIAS}
storeFile=release.jks
EOF

chmod 600 android/app/release.jks android/key.properties

actual_sha1="$({
  keytool -list -v \
    -keystore android/app/release.jks \
    -storepass "$ANDROID_KEYSTORE_PASSWORD" \
    -alias "$ANDROID_KEY_ALIAS"
} | sed -n 's/^[[:space:]]*SHA1: //p' | head -n 1 | tr '[:lower:]' '[:upper:]')"

if [[ "$actual_sha1" != "${ANDROID_EXPECTED_SHA1^^}" ]]; then
  echo "Android upload certificate mismatch: expected $ANDROID_EXPECTED_SHA1, got $actual_sha1" >&2
  rm -f android/app/release.jks android/key.properties
  exit 1
fi
