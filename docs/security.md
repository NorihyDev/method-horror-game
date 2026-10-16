# Security & Threat Model

Scope: the game client, the solo/authority rules, local saves, and the planned
online services (lobby + dedicated server, Milestone 3). Nothing here claims
perfect anti-cheat, unhackable saves or certification.

## Trust boundaries

| Component | Trusted for | Not trusted for |
|---|---|---|
| Player device (client) | Its own input, its own presentation | Anything shared: items, doors, objectives, damage, rewards, timing |
| Solo process | Everything — it is its own authority | Online currency (local wallet stays local) |
| Dedicated server (M3) | Match state, enemy AI, validation, results | Identity (comes from lobby tickets) |
| Lobby service (M3) | Guest identity, rooms, tickets, verified wallet | Client-supplied prices, outcomes, timestamps |
| LAN listen host (dev) | Nothing beyond that LAN test session | Never mints online currency |

## Threats and mitigations

| Threat | Mitigation (status) |
|---|---|
| **Unauthenticated / forged RPCs** | Every mutation goes through `MatchController.server_interact` (implemented). Online: gameplay RPCs accepted only after a valid room-bound ticket (M3, planned). |
| **Malformed payloads** | Interaction args limited to ≤4 keys, int/bool/finite float/short strings; sub-target and action length bounded; unknown entities/players rejected (implemented, tested). |
| **Impossible interactions** (range, through walls, closed drawers, while hidden) | Eye-to-target range + tolerance, server-side line of sight excluding the target's own colliders, drawer-open check, hidden players can only use their own hiding spot (implemented, tested). |
| **Spam / brute force** | Per-player interaction rate limit (120 ms); keypad attempt cooldown 1 s and noise on wrong codes; crank cooldown (implemented). Online room create/join/guess rate limits per identity and IP (M3). |
| **Timing manipulation** (crank) | Client may report a press time only within [now−0.4 s, now+0.05 s]; otherwise server time is used (implemented, tested). |
| **Movement manipulation / noise cheating** | Noise is derived on the authority from reported movement; non-finite positions are dropped; jumps >3 m produce no step noise. Online: speed/teleport validation and correction (M3). |
| **Duplicate pickups / conflicting puzzle actions** | Single authority, atomic state changes; taking an item checks `taken` first; tested with repeated requests. |
| **Duplicate rewards** | Rewards keyed by `match:<match_id>`; wallet refuses repeated ids (tested). Online: server-side idempotent ledger (M3/M4). |
| **Purchase manipulation** | Prices read from the catalog, never from the caller; no partial charge on failure; balance cannot go negative (tested). |
| **Save tampering** | Checksummed envelope detects corruption/casual edits and falls back to backup; **local coins are explicitly untrusted** and never imported online. |
| **Malicious display names** | Length 2–20, control/bidi/zero-width/private-use/markup characters rejected (client; mirrored server-side in M3); names rendered as plain text with auto-translation disabled; names never grant access. |
| **Room enumeration** (M3) | 6-digit codes are short-lived locators only; joining needs an authenticated guest session; guesses are rate-limited; no public room directory; optional room password hashed server-side (scrypt). |
| **Leaked secrets** | No keys/tokens in the repo; `.gitignore` blocks keystores/env files; gitleaks runs in CI (clean on current history); release keystore exists only as a protected CI secret written to a temp file and removed in `always()`. |
| **Unsafe deserialization** | Network/snapshot data is plain dictionaries/arrays; `MatchState.from_snapshot` sanitizes types and ranges; no objects, resources or file paths are accepted from the network (Godot's object decoding stays disabled). |
| **Puzzle answer leakage** | `MatchState.client_snapshot()` strips seeded answers; entities publish only what the world shows. The dev objective inspector (F3) exists only in debug builds. |

## Transport

- Backend APIs (M3): HTTPS only, TLS terminated by a reverse proxy.
- Gameplay (M3): ENet over UDP. **Plain ENet is not encrypted.** Godot's
  `ENetConnection.dtls_server_setup/dtls_client_setup` provides DTLS; the plan
  is DTLS for internet sessions with a certificate on the dedicated server.
  LAN development mode is labeled unencrypted.

## Local data

Stored under the Godot user directory (`method_horror`): profile/progress/
wallet/cosmetics (`profile.json`), settings, and a checkpoint, each with a
`.bak`. No analytics, advertising or tracking SDKs; no personal data beyond the
chosen display name. *Profile → Delete local data* removes everything.

## Known gaps

- A malicious LAN host can do anything in its own session; LAN is for
  development only and cannot affect online wallets.
- Client-side movement is trusted for responsiveness in solo; online correction
  is Milestone 3 work.
- No secure-storage integration yet (no tokens exist until M3).

## Reporting

See [SECURITY.md](../SECURITY.md).
