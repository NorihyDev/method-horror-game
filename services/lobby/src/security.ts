// Security primitives: tokens, tickets (mirrors game/scripts/network/net_protocol.gd),
// password hashing, room codes and display-name validation
// (mirrors game/scripts/core/name_validator.gd).

import { createHash, createHmac, randomBytes, randomInt, scrypt, timingSafeEqual } from "node:crypto";

export function b64url(buf: Buffer): string {
  return buf.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function b64urlDecode(text: string): Buffer {
  return Buffer.from(text.replace(/-/g, "+").replace(/_/g, "/"), "base64");
}

export function sha256Hex(text: string): string {
  return createHash("sha256").update(text, "utf8").digest("hex");
}

/** Opaque bearer token: 32 random bytes. Only its SHA-256 is stored. */
export function newToken(): string {
  return b64url(randomBytes(32));
}

export function newId(prefix: string): string {
  return `${prefix}_${b64url(randomBytes(12))}`;
}

export interface TicketPayload {
  v: 1;
  room: string;
  uid: string;
  name: string;
  color: number;
  exp: number;
}

export function signTicket(payload: TicketPayload, secret: string): string {
  const body = Buffer.from(JSON.stringify(payload), "utf8");
  const sig = createHmac("sha256", secret).update(body).digest();
  return `${b64url(body)}.${b64url(sig)}`;
}

export function verifyTicket(ticket: string, secret: string, roomId: string, nowSeconds: number): TicketPayload | null {
  const parts = ticket.split(".");
  if (parts.length !== 2 || ticket.length > 1500) return null;
  const body = b64urlDecode(parts[0] ?? "");
  const sig = b64urlDecode(parts[1] ?? "");
  const expected = createHmac("sha256", secret).update(body).digest();
  if (sig.length !== expected.length || !timingSafeEqual(sig, expected)) return null;
  let payload: unknown;
  try {
    payload = JSON.parse(body.toString("utf8"));
  } catch {
    return null;
  }
  const p = payload as Partial<TicketPayload>;
  if (p.v !== 1 || p.room !== roomId || typeof p.uid !== "string" || typeof p.exp !== "number") return null;
  if (p.exp < nowSeconds) return null;
  return p as TicketPayload;
}

/** HMAC over method + path + timestamp + body for server→lobby calls. */
export function signServerRequest(secret: string, method: string, path: string, timestamp: string, body: string): string {
  return createHmac("sha256", secret).update(`${method}\n${path}\n${timestamp}\n${body}`).digest("hex");
}

export function verifyServerRequest(
  secret: string, method: string, path: string, timestamp: string, body: string, signature: string, nowSeconds: number,
): boolean {
  const ts = Number.parseInt(timestamp, 10);
  if (!Number.isFinite(ts) || Math.abs(nowSeconds - ts) > 120) return false;
  const expected = Buffer.from(signServerRequest(secret, method, path, timestamp, body), "hex");
  const given = Buffer.from(signature, "hex");
  return given.length === expected.length && timingSafeEqual(given, expected);
}

const SCRYPT_N = 16384;
const SCRYPT_KEYLEN = 32;

function scryptAsync(password: string, salt: Buffer): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    scrypt(password, salt, SCRYPT_KEYLEN, { N: SCRYPT_N, r: 8, p: 1 }, (err, key) => (err ? reject(err) : resolve(key)));
  });
}

/** Room passwords: scrypt with a per-room salt. Format: scrypt$N$salt$hash */
export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const hash = await scryptAsync(password, salt);
  return `scrypt$${SCRYPT_N}$${b64url(salt)}$${b64url(hash)}`;
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [algo, n, saltText, hashText] = stored.split("$");
  if (algo !== "scrypt" || Number(n) !== SCRYPT_N || !saltText || !hashText) return false;
  const hash = await scryptAsync(password, b64urlDecode(saltText));
  const expected = b64urlDecode(hashText);
  return hash.length === expected.length && timingSafeEqual(hash, expected);
}

/** Six digits from a CSPRNG; uniqueness is enforced by the caller. */
export function newRoomCode(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, "0");
}

export const NAME_MIN = 2;
export const NAME_MAX = 20;

export function normalizeName(raw: string): string {
  return raw.trim().replace(/[\s 　]+/gu, " ");
}

/** Mirrors NameValidator._is_allowed_codepoint in the client. */
export function isAllowedCodepoint(code: number): boolean {
  if (code < 0x20 || (code >= 0x7f && code <= 0x9f)) return false;
  if (code >= 0x200b && code <= 0x200f) return false;
  if (code >= 0x202a && code <= 0x202e) return false;
  if (code >= 0x2066 && code <= 0x2069) return false;
  if (code === 0xfeff || code === 0x00ad) return false;
  if (code >= 0xe000 && code <= 0xf8ff) return false;
  if (code >= 0xd800 && code <= 0xdfff) return false;
  if (code >= 0xfff0) return false;
  if ([0x5b, 0x5d, 0x3c, 0x3e, 0x5c, 0x60, 0x7b, 0x7d].includes(code)) return false;
  return true;
}

export type NameResult = "ok" | "too_short" | "too_long" | "invalid_characters";

export function validateName(raw: unknown): NameResult {
  if (typeof raw !== "string") return "invalid_characters";
  const name = normalizeName(raw);
  // Length is counted in code units like Godot's String.length() for BMP text.
  const length = [...name].length;
  if (length < NAME_MIN) return "too_short";
  if (length > NAME_MAX) return "too_long";
  for (const ch of name) {
    if (!isAllowedCodepoint(ch.codePointAt(0) ?? 0)) return "invalid_characters";
  }
  return "ok";
}
