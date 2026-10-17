# Networking

How online and LAN co-op work, what each piece trusts, and what has been
verified. Deployment steps are in [deployment.md](deployment.md); the threat
model is in [security.md](security.md).

## Status

| Piece | State |
|---|---|
| **Online rooms over the internet** (create with a 6-digit code, join from any network, 2–4 players) | Implemented through the **METHOD relay** (Cloudflare Worker + one Durable Object per room, `services/relay`). **Deployed** at `https://method-horror-relay.norihyapp.workers.dev`. Verified with two Godot clients through the deployed relay (see *Verification*) |
| Phones on **different networks** | **Not yet tried**: the deployed test ran both clients on one PC (same network). Instructions: [deployment.md](deployment.md#testing-with-two-phones-on-different-networks) |
| Authority | The **room creator's device** runs the match (rules, enemy AI, physics) and is authoritative for the room; guests send intentions only. The relay checks membership, roles, sizes and rates, never game rules |
| Reconnect | A dropped guest rejoins its slot with a full snapshot, while the host is still there |
| Host departure | Ends the room for everyone, with an explicit message ("The room creator left") |
| Rewards | **None online**: results come from a player's device and cannot be verified. Solo coins are unchanged |
| LAN development mode | Implemented; in-process test |
| Self-hosted dedicated server + lobby service (`--server`, `services/lobby`) | Still in the repo and covered by in-process tests (`test_multiplayer.gd`), but **not used by the shipped client**: Cloudflare's free plan cannot host a Godot server or UDP |

## Components (shipped online mode)

```
 room creator's game (host, peer 1) ──wss──┐
                                           ├── Cloudflare Worker ── Durable Object "room <code>"
 guest's game (peer 2..4) ─────────────wss─┘      (relays packets, validates membership/limits)
```

- **Relay** (`services/relay`, TypeScript): `POST /v1/rooms` creates a room
  and returns its code and a secret host token. Each player then opens a
  WebSocket to `/v1/rooms/<code>/ws`. The room's Durable Object admits the
  host (token) and guests (code + optional password), then forwards packets
  host↔guest. Protocol and limits are in
  [services/relay/README.md](../services/relay/README.md).
- **Client transport** (`relay_peer.gd`, `RelayMultiplayerPeer`): a Godot
  `MultiplayerPeer` over that WebSocket. The game's `SceneMultiplayer`,
  `NetBridge` RPCs, validation, rate limits, start barrier and reconnect run
  on it unchanged, exactly as for a LAN host.
- **Session** (`online_flow.gd`): *Create* → `RelayClient.create_room` →
  connect as host → `NetBridge.host_relay` (this device plays as pid 1) →
  lobby. *Join* → connect as guest → `NetBridge.join_relay` → authenticate
  with the host (name + device id) → lobby.

**Update rates** (`NetProtocol`, configurable): relay rooms send world
updates (all players, each enemy) 10×/s and local motion every 80 ms, which
is lower than LAN/dedicated (15×/s, 50 ms). That keeps a four-player match
inside the free plan's daily request allowance. Remote players and enemies
are interpolated on every client.

**Trust and host limitations.** The host's device decides everything in the
match. A modified host can cheat for the whole room, but it can't touch
another player's device data, the relay's rules or any reward (online rooms
award none). Guests' intentions are validated by the host (`NetBridge`:
sender slot, phase, types, sizes, finite values, movement speed,
interaction range and rate). If the host's app is closed, backgrounded too
long or loses its connection, the room ends. There is no host migration,
because the enemy AI and physics state live only on the host.

## Authority and messages

The same message set runs on the relay (host = room creator), on LAN and on a
self-hosted dedicated server.

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
default). Online, with *Auto reconnect* on, a guest whose connection drops
reopens a WebSocket to the same room code with the same device id. The host
recognizes the id, puts the guest back into its slot, rebuilds the level on
the guest and sends a full snapshot (inventory included) before control
returns. After the window the player counts as *left*. New players cannot
join a running match. The host itself cannot reconnect: losing the host ends
the room.

## LAN development mode

*Multiplayer → Development: local network.* One device hosts (listen server on
UDP 24610, also plays as player 1); others enter its IP. No lobby service and
no tickets: the host trusts LAN names. It is labeled everywhere as a test mode
with lower trust, **never awards coins**, and is never used as a fallback for
online rooms.

## Errors the player can see

Every failure maps to a translated message (EN/FR) and returns the player to
the multiplayer screen:

- unreachable relay;
- version mismatch;
- wrong password, or too many wrong passwords;
- unknown or expired code;
- full room, or match already started;
- removed by the owner;
- duplicate connection;
- rate limited;
- the room creator left;
- lost connection.

Unknown reasons fall back to a generic message.

## Verification

| Command | What it shows |
|---|---|
| `cd services/relay && npm test` | Relay protocol: codes, create validation (2–4 players), frame encoding, routing (guests reach only the host), control messages, rate buckets |
| `RELAY_URL=<url> node scripts/check-relay.ts` | 20 checks against a running relay, over real WebSockets: no host yet, wrong host token, second host, wrong password, protocol mismatch, a full room, sender stamping, guest→guest blocked, broadcast/exclude/direct, oversize frame closes the socket, only the host kicks, flood rate-limited, host departure closes the room and deletes it |
| `GODOT_BIN=… RELAY_URL=<url> npm run e2e` | **Two separate Godot processes** through the relay, driving the real screens. The guest is refused for a wrong password and an unknown code, then joins by code and readies; the owner starts. Then: host interaction replicated; monster simulated by the host and moving on the guest; guest movement reaches the host; guest drops and rejoins its slot with the match state; host finishes the match and the guest gets the results; in a second room, the host leaves and the guest is told |
| `tools/godot.sh --headless --path game -- --test --filter=multiplayer` | In-process server + clients over real localhost ENet (the same NetBridge logic): lobby, ready/start barrier, late join refused, replicated interaction, pickup race, cheating attempts ignored, reconnect with state, six-player sync, Maps 2–5 replication |

Recorded on 2026-10-17 (Windows 11, Godot 4.7.2, Node 24.18, wrangler 4.147):

- **Local relay** (`wrangler dev`): 20/20 checks, e2e passed.
- **Deployed relay** (`wss://method-horror-relay.norihyapp.workers.dev`): 20/20 checks, e2e passed (repeatedly).
- **Measured traffic:** host 18 frames/s, guest 12 frames/s.

Both e2e clients ran on one PC. **Two phones on different networks have not been tried yet.**

## Known limits

- Online rooms depend on the host's device: if it leaves, the room ends (no
  host migration). The host can cheat for its own room; no rewards are at
  stake.
- WebSockets are TCP: a lost packet delays the following ones (no
  unreliable channel online). Interpolation hides small stalls.
- Free-plan quota: about 10 hours of four-player play per day across all
  rooms (see the relay README). Past it, connections fail until 00:00 UTC.
- No rollback reconciliation for the local player; on very lossy links,
  rejected moves snap back.
- Lobby rate limits and sessions live in one process (single-instance
  deployment). Multiple lobby instances need a shared store.
- The lobby trusts the dedicated servers it spawned (shared HMAC secret).
- Enemy simulation runs only on the server; clients see interpolated puppets.
