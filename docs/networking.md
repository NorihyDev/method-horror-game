# Networking

How online and LAN co-op work, what each piece trusts, and what has been
verified. Deployment steps are in [deployment.md](deployment.md); the threat
model is in [security.md](security.md).

## Status

| Piece | State |
|---|---|
| Authoritative server path (`MatchController` + `NetBridge`) | Implemented; in-process 2-client integration tests |
| Lobby service (guest identity, rooms, codes, tickets, verified wallet) | Implemented; 16 service tests |
| Dedicated server entry point (`--server`) | Implemented; exercised by the end-to-end test |
| Client flow + screens (create/join, lobby, loading barrier, in-match MP HUD, results) | Implemented; driven end to end by headless bots |
| Reconnect within the window, full snapshot before control | Implemented; end-to-end tested |
| Impaired links (latency, jitter, loss) | End-to-end tested on loopback through a lossy UDP relay (see *Verification*) |
| LAN development mode | Implemented; in-process test |
| **Internet play across separate networks** | **Not verified.** Needs a public host; see [deployment.md](deployment.md) |
| 5–6 players | Locked in the UI until sync/performance checks pass; protocol allows 6 |
| DTLS on gameplay traffic | Supported by the server (`METHOD_DTLS_KEY/CERT`), not enabled by default |

## Components

```
 game client ──HTTPS──> lobby service ──spawns──> dedicated Godot server (one per room)
      │                    ▲                              │
      └────ENet/UDP────────┼──────────────────────────────┘
                           └──HMAC-signed status + match results
```

- **Lobby service** (`services/lobby`, Node 24 + TypeScript, no runtime
  dependencies, SQLite via `node:sqlite`): guest sessions, private rooms and
  6-digit codes, optional scrypt-hashed room passwords, rate limits,
  short-lived room-bound connection tickets, server allocation, and the
  verified wallet/ledger. It never runs gameplay.
- **Dedicated server** (`godot --headless --path game -- --server …`): one
  process per room, the only authority for that match. Started by the lobby's
  `LocalSpawner` (single host) or any allocator implementing the same
  interface.
- **Client**: `LobbyClient` (HTTP) and `OnlineFlow` (session state machine),
  `NetBridge` (the single RPC endpoint), `RemoteAvatar` (other players),
  puppet `Watcher`s (enemy presentation).

"Host" in the online UI means the **room owner** (chooses map/difficulty,
kicks, starts). The owner's phone never runs the server.

## Session flow

1. **Guest identity.** `POST /v1/guest` with the display name → opaque bearer
   token (only its SHA-256 is stored server-side). Kept in the app's user
   directory; reinstalling loses it (the UI says so).
2. **Create** `POST /v1/rooms` (map, difficulty, 2–4 players, optional
   password) or **join** `POST /v1/rooms/join` (code + password). The lobby
   allocates a server and returns `{room_id, code, server{host, port}, ticket}`.
3. **Connect.** The client opens ENet to the server and, inside Godot's
   `SceneMultiplayer` auth handshake, sends `{ticket, protocol, build}`. No
   RPC is delivered before the server verifies the ticket (HMAC-SHA256,
   room-bound, expiring) and calls `complete_auth`. A freshly spawned server
   may still be booting, so the client retries `NET_UNREACHABLE` up to 8 times.
4. **Lobby.** Server-owned member list (ready, owner, away). The ticket marks
   the lobby's room owner; if the owner leaves before the match, ownership
   passes to the next connected member. Owner can change map/difficulty and
   remove players (removed players are banned from that room).
5. **Start barrier.** Owner starts when every connected member is ready. The
   server builds the level, sends each client the config (never the puzzle
   answers), waits for every client's `loaded` (60 s timeout; stragglers are
   marked away), then sends a full snapshot and `begin` to everyone at once.
6. **Play.** Clients send intentions; the server validates and broadcasts
   results (below).
7. **End.** When nobody is left alive (escaped/dead/left), the server
   finishes the match, sends each player their own result, reports the room
   `ended`, and posts results to the lobby, which computes and credits coins.
   The server lingers 30 s and exits.

## Authority and messages

The server runs exactly the same rules path as solo
(`MatchController.server_interact` etc.). Clients never mutate shared state.

| Client → server (`any_peer`, validated) | Rate bucket (capacity / refill per s) |
|---|---|
| `_c_motion(pos, yaw, speed, flags)` — unreliable ordered, 20 Hz | motion 40 / 30 |
| `_c_interact(entity, sub, action, args)` | action 10 / 8 (plus the 120 ms interaction limit) |
| `_c_drop(item)`, `_c_use_item(item)`, `_c_revive(target, start)` | action 10 / 8 |
| `_c_ping(pos, kind)` | ping 3 / 1 |
| `_c_set_ready`, `_c_set_options`, `_c_kick`, `_c_start`, `_c_loaded`, `_c_leave` | lobby 10 / 4 |

