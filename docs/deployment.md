# Deployment Runbook

## Online relay (what the game uses)

Online rooms run through the METHOD relay: a Cloudflare Worker plus one
Durable Object per room, on the **Workers Free plan**, with no card and no
paid add-ons. Design, protocol and free-plan math:
[services/relay/README.md](../services/relay/README.md).

**Deployed:** `https://method-horror-relay.norihyapp.workers.dev`
(2026-10-17), on the owner's Cloudflare account. It holds one Worker,
`method-horror-relay`, with a SQLite-backed Durable Object class, `RoomDO`.
No other resources were created or changed. The game points at it through
`method/online/relay_url` in `game/project.godot`, which is a public URL,
not a secret.

### Redeploy or deploy to another account

```bash
cd services/relay
npm ci
npx wrangler login        # official browser sign-in (OAuth); nothing is pasted anywhere
npx wrangler deploy       # prints https://method-horror-relay.<subdomain>.workers.dev
RELAY_URL=https://method-horror-relay.<subdomain>.workers.dev node scripts/check-relay.ts
```

Then set `method/online/relay_url` to the printed URL and re-export the game.
Wrangler keeps its OAuth credentials in your user profile, outside the repo.
Never commit them, and never put them in the game.

### Verify a deployment

```bash
cd services/relay
RELAY_URL=https://<your relay> node scripts/check-relay.ts                       # 20 protocol checks
GODOT_BIN=/path/to/godot RELAY_URL=https://<your relay> npm run e2e             # two Godot clients
```

Both passed against the deployed relay on 2026-10-17, with both clients on
one PC.

### Testing with two phones on different networks

**Not done yet.** This is the step that proves the internet path.

1. Build the debug APK with the relay URL already set:
   `./tools/godot.sh --headless --path game --export-debug "Android" ../builds/android/method_horror_debug.apk`
   (see [releases.md](releases.md)).
