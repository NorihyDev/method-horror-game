#!/usr/bin/env bash
# Downloads the pinned Godot Linux editor (and optionally export templates),
# verifies SHA-512 against the values below, and installs them.
# Usage: tools/ci/install_godot.sh [--templates]
# Outputs: $HOME/godot/godot (binary); templates in ~/.local/share/godot/export_templates/<ver>.
set -euo pipefail

VERSION="$(tr -d '[:space:]' < "$(dirname "$0")/../godot-version.txt")"   # e.g. 4.7.2-stable
TEMPLATE_DIR_NAME="${VERSION/-/.}"                                       # 4.7.2.stable
BASE="https://github.com/godotengine/godot/releases/download/${VERSION}"
EDITOR_ZIP="Godot_v${VERSION}_linux.x86_64.zip"
TEMPLATES_TPZ="Godot_v${VERSION}_export_templates.tpz"

# Official checksums from ${BASE}/SHA512-SUMS.txt (verified when pinning).
declare -A SHA512=(
  ["Godot_v4.7.2-stable_linux.x86_64.zip"]="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
  ["Godot_v4.7.2-stable_export_templates.tpz"]="ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"
)

fetch() {
  local name="$1" dest="$2"
  if [[ -z "${SHA512[$name]:-}" ]]; then
    echo "No pinned checksum for $name — update tools/ci/install_godot.sh when changing versions." >&2
    exit 1
  fi
  if [[ ! -f "$dest" ]]; then
    curl -fsSL --retry 3 -o "$dest" "${BASE}/${name}"
  fi
  echo "${SHA512[$name]}  $dest" | sha512sum -c -
}

mkdir -p "$HOME/godot" "$HOME/.cache/godot-dl"
fetch "$EDITOR_ZIP" "$HOME/.cache/godot-dl/$EDITOR_ZIP"
unzip -o -q "$HOME/.cache/godot-dl/$EDITOR_ZIP" -d "$HOME/godot"
mv -f "$HOME/godot/Godot_v${VERSION}_linux.x86_64" "$HOME/godot/godot"
chmod +x "$HOME/godot/godot"
"$HOME/godot/godot" --headless --version
# Make `godot` available to later CI steps (tools/godot.sh looks it up on PATH).
if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$HOME/godot" >> "$GITHUB_PATH"
fi

if [[ "${1:-}" == "--templates" ]]; then
  fetch "$TEMPLATES_TPZ" "$HOME/.cache/godot-dl/$TEMPLATES_TPZ"
  target="$HOME/.local/share/godot/export_templates/${TEMPLATE_DIR_NAME}"
  mkdir -p "$target"
  tmp="$(mktemp -d)"
  unzip -q "$HOME/.cache/godot-dl/$TEMPLATES_TPZ" -d "$tmp"
  cp "$tmp/templates/"* "$target/"
  rm -rf "$tmp"
  echo "Templates installed in $target"
fi
