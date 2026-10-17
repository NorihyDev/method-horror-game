# METHOD HORROR relay

The online multiplayer backend: a Cloudflare Worker plus **one Durable Object
per private room**, on the Workers **Free** plan. Phones connect over secure
WebSockets (`wss://`), so they can join each other from any Wi-Fi or mobile
network.

Deployed: `https://method-horror-relay.norihyapp.workers.dev` (set in
`game/project.godot` as `method/online/relay_url`).

## What it is, and what it is not

Cloudflare Workers cannot run a Godot server or accept ENet/UDP. So the
**room creator's device hosts the match**. It runs the rules, the enemy AI
and physics exactly like a LAN host. The relay forwards packets between it
and up to three guests.

The relay is **not an authoritative game server**. It enforces only these:

| Rule | Check |
|---|---|
| Membership | Only sockets admitted to this room exchange packets |
| Roles | The host is the one holding the secret token returned at creation; a second host connection is refused; guests may only reach the host, never each other; only the host may kick |
| Room size | 2–4 players (fixed at creation) |
| Passwords | Optional, salted SHA-256; 8 wrong attempts lock joins for 60 s |
| Sizes | Guest frames ≤ 4 KB, host frames ≤ 64 KB (largest measured snapshot ≈ 5 KB), control messages ≤ 512 B |
| Rates | Token buckets: guests 60/s (burst 120), host 300/s (burst 600); a socket dropping more than 300 frames is closed |
| Protocol | Version 1; anything else is refused |
| Lifetime | A room whose host never connects is deleted after 2 minutes; every room ends after 4 hours |
| Host departure | All guests receive `{"t":"closed","reason":"HOST_LEFT"}`, then the room's storage is deleted |

The relay never sees game rules and never handles rewards. Online relay
matches award **no coins**, because their results come from a player's
device and cannot be verified.

## Protocol (version 1)

HTTP:

- `POST /v1/rooms` with `{"proto":1,"max_players":2..4,"password":""}` returns `201 {"code","host_token","max_players","proto"}`. The code is 6 random digits, and the room is unique while it exists.
- `GET /v1/rooms/<code>/ws?proto=1&role=host&token=…` or `…&role=guest&pw=…` opens the WebSocket.
- `GET /v1/health` returns `{"ok":true,"proto":1}`.

WebSocket:

- **Binary frames** carry Godot's own multiplayer packets:
  - Client to relay: `[u8 1][i32 target LE][u8 channel][u8 mode][payload]`.
  - Relay to client: `[u8 1][i32 from LE][u8 channel][u8 mode][payload]`.
  - The relay stamps the real sender. A guest's target is ignored: guest packets always go to the host. The host addresses one guest, all guests (`0`) or all but one (`-id`).
- **Text frames** are JSON control messages:
  - Relay to client: `welcome {id, role, max}`, `join {id}` (to the host), `leave {id}` (to the host), `closed {reason}`, `error {code}`.
  - Client to relay: `kick {id}` (host only), `leave`.
  - `"ping"` is answered `"pong"` by the runtime, which isn't billed.
- **Refusal codes:** `ROOM_NOT_FOUND`, `ROOM_FULL`, `WRONG_PASSWORD`, `LOCKED_OUT`, `VERSION`, `HOST_TAKEN`, `KICKED`, `RATE_LIMITED`, `MALFORMED`, `ROOM_EXPIRED`, `HOST_LEFT`.

On the Godot side, `game/scripts/network/relay_peer.gd` implements Godot's
`MultiplayerPeer` over this protocol. The game's existing networking code
(`NetBridge`, with all its validation) runs unchanged on top.

## Free-plan limits (checked against Cloudflare's docs, October 2026)

| Limit (Free) | Value | Effect here |
|---|---|---|
| Durable Objects | SQLite-backed only | Configured that way (`new_sqlite_classes`) |
| DO requests | 100,000 / day | Each WebSocket connection is 1 request, and incoming WebSocket messages are billed **20 to 1**. Outgoing messages are free |
| DO duration | 13,000 GB-s / day (128 MB per object) | About 450 GB-s per hour while a room is busy, so about 28 room-hours/day. Idle lobbies hibernate (WebSocket Hibernation API) and aren't billed |
| Worker requests | 100,000 / day | Only room creation and WebSocket connects |
| Over the limit | Requests fail with an error until 00:00 UTC; never charged | Players see "could not reach" / "connection lost" |

**Measured message rates** (2026-10-17, two Godot clients through the
deployed relay): the host sends 18 frames/s and each guest 12 frames/s. The
relay rates are 10 world updates/s and a motion report every 80 ms, both set
in `NetProtocol`.

So a four-player match sends about 18 + 3 × 12 = 54 incoming messages/s,
which is about 2.7 billed requests/s or about 9,700 per hour. The free plan
therefore covers about **10 hours of four-player play per day across all
rooms** (about 18 hours for two-player matches). Requests run out before
duration does. The game won't charge anything; past the limit, connections
fail until the next UTC day.

## Develop, test, deploy

```bash
cd services/relay
npm ci
npm test && npm run typecheck              # protocol unit tests
npx wrangler dev --port 8787               # local relay (workerd), no account needed
RELAY_URL=http://127.0.0.1:8787 node scripts/check-relay.ts          # 20 protocol checks
GODOT_BIN=/path/to/godot RELAY_URL=http://127.0.0.1:8787 npm run e2e # two real Godot clients
```

To deploy to your own account (free plan, no card):

```bash
npx wrangler login     # official browser sign-in; credentials stay in your user profile
npx wrangler deploy    # prints https://method-horror-relay.<your-subdomain>.workers.dev
RELAY_URL=https://method-horror-relay.<your-subdomain>.workers.dev node scripts/check-relay.ts
```

Then set `method/online/relay_url` in `game/project.godot` to that URL. It's
public, not a secret. No Cloudflare credentials belong in the repo or the
game. For development, `--relay=<url>` or `METHOD_RELAY_URL` overrides the
setting.
