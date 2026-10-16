import { test } from "node:test";
import assert from "node:assert/strict";
import {
  hashPassword, newRoomCode, signServerRequest, signTicket, validateName, verifyPassword, verifyServerRequest, verifyTicket,
} from "../src/security.ts";
import { RateLimiter } from "../src/ratelimit.ts";
import { computeReward } from "../src/catalog.ts";

const SECRET = "test-secret-not-for-production-0123456789";
const now = () => Math.floor(Date.now() / 1000);

test("tickets verify and bind room, expiry and signature", () => {
  const t = signTicket({ v: 1, room: "room_a", uid: "usr_abcdefgh", name: "Ann", color: 1, exp: now() + 60 }, SECRET);
  assert.equal(verifyTicket(t, SECRET, "room_a", now())?.uid, "usr_abcdefgh");
  assert.equal(verifyTicket(t, SECRET, "room_b", now()), null, "other room");
  assert.equal(verifyTicket(t, "x".repeat(40), "room_a", now()), null, "other secret");
  assert.equal(verifyTicket(t, SECRET, "room_a", now() + 120), null, "expired");
  const [body, sig] = t.split(".");
  const forged = Buffer.from(JSON.stringify({ v: 1, room: "room_a", uid: "usr_attacker", name: "X", color: 0, exp: now() + 60 }))
    .toString("base64url");
  assert.equal(verifyTicket(`${forged}.${sig}`, SECRET, "room_a", now()), null, "payload swap");
  assert.equal(verifyTicket(`${body}.${sig}x`, SECRET, "room_a", now()), null, "bad signature");
});

test("ticket minted by the Godot client code verifies here (cross-language)", () => {
  // Minted by NetProtocol.make_ticket (Godot 4.7.2) with SECRET; exp 4102444800 (2100-01-01).
  const fromGodot =
    "eyJjb2xvciI6MiwiZXhwIjo0MTAyNDQ0ODAwLCJuYW1lIjoiQW5uIiwicm9vbSI6InJvb21fZ29kb3QiLCJ1aWQiOiJ1c3JfZnJvbWdvZG90IiwidiI6MX0." +
    "ikQDHmVgiHFdkWjJNq6l7rtpVBxYfVZWRHyjbfd7FQM";
  assert.equal(verifyTicket(fromGodot, SECRET, "room_godot", now())?.uid, "usr_fromgodot");
});

test("room codes are six digits", () => {
  for (let i = 0; i < 2000; i++) assert.match(newRoomCode(), /^\d{6}$/);
});

test("passwords use scrypt with per-hash salt and verify in constant time", async () => {
  const h1 = await hashPassword("hunter22");
  const h2 = await hashPassword("hunter22");
  assert.notEqual(h1, h2, "salted");
  assert.ok(h1.startsWith("scrypt$"));
  assert.equal(await verifyPassword("hunter22", h1), true);
  assert.equal(await verifyPassword("hunter23", h1), false);
  assert.equal(await verifyPassword("hunter22", "plain$text"), false);
});

test("display names mirror the client rules", () => {
  assert.equal(validateName("  Night   Owl "), "ok");
  assert.equal(validateName("A"), "too_short");
  assert.equal(validateName("x".repeat(21)), "too_long");
  assert.equal(validateName("[b]x[/b]"), "invalid_characters");
  assert.equal(validateName("ab‮cd"), "invalid_characters");
  assert.equal(validateName("ab​cd"), "invalid_characters");
  assert.equal(validateName("Zoé"), "ok");
  assert.equal(validateName("山田太郎"), "ok");
  assert.equal(validateName(42), "invalid_characters");
});

test("server request signatures expire and bind the request", () => {
  const ts = String(now());
  const sig = signServerRequest(SECRET, "POST", "/v1/internal/match-result", ts, "{}");
  assert.equal(verifyServerRequest(SECRET, "POST", "/v1/internal/match-result", ts, "{}", sig, now()), true);
  assert.equal(verifyServerRequest(SECRET, "POST", "/v1/internal/match-result", ts, "{\"x\":1}", sig, now()), false);
  assert.equal(verifyServerRequest(SECRET, "POST", "/v1/other", ts, "{}", sig, now()), false);
  assert.equal(verifyServerRequest(SECRET, "POST", "/v1/internal/match-result", ts, "{}", sig, now() + 600), false, "replay window");
});

test("rate limiter caps bursts and refills", () => {
  let t = 1000;
  const rl = new RateLimiter(() => t);
  const limit = { capacity: 3, perSecond: 1 };
  assert.equal(rl.take("k", limit), 0);
  assert.equal(rl.take("k", limit), 0);
  assert.equal(rl.take("k", limit), 0);
  assert.ok(rl.take("k", limit) > 0, "fourth call limited");
  t += 1;
  assert.equal(rl.take("k", limit), 0, "refilled");
  assert.equal(rl.take("other", limit), 0, "independent keys");
});

test("rewards follow the shared table", () => {
  assert.equal(computeReward("house", "normal", { escaped: true, optionalCompleted: 2, firstCompletion: true }), 300);
  assert.equal(computeReward("house", "hard", { escaped: true, optionalCompleted: 0, firstCompletion: false }), 150);
  assert.equal(computeReward("house", "normal", { escaped: false, optionalCompleted: 3, firstCompletion: true }), 0);
  assert.equal(computeReward("unknown", "normal", { escaped: true, optionalCompleted: 0, firstCompletion: false }), 0);
  assert.equal(computeReward("house", "normal", { escaped: true, optionalCompleted: 1e9, firstCompletion: false }), 350, "bounded");
});
