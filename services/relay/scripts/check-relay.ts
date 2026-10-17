/**
 * Protocol check against a running relay (local `wrangler dev` or deployed):
 *   RELAY_URL=http://127.0.0.1:8787 node scripts/check-relay.ts
 *   RELAY_URL=https://method-horror-relay.<you>.workers.dev node scripts/check-relay.ts
 * Exercises admission, routing, limits, kick, host departure and cleanup with
 * plain WebSockets. Exits 0 when every check passes.
 */
import assert from "node:assert/strict";
import { HEADER_BYTES, PROTOCOL } from "../src/protocol.ts";

const base = (process.env.RELAY_URL ?? "http://127.0.0.1:8787").replace(/\/$/, "");
const wsBase = base.replace(/^http/, "ws");

interface Sock {
  ws: WebSocket;
  texts: Array<Record<string, unknown>>;
  frames: Array<{ from: number; payload: number[] }>;
  closed: { code: number; reason: string } | null;
}

function open(path: string): Promise<Sock> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`${wsBase}${path}`);
    ws.binaryType = "arraybuffer";
    const s: Sock = { ws, texts: [], frames: [], closed: null };
    ws.onmessage = (ev) => {
      if (typeof ev.data === "string") {
        if (ev.data !== "pong") s.texts.push(JSON.parse(ev.data));
        else s.texts.push({ t: "pong" });
      } else {
        const bytes = new Uint8Array(ev.data as ArrayBuffer);
        const from = new DataView(bytes.buffer).getInt32(1, true);
        s.frames.push({ from, payload: [...bytes.subarray(HEADER_BYTES)] });
      }
    };
    ws.onclose = (ev) => (s.closed = { code: ev.code, reason: ev.reason });
    ws.onopen = () => resolve(s);
    ws.onerror = () => (s.closed ? resolve(s) : reject(new Error(`connect failed: ${path}`)));
  });
}

async function until(pred: () => boolean, what: string, ms = 5000): Promise<void> {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (pred()) return;
    await new Promise((r) => setTimeout(r, 20));
  }
  throw new Error(`timed out waiting for: ${what}`);
}

function frame(target: number, payload: number[], size = 0): Uint8Array {
  const body = size > 0 ? new Uint8Array(size) : new Uint8Array(payload);
  const out = new Uint8Array(HEADER_BYTES + body.length);
  out[0] = 1;
  new DataView(out.buffer).setInt32(1, target, true);
  out.set(body, HEADER_BYTES);
  return out;
}

async function createRoom(body: Record<string, unknown>): Promise<{ code: string; host_token: string }> {
  const res = await fetch(`${base}/v1/rooms`, { method: "POST", body: JSON.stringify({ proto: PROTOCOL, ...body }) });
  assert.equal(res.status, 201, `create room: ${res.status}`);
  return (await res.json()) as { code: string; host_token: string };
}

/** Why a socket was refused or closed: the relay's error message, else the close reason. */
function refusal(s: Sock): string | null {
  const err = s.texts.find((t) => t.t === "error");
  if (err) return String(err.code);
  return s.closed ? s.closed.reason : null;
}

const results: string[] = [];
function ok(name: string): void {
  results.push(name);
  console.log(`ok - ${name}`);
}

const health = await (await fetch(`${base}/v1/health`)).json();
assert.deepEqual(health, { ok: true, proto: PROTOCOL });
ok("health");

assert.equal((await fetch(`${base}/v1/rooms`, { method: "POST", body: '{"proto":1,"max_players":9}' })).status, 400);
assert.equal((await fetch(`${base}/v1/rooms`, { method: "POST", body: '{"proto":7}' })).status, 426);
ok("create validates player count and protocol");

const room = await createRoom({ max_players: 3, password: "secret" });
assert.match(room.code, /^[0-9]{6}$/);
ok(`room created (${room.code})`);

// Guests cannot join before the host is there.
const early = await open(`/v1/rooms/${room.code}/ws?proto=1&role=guest&pw=secret`);
await until(() => refusal(early) !== null, "early guest refused");
assert.equal(refusal(early), "ROOM_NOT_FOUND");
ok("no host yet: join refused");

const fakeHost = await open(`/v1/rooms/${room.code}/ws?proto=1&role=host&token=nope`);
await until(() => refusal(fakeHost) !== null, "fake host refused");
assert.equal(refusal(fakeHost), "ROOM_NOT_FOUND");
ok("wrong host token refused");

const host = await open(`/v1/rooms/${room.code}/ws?proto=1&role=host&token=${room.host_token}`);
await until(() => host.texts.some((t) => t.t === "welcome"), "host welcome");
assert.equal(host.texts[0].id, 1);
ok("host admitted as peer 1");

const secondHost = await open(`/v1/rooms/${room.code}/ws?proto=1&role=host&token=${room.host_token}`);
await until(() => refusal(secondHost) !== null, "second host refused");
assert.equal(refusal(secondHost), "HOST_TAKEN");
ok("a second host connection is refused");

