# Continuation Notes

Exact state and next steps. Updated 2026-10-17.

## Where things are

| Milestone | State |
|---|---|
| 1. Foundation | Done |
| 2. Solo vertical slice (*The Abandoned House*) | Done; desktop-verified; **phone hardware testing pending** |
| 3. Multiplayer | Done and verified on one machine (in-process tests + multi-process end-to-end on an impaired link, also on GitHub's Linux CI). **Internet verification pending**: needs a deployed host ([deployment.md](deployment.md)) |
| 4. Online economy + Maps 2 and 3 | Done: *The Black Ward*, *Last Train*, enemy profiles, map unlocks (offline + verified online), online shop |
| 5. Refinement, accessibility, Android profiling, signing | In progress: benchmark tool done (desktop baseline in [performance.md](performance.md)) |
| 6. Maps 4 and 5 | Later |

Branches: `main` (milestones 1–3 core), `network/multiplayer` (milestone 3,
PR #3 — open, CI green except dependency review), `content/maps-2-3`
(milestone 4, stacked on `network/multiplayer`). Merging needs the owner's
go-ahead.

## Verified (2026-10-17, Windows 11, Godot 4.7.2, Node 24.18)

- `tools/check.sh`: 142 scripts compile. `tools/lint.sh`: clean.
- `--test`: 95/95. `--smoke`: OK.
- `--bench` (desktop, 1280×720, High): all maps well inside the draw-call,
  triangle and script budgets; see [performance.md](performance.md).
- `services/lobby`: 18/18 tests, typecheck clean.
- `npm run e2e`: passed repeatedly at the default impairment and at 300 ms
  RTT ±80 ms / 10% loss, including the online shop.
- All three maps screenshot-checked (`tools/shots.sh <dir> --map=<id> [--watcher]`).

## Known gaps

1. Internet verification across separate networks (deploy, then the
   checklist in [deployment.md](deployment.md)).
2. No phone has run the game: touch controls, performance and thermals are
   unmeasured.
3. DTLS on the client; 5–6 player performance on phones; local-player
   reconciliation beyond "reject and correct".
4. The repository's dependency graph is off, so the dependency-review CI job
   fails until it is enabled (Settings → Code security → Dependency graph).
5. Online, METHOD files (collectibles) are not part of the verified wallet.

## Milestone 5 plan

1. **Android device pass:** install the debug APK on a real phone; run the
   manual QA checklist ([testing.md](testing.md)); run *Settings → Graphics →
   Run benchmark* at Medium and Low and record the result; tune the Mobile preset (shadows, lights per room, particle
   counts) to the 30 FPS baseline.
2. **Accessibility:** screen-reader-friendly focus order audit, colour-blind
   check of every state that uses colour, caption coverage of every cue
   (new maps included), remappable controller buttons.
3. **Animation/audio/UI refinement:** per-enemy idle/search variations,
   positional reverb zones (ward tile, station tunnel), menu diorama per map.
4. **Release:** signed Android build through `release.yml` with protected
   secrets (owner must create the keystore and secrets), store-listing copy
   that matches [asset-manifest.md](asset-manifest.md) honesty limits.
5. **Operations:** if a host is provided, deploy per
   [deployment.md](deployment.md) and run the internet verification.

## How to resume

```bash
git checkout content/maps-2-3 && git pull
export GODOT=/path/to/Godot_v4.7.2-stable
./tools/check.sh
./tools/godot.sh --headless --path game -- --test
(cd services/lobby && npm ci && npm test && npm run typecheck)
(cd services/lobby && GODOT_BIN="$GODOT" npm run e2e)
```

After any `tools/lint.sh --fix`, run `tools/check.sh` again: gdformat can
produce GDScript that Godot 4.7 does not parse (a multi-line lambda as the
last call argument).
