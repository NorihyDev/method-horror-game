# Asset Replacement Guide

How to swap procedural placeholders for authored assets without touching game
rules.

## Conventions

| Convention | Value |
|---|---|
| Units | 1 unit = 1 meter |
| Up / forward | +Y up; characters and props face **−Z** (Godot forward) unless noted |
| Pivots | Floor-standing props: bottom center. Doors: hinge edge, panel along +X. Wall-mounted entities (fuse panel, keypad, notes, clues): back face center, front facing +Z local. Hiding spots: bottom center, opening toward +Z |
| Scale | Apply transforms before export (scale 1) |
| Formats | glTF 2.0 (`.glb`) for models; PNG for textures (albedo sRGB, normal map OpenGL +Y); OGG Vorbis or WAV for audio |
| Naming | `snake_case`; meshes `sm_<name>`, textures `t_<name>_<albedo|normal|orm>`, sounds keep the existing ids (e.g. `door_creak_1.wav`) |
| Texture size | 1024 px max for hero props, 512 px for surfaces; power of two |
| Materials | One material slot per surface type where possible (reuse `MaterialLib` names: `wallpaper`, `wood_floor`, `metal`, …) |
| Collision | Simple boxes/convex hulls; walls/floors on layer `world`, furniture on `prop`, interaction targets on `interactable` |
| LOD | Godot auto-LOD on import for meshes > 2 k triangles; manual LOD not required yet |

## Surfaces

Drop new textures into `assets/generated/textures/` using the same file names
(`<surface>_albedo.png`, `<surface>_normal.png`, and `_lo` variants at half
size), or add a new entry to `MaterialLib.SURFACES` pointing at new names.
Textures are world-mapped (1 UV = 1 m × `tiles_per_meter`), so they must tile.

## Props and rooms

Static set dressing is built in map scripts with `PropFactory`. To use a model:
instance it in the map's `build_level()` under `nav_region` (so navigation
bakes around its collision) and give its collision the `prop` layer. Keep
`PropFactory` calls as a fallback when the model is missing.

## Interactables

Entity scripts own logic; visuals are created in their `_ready()`. To replace a
visual, add a `PackedScene` export (e.g. `@export var model: PackedScene`),
instance it instead of the `add_mesh` calls, and keep `add_target(...)` boxes
(interaction rays) and any `AnimatableBody3D` used for physics (doors, garage
door). Do not rename `entity_id`s — rules and saves refer to them.

## The Watcher

`Watcher` (logic) expects a child with:

- `play(name: String, blend: float, speed: float)` and `current()`;
- a `foot_planted` signal (footstep audio is driven by animation);
- `set_lens_intensity(k: float)` (glow cue when chasing; can be a no-op).

Animation names: `idle`, `walk`, `run`, `search`, `alert`, `windup`, `strike`,
`recover`, `hit`, `open_door`. A rigged replacement should use a `Skeleton3D`
with an `AnimationPlayer`/`AnimationTree` exposing these names and call
`foot_planted` from method tracks on foot contacts. Height ≈ 2.2 m hunched; the
collision capsule is 0.38 m radius × 2.0 m and must fit 2.2 m doorways. The rig
faces +Z internally and is rotated 180° by `Watcher`; a replacement facing −Z
should drop that rotation.

## Viewmodel

`Viewmodel` must expose a `flashlight: SpotLight3D` and the methods
`update_motion`, `set_style`, `set_lens_glow`, `play_pickup`, `play_reach`,
`play_use`, `play_inspect`. A rigged arm scene can implement these by driving
its own AnimationPlayer.

## Audio

Replace files in `assets/audio/generated/` keeping their names; variant sets
keep the `_1.._n` suffix and count in `AudioService.VARIANTS`. Loops must be
seamless and keep the `_loop` suffix (import loop mode is applied by
`tools/configure_imports.sh`). Update `docs/asset-manifest.md` with source,
author and license for every new file.
