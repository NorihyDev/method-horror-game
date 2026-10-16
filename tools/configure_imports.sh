#!/usr/bin/env bash
# Applies project import conventions to generated assets (idempotent).
# Run after generating new textures/audio and after a first `--import`, then re-import.
#  - Textures: VRAM compressed (S3TC/BPTC desktop, ETC2/ASTC mobile), mipmaps, normal-map flag.
#  - Audio: *_loop.wav loop forward; everything else QOA compressed (default).
set -euo pipefail
cd "$(dirname "$0")/../game"
for f in assets/generated/textures/*.png.import; do
  sed -i -e 's/^compress\/mode=.*/compress\/mode=2/' \
         -e 's/^mipmaps\/generate=.*/mipmaps\/generate=true/' \
         -e 's/^detect_3d\/compress_to=.*/detect_3d\/compress_to=0/' "$f"
  if [[ "$f" == *_normal* ]]; then
    sed -i -e 's/^compress\/normal_map=.*/compress\/normal_map=1/' "$f"
  fi
done
for f in assets/audio/generated/*_loop.wav.import; do
  sed -i -e 's/^edit\/loop_mode=.*/edit\/loop_mode=2/' "$f"
done
echo "Import settings applied. Run: godot --headless --path game --import"
