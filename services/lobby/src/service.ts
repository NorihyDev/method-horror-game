// Lobby business rules: guest identity, rooms, tickets, verified wallet.
// HTTP concerns live in http.ts; this module is pure logic over the DB.

import type { Db } from "./db.ts";
import { tx } from "./db.ts";
import type { Config } from "./config.ts";
import type { Allocator } from "./servers.ts";
import {
  hashPassword, newId, newRoomCode, newToken, normalizeName, sha256Hex, signTicket, validateName, verifyPassword,
} from "./security.ts";
import { CATALOG, DIFFICULTIES, PLAYABLE_MAPS, computeReward } from "./catalog.ts";

export class ApiError extends Error {
  status: number;
  code: string;
  retryAfter: number;
  constructor(status: number, code: string, retryAfter = 0) {
    super(code);
    this.status = status;
    this.code = code;
    this.retryAfter = retryAfter;
  }
}

export interface User {
  id: string;
  name: string;
  color: number;
}

interface RoomRow {
  id: string;
  code: string;
  owner_id: string;
  map_id: string;
  difficulty_id: string;
  max_players: number;
  password_hash: string | null;
  state: string;
  server_host: string | null;
  server_port: number | null;
  created_at: number;
  updated_at: number;
}

export class LobbyService {
  private db: Db;
  private cfg: Config;
  private allocator: Allocator;
  private now: () => number;

  constructor(db: Db, cfg: Config, allocator: Allocator, now: () => number = () => Math.floor(Date.now() / 1000)) {
    this.db = db;
    this.cfg = cfg;
    this.allocator = allocator;
    this.now = now;
  }

  // --- Identity -----------------------------------------------------------------------

  createGuest(rawName: unknown, rawColor: unknown): { user: User; token: string; expiresAt: number } {
    const nameCheck = validateName(rawName);
    if (nameCheck !== "ok") throw new ApiError(400, `NAME_${nameCheck.toUpperCase()}`);
    const name = normalizeName(rawName as string);
    const color = clampInt(rawColor, 0, 5);
    const id = newId("usr");
    const token = newToken();
    const t = this.now();
    const expiresAt = t + this.cfg.sessionTtlDays * 86400;
    tx(this.db, () => {
      this.db.prepare("INSERT INTO users (id, name, color, created_at, last_seen) VALUES (?, ?, ?, ?, ?)").run(id, name, color, t, t);
      this.db.prepare("INSERT INTO sessions (token_hash, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)").run(
        sha256Hex(token), id, t, expiresAt,
      );
      for (const [item, def] of Object.entries(CATALOG)) {
        if (def.price === 0) this.db.prepare("INSERT INTO owned_items VALUES (?, ?, ?)").run(id, item, t);
      }
    });
    return { user: { id, name, color }, token, expiresAt };
  }

  authenticate(token: string | undefined): User {
    if (!token || token.length > 128) throw new ApiError(401, "UNAUTHORIZED");
    const row = this.db.prepare(
      "SELECT u.id, u.name, u.color, s.expires_at FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ?",
    ).get(sha256Hex(token)) as { id: string; name: string; color: number; expires_at: number } | undefined;
    if (!row) throw new ApiError(401, "UNAUTHORIZED");
    if (row.expires_at < this.now()) {
      this.db.prepare("DELETE FROM sessions WHERE token_hash = ?").run(sha256Hex(token));
      throw new ApiError(401, "SESSION_EXPIRED");
    }
    this.db.prepare("UPDATE users SET last_seen = ? WHERE id = ?").run(this.now(), row.id);
    return { id: row.id, name: row.name, color: row.color };
  }

  updateProfile(user: User, rawName: unknown, rawColor: unknown): User {
    let name = user.name;
    if (rawName !== undefined) {
      const check = validateName(rawName);
      if (check !== "ok") throw new ApiError(400, `NAME_${check.toUpperCase()}`);
      name = normalizeName(rawName as string);
    }
    const color = rawColor === undefined ? user.color : clampInt(rawColor, 0, 5);
    this.db.prepare("UPDATE users SET name = ?, color = ? WHERE id = ?").run(name, color, user.id);
    return { id: user.id, name, color };
  }

  logout(token: string): void {
    this.db.prepare("DELETE FROM sessions WHERE token_hash = ?").run(sha256Hex(token));
  }

