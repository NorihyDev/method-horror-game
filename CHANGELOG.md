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

### Fixed
- CI: shell scripts are executable; gitleaks no longer flags the fake test
  ticket secret.
- A NUL sentinel string produced Unicode warnings at every startup.
- Navigation bake no longer warns about agent radius/climb rounding.

### Security
- Server-side validation of every interaction (range, line of sight, rate,
  payload types/sizes), puzzle answers withheld from client snapshots, and
  lag-bounded crank timing.

[Unreleased]: https://github.com/NorihyDev/method-horror-game/commits/main
