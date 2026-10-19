import assert from "node:assert/strict";
import { test } from "node:test";
import {
  HEADER_BYTES,
  MAX_PLAYERS,
  PROTOCOL,
  TokenBucket,
  encodeRelayFrame,
  generateCode,
  isValidCode,
  isValidPassword,
  parseClientFrame,
  parseControl,
  parseCreate,
  route,
  safeEqual,
} from "../src/protocol.ts";

const random = (n: number) => crypto.getRandomValues(new Uint8Array(n));

test("codes are six digits and vary", () => {
  const seen = new Set<string>();
  for (let i = 0; i < 500; i++) {
    const c = generateCode(random);
    assert.ok(isValidCode(c), c);
    seen.add(c);
  }
  assert.ok(seen.size > 490, "codes are not repeating");
  assert.equal(isValidCode("12345"), false);
  assert.equal(isValidCode("12a456"), false);
  assert.equal(isValidCode(123456), false);
});

test("create requests are validated", () => {
  assert.deepEqual(parseCreate({ proto: PROTOCOL, max_players: 3, password: "x" }), {
    proto: PROTOCOL,
    max_players: 3,
    password: "x",
  });
  assert.equal((parseCreate({ proto: PROTOCOL }) as { max_players: number }).max_players, MAX_PLAYERS);
  assert.deepEqual(parseCreate({ proto: 99, max_players: 2 }), { error: "VERSION" });
  assert.deepEqual(parseCreate({ proto: PROTOCOL, max_players: 10 }).max_players, 10, "ten players allowed");
  assert.deepEqual(parseCreate({ proto: PROTOCOL, max_players: 11 }), { error: "BAD_REQUEST" }, "ten players max");
  assert.deepEqual(parseCreate({ proto: PROTOCOL, max_players: 1 }), { error: "BAD_REQUEST" });
  assert.deepEqual(parseCreate({ proto: PROTOCOL, max_players: 2.5 }), { error: "BAD_REQUEST" });
  assert.deepEqual(parseCreate({ proto: PROTOCOL, password: "a".repeat(33) }), { error: "BAD_REQUEST" });
  assert.deepEqual(parseCreate("nope"), { error: "BAD_REQUEST" });
  assert.equal(isValidPassword("café"), false, "printable ASCII only");
});

test("frames round-trip and malformed frames are rejected", () => {
  const payload = new Uint8Array([9, 8, 7]);
  const client = new Uint8Array(HEADER_BYTES + 3);
  client[0] = 1;
  new DataView(client.buffer).setInt32(1, -3, true);
  client[5] = 2;
  client[6] = 1;
  client.set(payload, HEADER_BYTES);
  const parsed = parseClientFrame(client.buffer);
  assert.ok(parsed);
  assert.equal(parsed.target, -3);
  assert.equal(parsed.channel, 2);
  assert.equal(parsed.mode, 1);
  assert.deepEqual([...parsed.payload], [9, 8, 7]);
  const out = encodeRelayFrame(5, 2, 1, payload);
  assert.equal(new DataView(out.buffer).getInt32(1, true), 5, "the relay stamps the real sender");
  assert.equal(parseClientFrame(new Uint8Array([1, 0, 0])), null, "too short");
  assert.equal(parseClientFrame(new Uint8Array([2, 0, 0, 0, 0, 0, 0])), null, "unknown kind");
  assert.equal(parseClientFrame(new Uint8Array([1, 0, 0, 0, 0, 0, 3])), null, "unknown transfer mode");
});

test("guests reach only the host; the host addresses guests", () => {
  const members = [1, 2, 3, 4];
  assert.deepEqual(route(2, 3, members), [1], "a guest cannot address another guest");
  assert.deepEqual(route(2, 0, members), [1], "a guest broadcast goes to the host only");
  assert.deepEqual(route(3, 1, [2, 3]), [], "no host, nobody");
  assert.deepEqual(route(1, 0, members), [2, 3, 4]);
  assert.deepEqual(route(1, 3, members), [3]);
  assert.deepEqual(route(1, 9, members), [], "unknown guest");
  assert.deepEqual(route(1, -3, members), [2, 4]);
  assert.deepEqual(route(1, 1, members), [], "not to itself");
});

test("control messages: only the host may kick", () => {
  assert.deepEqual(parseControl('{"t":"kick","id":3}', true), { t: "kick", id: 3 });
  assert.equal(parseControl('{"t":"kick","id":3}', false), null);
  assert.equal(parseControl('{"t":"kick","id":1}', true), null, "cannot kick the host");
  assert.deepEqual(parseControl('{"t":"leave"}', false), { t: "leave" });
  assert.equal(parseControl("not json", true), null);
  assert.equal(parseControl(`{"t":"leave","x":"${"a".repeat(600)}"}`, false), null, "oversize");
});

test("token bucket limits sustained rate and refills", () => {
  const b = new TokenBucket(5, 10, 0);
  let allowed = 0;
  for (let i = 0; i < 20; i++) if (b.take(0)) allowed++;
  assert.equal(allowed, 5, "burst capped");
  assert.equal(b.take(50), false, "half a token after 50 ms");
  assert.equal(b.take(200), true, "refilled");
});

test("host tokens compare in constant time", () => {
  assert.equal(safeEqual("abcd", "abcd"), true);
  assert.equal(safeEqual("abcd", "abce"), false);
  assert.equal(safeEqual("abc", "abcd"), false);
});
