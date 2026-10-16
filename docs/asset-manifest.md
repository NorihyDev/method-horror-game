# Asset Manifest

Every shipped asset, where it comes from and its status. No third-party art,
audio, music, fonts or models are included.

| Asset | Path | Source | Author | License | Status |
|---|---|---|---|---|---|
| Surface textures (11 × albedo + normal, 512 px and 256 px) | `game/assets/generated/textures/` | `game/tools/generate_textures.gd` (FastNoiseLite + procedural patterns) | METHOD | Proprietary (METHOD) | Placeholder |
| Sound effects, ambience, music loops (74 files) | `game/assets/audio/generated/` | `game/tools/generate_audio.gd` → `scripts/audio/sound_synth.gd` (noise, oscillators, filters, reverb) | METHOD | Proprietary (METHOD) | Placeholder |
| Surface shader | `game/assets/materials/surface.gdshader` | Hand-written | METHOD | Proprietary | Final candidate |
| App icon | `game/icon.svg` | Hand-written SVG (METHOD "M" mark) | METHOD | Proprietary | Placeholder |
| Level geometry & props | generated at runtime (`scripts/world/geo_builder.gd`, `prop_factory.gd`, map scripts) | Procedural | METHOD | Proprietary | Placeholder |
| The Watcher model & animations | generated at runtime (`scripts/ai/watcher_rig.gd`) | Procedural joint hierarchy + AnimationPlayer tracks | METHOD | Proprietary | Placeholder |
| Viewmodel (hand + flashlight) | `scripts/player/viewmodel.gd` | Procedural | METHOD | Proprietary | Placeholder |
| Item models | `scripts/interaction/item_visuals.gd` | Procedural | METHOD | Proprietary | Placeholder |
| UI font | engine default (bundled with Godot, see THIRD_PARTY_NOTICES) + `SystemFont` serif/monospace requests | Godot / player's OS | — | Engine license; OS fonts are not redistributed | Final candidate |
| Writing (notes, tapes, files, UI) | `game/localization/*.json` | Original | METHOD | Proprietary | Draft |

## Quality limits (be honest in store copy)

- Audio is synthesized: footsteps and doors are stylized, not recorded foley;
  the tape "voice" is deliberately unintelligible (subtitles carry the text).
- Geometry is box-based; characters are articulated primitives, not sculpted
  models. Silhouette and lighting carry the mood.

## Regenerating

```bash
./tools/godot.sh --headless --path game --script res://tools/generate_textures.gd
./tools/godot.sh --headless --path game --script res://tools/generate_audio.gd [-- --only=<sound>]
./tools/godot.sh --headless --path game --import
./tools/configure_imports.sh && ./tools/godot.sh --headless --path game --import
```

Generators are deterministic (fixed seeds), so regenerated files match unless a
recipe changes.