  /** Deletes the guest and everything tied to it (data-deletion request). */
  deleteAccount(user: User): void {
    tx(this.db, () => {
      this.db.prepare("DELETE FROM room_members WHERE user_id = ?").run(user.id);
      this.db.prepare("UPDATE rooms SET state = 'closed' WHERE owner_id = ? AND state IN ('open','playing')").run(user.id);
      this.db.prepare("DELETE FROM users WHERE id = ?").run(user.id);
    });
  }

  // --- Rooms ----------------------------------------------------------------------------

  async createRoom(
    user: User, body: { map_id?: unknown; difficulty_id?: unknown; max_players?: unknown; password?: unknown },
  ): Promise<Record<string, unknown>> {
    const mapId = String(body.map_id ?? "");
    const difficultyId = String(body.difficulty_id ?? "");
    if (!PLAYABLE_MAPS.has(mapId)) throw new ApiError(400, "MAP_UNAVAILABLE");
    if (!DIFFICULTIES.has(difficultyId)) throw new ApiError(400, "DIFFICULTY_INVALID");
    const maxPlayers = clampInt(body.max_players, 1, 6);
    let passwordHash: string | null = null;
    if (body.password !== undefined && body.password !== null && body.password !== "") {
      if (typeof body.password !== "string" || body.password.length < 4 || body.password.length > 64) {
        throw new ApiError(400, "PASSWORD_INVALID");
      }
      passwordHash = await hashPassword(body.password);
    }
    this.expireRooms();
    const id = newId("room");
    const t = this.now();
    let code = "";
    tx(this.db, () => {
      for (let attempt = 0; attempt < 50; attempt++) {
        const candidate = newRoomCode();
        const clash = this.db.prepare("SELECT 1 FROM rooms WHERE code = ? AND state IN ('open','playing')").get(candidate);
        if (!clash) {
          code = candidate;
          break;
        }
      }
      if (!code) throw new ApiError(503, "NO_CODES");
      this.db.prepare(
        `INSERT INTO rooms (id, code, owner_id, map_id, difficulty_id, max_players, password_hash, state, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'open', ?, ?)`,
      ).run(id, code, user.id, mapId, difficultyId, maxPlayers, passwordHash, t, t);
      this.db.prepare("INSERT INTO room_members VALUES (?, ?, ?)").run(id, user.id, t);
    });
    let alloc;
    try {
      alloc = await this.allocator.allocate(
        { roomId: id, code, mapId, difficultyId, maxPlayers }, (roomId) => this.onServerExit(roomId),
      );
    } catch {
      this.db.prepare("UPDATE rooms SET state = 'closed' WHERE id = ?").run(id);
      throw new ApiError(503, "SERVER_UNAVAILABLE");
    }
    this.db.prepare("UPDATE rooms SET server_host = ?, server_port = ? WHERE id = ?").run(alloc.host, alloc.port, id);
    return this.joinResponse(this.room(id)!, user);
  }

  async joinRoom(user: User, rawCode: unknown, rawPassword: unknown): Promise<Record<string, unknown>> {
    const code = String(rawCode ?? "");
    if (!/^\d{6}$/.test(code)) throw new ApiError(400, "CODE_FORMAT");
    this.expireRooms();
    const room = this.db.prepare("SELECT * FROM rooms WHERE code = ? AND state IN ('open','playing')").get(code) as
      | RoomRow | undefined;
    if (!room) throw new ApiError(404, "ROOM_NOT_FOUND");
    const member = this.isMember(room.id, user.id);
    if (room.state === "playing" && !member) throw new ApiError(409, "ROOM_STARTED");
    if (!member) {
      if (room.password_hash) {
        if (typeof rawPassword !== "string" || rawPassword === "") throw new ApiError(403, "PASSWORD_REQUIRED");
        if (!(await verifyPassword(rawPassword, room.password_hash))) throw new ApiError(403, "PASSWORD_WRONG");
      }
      tx(this.db, () => {
        const count = (this.db.prepare("SELECT COUNT(*) AS n FROM room_members WHERE room_id = ?").get(room.id) as { n: number }).n;
        if (count >= room.max_players) throw new ApiError(409, "ROOM_FULL");
        this.db.prepare("INSERT INTO room_members VALUES (?, ?, ?)").run(room.id, user.id, this.now());
        this.db.prepare("UPDATE rooms SET updated_at = ? WHERE id = ?").run(this.now(), room.id);
      });
    }
    return this.joinResponse(room, user);
  }

