# Asset Manifest

Every shipped asset, where it comes from and its status. The only third-party
art is the CC0 MakeHuman content inside the Punky character model.

| Asset | Path | Source | Author | License | Status |
|---|---|---|---|---|---|
| Surface textures (15 × albedo + normal, 512 px and 256 px) | `game/assets/generated/textures/` | `game/tools/generate_textures.gd` (FastNoiseLite + procedural patterns) | METHOD | Proprietary (METHOD) | Placeholder |
| Sound effects, ambience, music loops (128 files) | `game/assets/audio/generated/` | `game/tools/generate_audio.gd` → `scripts/audio/sound_synth.gd` + `sound_synth_maps.gd` + `sound_synth_finale.gd` + `sound_synth_terror.gd` (noise, oscillators, filters, reverb) | METHOD | Proprietary (METHOD) | Placeholder |
| Decals (blood splatters, smear, drips, handprints, scratches, tally marks, stains; 10 × 256 px RGBA) | `game/assets/generated/decals/` | `game/tools/generate_decals.gd`, scattered by `scripts/world/decal_scatter.gd` | METHOD | Proprietary (METHOD) | Placeholder |
| Photo surface textures (wood floor, plaster, concrete, kitchen tiles, metal, wood, fabric, cinder blocks, carpet, wall tiles, ceiling panels, gravel, rust) | `game/assets/generated/textures/` (same file names) | ambientCG: WoodFloor051, Plaster001, Concrete034, Tiles074, Metal032, Wood049, Fabric030, Bricks066, Carpet016, Tiles009, OfficeCeiling005, Gravel022, Rust004 (1K) | ambientCG.com | CC0 1.0 | Final candidate |
| Surface shader | `game/assets/materials/surface.gdshader` | Hand-written | METHOD | Proprietary | Final candidate |
| App icon | `game/icon.svg` | Hand-written SVG (METHOD "M" mark) | METHOD | Proprietary | Placeholder |
| Level geometry & props | generated at runtime (`scripts/world/geo_builder.gd`, `prop_factory.gd`, `facility_props.gd`, `finale_props.gd`, map scripts) | Procedural | METHOD | Proprietary | Placeholder |
| Enemy models & animations (Watcher, Sister, Lineman, Headmistress, Subject Zero) | generated at runtime (`scripts/ai/watcher_rig.gd`, one skeleton, five styles) | Procedural joint hierarchy + AnimationPlayer tracks | METHOD | Proprietary | Placeholder |
| Viewmodel (hand + flashlight) | `scripts/player/viewmodel.gd` | Procedural | METHOD | Proprietary | Placeholder |
| Item models | `scripts/interaction/item_visuals.gd` | Procedural | METHOD | Proprietary | Placeholder |
| UI font | engine default (bundled with Godot, see THIRD_PARTY_NOTICES) + `SystemFont` serif/monospace requests | Godot / player's OS | — | Engine license; OS fonts are not redistributed | Final candidate |
| Teammate characters (Punky, Tsila, Mianja, Paulino, Nox, Ninja) (meshes, rig, 6 animation clips, textures, portraits) | `game/assets/characters/` | Blender 5.2 + MPFB 2 scripts in `tools/characters/` (see `docs/characters.md`); MakeHuman base mesh, skin, eyes, brows, lashes, hair, clothes and shoes; face textures projected from photos used with each person's consent | METHOD; MakeHuman community assets | MakeHuman assets CC0 1.0; likenesses used with consent (photos not in repo) | First version |
| Writing (notes, tapes, files, UI) | `game/localization/*.json` | Original | METHOD | Proprietary | Draft |

## Quality limits (be honest in store copy)

- Audio is synthesized: footsteps and doors are stylized, not recorded foley;
  the tape "voice" is deliberately unintelligible (subtitles carry the text).
- Geometry is box-based; enemies are articulated primitives, not sculpted
  models. Co-op teammates use the Punky model. Silhouette and lighting carry the mood.

## Regenerating

```bash
./tools/godot.sh --headless --path game --script res://tools/generate_textures.gd
./tools/godot.sh --headless --path game --script res://tools/generate_audio.gd [-- --only=<sound>]
./tools/godot.sh --headless --path game --import
./tools/configure_imports.sh && ./tools/godot.sh --headless --path game --import
```

Generators are deterministic (fixed seeds), so regenerated files match unless a
recipe changes.
