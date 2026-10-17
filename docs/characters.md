# Characters

## Punky (co-op teammates)

Other players appear in co-op as **Punky**, a realistic, rigged and animated
human. One model is used for every teammate for now. The local player still
sees only their own hands and flashlight.

| | |
|---|---|
| File | `game/assets/characters/punky/punky.glb` (+ extracted WebP textures, VRAM-compressed on import) |
| Size | about 23.7k triangles across 7 meshes; skin 2048 px, others 1024 px or smaller; 1.5 MB GLB |
| Height | 1.68 m, origin between the feet, faces +Z (the game turns him to -Z) |
| Skeleton | MPFB `game_engine` rig (Unreal-style names: `pelvis`, `spine_01..03`, `upperarm_l`, `hand_r`, `thigh_l`, …) |
| Clips (all loop) | `idle`, `walk` (authored at 1.125 m/s), `run` (3.5 m/s), `crouch_idle`, `crouch_walk` (0.733 m/s), `downed` (face-down crawl) |
| Game code | `scripts/network/teammate_model.gd` picks the clip from speed, crouch and downed state, and scales playback to match ground speed (0.6×–2.2×). `remote_avatar.gd` falls back to the old capsule figure if the model is missing. |
| Test | `tests/integration/test_teammate_model.gd` |

The flashlight in his right hand is a small cylinder attached to `hand_r`
in Godot. The light itself still comes from `RemoteAvatar`.

### How he was made

Everything is scripted in Blender 5.2 with the MPFB 2 extension
(`tools/characters/punky/`):

1. `install_packs.py` installs the MakeHuman asset packs (*system*, *skins02*
   and *hair01*, all CC0) into MPFB.
2. `build_punky.py` builds the human: phenotype, face targets,
   `young_african_male` skin, high-poly eyes with `punky_eye.png` (dark iris),
   `culturalibre_hair_06` recoloured black (`punky_hair.png`), and the
   `male_casualsuit05` and `shoes03` outfit.
3. `face_bake.py` projects a front photo of the real person onto the head:
   - The photo is fitted to the model's eyes and lips.
   - It is de-lit to remove the studio lighting.
   - It is blended into the skin by a feathered face oval and how much each
     point faces forward.
   - Everything is baked by Cycles into one 2048 px skin texture
     (`punky_skin.png`).
   - The rest of the body is tinted to his skin tone.
4. `animate_export.py` writes the clips procedurally:
   - Poses are armature-space bone directions.
   - Legs use two-bone IK, so planted feet stay on the floor.
   - The clips are pushed to NLA tracks.
   - The script bakes in shape keys and clothing masks, decimates the body,
     hair and shoes, simplifies the materials and exports the GLB (WebP
     textures).

Commands (each takes the work folder that holds `face_src.png`):

```bash
blender -b --python build_punky.py -- <work>
blender -b <work>/punky_base.blend --python face_bake.py -- <work>
blender -b <work>/punky_face.blend --python animate_export.py -- <work> <work>/out/punky.glb
```

Then copy the GLB to `game/assets/characters/punky/`, run
`tools/configure_imports.sh` and re-import.

### The face photo

Punky's face comes from a photo of a real person, used with his consent. The
**photo itself is never committed**: `.gitignore` excludes `face_src.*` and the
intermediate images. The baked skin texture inside the GLB does show his face,
and this repository is public. If he withdraws consent:

- remove the GLB and its textures;
- re-run steps 2–4 without `face_bake.py`'s photo, giving MPFB's stock face.

### Known limits

- The head shape comes from MPFB sliders, not a 3D scan. The likeness comes
  mostly from the projected photo, so it reads best from the front and fades
  toward the sides.
- The hair is cut-out cards: alpha scissor, no sorting.
- The animations are procedural keyframes, not motion capture.
- There are no interact, revive or death clips yet. Dead players are hidden
  and revives show the crouch.
