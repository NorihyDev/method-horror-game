# Continuation Notes

Exact state when work paused (2026-10-16), and what to do next.

## Branches

| Branch | Contents | State |
|---|---|---|
| `main` | Project structure, procedural audio/texture generators | Stable |
| `gameplay/solo-vertical-slice` | Milestone 2: full solo game, tests, lint, CI, exports, docs | Done, verified locally |
| `network/multiplayer` | Milestone 3 work in progress (on top of the slice branch) | Partially done — see below |

Nothing has been merged into `main` beyond the foundation; review and merge
`gameplay/solo-vertical-slice` first.

## Verified so far

- Solo M2: 62 Godot tests pass; smoke mode passes; lint/format clean; Windows
  export and Android debug APK built and inspected; gitleaks clean.
- M3 (branch `network/multiplayer`):
  - `NetBridge` (server/client RPC endpoint, SceneMultiplayer auth gate,
    lobby, load barrier, snapshots, reconnect, revives, pings) — 2 in-process
    integration tests pass (server + 2 clients over localhost ENet; LAN host).
  - `NetProtocol` tickets/rate limits — unit tests pass, including tickets
    minted by the Node service.
  - Lobby service (`services/lobby`, Node 24 + TypeScript, zero runtime deps) —
    16 tests pass, `tsc --noEmit` clean.
  - `LobbyClient`, `DedicatedServer`, `OnlineFlow`, online loading path —
    written and compiling, **not yet exercised end to end**.

## Not done yet (Milestone 3)

1. `multiplayer_screen.gd` (create/join room, LAN host/join) and
   `lobby_screen.gd` (members, ready, owner start/kick/options, code copy).
   The current multiplayer screen still shows the M2 "unavailable" state.
2. Gameplay MP UI: ping action/markers, teammate status list, downed state
   (`PlayerController.set_downed`), revive progress, spectator camera when
   dead, RTT display (`show_ping`).
3. Online results text (verified wallet note, LAN "no coins") in
   `results_screen.gd`.
4. Translation keys used by the new code (the string-coverage test currently
   fails on `NET_*`, `PROMPT_REVIVE`, `NOTE_REVIVED`, `LOADING_WAITING_PLAYERS`,
   `MP_STATUS_*`, `MP_*` keys) — add to `en.json` and `fr.json`.
5. End-to-end multi-process test: lobby (`SPAWN_LOCAL_SERVERS=1`) + spawned
   dedicated server + two headless bot clients joining by code.
6. CI job for `services/lobby` (npm ci, test, typecheck); docs:
   `docs/networking.md`, `docs/deployment.md`; README status table.
7. Lint pass (`tools/lint.sh`) — new files not yet formatted; `REVIVE_RADIUS`
   const in `match_controller.gd` must move above the vars.
8. Internet verification across separate networks (needs a public host).

## How to resume

```bash
git checkout network/multiplayer
./tools/check.sh
./tools/godot.sh --headless --path game -- --test --filter=multiplayer
(cd services/lobby && npm ci && npm test && npx tsc --noEmit)
```
