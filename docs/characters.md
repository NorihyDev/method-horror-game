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
| `norihy` (default, first) | Norihy | `game/assets/characters/norihy/norihy.glb` | about 31k | Afro, teal baseball METHOD jersey |
| `punky` | Punky | `game/assets/characters/punky/punky.glb` | about 23.7k | Black mop of hair, grey jacket over a striped shirt, jeans |
| `tsila` | Tsila | `game/assets/characters/tsila/tsila.glb` | about 17k | Short curly hair, black METHOD jersey with neon-green trim, dark trousers |
| `paulino` | Paulino | `game/assets/characters/paulino/paulino.glb` | about 17k | Short curly hair, moustache and goatee, teal "baseball" METHOD jersey |
| `nox` | Nox | `game/assets/characters/nox/nox.glb` | about 17k | Short curly hair, heavier build, teal baseball jersey |
| `ninja` | Ninja | `game/assets/characters/ninja/ninja.glb` | about 17k | Curly hair, wire glasses, teal baseball jersey |
| `dekai` | Dekai | `game/assets/characters/dekai/dekai.glb` | about 24k | Box braids (modelled strands), black-and-orange pro METHOD jersey |
| `kanzaki` | Kanzaki | `game/assets/characters/kanzaki/kanzaki.glb` | about 31k | Short hair, black-and-white pro METHOD jersey with a Madagascar flag |
| `mianja` | Mianja | `game/assets/characters/mianja/mianja.glb` | about 17k | Black snapback cap over a fade, "pro" METHOD jersey (V-neck, METHOD on both shoulders, grey slashes, sleeve M), dark trousers |

Both use the same skeleton, clips and code:

