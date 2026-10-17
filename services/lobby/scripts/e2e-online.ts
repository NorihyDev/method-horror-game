// End-to-end online check with real processes: this lobby service, a
// dedicated headless Godot server it spawns for the room, and two headless
// game clients (game/tests/e2e/online_bot.gd) that create and join the room
// by its six-digit code, play, drop/reconnect and leave.
//
// Usage (from services/lobby):  GODOT_BIN=/path/to/godot npm run e2e
// Everything binds to 127.0.0.1 with throwaway secrets and a temp database.
// This proves the flow on one machine; it is not an internet (cross-network) test.
//
// Game traffic goes through an impairing UDP relay (the lobby advertises
// bind port + PUBLIC_GAME_PORT_OFFSET): E2E_LATENCY_MS round trip (default
// 120), E2E_JITTER_MS (default 30) and E2E_LOSS per packet and direction
// (default 0.03). Set E2E_LOSS=0 E2E_LATENCY_MS=0 E2E_JITTER_MS=0 for a clean link.

import { spawn, type ChildProcess } from "node:child_process";
import { randomBytes } from "node:crypto";
import { createSocket, type Socket } from "node:dgram";
import { createWriteStream, mkdtempSync, rmSync, type WriteStream } from "node:fs";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createInterface } from "node:readline";

const GODOT = process.env.GODOT_BIN ?? process.env.GODOT ?? "";
const TIMEOUT_MS = Number(process.env.E2E_TIMEOUT_MS ?? 420_000);
const LOBBY_DIR = resolve(import.meta.dirname, "..");
const GAME_DIR = resolve(LOBBY_DIR, "../../game");
const LATENCY_MS = Number(process.env.E2E_LATENCY_MS ?? 120);
const JITTER_MS = Number(process.env.E2E_JITTER_MS ?? 30);
const LOSS = Number(process.env.E2E_LOSS ?? 0.03);
const PORT_OFFSET = 100;

const OWNER_EVENTS = [
  "code", "owner", "guest_ready", "in_match", "interaction_applied", "teammate_away", "teammate_back",
  "result_recorded", "done",
];
const GUEST_EVENTS = [
  "wrong_password_refused", "unknown_code_refused", "joined", "in_match", "saw_interaction", "reconnected_with_state",
  "done",
];

interface Proc {
  name: string;
  child: ChildProcess;
  events: Map<string, string>;
  exit: Promise<number>;
}

const procs: Proc[] = [];
const sockets: Socket[] = [];
const relayStats = { forwarded: 0, dropped: 0 };
const workDir = mkdtempSync(join(tmpdir(), "method-e2e-"));

/** Each packet, each direction: dropped with probability LOSS, else delayed by
 * half the round-trip latency ± jitter (so packets can also reorder). */
function impair(send: () => void): void {
  if (Math.random() < LOSS) {
    relayStats.dropped++;
    return;
  }
  relayStats.forwarded++;
  const delay = Math.max(0, LATENCY_MS / 2 + (Math.random() * 2 - 1) * JITTER_MS);
  const safeSend = () => {
    try {
      send();
    } catch {
      // socket closed during shutdown; the packet is simply lost
    }
  };
  if (delay === 0) safeSend();
  else setTimeout(safeSend, delay).unref();
}

/** UDP relay 127.0.0.1:listenPort -> 127.0.0.1:targetPort, one upstream socket per client. */
function startRelay(listenPort: number, targetPort: number): void {
  const front = createSocket("udp4");
  const upstreams = new Map<string, Socket>();
  front.on("message", (msg, from) => {
    const key = `${from.address}:${from.port}`;
    let up = upstreams.get(key);
    if (!up) {
      const sock = createSocket("udp4");
      sock.on("message", (back) => impair(() => front.send(back, from.port, from.address)));
      sock.on("error", () => sock.close());
      sockets.push(sock);
      upstreams.set(key, sock);
      up = sock;
    }
    const target = up;
    impair(() => target.send(msg, targetPort, "127.0.0.1"));
  });
  front.on("error", (err) => console.log(`  [relay ${listenPort}] ${err.message}`));
  front.bind(listenPort, "127.0.0.1");
  sockets.push(front);
}

function freeTcpPort(): Promise<number> {
  return new Promise((ok, fail) => {
    const srv = createServer();
    srv.once("error", fail);
    srv.listen(0, "127.0.0.1", () => {
      const port = (srv.address() as { port: number }).port;
      srv.close(() => ok(port));
    });
  });
}

function start(name: string, cmd: string, args: string[], env: NodeJS.ProcessEnv, cwd: string, onEvent?: (e: string, d: string) => void): Proc {
  const log: WriteStream = createWriteStream(join(workDir, `${name}.log`));
  const child = spawn(cmd, args, { cwd, env, stdio: ["ignore", "pipe", "pipe"] });
  const events = new Map<string, string>();
  const handle = (line: string) => {
    log.write(line + "\n");
    const m = /BOT_EVENT (\S+) ?(.*)$/.exec(line);
    if (m) {
      events.set(m[1]!, (m[2] ?? "").trim());
      console.log(`  [${name}] ${m[1]} ${(m[2] ?? "").trim()}`);
      onEvent?.(m[1]!, (m[2] ?? "").trim());
    } else if (/BOT_FAIL|SCRIPT ERROR|"level":"error"/.test(line)) {
      console.log(`  [${name}] ${line}`);
    }
  };
  createInterface({ input: child.stdout! }).on("line", handle);
  createInterface({ input: child.stderr! }).on("line", handle);
  const exit = new Promise<number>((ok) => child.on("exit", (code) => ok(code ?? -1)));
  const p = { name, child, events, exit };
  procs.push(p);
  return p;
}