  /** Members (including reconnecting players) get a fresh short-lived ticket. */
  ticketFor(user: User, roomId: string): Record<string, unknown> {
    const room = this.room(roomId);
    if (!room || !["open", "playing"].includes(room.state)) throw new ApiError(410, "ROOM_CLOSED");
    if (!this.isMember(roomId, user.id)) throw new ApiError(403, "NOT_A_MEMBER");
    return this.joinResponse(room, user);
  }

  leaveRoom(user: User, roomId: string): void {
    const room = this.room(roomId);
    if (!room) return;
    if (room.state === "open") {
      this.db.prepare("DELETE FROM room_members WHERE room_id = ? AND user_id = ?").run(roomId, user.id);
    }
  }

  closeRoom(user: User, roomId: string): void {
    const room = this.room(roomId);
    if (!room) throw new ApiError(404, "ROOM_NOT_FOUND");
    if (room.owner_id !== user.id) throw new ApiError(403, "NOT_OWNER");
    this.db.prepare("UPDATE rooms SET state = 'closed', updated_at = ? WHERE id = ?").run(this.now(), roomId);
    this.allocator.release(roomId);
  }

  /** Called by the game server (HMAC-authenticated) when its phase changes. */
  serverStatus(roomId: string, state: unknown): void {
    const room = this.room(roomId);
    if (!room) throw new ApiError(404, "ROOM_NOT_FOUND");
    const next = state === "playing" ? "playing" : state === "ended" ? "ended" : "open";
    this.db.prepare("UPDATE rooms SET state = ?, updated_at = ? WHERE id = ? AND state IN ('open','playing')").run(
      next, this.now(), roomId,
    );
  }

  onServerExit(roomId: string): void {
    this.db.prepare("UPDATE rooms SET state = 'closed', updated_at = ? WHERE id = ? AND state IN ('open','playing')").run(
      this.now(), roomId,
    );
  }

  /** Unused rooms expire so codes recycle and nothing lingers. */
  expireRooms(): number {
    const cutoff = this.now() - this.cfg.roomIdleMinutes * 60;
    const stale = this.db.prepare("SELECT id FROM rooms WHERE state = 'open' AND updated_at < ?").all(cutoff) as { id: string }[];
    for (const r of stale) {
      this.db.prepare("UPDATE rooms SET state = 'expired' WHERE id = ?").run(r.id);
      this.allocator.release(r.id);
    }
    return stale.length;
  }

  // --- Verified wallet -----------------------------------------------------------------

  wallet(user: User): { balance: number; owned: string[]; ledger: unknown[] } {
    const balance = this.balance(user.id);
    const owned = (this.db.prepare("SELECT item_id FROM owned_items WHERE user_id = ?").all(user.id) as { item_id: string }[])
      .map((r) => r.item_id);
    const ledger = this.db.prepare(
      "SELECT delta, reason, created_at FROM ledger WHERE user_id = ? ORDER BY id DESC LIMIT 50",
    ).all(user.id);
    return { balance, owned, ledger };
  }

  purchase(user: User, rawItem: unknown, rawKey: unknown): { balance: number; owned: string[] } {
    const itemId = String(rawItem ?? "");
    const key = String(rawKey ?? "");
    const item = CATALOG[itemId];
    if (!item) throw new ApiError(404, "ITEM_UNKNOWN");
    if (!/^[A-Za-z0-9_-]{8,64}$/.test(key)) throw new ApiError(400, "IDEMPOTENCY_KEY_REQUIRED");
    const ref = `buy:${user.id}:${key}`;
    tx(this.db, () => {
      if (this.db.prepare("SELECT 1 FROM ledger WHERE ref = ?").get(ref)) return; // retried request: already applied
      if (this.db.prepare("SELECT 1 FROM owned_items WHERE user_id = ? AND item_id = ?").get(user.id, itemId)) {
        throw new ApiError(409, "ALREADY_OWNED");
      }
      if (this.balance(user.id) < item.price) throw new ApiError(402, "INSUFFICIENT_FUNDS");
      this.db.prepare("INSERT INTO ledger (user_id, delta, reason, ref, created_at) VALUES (?, ?, 'purchase', ?, ?)").run(
        user.id, -item.price, ref, this.now(),
      );
      this.db.prepare("INSERT INTO owned_items VALUES (?, ?, ?)").run(user.id, itemId, this.now());
    });
    return { balance: this.balance(user.id), owned: this.wallet(user).owned };
  }

