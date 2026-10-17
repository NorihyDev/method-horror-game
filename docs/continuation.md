# Continuation Notes

Exact state and next steps. Updated 2026-10-17.

## Where things are

| Milestone | State |
|---|---|
| 1. Foundation | Done |
| 2. Solo vertical slice (*The Abandoned House*) | Done; desktop-verified; **phone hardware testing pending** |
| 3. Multiplayer | Done. Online rooms run through the **deployed Cloudflare relay** (room creator hosts); verified with two Godot clients through it on one PC. **Two phones on different networks: not tried yet** ([deployment.md](deployment.md#testing-with-two-phones-on-different-networks)) |
| 4. Online economy + Maps 2 and 3 | Done: *The Black Ward*, *Last Train*, enemy profiles, map unlocks (offline + verified online), online shop |
| 5. Refinement, accessibility, Android profiling, signing | In progress: benchmark tool (desktop baseline in [performance.md](performance.md)), accessibility audit and fixes, debug APK rebuilt with three maps |
| 6. Maps 4 and 5 | Done: *The Silent School* (Headmistress) and *METHOD Facility* (Subject Zero), tested and screenshot-checked |

Branches: `main` (milestones 1–3 core), `network/multiplayer` (milestone 3,
PR #3), `content/maps-2-3` (milestone 4 + milestone 5 work so far, PR #4,
stacked on `network/multiplayer`), `content/maps-4-5` (milestone 6, stacked
on `content/maps-2-3`), `online/relay` (internet co-op through Cloudflare,
stacked on `content/maps-4-5`). All open; CI green except dependency review.
Merging needs the owner's go-ahead, in that order.

## Verified (2026-10-17, Windows 11, Godot 4.7.2, Node 24.18)

- `tools/check.sh`: 153 scripts compile. `tools/lint.sh`: clean.
- `--test`: 114/114. `--smoke`: OK.
- `--bench` (desktop, 1280×720, High/Medium/Low): 60 FPS everywhere; the
  school and facility exceed the 250 draw-call budget at High and Medium
  (fit at Low); see [performance.md](performance.md).
- `services/lobby`: 18/18 tests, typecheck clean.
- Relay: 7/7 unit tests; 20/20 protocol checks locally and against the
  deployed Worker; two-client Godot e2e passed locally and through the
  deployed relay (host 18 frames/s, guest 12 frames/s).
- All five maps screenshot-checked (`tools/shots.sh <dir> --map=<id> [--watcher]`).

## Known gaps

0. Maps 4–5 draw 255–285 draw calls at High/Medium (budget 250); fine on
   the desktop, to confirm on a phone (see [performance.md](performance.md)).

1. Two phones on different networks through the deployed relay (steps in
   [deployment.md](deployment.md#testing-with-two-phones-on-different-networks)).
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
2. **Accessibility:** automated audit done (`test_accessibility.gd`:
   contrast, target size, screen-reader names, focus, caption coverage).
   Remaining: try TalkBack/Narrator on real devices, colour-blind check of
   states that use colour, remappable controller buttons, and decide whether
   phones should default to a larger interface scale (targets are ~32 dp at
   1.0).
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
(cd services/relay && npm ci && npm test && npm run typecheck)
(cd services/relay && npx wrangler dev --port 8787 &) && sleep 15
(cd services/relay && GODOT_BIN="$GODOT" npm run e2e)
```

After any `tools/lint.sh --fix`, run `tools/check.sh` again: gdformat can
produce GDScript that Godot 4.7 does not parse (a multi-line lambda as the
last call argument).
