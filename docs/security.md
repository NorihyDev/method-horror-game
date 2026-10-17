# Security & Threat Model

Scope: the game client, the solo/authority rules, local saves, and the online
services (lobby + dedicated server). Nothing here claims perfect anti-cheat,
unhackable saves or certification. The online services are **not deployed**;
see [deployment.md](deployment.md).

## Trust boundaries

| Component | Trusted for | Not trusted for |
|---|---|---|
| Player device (client) | Its own input, its own presentation | Anything shared: items, doors, objectives, damage, rewards, timing |
| Solo process | Everything — it is its own authority | Online currency (local wallet stays local) |
| Dedicated server | Match state, enemy AI, validation, results | Identity (comes from lobby tickets) |
| Lobby service | Guest identity, rooms, tickets, verified wallet | Client-supplied prices, outcomes, timestamps; results not signed by a spawned server |
| LAN listen host (dev) | Nothing beyond that LAN test session | Never mints online currency |

## Threats and mitigations

| Threat | Mitigation (status) |
|---|---|
| **Unauthenticated / forged RPCs** | Every mutation goes through `MatchController.server_interact` (implemented). Online: Godot's `SceneMultiplayer` auth handshake delivers no RPC from a peer until its room-bound, expiring HMAC ticket verifies; server-only RPCs are `authority`-mode and rejected from clients (implemented, tested in-process and end to end). |
| **Malformed payloads** | Interaction args limited to ≤4 keys, int/bool/finite float/short strings; sub-target and action length bounded; unknown entities/players rejected (implemented, tested). |
| **Impossible interactions** (range, through walls, closed drawers, while hidden) | Eye-to-target range + tolerance, server-side line of sight excluding the target's own colliders, drawer-open check, hidden players can only use their own hiding spot (implemented, tested). |
| **Spam / brute force** | Per-player interaction rate limit (120 ms); keypad attempt cooldown 1 s and noise on wrong codes; crank cooldown (implemented). Online: guest creation, room create/join and wrong-code guesses are rate-limited per identity and per IP (IP limits sized for shared networks); every gameplay RPC kind has a per-peer token bucket and abusive peers are disconnected (implemented, tested). |
| **Timing manipulation** (crank) | Client may report a press time only within [now−0.4 s, now+0.05 s]; otherwise server time is used (implemented, tested). |
| **Movement manipulation / noise cheating** | Noise is derived on the authority from reported movement; non-finite positions are dropped; jumps >3 m produce no step noise. Online: motion is accepted only within a speed envelope for living, non-hidden players; violations get a correction to the last valid position (implemented, tested). |
| **Duplicate pickups / conflicting puzzle actions** | Single authority, atomic state changes; taking an item checks `taken` first; tested with repeated requests. |
| **Duplicate rewards** | Rewards keyed by `match:<match_id>`; wallet refuses repeated ids (tested). Online: coins are computed by the lobby from server-reported outcomes and credited once per `match:<match_id>:<user>` (implemented, tested). |
| **Purchase manipulation** | Prices read from the catalog, never from the caller; no partial charge on failure; balance cannot go negative (tested). Online purchases carry an idempotency key; a retried request never charges twice (tested). The game's cached copy of the online wallet is display-only. |
| **Locked-map access online** | The lobby refuses rooms on maps the owner has not unlocked (verified completions) and passes the owner's unlocked maps to the game server, which refuses switching to others in the lobby (tested). |
| **Save tampering** | Checksummed envelope detects corruption/casual edits and falls back to backup; **local coins are explicitly untrusted** and never imported online. |
| **Malicious display names** | Length 2–20, control/bidi/zero-width/private-use/markup characters rejected (client, lobby service and dedicated server); names rendered as plain text with auto-translation disabled; names never grant access. |
| **Room enumeration** | 6-digit codes are short-lived locators only; joining needs an authenticated guest session; guesses are rate-limited; no public room directory; optional room password hashed server-side (scrypt). |
| **Leaked secrets** | No keys/tokens in the repo; `.gitignore` blocks keystores/env files; gitleaks runs in CI (clean on current history); release keystore exists only as a protected CI secret written to a temp file and removed in `always()`. |
| **Unsafe deserialization** | Network/snapshot data is plain dictionaries/arrays; `MatchState.from_snapshot` sanitizes types and ranges; no objects, resources or file paths are accepted from the network (Godot's object decoding stays disabled). |
| **Room ownership spoofing** | The lobby marks the room owner inside the signed ticket; the dedicated server grants owner controls (options, kick, start) only to that slot, or to the next connected member if the owner left before the match (implemented). |
| **Puzzle answer leakage** | `MatchState.client_snapshot()` strips seeded answers; entities publish only what the world shows. The dev objective inspector (F3) exists only in debug builds. |

## Transport

- Backend APIs: the client refuses any lobby URL that is not `https://`
  (plain `http://` only for localhost development); TLS is terminated by a
  reverse proxy (see [deployment.md](deployment.md)).
- Server → lobby calls (status, results) are HMAC-SHA256 signed over method,
  path, timestamp and body, with a timestamp window.
- Gameplay: ENet over UDP. **Plain ENet is not encrypted.** The dedicated
  server supports DTLS (`METHOD_DTLS_KEY` / `METHOD_DTLS_CERT`), but the
  client does not yet connect with DTLS, so it is **off** today. Tickets are
  short-lived and room-bound, which limits what a captured ticket is worth.
  LAN development mode is unencrypted.

## Local data

Stored under the Godot user directory (`method_horror`): profile/progress/
wallet/cosmetics (`profile.json`), settings, and a checkpoint, each with a
`.bak`. No analytics, advertising or tracking SDKs; no personal data beyond the
chosen display name. *Profile → Delete local data* removes everything.

## Known gaps

- A malicious LAN host can do anything in its own session; LAN is for
  development only and cannot affect online wallets.
- Movement within the speed envelope is trusted (no server-side physics
  simulation of players), so small position cheats inside that envelope are
  possible online.
- The guest token is stored in the app's private user directory with a
  checksum. Godot has no OS keychain API, so it is **not** hardware-backed
  secure storage; a rooted device can read it. It grants only that guest's
  rooms and online coins.
- Gameplay traffic is unencrypted until DTLS is wired into the client.
- The lobby trusts every game server holding the server secret; spawned
  servers run on the same host.
- Internet play has not been verified across separate networks.

## Reporting

See [SECURITY.md](../SECURITY.md).
