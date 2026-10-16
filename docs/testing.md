# Testing

## Automated

```bash
./tools/check.sh                                     # import + compile every script (non-zero on error)
./tools/lint.sh                                      # gdformat --check + gdlint (pip install -r tools/requirements-dev.txt)
./tools/godot.sh --headless --path game -- --test    # unit + integration tests
./tools/godot.sh --headless --path game -- --smoke   # startup smoke: build map, nav, spawn enemy, 300 frames
```

The test runner (`game/tests/test_runner.gd`) runs inside the real project so
autoloads exist, uses isolated `test_*` save/settings files, prints one line per
test and exits `0` (pass), `1` (failures) or `2` (240 s watchdog — a hang is a
failure). `--filter=<substring>` selects files.

### Coverage (62 tests)

| File | What it proves |
|---|---|
| `unit/test_persistence.gd` | Atomic writes keep a backup; corrupted primary recovers from backup; tampered payload rejected; v0→v1 profile migration (incl. negative coins clamp); invalid stored names cleared |
| `unit/test_settings.gd` | Out-of-range/NaN/wrong-type values sanitized; presets → custom; persistence; per-category reset; viewport scale & battery saver applied; settings v0 migration; every visible setting has EN label + tooltip |
| `unit/test_name_validator.gd` | Normalization; length bounds; control, zero-width, bidi-override, BOM and markup characters rejected; international names accepted; BBCode escaping |
| `unit/test_objectives_and_solvability.gd` | Activation/completion order; early flags; cycles/unknown/optional-dependency validation; hint tiers; key-behind-own-door unsolvable; consumable counts; house & tutorial rules valid; **300 seeds all solvable, distinct spawns, deterministic**; code matches clues; validator flags a deliberately broken candidate |
| `unit/test_economy.gd` | Inventory capacity/stacking/atomic removes/malformed loads; reward idempotency; catalog prices; insufficient funds; owned/equip rules; serialization; reward math; local rewards apply once |
| `unit/test_snapshot_and_strings.gd` | Snapshot round trip through JSON; client snapshots hide answers; malformed snapshots sanitized/rejected; EN/FR key parity and placeholder counts; every key referenced in code exists |
| `integration/test_house_playthrough.gd` | **Full escape through the authority API** (front door, key, study, fuses incl. short-circuit + recovery, maglock, wrong then right code, gear/belt/workbench/motor, crank miss + lag-compensated hits, door, escape zone, victory result, rewards applied once); invalid/remote requests rejected; no interaction through walls; closed drawers block items; drop & recover key items; checkpoint restore; stale/future crank times ignored; tutorial chain |
| `integration/test_watcher.gd` | Never spawns near/in sight of players; hears loud noise and investigates; ignores inaudible noise; sees and chases a lit player in front; no vision through walls; telegraphed attack damages exactly once; checks the locker it saw you enter |

### Visual checks (need a GPU)

```bash
./tools/shots.sh <dir> [--watcher]          # 12 level reference shots + contact sheet
./tools/godot.sh --path game -- --uishots=<dir>   # every screen and overlay
```

### CI

`.github/workflows/ci.yml`: lint, import/compile, tests, smoke, gitleaks,
dependency review. `build.yml`: exports + exported-build smoke + APK.
**These workflows have not run on GitHub yet** (no remote). Their steps were
executed locally on Windows (lint, compile, tests, smoke, gitleaks, Windows and
Android exports); the Linux runner path is untested until the first push.

## Manual QA checklist

Run on at least one phone, one tablet and desktop before calling a milestone
"playable". Record device, OS, build, result.

### Touch & input
- [ ] Move with the left thumb while looking with the right — both work simultaneously.
- [ ] Hold RUN while moving and looking; release stops sprinting (hold mode).
- [ ] Tap a button while dragging look: camera does not jump; button fires.
- [ ] Look drag starting on a button does not rotate the camera.
- [ ] Floating vs fixed joystick; dead-zone slider has an effect.
- [ ] Layout editor: drag, save, reset; left-handed mirrors layout.
- [ ] Button size/opacity sliders apply live.
- [ ] Controller: full menu navigation with focus outlines; gameplay with sticks; rebinding keyboard keys with conflict swap.
- [ ] Mouse capture/release on pause, overlays and results.

### UI on devices
- [ ] Phone (≈20:9) and tablet (4:3): no clipped text, touch targets ≥ 48 dp, notch/cut-out safe areas respected, nothing under system gesture bars.
- [ ] French locale: no overflow.
- [ ] UI scale 0.85 and 1.3.

### World & collision
- [ ] Walk every room, the stairs both ways and the basement; no snagging on doorframes or stairs.
- [ ] Crouch under the rising garage door; cannot stand up under low ceilings.
- [ ] Doors cannot trap the player; locked doors stay closed.

### Hiding & enemy
- [ ] Hide/leave in each locker and wardrobe; camera and audio muffling correct.
- [ ] Watcher arrives after the grace period, away from you; prowling sounds before.
- [ ] Lamps flicker near it; keys jingle; captions show direction.
- [ ] Sprinting draws it; crouching near it does not; a crank miss draws it.
- [ ] Chase music starts/stops sensibly; heartbeat when close.
- [ ] Getting caught: wind-up visible, damage once, stumble; death screen options work.
- [ ] Hiding in front of it → it checks that locker.

### Flow
- [ ] First launch: splash → notice → name → menu. Second launch skips name.
- [ ] Solo full run on each difficulty; checkpoint restore after quitting from pause.
- [ ] Results: rewards shown once; Play again; Main menu.
- [ ] Tutorial completes.
- [ ] App to background mid-match (home button / alt-tab): solo pauses; resume works.
- [ ] Android back: closes overlays → pause → confirm quit from main menu.

### Audio & graphics settings
- [ ] Every volume slider audibly changes its bus; mute; night mode; mono.
- [ ] Subtitles on the tape; sound captions on/off; caption size/background.
- [ ] Low/Medium/High presets visibly differ; render scale and FSR; MSAA; shadows off/low/high; dust particles; fog distance; exposure.
- [ ] Battery saver caps at 30 FPS.
- [ ] Settings persist after restart; "Undo changes" restores.

### Failure handling
- [ ] Corrupt `profile.json` by hand → game reports recovery from backup.
- [ ] Delete local data → back to name entry with defaults.