Every handler re-checks the sender's slot, the match phase, argument types,
sizes and finiteness. A peer that keeps hitting the limits (>400 drops) is
disconnected. Motion is accepted only for living, non-hidden players and only
within `6.5 m/s × elapsed × 1.5 + 0.6 m`; otherwise the server sends a
correction to the last valid position. Footstep noise is derived on the server
from accepted movement, never reported by clients.

| Server → clients (`authority`) | Channel |
|---|---|
| `_s_room` (lobby state), `_s_load`, `_s_snapshot`, `_s_begin`, `_s_finished` | reliable |
| `_s_entity`, `_s_flag`, `_s_counters`, `_s_objectives`, `_s_phase` | reliable, by stable entity id |
| `_s_inventory` (to its owner only), `_s_notify`, `_s_recharge` | reliable |
| `_s_damage`, `_s_status`, `_s_hiding`, `_s_revive`, `_s_away`, `_s_ping`, `_s_sound` | reliable |
| `_s_players` (all positions), `_s_enemy` (position, animation, lens) | unreliable ordered, 15 Hz |
| `_s_time` (match clock) | unreliable ordered, every 2 s |

**Tick budget.** Physics 60 Hz on the server; world broadcasts 15 Hz; client
motion 20 Hz; clock sync 2 s. Remote players and enemies are interpolated
(`lerp` toward the latest packet). The local player moves immediately
(client-side prediction) and the server corrects only invalid moves; there is
no full rollback reconciliation yet.

**Duplicate protection.** Pickups, puzzle steps and revives are single atomic
state changes on the server (two clients racing for one battery: exactly one
gets it — tested).

## Downed, revive, dead, spectator

- At the difficulty's hit limit a player goes **down** instead of dying (solo
  still dies). Downed players can look around but not move or act; a bleed-out
  bar counts down (`bleedout_time`).
- A living teammate holds Interact on them to start a **revive**
  (`revive_time`). The server re-checks every tick: both still valid, reviver
  not hidden or away, within 2.2 m (+0.3 m slack). Moving away cancels it.
- Bleed-out → **dead**. Dead or escaped players **spectate** living teammates
  (Interact / Use cycles), and can still open the pause menu to leave.
- The match ends when no one is left standing; escaped players count as a
  victory.

## Reconnect

Disconnected players keep their slot for `reconnect_window` seconds (60 by
default; the lobby passes `SERVER_RECONNECT_WINDOW`). With *Auto reconnect*
on, the client asks the lobby for a fresh ticket (`POST
/v1/rooms/:id/ticket`, members only) up to 5 times, reconnects to the same
slot, rebuilds the level, receives a full snapshot (inventory included) and
only then regains control. After the window the player counts as *left*. New
players cannot join a running match.

## LAN development mode

*Multiplayer → Development: local network.* One device hosts (listen server on
UDP 24610, also plays as player 1); others enter its IP. No lobby service and
no tickets: the host trusts LAN names. It is labeled everywhere as a test mode
with lower trust, **never awards coins**, and is never used as a fallback for
online rooms.

## Errors the player can see

Every failure maps to a translated message (EN/FR) and returns the player to
the multiplayer screen: unreachable service or server, version mismatch, bad
or expired ticket, wrong/missing password, unknown or expired code, full room,
match already started, removed by owner, duplicate connection, rate limited,
lost connection. Unknown reasons fall back to a generic message.

## Verification

| Command | What it shows |
|---|---|
| `tools/godot.sh --headless --path game -- --test --filter=multiplayer` | In-process server + 2 clients over real localhost ENet: lobby, rejected tickets, ready/start barrier, late join refused, replicated interaction, pickup race, cheating attempts ignored, disconnect + reconnect with state; LAN host |
| `cd services/lobby && npm test` | Guest/session/room/code/password/rate-limit/ticket/server-signature/wallet/idempotency rules |
| `cd services/lobby && GODOT_BIN=… npm run e2e` | **Separate processes**: lobby + spawned dedicated server + two headless clients that create and join by code (wrong password and unknown code refused), ready, start, replicate an interaction, drop and reconnect with a full snapshot, leave; the server records the result in the verified wallet. All game traffic passes through a UDP relay adding 120 ms RTT, ±30 ms jitter and 3% loss per direction (configurable) |

Recorded locally (Windows 11, Godot 4.7.2, Node 24.18) on 2026-10-17: the e2e
test passed at the default impairment and at 300 ms RTT / ±80 ms jitter / 10%
loss. This proves protocol correctness under impairment on one machine; it
does not measure how play *feels* on such links, and it is not a cross-network
internet test.

## Known limits

- No rollback reconciliation for the local player; on very lossy links,
  rejected moves snap back.
- Lobby rate limits and sessions live in one process (single-instance
  deployment). Multiple lobby instances need a shared store.
- The lobby trusts the dedicated servers it spawned (shared HMAC secret).
- Enemy simulation runs only on the server; clients see interpolated puppets.
