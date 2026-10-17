import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import type { Server } from "node:http";
import { loadConfig } from "../src/config.ts";
import { openDb } from "../src/db.ts";
import { LobbyService } from "../src/service.ts";
import { RateLimiter } from "../src/ratelimit.ts";
import { createApp } from "../src/http.ts";
import { FixedAllocator } from "../src/servers.ts";
import { signServerRequest, verifyTicket } from "../src/security.ts";

const cfg = loadConfig({
  dbPath: ":memory:",
  ticketSecret: "t".repeat(40),
  serverSecret: "s".repeat(40),
  port: 0,
  roomIdleMinutes: 15,
  // Tests simulate distinct clients with X-Forwarded-For.
  trustProxy: true,
});
let ipCounter = 1;
let clock = Math.floor(Date.now() / 1000);
const db = openDb(":memory:");
const allocator = new FixedAllocator("10.0.0.5", 24600);
const service = new LobbyService(db, cfg, allocator, () => clock);
const app: Server = createApp({ cfg, service, limiter: new RateLimiter(), version: "test" });
let base = "";

before(async () => {
  await new Promise<void>((r) => app.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${(app.address() as AddressInfo).port}`;
});
after(() => app.close());

async function call(method: string, path: string, body?: unknown, token?: string, headers: Record<string, string> = {}) {
  const res = await fetch(base + path, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    body: body === undefined ? undefined : typeof body === "string" ? body : JSON.stringify(body),
  });
  const json = (await res.json()) as Record<string, unknown>;
  return { status: res.status, json, headers: res.headers };
}

async function guest(name: string) {
  const r = await call("POST", "/v1/guest", { name, color: 2 }, undefined, { "X-Forwarded-For": `198.51.100.${ipCounter++}` });
  assert.equal(r.status, 201, JSON.stringify(r.json));
  return { token: r.json.token as string, id: r.json.user_id as string };
}

function serverCall(path: string, body: unknown) {
  const raw = JSON.stringify(body);
  const ts = String(Math.floor(Date.now() / 1000));
  return call("POST", path, raw, undefined, {
    "X-Method-Timestamp": ts,
    "X-Method-Signature": signServerRequest(cfg.serverSecret, "POST", path, ts, raw),
  });
}

test("health", async () => {
  const r = await call("GET", "/healthz");
  assert.equal(r.status, 200);
  assert.equal(r.json.ok, true);
});

test("guest identity: validation, auth, profile, logout", async () => {
  assert.equal((await call("POST", "/v1/guest", { name: "<x>" })).json.error, "NAME_INVALID_CHARACTERS");
  assert.equal((await call("POST", "/v1/guest", { name: "a" })).json.error, "NAME_TOO_SHORT");
  assert.equal((await call("POST", "/v1/guest", "not json")).json.error, "INVALID_JSON");
  const g = await guest("  Mira   K ");
  const me = await call("GET", "/v1/me", undefined, g.token);
  assert.equal(me.json.name, "Mira K");
  assert.equal((await call("GET", "/v1/me")).status, 401, "no token");
  assert.equal((await call("GET", "/v1/me", undefined, "forged-token")).status, 401, "unknown token");
  assert.equal((await call("PATCH", "/v1/me", { name: "Mira" }, g.token)).json.name, "Mira");
  assert.equal((await call("GET", "/v1/me", undefined, g.token, { "X-Method-Protocol": "999" })).status, 426);
  await call("POST", "/v1/logout", {}, g.token);
  assert.equal((await call("GET", "/v1/me", undefined, g.token)).status, 401, "revoked");
});

test("rooms: create, join by code, password, full, started, reconnect, close", async () => {
  const owner = await guest("Owner");
  const created = await call("POST", "/v1/rooms", { map_id: "house", difficulty_id: "hard", max_players: 2, password: "s3cret" }, owner.token);
  assert.equal(created.status, 201, JSON.stringify(created.json));
  const code = created.json.code as string;
  const roomId = created.json.room_id as string;
  assert.match(code, /^\d{6}$/);
  assert.deepEqual(created.json.server, { host: "10.0.0.5", port: 24600 });
  const ownerTicket = verifyTicket(created.json.ticket as string, cfg.ticketSecret, roomId, clock);
  assert.equal(ownerTicket?.uid, owner.id);
  assert.equal(ownerTicket?.own, true, "the game server learns the room owner from the signed ticket");
  assert.equal((await call("POST", "/v1/rooms", { map_id: "black_ward", difficulty_id: "normal" }, owner.token)).json.error, "MAP_UNAVAILABLE");

  const p2 = await guest("Second");
  assert.equal((await call("POST", "/v1/rooms/join", { code: "12a456" }, p2.token)).json.error, "CODE_FORMAT");
  const wrongCode = code === "000000" ? "000001" : "000000";
  assert.equal((await call("POST", "/v1/rooms/join", { code: wrongCode }, p2.token)).status, 404);
  assert.equal((await call("POST", "/v1/rooms/join", { code }, p2.token)).json.error, "PASSWORD_REQUIRED");
  assert.equal((await call("POST", "/v1/rooms/join", { code, password: "nope!" }, p2.token)).json.error, "PASSWORD_WRONG");
  const joined = await call("POST", "/v1/rooms/join", { code, password: "s3cret" }, p2.token);
  assert.equal(joined.status, 200);
  assert.equal(joined.json.owner, false);
  assert.equal(verifyTicket(joined.json.ticket as string, cfg.ticketSecret, roomId, clock)?.own, false);

  const p3 = await guest("Third");
  assert.equal((await call("POST", "/v1/rooms/join", { code, password: "s3cret" }, p3.token)).json.error, "ROOM_FULL");

  // Game server reports the match started: new players refused, members may rejoin.
  assert.equal((await serverCall(`/v1/internal/rooms/${roomId}/status`, { state: "playing" })).status, 200);
  const p4 = await guest("Fourth");
  assert.equal((await call("POST", "/v1/rooms/join", { code, password: "s3cret" }, p4.token)).json.error, "ROOM_STARTED");
  const rejoin = await call("POST", `/v1/rooms/${roomId}/ticket`, {}, p2.token);
  assert.equal(rejoin.status, 200, "member can get a reconnect ticket");
  assert.equal((await call("POST", `/v1/rooms/${roomId}/ticket`, {}, p4.token)).json.error, "NOT_A_MEMBER");

  assert.equal((await call("POST", `/v1/rooms/${roomId}/close`, {}, p2.token)).json.error, "NOT_OWNER");
  assert.equal((await call("POST", `/v1/rooms/${roomId}/close`, {}, owner.token)).status, 200);
  assert.ok(allocator.released.includes(roomId), "server released");
  assert.equal((await call("POST", "/v1/rooms/join", { code, password: "s3cret" }, p2.token)).status, 404, "closed room code is dead");
});

test("unused rooms expire", async () => {
  const owner = await guest("Idle");
  const created = await call("POST", "/v1/rooms", { map_id: "house", difficulty_id: "normal", max_players: 4 }, owner.token);
  const p2 = await guest("Late");
  clock += 16 * 60;
  assert.equal((await call("POST", "/v1/rooms/join", { code: created.json.code }, p2.token)).status, 404);
  clock -= 16 * 60;
});

test("code guessing is rate limited per user", async () => {
  const g = await guest("Guesser");
  let limited = false;
  for (let i = 0; i < 40; i++) {
    const r = await call("POST", "/v1/rooms/join", { code: String(100000 + i) }, g.token);
    if (r.status === 429) {
      limited = true;
      assert.ok(Number(r.headers.get("retry-after")) > 0);
      break;
    }
  }
  assert.ok(limited, "guessing must be throttled");
});

test("internal endpoints require a valid server signature", async () => {
  const r = await call("POST", "/v1/internal/match-result", { room_id: "x" });
  assert.equal(r.status, 401);
  const forged = await call("POST", "/v1/internal/match-result", JSON.stringify({ room_id: "x" }), undefined, {
    "X-Method-Timestamp": String(Math.floor(Date.now() / 1000)),
    "X-Method-Signature": "00".repeat(32),
  });
  assert.equal(forged.status, 401);
});

test("verified rewards are idempotent and purchases cannot overspend", async () => {
  const owner = await guest("Payer");
  const mate = await guest("Mate");
  const created = await call("POST", "/v1/rooms", { map_id: "house", difficulty_id: "normal", max_players: 4 }, owner.token);
  await call("POST", "/v1/rooms/join", { code: created.json.code }, mate.token);
  const outsider = await guest("Outsider");
  const report = {
    room_id: created.json.room_id, match_id: "abcdef0123456789", map_id: "house", difficulty_id: "normal",
    players: [
      { user_id: owner.id, escaped: true, optional_completed: 1 },
      { user_id: mate.id, escaped: false, optional_completed: 0 },
      { user_id: outsider.id, escaped: true, optional_completed: 3 },
    ],
  };
  const first = await serverCall("/v1/internal/match-result", report);
  assert.equal(first.status, 200);
  assert.equal(first.json.credited, 275, "100 + 25 + 150 first completion");
  const again = await serverCall("/v1/internal/match-result", report);
  assert.equal(again.json.credited, 0, "retry pays nothing");
  assert.equal((await call("GET", "/v1/wallet", undefined, owner.token)).json.balance, 275);
  assert.equal((await call("GET", "/v1/wallet", undefined, outsider.token)).json.balance, 0, "non-members get nothing");

  const buy = (item: string, key: string) => call("POST", "/v1/shop/purchase", { item_id: item, idempotency_key: key }, owner.token);
  assert.equal((await buy("flashlight_method", "key-00000001")).json.error, "INSUFFICIENT_FUNDS");
  const ok = await buy("flashlight_sodium", "key-00000002");
  assert.equal(ok.status, 200);
  assert.equal(ok.json.balance, 125);
  const retried = await buy("flashlight_sodium", "key-00000002");
  assert.equal(retried.json.balance, 125, "same idempotency key never charges twice");
  assert.equal((await buy("flashlight_surgical", "key-00000003")).json.error, "INSUFFICIENT_FUNDS", "cannot go below zero");
  assert.equal((await buy("flashlight_sodium", "key-00000004")).json.error, "ALREADY_OWNED");
  assert.equal((await buy("no_such_item", "key-00000005")).status, 404);
  assert.equal((await buy("flashlight_sodium", "x")).json.error, "IDEMPOTENCY_KEY_REQUIRED");
  assert.equal((await call("GET", "/v1/wallet", undefined, owner.token)).json.balance, 125);
});

test("guest creation is rate limited per network source", async () => {
  let limited = false;
  for (let i = 0; i < 15; i++) {
    const r = await call("POST", "/v1/guest", { name: `Bot${i}` }, undefined, { "X-Forwarded-For": "203.0.113.9" });
    if (r.status === 429) {
      limited = true;
      break;
    }
  }
  assert.ok(limited);
});