2. Install it on both phones: `adb install -r builds/android/method_horror_debug.apk`, or copy the APK over and open it with *Install unknown apps* allowed.
3. Put the phones on **different networks**: phone A on home Wi‑Fi, phone B with Wi‑Fi **off** on mobile data.
4. Unlock the map on phone A if needed (online rooms offer the creator's unlocked maps; *The Abandoned House* is always available).
5. **Phone A:** *Multiplayer → Online → Create room*. Choose the map, difficulty and 2–10 players, and optionally a password. The lobby shows a 6-digit code.
6. **Phone B:** *Multiplayer → Online → Join room*. Enter the code (and password) and tap *Ready*. Phone A's lobby lists both players with B ready.
7. **Phone A:** *Start*. Both phones load the same map and begin together.
8. Check:
   - each player sees the other walk, turn and crouch, and the flashlight beam;
   - doors, pickups, notes and objectives update on both phones;
   - the monster appears on both and chases the same player;
   - a downed player can be revived.
9. Reconnect: on phone B, toggle airplane mode for about 5 s. B reconnects into the same match with its inventory.
10. Finish or lose the match: both phones show results, with no coins for online.
11. Host departure: create a new room on A, join from B, then close the app on A. B shows "The room creator left".

Report anything that differs. Cloudflare's free plan returns errors once its
daily allowance is used, so a failure late in a long test day can be the
quota. It resets at 00:00 UTC.

## Self-hosted alternative: lobby service + dedicated server (not used by the shipped client)

### Docker image

Every release publishes the lobby and the dedicated server together as
`ghcr.io/norihydev/method-horror-server:<version>` (and `:latest`), built by
`.github/workflows/package.yml` from `deploy/server/Dockerfile`. The image
holds no secrets; pass them at run time:

```bash
docker run -d --name method-horror   -e METHOD_TICKET_SECRET=<32+ random characters>   -e METHOD_SERVER_SECRET=<32+ random characters>   -e PUBLIC_GAME_HOST=<public IP or DNS name>   -p 8787:8787 -p 24600-24699:24600-24699/udp   -v method-horror-data:/data   ghcr.io/norihydev/method-horror-server:latest
```

The lobby answers on port 8787 (`/healthz`); put an HTTPS proxy in front of
it for real players, as below. Without the two secrets it refuses to start.

The repository still contains a lobby service (`services/lobby`) and a
headless dedicated server (`--server`). They run the match on a server you
control, with verified wallet rewards, but need a paid host with UDP. The
game client no longer connects to them: online rooms use the relay. Nothing
of this kind is deployed.

### What you need (external, not provided)

| Item | Why | Cost |
|---|---|---|
| A Linux host with a public IPv4 address | Runs the lobby service and one dedicated Godot server per room | Paid, provider-dependent; not purchased |
| A domain name pointing at that host | HTTPS for the lobby API | Paid, registrar-dependent; not purchased |
| A TLS certificate | HTTPS (clients refuse plain `http://` except localhost) | Free via Let's Encrypt (the Caddy setup below obtains it automatically) |
| Open ports: TCP 80 + 443 (lobby/ACME), UDP 24600–24699 (game servers) | Clients reach both | — |
| Two players on **different networks** (e.g. one on mobile data, one on home Wi‑Fi) | The internet verification step | — |

Per-room load is one headless Godot process. Its memory and CPU use on a VPS
have **not been measured yet**; do that before sizing a host.

### Local development (one machine)

```bash
cd services/lobby
npm ci
cp .env.example .env            # never commit .env
# edit .env: SPAWN_LOCAL_SERVERS=1, GODOT_BIN=<your Godot 4.7.2>, GAME_PATH=../../game
node --env-file=.env src/main.ts
```

Then start two game windows pointing at it (plain `http://` is accepted only
for localhost):

```bash
./tools/godot.sh --path game -- --lobby=http://127.0.0.1:8787
./tools/godot.sh --path game -- --lobby=http://127.0.0.1:8787
```

Create a room in one, join with the code in the other. Without secrets in
`.env`, development mode generates throwaway secrets per run (tickets die
with the process).

### Production: single host

#### 1. Build artifacts

- **Dedicated server:** the *Linux Dedicated Server* export
  (`builds/server/method_horror_server.x86_64`, produced by
  `.github/workflows/build.yml` or locally with
  `godot --headless --path game --export-release "Linux Dedicated Server" …`).
  It embeds the game, so the lobby runs it with `GAME_PATH=` (empty).
- **Lobby:** this repository's `services/lobby` at the same commit (no build
  step; Node 24 runs the TypeScript directly).

#### 2. Host setup

```bash
sudo useradd --system --create-home --home-dir /opt/method method
sudo -u method mkdir -p /opt/method/{lobby,server,data}
# copy services/lobby -> /opt/method/lobby, the server binary -> /opt/method/server/
cd /opt/method/lobby && sudo -u method npm ci --omit=dev
```

Install Node.js 24 LTS from your distribution or nodejs.org.

#### 3. Secrets and configuration

Generate two independent secrets (≥32 random characters each):

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))"
```

`/opt/method/lobby/.env` (mode 600, owned by `method`; never in git):

```ini
NODE_ENV=production
LOBBY_HOST=127.0.0.1
LOBBY_PORT=8787
LOBBY_DB_PATH=/opt/method/data/lobby.sqlite
METHOD_TICKET_SECRET=<secret 1>
METHOD_SERVER_SECRET=<secret 2>
PUBLIC_GAME_HOST=<public IP or DNS name>
PUBLIC_GAME_PORT_OFFSET=0
SPAWN_LOCAL_SERVERS=1
GODOT_BIN=/opt/method/server/method_horror_server.x86_64
GAME_PATH=
SERVER_PORT_MIN=24600
SERVER_PORT_MAX=24699
SERVER_RECONNECT_WINDOW=60
LOBBY_URL_FOR_SERVERS=http://127.0.0.1:8787
TRUST_PROXY=1
```

In production the service refuses to start without both secrets. The game
servers receive them through their environment only (never the command line,
which is visible in process lists).

#### 4. Service

`/etc/systemd/system/method-lobby.service`:

```ini
[Unit]
Description=METHOD HORROR lobby service
After=network-online.target

