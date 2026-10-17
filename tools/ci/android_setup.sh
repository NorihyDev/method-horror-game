#!/usr/bin/env bash
# Prepares a fresh Linux runner for a headless Godot Android export:
# creates the standard (public) Android DEBUG keystore and writes the editor
# settings Godot reads for Java/SDK/keystore paths.
#
# Requires: JAVA_HOME (JDK 17+), ANDROID_HOME (SDK with build-tools).
# Release signing never goes here: it uses GODOT_ANDROID_KEYSTORE_RELEASE_*
# environment variables provided only to the protected release job.
set -euo pipefail
: "${JAVA_HOME:?JAVA_HOME must be set}"
: "${ANDROID_HOME:?ANDROID_HOME must be set}"

VERSION="$(tr -d '[:space:]' < "$(dirname "$0")/../godot-version.txt")"
MAJOR_MINOR="$(echo "$VERSION" | cut -d. -f1-2)"              # 4.7
CONFIG_DIR="$HOME/.config/godot"
KEYSTORE="$CONFIG_DIR/keystores/debug.keystore"

mkdir -p "$CONFIG_DIR/keystores"
if [[ ! -f "$KEYSTORE" ]]; then
  "$JAVA_HOME/bin/keytool" -keyalg RSA -genkeypair -alias androiddebugkey \
    -keypass android -keystore "$KEYSTORE" -storepass android \
    -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
fi

cat > "$CONFIG_DIR/editor_settings-${MAJOR_MINOR}.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "${JAVA_HOME}"
export/android/android_sdk_path = "${ANDROID_HOME}"
export/android/debug_keystore = "${KEYSTORE}"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
echo "Android export environment ready (debug keystore only)."
