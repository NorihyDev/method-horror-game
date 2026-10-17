# Continuation Notes

Exact state and next steps. Updated 2026-10-17.

## Where things are

| Milestone | State |
|---|---|
| 1. Foundation | Done |
| 2. Solo vertical slice (*The Abandoned House*) | Done; desktop-verified; **phone hardware testing pending** |
| 3. Multiplayer | Implemented and verified on one machine (in-process tests + multi-process end-to-end with an impaired link). **Internet verification pending**: needs a deployed host ([deployment.md](deployment.md)) |
| 4. Online economy + Maps 2 and 3 | Next |
| 5. Refinement, accessibility, Android profiling, signing | Later |
| 6. Maps 4 and 5 | Later |

Branches: `main` (merged work), `network/multiplayer` (milestone 3; merged
through a pull request once CI passes on GitHub).

## Verified (2026-10-17, Windows 11, Godot 4.7.2, Node 24.18)

- `tools/check.sh`: 120 scripts compile. `tools/lint.sh`: clean.
- `--test`: 71/71. `--smoke`: OK.
- `services/lobby`: 16/16 tests, typecheck clean.
- `npm run e2e`: passed at 120 ms RTT ±30 ms / 3% loss (default) and at
  300 ms RTT ±80 ms / 10% loss.
- Multiplayer screens screenshot-checked (`--uishots-mp`).

## Not done in milestone 3

1. Internet verification across separate networks (deploy per
   [deployment.md](deployment.md), then the checklist there).
2. DTLS on the client (`NetBridge.join` supports a trusted certificate; the
   flow does not pass one yet).
3. 5–6 players: protocol allows them; UI caps at 4 until a 6-client sync and
   performance run passes.
4. Local-player reconciliation beyond "reject and correct".

## Milestone 4 plan

1. **Online economy UI:** shop and profile show the online wallet when signed
   in (purchases through `/v1/shop/purchase` with idempotency keys), clearly
   separate from offline coins.
2. **Map progression:** unlock rules per map (solo progress offline; online
   completions from the lobby's `completions` table).
3. **Map 2 — *The Black Ward*:** distinct medical-facility layout, access-card
   doors, emergency circuits, observation rooms, a new enemy with a different
   perception rule; data-driven rules + solvability proof like the house.
4. **Map 3 — *Last Train*:** station/maintenance layout, signal routing,
   moving sound sources, evacuation objective, its own enemy setup.
5. Each new map: collision, navigation, safe spawns, hiding spots, validated
   item placement (300-seed solvability test), ambience, exit, playthrough
   integration test, lobby `PLAYABLE_MAPS` + reward table update (the lobby
   test that expects `black_ward` to be unavailable must change then).

## How to resume

```bash
git checkout main && git pull
export GODOT=/path/to/Godot_v4.7.2-stable
./tools/check.sh
./tools/godot.sh --headless --path game -- --test
(cd services/lobby && npm ci && npm test && npm run typecheck)
(cd services/lobby && GODOT_BIN="$GODOT" npm run e2e)
```

After any `tools/lint.sh --fix`, run `tools/check.sh` again: gdformat can
produce GDScript that Godot 4.7 does not parse (a multi-line lambda as the
last call argument).
