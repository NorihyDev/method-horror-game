#!/usr/bin/env bash
# Renders reference screenshots (needs a GPU/display) into $1 and builds a contact sheet.
set -euo pipefail
out="${1:?usage: tools/shots.sh <out_dir> [extra args]}"; shift || true
mkdir -p "$out"
cd "$(dirname "$0")/.."
timeout 240 ./tools/godot.sh --path game --resolution 1280x720 -- --autoshot="$out" "$@" 2>&1 | grep -E "^shot:|SCRIPT ERROR" || true
python -I - "$out" <<'PY'
import sys, glob, os
from PIL import Image
out = sys.argv[1]
files = sorted(glob.glob(os.path.join(out, '[0-9]*.png')))
w, h = 640, 360
cols = 3
rows = (len(files) + cols - 1) // cols
sheet = Image.new('RGB', (w * cols, h * max(rows, 1)))
for i, f in enumerate(files):
    sheet.paste(Image.open(f).convert('RGB').resize((w, h)), ((i % cols) * w, (i // cols) * h))
sheet.save(os.path.join(out, 'sheet.png'))
PY
