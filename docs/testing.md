# Testing

## Automated

```bash
./tools/check.sh                                     # import + compile every script (non-zero on error)
./tools/lint.sh                                      # gdformat --check + gdlint (pip install -r tools/requirements-dev.txt)
./tools/godot.sh --headless --path game -- --test    # unit + integration tests
./tools/godot.sh --headless --path game -- --smoke   # startup smoke: build map, nav, spawn enemy, 300 frames
(cd services/lobby && npm ci && npm test && npm run typecheck)   # lobby service (16 tests)
(cd services/lobby && GODOT_BIN=/path/to/godot npm run e2e)     # online end to end, separate processes
```

The test runner (`game/tests/test_runner.gd`) runs inside the real project so
autoloads exist, uses isolated `test_*` save/settings files, prints one line per
test and exits `0` (pass), `1` (failures) or `2` (240 s watchdog — a hang is a
failure). `--filter=<substring>` selects files.

### Coverage (114 Godot tests + 18 lobby tests + 1 end-to-end run)

| File | What it proves |
|---|---|
| `unit/test_persistence.gd` | Atomic writes keep a backup; corrupted primary recovers from backup; tampered payload rejected; v0→v1 profile migration (incl. negative coins clamp); invalid stored names cleared |
| `unit/test_settings.gd` | Out-of-range/NaN/wrong-type values sanitized; presets → custom; persistence; per-category reset; viewport scale & battery saver applied; settings v0 migration; every visible setting has EN label + tooltip |
| `unit/test_name_validator.gd` | Normalization; length bounds; control, zero-width, bidi-override, BOM and markup characters rejected; international names accepted; BBCode escaping |
| `unit/test_objectives_and_solvability.gd` | Activation/completion order; early flags; cycles/unknown/optional-dependency validation; hint tiers; key-behind-own-door unsolvable; consumable counts; house & tutorial rules valid; **300 seeds all solvable, distinct spawns, deterministic**; code matches clues; validator flags a deliberately broken candidate |
| `unit/test_economy.gd` | Inventory capacity/stacking/atomic removes/malformed loads; reward idempotency; catalog prices; insufficient funds; owned/equip rules; serialization; reward math; local rewards apply once |
| `unit/test_snapshot_and_strings.gd` | Snapshot round trip through JSON; client snapshots hide answers; malformed snapshots sanitized/rejected; EN/FR key parity and placeholder counts; every key referenced in code exists |
| `integration/test_house_playthrough.gd` | **Full escape through the authority API** (front door, key, study, fuses incl. short-circuit + recovery, maglock, wrong then right code, gear/belt/workbench/motor, crank miss + lag-compensated hits, door, escape zone, victory result, rewards applied once); invalid/remote requests rejected; no interaction through walls; closed drawers block items; drop & recover key items; checkpoint restore; stale/future crank times ignored; tutorial chain |
| `unit/test_net_protocol.gd` | Ticket signing/verification (bad signature, wrong room, expired, malformed, oversize), a ticket minted by the Node service verifies in Godot, constant-time compare, rate-limit buckets, finite-value checks |
| `integration/test_multiplayer.gd` | Server + 2 clients over real localhost ENet in one process: lobby/ownership, wrong-room and expired tickets refused, ready/start barrier, late join refused, clients never get puzzle answers, replicated interaction, two players racing for one pickup (exactly one wins), teleport/NaN/server-only RPC/malformed/kick cheats ignored, disconnect + reconnect into the same slot with progress and inventory; both new maps replicate (enemy profile, powered monitors, ghost trains); Maps 4–5 replicate (Headmistress and Subject Zero profiles, music box state, school power, Subject Zero gaining sight on the client, lift progress); six clients join, start together, see each other move and share state, with the server broadcast cost measured; downed players replicate and cannot act, out-of-range revive refused, revive completes for revive_time, walking away cancels, bleed-out kills, last player down ends the match in defeat; LAN host plays and hosts |
| `services/lobby/test/*.test.ts` | Online map progression verified from completions (and passed to the game server), reward table and prerequisites match the game's map resources, guest sessions (validation, auth, profile, logout, protocol check), name rules mirrored from the client, rooms (create, join by code, passwords, full, started, member reconnect tickets, owner-only close, expiry), owner flag in tickets, code-guess and guest-creation rate limits, ticket and server-signature binding/expiry, scrypt passwords, idempotent match credits and purchases |
| `services/lobby/scripts/e2e-online.ts` | Real processes: lobby + spawned dedicated server + 2 headless clients driving the real screens: create, wrong password and unknown code refused, join by code, ready, start barrier, replicated interaction, drop + reconnect with full snapshot, leave, result credited in the verified wallet, the real shop screen loads the verified balance and the service refuses an unaffordable purchase; all game traffic through a relay adding latency, jitter and loss |
| `unit/test_progression.gd` | All five maps unlock in order on this device; a locked map cannot be started; every map lists all its recovered files on the progress screen, readable in EN and FR |
| `integration/test_ward_playthrough.gd` | Full Black Ward escape through the authority API: shutter with no power, card reader without/with card, generator without relay, wrong breaker pattern trips the board, right pattern powers the wing, monitors + roster give the code, wrong then right code, console, shutter, escape; console refuses without power; monitors dark until power |
| `integration/test_sister.gd` | The ward uses the sister profile; she ignores a lit player in plain sight; close footsteps start a hunt, crouched ones do not; distant or machine noise is only investigated; silence loses her; bumping into her is not safe |
| `integration/test_station_playthrough.gd` | Full Last Train escape: collapsed exit, help point refuses without a route, key, frame refuses without power, two cells, wrong route refused, right route set, train called, hold-out, boarding; the platform edge stays closed; ghost trains mask footsteps near the tracks only; The Lineman sees along his beam and not beside it |
| `integration/test_school_playthrough.gd` | Full Silent School escape: chained doors, the music box seeded beside the wing key (and silenced), wing door, PA refused without power, main breaker, PA tune queued for the speakers and replayable, a plain scale refused on the chimes, the right tune releases the tuned office lock, bolt cutters cut the chain, escape; the Headmistress is held only when watched in light (torch beam or lit room), holds still even while hunting, and moves the moment the gaze leaves |
| `integration/test_facility_playthrough.gd` | Full METHOD Facility escape: dead lift, card door, maglock release, lift refused without power, two cells start the generator, monitors + protocol give the code (wrong code first), lift called, hold-out, ride up; the shaft gate holds until arrival; Subject Zero ignores a lit player while blind and sees once the power returns |
| `unit/test_objectives_and_solvability.gd` (Maps 4–5) | 300 seeds each solvable and deterministic; the school tune uses each bar once and is never a plain scale; the facility code equals the cell readings in protocol order; validators flag items placed behind their own locks |
| `integration/test_accessibility.gd` | Every text colour reaches WCAG 2.2 AA (4.5:1) on every surface, button text in every state too; every menu screen, every settings tab and the confirm dialog: each interactive control is at least 48 px (base resolution), has an accessible name for screen readers and can take keyboard/controller focus; every enemy cue has a caption in EN and FR; looping sounds (humming, trains, motors) caption while audible and not when far or stopped |
| `unit/test_benchmark.gd` | Benchmark cost percentiles and the per-map summary line, including maps that report an error |
| `integration/test_watcher.gd` | Never spawns near/in sight of players; hears loud noise and investigates; ignores inaudible noise; sees and chases a lit player in front; no vision through walls; telegraphed attack damages exactly once; checks the locker it saw you enter |

