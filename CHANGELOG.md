# Changelog

All notable changes are recorded here. Versions follow semantic versioning;
dates are ISO 8601.

## [Unreleased]

### Added
- Godot 4.7.2-stable project (Mobile renderer), METHOD theme, four focused
  autoload services, atomic checksummed saves with backups and migrations.
- Procedural audio (74 sounds/loops) and texture (11 surfaces) generators with
  committed outputs and import conventions.
- *The Abandoned House*: nine ground-floor rooms, stairwell, basement and
  garage exit; seeded item placement proven solvable; fuse-circuit, painted-code
  keypad, repair and crank-timing puzzles; optional files and tape.
- *Orientation* tutorial with no hostile enemy.
- The Watcher: articulated procedural rig with ten animations; sight/hearing/
  light/crouch perception, investigate/search/chase/attack/check-hiding states,
  door use, stuck recovery, flicker and key cues.
- First-person controller with stamina, crouch, flashlight battery, hiding,
  inventory and damage; multitouch controls with layout editor; controller and
  rebindable keyboard input.
- Full menu flow (splash, notice, name entry, main menu with 3D diorama, solo
  setup, multiplayer status, loading/briefing, HUD, pause with hints, inventory,
  notes, keypad, death, results, settings, shop, chapters, profile, credits).
- Local coin economy with idempotent rewards and a cosmetic shop.
- English and French localization.
- 62 automated tests, startup smoke mode, lint/format tooling, CI/build/release
  workflows, export presets for Windows, Linux, Linux dedicated server and
  Android.
- Online co-op: lobby service (guest identity, private rooms with six-digit
  codes and optional passwords, rate limits, room-bound tickets, server
  allocation, verified wallet), dedicated server mode, authoritative
  `NetBridge` with a server-controlled start barrier, snapshots and reconnect.
- Multiplayer menus: create/join room, lobby (ready, owner controls, kick,
  start feedback, ping), LAN development mode labeled as lower trust with no
  coins.
- In-match co-op: teammate status list, pings, downed/revive/bleed-out,
  spectating after death or escape, round-trip time, online results with the
  verified wallet balance.
- Online end-to-end test with separate processes and an impaired-link relay;
  networking and deployment documentation.

- *The Black Ward*: a clinical wing with card doors, an emergency power board
  (relay + breaker pattern from a schematic), observation monitors, a
  night-round code and a bay shutter; The Sister, a blind enemy who hunts by
  sound and hums until she does.
- *Last Train*: a sealed station with a collapsed exit, power cells, a signal
  lever frame and route card, a help point and an evacuation train to hold
  out for; ghost trains as moving sound sources that mask noise; The
  Lineman, who sees only along his headlamp beam.
- Enemy profiles: one tested state machine, per-map senses, speeds, sounds
  and body styles. 26 new procedural sounds, 4 new surfaces, 5 items.
- Map unlocks in order: offline per device, online verified by the lobby
  service, which also limits in-lobby map changes to the owner's unlocks.
- The shop can use the verified online wallet with idempotent purchases.

### Fixed
- Multiplayer: a client could send Ready before its connection existed;
  server-side leaves, kicks and flood disconnects did not mark players away.
- The house's basement cage gate and door materials were never applied.
- The enemy could pick a furniture top as a navigation target.
- CI: shell scripts are executable; gitleaks no longer flags the fake test
  ticket secret.
- A NUL sentinel string produced Unicode warnings at every startup.
- Navigation bake no longer warns about agent radius/climb rounding.

### Security
- Server-side validation of every interaction (range, line of sight, rate,
  payload types/sizes), puzzle answers withheld from client snapshots, and
  lag-bounded crank timing.

[Unreleased]: https://github.com/NorihyDev/method-horror-game/commits/main
