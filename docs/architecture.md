# Architecture

## Engine and renderer

- **Godot 4.7.2-stable**, pinned in `tools/godot-version.txt`, CI and docs.
- **Mobile renderer** (Vulkan) for every platform so desktop development sees
  the same feature set Android gets. Effects used: dynamic omni/spot lights,
  positional shadows (bounded by settings), glow, depth fog, ACES tonemapping,
  color adjustment, FSR 1 upscaling, MSAA. Not used (Forward+-only or too
  costly): SDFGI, VoxelGI, SSAO/SSR/SSIL, volumetric fog.
- Typed GDScript everywhere. Godot 4.7 treats Variant-inferred `:=` as an
  error, which keeps types honest.

## Runtime layout

```
App (boot.tscn)                     process_mode ALWAYS (UI works while paused)
├─ World (Node3D, PAUSABLE)         the current 3D world: MenuDiorama or a Level
│  └─ Level (MapBase subclass)
│     ├─ Navigation (NavigationRegion3D)
│     │  ├─ WorldCollision (StaticBody3D, layer "world")
│     │  ├─ PropCollision  (StaticBody3D, layer "prop")
│     │  └─ merged meshes (one per room × material)
│     ├─ Lights · Entities · Players · Enemies · Environment
│     └─ Match (MatchController)
├─ PostFX (CanvasLayer 5)          vignette/grain/damage/locker slats/flash
├─ Screens (CanvasLayer 10)        screen stack (Screen subclasses)
├─ Modals (CanvasLayer 20)         confirm/alert dialogs
└─ Overlay (CanvasLayer 30)        captions, toasts, fades
```

Autoloads (four, each with one responsibility):

| Autoload | Responsibility |
|---|---|
| `Settings` | Schema-driven preferences, presets, persistence, applying viewport/window/input/locale settings |
| `Saves` | Local profile, progress, local wallet + cosmetics, checkpoints, schema migrations |
| `AudioService` | Buses/effects, pooled playback, music/ambience crossfades, captions & subtitles |
| `Session` | Content registries (maps/difficulties/items), match start/finish flow, app lifecycle (background, Android back) |

## Rules vs presentation

Pure rule classes (no nodes, fully unit-tested):

- `ObjectiveGraph` — objective dependencies, activation/completion from flags, hint tiers, validation (cycles, unknown/optional deps, single final).
- `ReachabilitySolver` + `MapRules` — zones/gates/actions/item slots; seeded variants guaranteed solvable.
- `Inventory`, `Wallet`, `CosmeticCatalog`, `RewardCalculator`, `NameValidator`, `SaveIO`, `MatchState`.

`MatchController` is the **only** place world state changes:

```
client input ─► PlayerController ─► mc.request_interact(id, sub, action, args)
                                        │ solo: direct call
                                        │ online (M3): RPC to server
                                        ▼
                         mc.server_interact(pid, …)   ← validation:
                           entity exists · player alive · not hidden elsewhere
                           rate limit · argument types/sizes/finiteness
                           eye-to-entity range · line of sight (own colliders excluded)
                                        ▼
                         entity.authority_interact(ctx) ─► mc.set_entity_state / give_item /
                                                            set_flag / emit_noise / world_sound
                                        ▼
                         entity.apply_state(state)  (presentation; idempotent)
```

Entities store **public** state only (door open/locked, which pickups exist and
where, painted digits). Puzzle answers (`state.variant`) never leave the
authority; `MatchState.client_snapshot()` strips them.

Noise is derived on the authority from reported movement (step distance ×
stance) — clients never report "I was quiet".

## Levels

Levels are built procedurally in code (`GeoBuilder`, `PropFactory`), which keeps
them diff-able and asset-free:

- Walls are two half-thickness boxes so each side gets its room's material;
  geometry is merged per room+material (≈ 60–80 draw batches for the house).
- UVs are world-scaled planar projections, so one texture sample per pixel gives
  correct tiling and normal-map tangents. A low-frequency second sample breaks
  repetition; a storey-relative term adds floor grime.
- Collision layers: `world`(1) walls/floors/locked doors; `player`(2); `enemy`(3);
  `interactable`(4) raycast targets; `door`(5) door panels; `trigger`(6);
  `prop`(7) furniture (blocks movement, navigation and enemy sight, not
  interaction rays).
- Navigation is baked at load from `world|prop` colliders. Locked doors are on
  the world layer so the enemy cannot path through them; unlocking re-bakes on a
  thread.

## Data

- `resources/maps/*.tres` — `MapDefinition` (status, builder & rules scripts, rewards, ambience).
- `resources/difficulties/*.tres` — `DifficultyDefinition` (every tunable rule).
- `resources/items/*.tres` — `ItemDefinition`.
- `localization/{en,fr}.json` — string tables loaded at runtime into `TranslationServer`.

## Saves

`SaveIO.write_atomic`: write `*.tmp` → move current file to `*.bak` → rename tmp.
Envelope: `{format, checksum (SHA-256 of payload text), payload (JSON text)}`.
Reads fall back to the backup and report recovery to the player. Profile and
settings carry `schema_version` with forward migrations (tested from v0).

## Scene transitions and cleanup

`App.set_world()` frees the previous world; `Session.quit_to_menu()` stops
world audio, unpauses, disables post-FX and dynamic resolution. Screens are
freed when popped. Tween/timer callbacks guard `is_inside_tree()`.

## Multiplayer (planned, M3)

See [networking.md](networking.md). The authority path above is already the
server path; M3 adds the transport (`net` bridge on `MatchController`), the
lobby service and the dedicated server entry point.
