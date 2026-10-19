/**
 * METHOD HORROR relay protocol, version 1 (shared by the Worker, the room
 * Durable Object and the tests). Pure functions only: no Cloudflare APIs.
 *
 * Transport: one secure WebSocket per player to the room's Durable Object.
 * - Binary frames carry the game's own packets (Godot SceneMultiplayer) between
 *   the room creator's device (the "host", peer 1) and the other players.
 *     client -> relay: [u8 kind=1][i32 target LE][u8 channel][u8 mode][payload]
 *     relay -> client: [u8 kind=1][i32 from LE][u8 channel][u8 mode][payload]
 *   A guest can only reach the host; the host can reach one guest (target > 1),
 *   every guest (0) or every guest but one (-id).
 * - Text frames are small JSON control messages (welcome, join, leave, kick,
 *   closed, error). "ping" is answered "pong" by the runtime (not billed).
 */

export const PROTOCOL = 1;
export const KIND_DATA = 1;
export const HEADER_BYTES = 7;
export const HOST_ID = 1;
export const MIN_PLAYERS = 2;
/** The host's phone simulates the match (enemy AI, physics) for everyone. */
export const MAX_PLAYERS = 10;
export const CODE_LENGTH = 6;
export const MAX_PASSWORD = 32;

export const LIMITS = {
  /** Guests send intentions (movement, interactions): small. */
  guestFrameBytes: 4096,
  /** The host sends full match snapshots on join/reconnect (measured ~5 KB). */
  hostFrameBytes: 65536,
  controlBytes: 512,
  createBodyBytes: 1024,
  guest: { capacity: 120, refillPerSecond: 60 },
  host: { capacity: 600, refillPerSecond: 300 },
  /** Dropped frames tolerated before a socket is closed for abuse. */
  maxDrops: 300,
  /** Wrong passwords before the room refuses joins for lockoutMs. */
  passwordFailures: 8,
  lockoutMs: 60_000,
  /** A created room must see its host within this time. */
  hostGraceMs: 120_000,
  /** Hard cap on a room's life. */
  maxRoomMs: 4 * 60 * 60 * 1000,
} as const;

/** WebSocket close codes (4000-4999 are application-defined). */
export const CLOSE = {
  LEFT: 4000,
  HOST_LEFT: 4001,
  ROOM_FULL: 4002,
  KICKED: 4003,
  ROOM_NOT_FOUND: 4004,
  WRONG_PASSWORD: 4005,
  VERSION: 4006,
  RATE_LIMITED: 4007,
  MALFORMED: 4008,
  HOST_TAKEN: 4009,
  ROOM_EXPIRED: 4010,
  LOCKED_OUT: 4011,
} as const;

export type CloseReason = keyof typeof CLOSE;

export function isValidCode(code: unknown): code is string {
  return typeof code === "string" && /^[0-9]{6}$/.test(code);
}

/** Six random digits from a cryptographic source. */
export function generateCode(randomBytes: (n: number) => Uint8Array): string {
  let out = "";
  while (out.length < CODE_LENGTH) {
    for (const b of randomBytes(8)) {
      // Reject 250-255 so every digit is equally likely.
      if (b < 250 && out.length < CODE_LENGTH) out += String(b % 10);
    }
  }
  return out;
}

export function isValidPassword(pw: unknown): pw is string {
  return typeof pw === "string" && pw.length <= MAX_PASSWORD && /^[\x20-\x7E]*$/.test(pw);
}

export function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

export async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return toHex(new Uint8Array(digest));
}

/** Constant-time comparison of two equal-length hex strings. */
export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export interface CreateRequest {
  proto: number;
  max_players: number;
  password: string;
}

/** Validates the body of POST /v1/rooms. */
export function parseCreate(body: unknown): CreateRequest | { error: string } {
  if (typeof body !== "object" || body === null) return { error: "BAD_REQUEST" };
  const b = body as Record<string, unknown>;
  if (b.proto !== PROTOCOL) return { error: "VERSION" };
  const max = b.max_players ?? MAX_PLAYERS;
  if (typeof max !== "number" || !Number.isInteger(max) || max < MIN_PLAYERS || max > MAX_PLAYERS) {
    return { error: "BAD_REQUEST" };
  }
  const password = b.password ?? "";
  if (!isValidPassword(password)) return { error: "BAD_REQUEST" };
  return { proto: PROTOCOL, max_players: max, password };
}

export interface ClientFrame {
  target: number;
  channel: number;
  mode: number;
  payload: Uint8Array;
}

/** Parses a binary frame from a client; null if malformed. */
export function parseClientFrame(data: ArrayBuffer | Uint8Array): ClientFrame | null {
  const bytes = data instanceof Uint8Array ? data : new Uint8Array(data);
  if (bytes.length < HEADER_BYTES || bytes[0] !== KIND_DATA) return null;
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const mode = bytes[6];
  if (mode > 2) return null;
  return { target: view.getInt32(1, true), channel: bytes[5], mode, payload: bytes.subarray(HEADER_BYTES) };
}

/** Builds the frame a client receives. */
export function encodeRelayFrame(from: number, channel: number, mode: number, payload: Uint8Array): Uint8Array {
  const out = new Uint8Array(HEADER_BYTES + payload.length);
  const view = new DataView(out.buffer);
  out[0] = KIND_DATA;
  view.setInt32(1, from, true);
  out[5] = channel;
  out[6] = mode;
  out.set(payload, HEADER_BYTES);
  return out;
}

/**
 * Who receives a frame. Guests talk only to the host, whatever target they
 * claim; the host addresses one guest, all guests, or all but one.
 */
export function route(senderId: number, target: number, memberIds: readonly number[]): number[] {
  if (senderId !== HOST_ID) return memberIds.includes(HOST_ID) ? [HOST_ID] : [];
  const guests = memberIds.filter((id) => id !== HOST_ID);
  if (target === 0) return guests;
  if (target > HOST_ID) return guests.includes(target) ? [target] : [];
  if (target < 0) return guests.filter((id) => id !== -target);
  return [];
}

export type Control = { t: "kick"; id: number } | { t: "leave" };

/** Parses a text control message; only the host may kick. */
export function parseControl(text: string, isHost: boolean): Control | null {
  if (text.length > LIMITS.controlBytes) return null;
  let v: unknown;
  try {
    v = JSON.parse(text);
  } catch {
    return null;
  }
  if (typeof v !== "object" || v === null) return null;
  const m = v as Record<string, unknown>;
  if (m.t === "leave") return { t: "leave" };
  if (m.t === "kick" && isHost && typeof m.id === "number" && Number.isInteger(m.id) && m.id > HOST_ID) {
    return { t: "kick", id: m.id };
  }
  return null;
}

/** Token bucket: `capacity` burst, `refillPerSecond` sustained. */
export class TokenBucket {
  private readonly capacity: number;
  private readonly refillPerSecond: number;
  private tokens: number;
  private last: number;
  constructor(capacity: number, refillPerSecond: number, now: number) {
    this.capacity = capacity;
    this.refillPerSecond = refillPerSecond;
    this.tokens = capacity;
    this.last = now;
  }
  take(now: number): boolean {
    this.tokens = Math.min(this.capacity, this.tokens + ((now - this.last) / 1000) * this.refillPerSecond);
    this.last = now;
    if (this.tokens < 1) return false;
    this.tokens -= 1;
    return true;
  }
}