function cleanup(): void {
  for (const p of procs) {
    if (p.child.exitCode === null) p.child.kill();
  }
  for (const s of sockets) {
    try {
      s.close();
    } catch {
      // already closed
    }
  }
}

async function waitForHealth(url: string): Promise<void> {
  const deadline = Date.now() + 20_000;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(`${url}/healthz`);
      if (res.ok) return;
    } catch {
      // not listening yet
    }
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error("lobby service did not become healthy");
}

async function main(): Promise<number> {
  if (!GODOT) {
    console.error("Set GODOT_BIN to the pinned Godot 4.7.2 binary.");
    return 2;
  }
  const lobbyPort = await freeTcpPort();
  const gamePortMin = 26000 + Math.floor(Math.random() * 3000);
  const lobbyUrl = `http://127.0.0.1:${lobbyPort}`;
  console.log(`e2e: lobby ${lobbyUrl}, game ports ${gamePortMin}+, logs in ${workDir}`);
  console.log(`e2e: link ${LATENCY_MS} ms RTT ±${JITTER_MS} ms jitter, ${(LOSS * 100).toFixed(1)}% loss per direction`);
  for (let i = 0; i < 10; i++) startRelay(gamePortMin + PORT_OFFSET + i, gamePortMin + i);
  start("lobby", process.execPath, ["src/main.ts"], {
    ...process.env,
    NODE_ENV: "development",
    LOBBY_HOST: "127.0.0.1",
    LOBBY_PORT: String(lobbyPort),
    LOBBY_DB_PATH: join(workDir, "lobby.sqlite"),
    METHOD_TICKET_SECRET: randomBytes(32).toString("base64url"),
    METHOD_SERVER_SECRET: randomBytes(32).toString("base64url"),
    PUBLIC_GAME_HOST: "127.0.0.1",
    PUBLIC_GAME_PORT_OFFSET: String(PORT_OFFSET),
    SPAWN_LOCAL_SERVERS: "1",
    GODOT_BIN: GODOT,
    GAME_PATH: GAME_DIR,
    SERVER_PORT_MIN: String(gamePortMin),
    SERVER_PORT_MAX: String(gamePortMin + 9),
    SERVER_RECONNECT_WINDOW: "8",
    LOBBY_URL_FOR_SERVERS: lobbyUrl,
  }, LOBBY_DIR);
  await waitForHealth(lobbyUrl);
  const godotArgs = (role: string, extra: string[] = []) => [
    "--headless", "--path", GAME_DIR, "--", "--bot", `--role=${role}`, `--lobby=${lobbyUrl}`, ...extra,
  ];
  let guest: Proc | null = null;
  const owner = start("owner", GODOT, godotArgs("owner"), process.env, GAME_DIR, (event, data) => {
    if (event === "code" && !guest) guest = start("guest", GODOT, godotArgs("guest", [`--code=${data}`]), process.env, GAME_DIR);
  });
  const timer = new Promise<"timeout">((ok) => setTimeout(() => ok("timeout"), TIMEOUT_MS).unref());
  const ownerCode = await Promise.race([owner.exit, timer]);
  if (ownerCode === "timeout") {
    console.error("e2e: timed out");
    return 1;
  }
  const guestCode = guest ? await Promise.race([(guest as Proc).exit, timer]) : -1;
  let failed = ownerCode !== 0 || guestCode !== 0;
  const missing = (p: Proc | null, expected: string[]) => expected.filter((e) => !p?.events.has(e));
  const ownerMissing = missing(owner, OWNER_EVENTS);
  const guestMissing = missing(guest, GUEST_EVENTS);
  if (ownerMissing.length || guestMissing.length) failed = true;
  if (relayStats.forwarded === 0) {
    console.log("e2e: no game traffic went through the impairing relay");
    failed = true;
  }
  console.log(`e2e: owner exit ${ownerCode}, guest exit ${guestCode}`);
  console.log(`e2e: relay forwarded ${relayStats.forwarded} packets, dropped ${relayStats.dropped}`);
  if (ownerMissing.length) console.log(`e2e: owner missing events: ${ownerMissing.join(", ")}`);
  if (guestMissing.length) console.log(`e2e: guest missing events: ${guestMissing.join(", ")}`);
  console.log(failed ? `e2e: FAILED (logs kept in ${workDir})` : "e2e: PASSED");
  return failed ? 1 : 0;
}

let code = 1;
try {
  code = await main();
} catch (err) {
  console.error("e2e:", err);
} finally {
  cleanup();
  await new Promise((r) => setTimeout(r, 1500));
  if (code === 0 && !process.env.E2E_KEEP_LOGS) rmSync(workDir, { recursive: true, force: true });
}
process.exit(code);