  /**
   * Called by the game server (HMAC-authenticated). Rewards are computed here
   * from authoritative outcomes; a retried report cannot pay twice because each
   * credit's ref is unique per (match, user).
   */
  recordMatch(body: {
    room_id?: unknown; match_id?: unknown; map_id?: unknown; difficulty_id?: unknown; players?: unknown;
  }): { credited: number } {
    const roomId = String(body.room_id ?? "");
    const matchId = String(body.match_id ?? "");
    const mapId = String(body.map_id ?? "");
    const difficultyId = String(body.difficulty_id ?? "");
    if (!/^[a-f0-9]{8,64}$/.test(matchId)) throw new ApiError(400, "MATCH_ID_INVALID");
    const room = this.room(roomId);
    if (!room) throw new ApiError(404, "ROOM_NOT_FOUND");
    if (!Array.isArray(body.players) || body.players.length > 6) throw new ApiError(400, "PLAYERS_INVALID");
    let credited = 0;
    tx(this.db, () => {
      for (const raw of body.players as unknown[]) {
        const p = raw as { user_id?: unknown; escaped?: unknown; optional_completed?: unknown };
        const userId = String(p.user_id ?? "");
        if (!this.isMember(roomId, userId)) continue; // only members of this room
        const escaped = p.escaped === true;
        const first = escaped && !this.db.prepare("SELECT 1 FROM completions WHERE user_id = ? AND map_id = ?").get(userId, mapId);
        const amount = computeReward(mapId, difficultyId, {
          escaped, optionalCompleted: Number(p.optional_completed ?? 0), firstCompletion: Boolean(first),
        });
        const ref = `match:${matchId}:${userId}`;
        if (this.db.prepare("SELECT 1 FROM ledger WHERE ref = ?").get(ref)) continue;
        this.db.prepare("INSERT INTO ledger (user_id, delta, reason, ref, created_at) VALUES (?, ?, 'match', ?, ?)").run(
          userId, amount, ref, this.now(),
        );
        if (escaped) this.db.prepare("INSERT OR IGNORE INTO completions VALUES (?, ?)").run(userId, mapId);
        credited += amount;
      }
      this.db.prepare("UPDATE rooms SET state = 'ended', updated_at = ? WHERE id = ?").run(this.now(), roomId);
    });
    return { credited };
  }

  /** Retention: drop expired sessions, idle guests and old rooms. */
  cleanup(): void {
    const t = this.now();
    this.db.prepare("DELETE FROM sessions WHERE expires_at < ?").run(t);
    this.db.prepare("DELETE FROM users WHERE last_seen < ? AND id NOT IN (SELECT user_id FROM sessions)").run(t - 180 * 86400);
    this.db.prepare("DELETE FROM rooms WHERE state NOT IN ('open','playing') AND updated_at < ?").run(t - 86400);
  }

  // --- Internals ------------------------------------------------------------------------

  private balance(userId: string): number {
    return (this.db.prepare("SELECT COALESCE(SUM(delta), 0) AS b FROM ledger WHERE user_id = ?").get(userId) as { b: number }).b;
  }

  private room(id: string): RoomRow | undefined {
    return this.db.prepare("SELECT * FROM rooms WHERE id = ?").get(id) as RoomRow | undefined;
  }

  private isMember(roomId: string, userId: string): boolean {
    return Boolean(this.db.prepare("SELECT 1 FROM room_members WHERE room_id = ? AND user_id = ?").get(roomId, userId));
  }

  private joinResponse(room: RoomRow, user: User): Record<string, unknown> {
    const ticket = signTicket(
      { v: 1, room: room.id, uid: user.id, name: user.name, color: user.color, exp: this.now() + this.cfg.ticketTtlSeconds },
      this.cfg.ticketSecret,
    );
    return {
      room_id: room.id,
      code: room.code,
      map_id: room.map_id,
      difficulty_id: room.difficulty_id,
      max_players: room.max_players,
      owner: room.owner_id === user.id,
      has_password: room.password_hash !== null,
      server: { host: room.server_host, port: room.server_port },
      ticket,
      ticket_expires_in: this.cfg.ticketTtlSeconds,
    };
  }
}

function clampInt(value: unknown, min: number, max: number): number {
  const n = Math.floor(Number(value));
  if (!Number.isFinite(n)) return min;
  return Math.max(min, Math.min(max, n));
}
