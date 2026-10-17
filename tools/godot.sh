#!/usr/bin/env bash
# Resolves the pinned Godot binary. Override with GODOT=/path/to/godot.
set -euo pipefail
if [[ -n "${GODOT:-}" ]]; then exec "$GODOT" "$@"; fi
for candidate in godot godot4 "Godot_v$(cat "$(dirname "$0")/godot-version.txt")_linux.x86_64"; do
  if command -v "$candidate" >/dev/null 2>&1; then exec "$candidate" "$@"; fi
done
echo "Godot $(cat "$(dirname "$0")/godot-version.txt") not found. Set GODOT=/path/to/binary." >&2
exit 127