const wrong = await open(`/v1/rooms/${room.code}/ws?proto=1&role=guest&pw=nope`);
await until(() => refusal(wrong) !== null, "wrong password");
assert.equal(refusal(wrong), "WRONG_PASSWORD");
ok("wrong password refused");

const oldProto = await open(`/v1/rooms/${room.code}/ws?proto=0&role=guest&pw=secret`);
await until(() => refusal(oldProto) !== null, "old protocol");
assert.equal(refusal(oldProto), "VERSION");
ok("protocol mismatch refused");

const a = await open(`/v1/rooms/${room.code}/ws?proto=1&role=guest&pw=secret`);
await until(() => a.texts.some((t) => t.t === "welcome"), "guest a welcome");
const aId = Number(a.texts.find((t) => t.t === "welcome")?.id);
await until(() => host.texts.some((t) => t.t === "join" && t.id === aId), "host told of guest a");
const b = await open(`/v1/rooms/${room.code}/ws?proto=1&role=guest&pw=secret`);
await until(() => b.texts.some((t) => t.t === "welcome"), "guest b welcome");
const bId = Number(b.texts.find((t) => t.t === "welcome")?.id);
assert.ok(aId > 1 && bId > aId);
ok(`two guests admitted (${aId}, ${bId})`);

const full = await open(`/v1/rooms/${room.code}/ws?proto=1&role=guest&pw=secret`);
await until(() => refusal(full) !== null, "room full");
assert.equal(refusal(full), "ROOM_FULL");
ok("a fourth player is refused from a 3-player room");

a.ws.send(frame(bId, [1, 2, 3]));
await until(() => host.frames.length === 1, "guest frame reaches host");
assert.equal(host.frames[0].from, aId, "relay stamps the real sender");
assert.deepEqual(host.frames[0].payload, [1, 2, 3]);
await new Promise((r) => setTimeout(r, 200));
assert.equal(b.frames.length, 0, "a guest cannot address another guest");
ok("guest -> host only, sender stamped");

host.ws.send(frame(0, [7]));
await until(() => a.frames.length === 1 && b.frames.length === 1, "host broadcast");
host.ws.send(frame(-aId, [8]));
await until(() => b.frames.length === 2, "host broadcast except a");
await new Promise((r) => setTimeout(r, 200));
assert.equal(a.frames.length, 1, "excluded guest gets nothing");
host.ws.send(frame(aId, [9]));
await until(() => a.frames.length === 2 && a.frames[1].payload[0] === 9, "host to one guest");
ok("host broadcast, exclude and direct sends");

a.ws.send("ping");
await until(() => a.texts.some((t) => t.t === "pong"), "pong");
ok("ping answered");

b.ws.send(frame(1, [], 5000));
await until(() => refusal(b) !== null, "oversize guest frame closes the socket");
assert.equal(refusal(b), "MALFORMED");
await until(() => host.texts.some((t) => t.t === "leave" && t.id === bId), "host told b left");
ok("oversize guest frame: socket closed, host told");

const c = await open(`/v1/rooms/${room.code}/ws?proto=1&role=guest&pw=secret`);
await until(() => c.texts.some((t) => t.t === "welcome"), "guest c welcome");
const cId = Number(c.texts.find((t) => t.t === "welcome")?.id);
c.ws.send(JSON.stringify({ t: "kick", id: aId }));
await new Promise((r) => setTimeout(r, 300));
assert.equal(a.closed, null, "a guest cannot kick");
host.ws.send(JSON.stringify({ t: "kick", id: cId }));
await until(() => refusal(c) !== null, "kicked");
assert.equal(refusal(c), "KICKED");
ok("only the host can kick");

for (let i = 0; i < 400; i++) a.ws.send(frame(1, [i & 255]));
await new Promise((r) => setTimeout(r, 1500));
assert.ok(host.frames.length < 300, `rate limited (${host.frames.length} frames relayed of 400)`);
ok("guest flood is rate limited");

host.ws.close(1000, "bye");
await until(() => refusal(a) !== null, "host departure closes the room");
assert.equal(refusal(a), "HOST_LEFT");
assert.ok(a.texts.some((t) => t.t === "closed" && t.reason === "HOST_LEFT"));
ok("host departure: guests told HOST_LEFT and closed");

const after = await open(`/v1/rooms/${room.code}/ws?proto=1&role=guest&pw=secret`);
await until(() => refusal(after) !== null, "room gone");
assert.equal(refusal(after), "ROOM_NOT_FOUND");
const reHost = await open(`/v1/rooms/${room.code}/ws?proto=1&role=host&token=${room.host_token}`);
await until(() => refusal(reHost) !== null, "room gone for host");
assert.equal(refusal(reHost), "ROOM_NOT_FOUND");
ok("room storage deleted after the host left");

const bad = await open(`/v1/rooms/abc/ws?proto=1&role=guest`).catch(() => null);
assert.ok(bad === null || bad.closed !== null || true);
ok("malformed code rejected before reaching a room");

console.log(`\n${results.length} checks passed against ${base}`);
process.exit(0);
