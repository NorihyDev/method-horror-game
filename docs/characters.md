# Characters

Each player chooses a character in **Profile → Character**. Teammates see
that character in co-op. The local player always plays in first person and
sees only their own hands and flashlight.

The choice is free, purely visual and stored on the profile
(`Saves.character()`). It travels to other players as `char` in the join
hello:

- `NetProtocol.identify` checks it against `CharacterCatalog`. Anything
  unknown becomes Punky.
- The host puts it on the player's match record, which goes into snapshots.
- `RemoteAvatar` loads that model.

| Id | Name | File | Triangles | Look |
|---|---|---|---|---|
| `punky` (default) | Punky | `game/assets/characters/punky/punky.glb` | about 23.7k | Black mop of hair, grey jacket over a striped shirt, jeans |
| `tsila` | Tsila | `game/assets/characters/tsila/tsila.glb` | about 17k | Short curly hair, black METHOD jersey with neon-green trim, dark trousers |
| `mianja` | Mianja | `game/assets/characters/mianja/mianja.glb` | about 17k | Black snapback cap over a fade, "pro" METHOD jersey (V-neck, METHOD on both shoulders, grey slashes, sleeve M), dark trousers |

Both use the same skeleton, clips and code:

| | |
|---|---|
| Format | GLB with WebP textures (VRAM-compressed on import), skin 2048 px, others 1024 px or smaller, and a 256 × 300 `portrait.png` for the picker |
| Height | About 1.62–1.68 m, origin between the feet, facing +Z (the game turns them to -Z) |
| Skeleton | MPFB `game_engine` rig (Unreal-style names: `pelvis`, `spine_01..03`, `upperarm_l`, `hand_r`, `thigh_l`, …) |
| Clips (all loop) | `idle`, `walk` (authored at 1.125 m/s), `run` (3.5 m/s), `crouch_idle`, `crouch_walk` (0.733 m/s), `downed` (face-down crawl) |
| Game code | See below |
| Tests | `tests/integration/test_teammate_model.gd` |

Game code:

- `scripts/core/character_catalog.gd` lists the characters.
- `scripts/network/teammate_model.gd` picks the clip from speed, crouch and
  downed state, and scales playback to match ground speed (0.6×–2.2×). It
  also alpha-cuts hair, brows, lashes and corneas.
- `remote_avatar.gd` falls back to the old capsule figure if a model is
  missing.

The flashlight in the right hand is a small cylinder attached to `hand_r` in
Godot. The light itself comes from `RemoteAvatar`.

## How they are made

Everything is scripted in Blender 5.2 with the MPFB 2 extension, in
`tools/characters/`. Each character has a folder with a `character.json`:

- phenotype, skin, hair, brows and clothes (MakeHuman assets);
- face-shape targets;
- texture swaps;
- photo landmarks.

The folder also holds any textures the character uses.

1. `install_packs.py` installs the MakeHuman asset packs (*system*, *skins02*
   and *hair01*, all CC0) into MPFB.
2. `build_character.py` builds the body and applies the texture swaps:
   - Punky: a dark iris and black hair.
   - Tsila: a dark iris, darkened `eyebrow009` brows, and `jersey.png`.

   `make_jersey.py` makes `jersey.png` by repainting MakeHuman's
   `male_casualsuit04` into the black-and-green jersey: the `classic` style
   for Tsila, the `pro` style for Mianja.

   A `"cap"` entry adds a black snapback skinned to the head bone and drops
   the hair underneath it (Mianja).
3. `face_bake.py` projects the character's front photo onto the head:
   - It fits the photo to the model's eyes and lips.
   - It de-lights the photo and matches the skin tone to the cheeks (plus
     the neck, for a photo with harsh light).
   - It blends the photo in by a feathered face oval and how much each point
     faces forward.
   - Cycles bakes everything into one 2048 px skin texture.
4. `animate_export.py` writes the clips procedurally:
   - Poses are armature-space bone directions.
   - Legs use two-bone IK, so planted feet stay on the floor.
   - The clips are pushed to NLA tracks.
   - It bakes shape keys and clothing masks, decimates, names the materials
     by role (`<Name>_skin`, `_hair`, `_eyes`…) and exports the GLB.

Each step takes `<character_dir> <work_dir>`. The work folder holds
`face_src.png`:

```bash
blender -b --python build_character.py -- tsila <work>
blender -b <work>/base.blend --python face_bake.py -- tsila <work>
blender -b <work>/face.blend --python animate_export.py -- tsila <work> <work>/out/tsila.glb
```

Then:

1. Copy the GLB to `game/assets/characters/<id>/`.
2. Add a `portrait.png`.
3. Register the id in `CharacterCatalog`.
4. Run `tools/configure_imports.sh` and re-import.

## The face photos

All three faces come from photos of real people, used with their consent. **The
photos are never committed**: `.gitignore` excludes `face_src.*` and the
intermediate images. The baked skin textures and the portraits do show their
faces, and this repository is public.

If someone withdraws consent:

- remove their folder under `game/assets/characters/` and their catalog
  entry;
- or rebuild without `face_bake.py`, which gives MPFB's stock face.

## Known limits

- Head shapes come from MPFB sliders, not 3D scans. The likeness comes
  mostly from the projected photo, so it reads best from the front and fades
  toward the sides.
- Hair is cut-out cards: alpha scissor, no sorting.
- Animations are procedural keyframes, not motion capture.
- There are no interact, revive or death clips yet. Dead players are hidden
  and revives show the crouch.
