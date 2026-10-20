# Monsters

Each map's enemy can use an imported, animated monster model instead of the
procedural body built in `scripts/ai/watcher_rig.gd`. `MonsterCatalog` lists
them by enemy style. When a model is missing, the procedural body is used,
so the game always works.

| Map | Enemy style | Model | Source pack |
|---|---|---|---|
| The House | `watcher` | Frankie: an emaciated, bloodied creature in a top hat | "Big Frankie" (itch.io) |
| The Black Ward | `sister` | A plague doctor | "Killers Pack" by Dime (itch.io) |
| Last Train | `lineman` | A miner whose helmet lamp sweeps the tunnels | "Killers Pack" by Dime |
| The Silent School | `headmistress` | A clown | "Killers Pack" by Dime |
| METHOD Facility | `subject` | Gravvok, a crawling creature (desaturated to flesh tones) | "GRAVVOK – Retro PSX Monster" (itch.io) |

The other models in the packs were left out: the Straw Reaper, the spider,
the Masked man, the Scarecrow and the Sea explorer.

## Licences and what is in the repository

| Model | Author | Terms on its itch.io page |
|---|---|---|
| Big Frankie (House) | imaginais, from *The Roach Hotel* | No licence stated; the author's reply to a licence question: "you can use it but needs to be credited on the roach hotel" |
| Gravvok (Facility) | imaginais | No licence stated (name your own price) |
| Doctor, Miner, Clown | TheDime (Killer Pack) | "cc0 Models Credit is Optional" |

All five are credited in the game's Credits screen and in
`THIRD_PARTY_NOTICES.md`, and all five are built into the release downloads
(APK, Windows, Linux). The converted models of the Killer Pack and Big
Frankie are committed under `game/assets/monsters/`. Gravvok's converted model
and the raw source packs (`game/assets/monster-pack/`) are not published in
this repository; the release builds are made on the maintainer's machine,
where they are installed. A checkout without a model plays that map's
procedural monster, and `test_monster_models.gd` skips any missing model.

## Building them

`tools/monsters/build_monster.py` (Blender 5.2), driven by
`tools/monsters/monsters.json`:

1. Extract the packs (7-Zip), then for each monster:

   ```bash
   blender -b --python tools/monsters/build_monster.py -- tools/monsters/monsters.json <id> <extracted packs dir> game/assets/monsters/<id>/<id>.glb
   ```

2. Run `tools/configure_imports.sh`, then re-import.

What the script does:

- Relinks textures whose file names changed in the pack, optionally tints
  them, and caps them at 1024 px.
- Reduces each mesh to the mobile budget (14k triangles; the Killers Pack
  originals are 170k–650k).
- **Rigged models** (Frankie, Gravvok): maps their own clips to the names
  the AI plays (`idle`, `walk`, `run`, `search`, `alert`, `windup`,
  `strike`, `recover`, `hit`, `open_door`).
- **Unrigged models** (Doctor, Miner, Clown):
  - Grounds the mesh and fits a humanoid skeleton to it (T-pose or
    arms-down).
  - Skins it by distance to each bone. Limbs stay on their own side, and in
    a T-pose baggy sleeves belong to the arms.
  - Writes those clips procedurally: a hunched, dragging walk, a sprint, a
    head-turning search, a roar, an overhead wind-up and strike, a flinch
    and a door shove.

`MonsterCatalog` scales each model to its target height (about 1.9–2.05 m,
so it fits through doors). The helmet lamp is placed on the miner's head
bone. Imported clips have no foot-plant track, so the rig emits two
footsteps per walk/run loop for the step sounds.