### Visual checks (need a GPU)

```bash
./tools/shots.sh <dir> [--watcher]          # 12 level reference shots + contact sheet
./tools/godot.sh --path game -- --uishots=<dir>   # every screen and overlay
./tools/godot.sh --path game -- --uishots=<dir> --uishots-mp --lobby=http://127.0.0.1:9   # multiplayer screens
```

### CI

`.github/workflows/ci.yml`: lint, import/compile, tests, smoke, lobby service
tests + typecheck, online end-to-end, gitleaks, dependency review.
`build.yml`: exports + exported-build smoke + APK.

The first GitHub run (2026-10-16, push to `main`) **failed**: shell scripts
were committed from Windows without the executable bit, and gitleaks flagged
the fake test ticket secret. Both are fixed on `network/multiplayer`; the
Linux runner results for that branch are recorded in its pull request.

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

### Accessibility (needs a device and assistive tech)
- [ ] With TalkBack (Android) or Narrator / NVDA (Windows), menus read button and setting names; note what is missing (Godot's AccessKit support differs by platform).
- [ ] Sound captions on, eyes only: the Sister's humming, ghost trains, the arriving train, the garage motor and fast monitor beeps all show a caption with a direction.
- [ ] Interface scale 1.3: every screen still fits without clipped buttons.
- [ ] Touch: every menu button is easy to hit with a thumb on the smallest test phone (targets are about 32 dp at scale 1.0 on a 6.3" 1080p screen; Android recommends 48 dp, reached at roughly interface scale 1.3).

### Audio & graphics settings
- [ ] Every volume slider audibly changes its bus; mute; night mode; mono.
- [ ] Subtitles on the tape; sound captions on/off; caption size/background.
- [ ] Low/Medium/High presets visibly differ; render scale and FSR; MSAA; shadows off/low/high; dust particles; fog distance; exposure.
- [ ] Battery saver caps at 30 FPS.
- [ ] Settings persist after restart; "Undo changes" restores.

### Multiplayer (two or more devices)
- [ ] Create a room; the code shows and copies; a second device joins with the code (and the password when set).
- [ ] Wrong code, wrong password, full room and "match started" each show a clear message.
- [ ] Owner changes map/difficulty; members see it. Owner removes a member; they are told and cannot rejoin.
- [ ] Start is disabled until everyone is ready, with the reason shown; everyone enters the match together.
- [ ] Doors, items, fuses, keypad and crank changes appear on every device; only one player gets a contested item.
- [ ] Pings (Q / RB / PING button) appear for everyone with name, kind and distance.
- [ ] Getting downed: bleed-out bar, look-only; a teammate's hold-to-revive restores you; walking away cancels.
- [ ] Bleeding out → spectating a teammate; Interact/USE switches; pause → leave works.
- [ ] Turn Wi-Fi off mid-match for < 60 s: "Reconnecting…", then back in the same match with your items. Teammates see "Reconnecting…".
- [ ] Pause menu never freezes the match for others.
- [ ] Results: online note and wallet balance; LAN says no coins.
- [ ] LAN: host shows its address; a second device joins by IP; both labeled LAN test.

### Failure handling
- [ ] Corrupt `profile.json` by hand → game reports recovery from backup.
- [ ] Delete local data → back to name entry with defaults.