[Service]
User=method
WorkingDirectory=/opt/method/lobby
ExecStart=/usr/bin/node --env-file=/opt/method/lobby/.env src/main.ts
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/opt/method/data
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload && sudo systemctl enable --now method-lobby
journalctl -u method-lobby -f        # JSON log lines; tokens are never logged
```

#### 5. HTTPS reverse proxy

`/etc/caddy/Caddyfile` (Caddy obtains and renews the certificate):

```
lobby.example.com {
    reverse_proxy 127.0.0.1:8787
}
```

`TRUST_PROXY=1` makes the lobby rate-limit by the client address Caddy
forwards. Only enable it behind a proxy you control.

#### 6. Firewall

Allow TCP 80, 443 and UDP 24600–24699; nothing else from outside (the lobby
port 8787 stays on localhost).

#### 7. Point the game at the service

Set the project setting `method/online/lobby_url` for the builds you ship,
for example with a feature-tag override in `game/project.godot`:

```ini
[method]
online/lobby_url=""
online/lobby_url.release="https://lobby.example.com"
```

Debug builds keep the empty value (multiplayer shows "unavailable") unless
started with `--lobby=<url>`. Only `https://` URLs are accepted outside
localhost.

#### 8. Verify

1. `curl https://lobby.example.com/healthz` → `{"ok":true,…}`.
2. **Internet verification** (required before calling online play
   internet-ready): two devices on different networks create and join a room
   by code, play to an escape or defeat, leave, and check the online wallet on
   the results screen. Also try: wrong code, wrong password, full room, a
   kicked player, turning Wi‑Fi off mid-match and back on within 60 s.
   Record date, build, networks and outcome in `docs/testing.md`.

## Optional: encrypted gameplay traffic (DTLS)

ENet is unencrypted by default. To enable DTLS on game servers, provide a
key/certificate (PEM) and set `METHOD_DTLS_KEY` / `METHOD_DTLS_CERT` in the
lobby environment so spawned servers inherit them. Clients must then connect
with `dtls_trusted` set (not yet wired into the client UI — see
[networking.md](networking.md)).

## Operations

| Task | How |
|---|---|
| Backups | `sqlite3 /opt/method/data/lobby.sqlite ".backup /backup/lobby-$(date +%F).sqlite"` (safe while running; WAL mode) |
| Retention | Built in: expired sessions, idle guests (180 days) and old rooms are pruned every minute |
| Rotate the ticket secret | Change `METHOD_TICKET_SECRET`, restart. Outstanding tickets (≤5 min) and running matches' reconnects fail; schedule when idle |
| Rotate the server secret | Change `METHOD_SERVER_SECRET`, restart (restarting stops all running game servers) |
| Update | Deploy lobby and server binary from the same commit. Bump `PROTOCOL_VERSION` (game) and `METHOD_PROTOCOL_VERSION` (lobby) together for incompatible changes; old clients get a clear "update the game" message |
| Capacity | 20 servers per host by default (`maxServers`), ports from the configured range |

## Failure and recovery policy

- **A game server crashes:** the lobby marks the room closed; no result is
  posted, so **no rewards** are paid for that match (and none twice). Players
  see "connection lost" and return to the multiplayer menu.
- **The lobby restarts:** running game servers are stopped on shutdown; open
  rooms expire. Sessions and wallets persist in SQLite. In-memory rate limits
  reset.
- **Duplicate result reports:** credits are keyed `match:<match_id>:<user>`;
  retries are ignored.
- **Room owner leaves:** before the match, ownership moves to the next
  connected member on the dedicated server. There is no listen-server
  migration (online rooms never run on a player's device).

## Scaling beyond one host

`Allocator` (`services/lobby/src/servers.ts`) is the seam: a fleet or
container allocator returns `{host, port}` for a room. A multi-instance lobby
additionally needs a shared database and a shared rate-limit store. Neither is
implemented.