| | |
|---|---|
| Format | GLB with WebP textures (VRAM-compressed on import), skin 2048 px, others 1024 px or smaller, and a 256 × 300 `portrait.png` (a crop of the person's photo) for the picker |
| Height | About 1.62–1.68 m, origin between the feet, facing +Z (the game turns them to -Z) |
| Skeleton | MPFB `game_engine` rig (Unreal-style names: `pelvis`, `spine_01..03`, `upperarm_l`, `hand_r`, `thigh_l`, …) |
| Clips (all loop) | `idle`, `walk` (1.29 m/s), `jog` (2.55 m/s; the game's normal walk is 2.7), `run` (4.57 m/s; sprint is 4.7), `crouch_idle`, `crouch_walk` (1.15 m/s), `downed` (face-down crawl). Heel strike and toe-off, opposite arm swing, pelvis turn and sway with the chest turning against it, level head. |
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

   The `baseball` style (Paulino, Nox, Ninja) is teal with pinstripes, grey
   piping, a METHOD wordmark and a Madagascar flag on the sleeve. It
   deliberately carries no third-party sponsor or team logos.

   `make_jersey.py <src> <out> <style>[+flag] [accent hex]` recolours the trim
   (orange for Dekai, white plus a flag for Kanzaki).

   A `"cap"` entry adds a black snapback skinned to the head bone and drops
   the hair underneath it (Mianja). A `"glasses"` entry adds wire frames
   with no lenses (Ninja).

   `prepare_photo.py` levels a tilted photo by its eyes and prints the
   landmarks for `character.json`. The face oval, cheek samples and
   de-light radius default to values derived from those landmarks.
   `"exclude"` ellipses keep parts of the photo off the face, such as real
   glasses with glare. `"ring_tint"` matches the skin where the photo fades
   out.
3. `fb_head.py` gives the character the person's real head, using KeenTools
   FaceBuilder (a Blender add-on; free for Blender, installed separately):
   - FaceBuilder detects the face in the photo, places its automatic pins
     and solves a 3D head and the camera that took the photo.
   - The script projects the photo onto that head itself, only inside a
     face oval (brows to chin), only where the surface faces the camera,
     and never where the photo shows background or hair. Everything else
     is clean skin in the exact colour at the edge of the face. The body is
     tinted to the same colour (`skin_tone.json`), so there is no seam.
   - Hair (`"hair_shell"`) is a shell grown from the real skull. Its front
     hairline is read from the photo. Its depth is fitted to the hair's
     outline in the photo: rays go out from the head and stop where the
     photo turns to background. The result is spread over the back and
     capped by `max_thickness`. Its texture is the photo's own hair where
     the photo saw it, and curls in the photo's hair colour elsewhere.
     On it sit two layers of crossed hair cards using a generated atlas of
     coiled strands, darker at the root and lighter at the tip. The cards
     are shorter and sparser at the hairline. `tufts` and `tuft_size` set
     the volume; `"tufts": 0` with `"keep_cards": true` keeps the MakeHuman
     hair strands instead (Punky).
   - The neck below the jaw takes the body's own neck shape, is cut away
     wherever the top garment covers it, and copies the body's skin weights
     there, so it stays attached when the character moves.
   - `"braids"` (Dekai) grows plaited tubes from the crown along the scalp
     and lets them hang. Only the braids in `front_keep` fall over the face.
   - `"photo": {"exclude": [[cx, cy, rx, ry], ...]}` keeps parts of the
     photo off the face, such as a hand (Kanzaki) or braids crossing it
     (Dekai). `"facebuilder": {"paint_lips": true}` paints lips the photo
     doesn't show.
   - A `"cap"` (Mianja) is a structured snapback: a raised front, six stitched
     panels and a rim band baked into its texture, a pitched flat brim and a
     button, with faded short hair below it. It is built the same way: a crown that follows the real
     skull above a plane from mid-forehead to the nape, a curved flat brim
     and a button.
   - The head is aligned to the body using the eyes, mouth and nose tip,
     joins it at the neck below the jersey collar, and is skinned to the
     neck and head bones. The MPFB head, eyeballs, brows and lashes are
     hidden or removed.
   - Glasses are refitted from the MPFB skull to the new one.
   - With `"facebuilder"` in `character.json`, run this before
     `face_bake.py`, and set `"photo": {"strength": 0}`.
4. `face_bake.py` projects the character's front photo onto the head
   (characters without FaceBuilder), or with `strength` 0 only tints the
   body to the photo's skin tone:
   - It fits the photo to the model's eyes and lips.
   - It de-lights the photo and matches the skin tone to the cheeks (plus
     the neck, for a photo with harsh light). The body tint is computed in
     linear light, which is how Cycles applies it, so the face and body
     match without a seam.
   - It blends the photo in by a feathered face oval and how much each point
     faces forward.
   - Cycles bakes everything into one 2048 px skin texture.
5. `animate_export.py` writes the clips procedurally:
   - Poses are armature-space bone directions.
   - Legs use two-bone IK, so planted feet stay on the floor.
   - The clips are pushed to NLA tracks.
   - It bakes shape keys and clothing masks, decimates, names the materials
     by role (`<Name>_skin`, `_hair`, `_eyes`…) and exports the GLB.

Each step takes `<character_dir> <work_dir>`. The work folder holds
`face_src.png`:

```bash
blender -b --python build_character.py -- tsila <work>
blender -b <work>/base.blend --python fb_head.py -- tsila <work>
blender -b <work>/base.blend --python face_bake.py -- tsila <work>
blender -b <work>/face.blend --python animate_export.py -- tsila <work> <work>/out/tsila.glb
```

Then:

1. Copy the GLB to `game/assets/characters/<id>/`.
2. Add a `portrait.png`.
3. Register the id in `CharacterCatalog`.
4. Run `tools/configure_imports.sh` and re-import.

## The face photos

Every face comes from a photo of a real person, used with their consent. **The
photos are never committed**: `.gitignore` excludes `face_src.*` and the
intermediate images. The baked skin textures do show their faces, and the
picker portraits (`portrait.png`, 256 × 300) are head-and-shoulders crops of
the photos themselves. This repository is public.

If someone withdraws consent:

- remove their folder under `game/assets/characters/` and their catalog
  entry;
- or rebuild without `fb_head.py` and with `"strength": 0`, which gives
  MPFB's stock face.

## Known limits

- Heads are FaceBuilder reconstructions from a single front photo: true to
  the face from the front and at three-quarters. The sides and back of the
  head, which the photo never saw, are filled in and mostly covered by hair.
- Hair is cut-out cards: alpha scissor, no sorting.
- Animations are procedural keyframes, not motion capture.
- There are no interact, revive or death clips yet. Dead players are hidden
  and revives show the crouch.
