import { DurableObject } from "cloudflare:workers";
import {
  CLOSE,
  type CloseReason,
  HOST_ID,
  LIMITS,
  PROTOCOL,
  TokenBucket,
  encodeRelayFrame,
  parseClientFrame,
  parseControl,
  route,
  safeEqual,
  sha256Hex,
  toHex,
} from "./protocol.ts";

/** Room metadata, persisted in the object's SQLite-backed storage. */
interface Meta {
  created: number;
  maxPlayers: number;
  hostHash: string;
  pwSalt: string;
  pwHash: string;
  nextId: number;
  hostSeen: boolean;
  failures: number;
  lockUntil: number;
}

/** Per-socket identity, kept in the WebSocket attachment (survives hibernation). */
interface Member {
  id: number;
  role: "host" | "guest";
}

export interface Env {
  ROOMS: DurableObjectNamespace<RoomDO>;
}

/**
 * One private room. Relays packets between the room creator's device (the
 * host, which simulates the match) and up to three guests. It is NOT a game
 * server: it checks membership, roles, frame sizes and rates, never game
 * rules. Uses the WebSocket Hibernation API so idle rooms cost no duration.
 */
export class RoomDO extends DurableObject<Env> {
  private buckets = new Map<number, TokenBucket>();
  private drops = new Map<number, number>();

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    // Keep-alive pings are answered by the runtime without waking the object.
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/create" && request.method === "POST") return this.create(request);
    if (url.pathname === "/ws") return this.openSocket(url);
    return new Response("not found", { status: 404 });
  }

  private async create(request: Request): Promise<Response> {
    const existing = await this.ctx.storage.get<Meta>("meta");
    if (existing && Date.now() - existing.created < LIMITS.maxRoomMs) {
      return Response.json({ error: "CODE_IN_USE" }, { status: 409 });
    }
    const body = (await request.json()) as { max_players: number; password: string };
    const hostToken = toHex(crypto.getRandomValues(new Uint8Array(24)));
    const pwSalt = toHex(crypto.getRandomValues(new Uint8Array(16)));
    const meta: Meta = {
      created: Date.now(),
      maxPlayers: body.max_players,
      hostHash: await sha256Hex(hostToken),
      pwSalt,
      pwHash: body.password ? await sha256Hex(pwSalt + body.password) : "",
      nextId: HOST_ID + 1,
      hostSeen: false,
      failures: 0,
      lockUntil: 0,
    };
    await this.ctx.storage.deleteAll();
    await this.ctx.storage.put("meta", meta);
    await this.ctx.storage.setAlarm(Date.now() + LIMITS.hostGraceMs);
    return Response.json({ host_token: hostToken }, { status: 201 });
  }

  /** Accepts the socket first, so refusals reach the game as a close code + reason. */
  private async openSocket(url: URL): Promise<Response> {
    const pair = new WebSocketPair();
    const [client, server] = [pair[0], pair[1]];
    this.ctx.acceptWebSocket(server);
    const refusal = await this.admit(server, url);
    // Close only once the handshake response is out, or the client never sees why.
    if (refusal) setTimeout(() => this.refuse(server, refusal), 50);
    return new Response(null, { status: 101, webSocket: client });
  }

  private async admit(ws: WebSocket, url: URL): Promise<CloseReason | null> {
    if (Number(url.searchParams.get("proto")) !== PROTOCOL) return "VERSION";
    const meta = await this.ctx.storage.get<Meta>("meta");
    if (!meta) return "ROOM_NOT_FOUND";
    const members = this.members(ws);
    if (url.searchParams.get("role") === "host") {
      const token = url.searchParams.get("token") ?? "";
      if (!safeEqual(await sha256Hex(token), meta.hostHash)) return "ROOM_NOT_FOUND";
      if (members.some((m) => m.role === "host") || meta.hostSeen) return "HOST_TAKEN";
      meta.hostSeen = true;
      await this.ctx.storage.put("meta", meta);
      await this.ctx.storage.setAlarm(meta.created + LIMITS.maxRoomMs);
      this.adopt(ws, { id: HOST_ID, role: "host" });
      this.sendJson(ws, { t: "welcome", proto: PROTOCOL, id: HOST_ID, role: "host", max: meta.maxPlayers });
      return null;
    }
    // Guests join only a room whose host is present.
    const host = members.find((m) => m.role === "host");
    if (!host) return "ROOM_NOT_FOUND";
    if (Date.now() < meta.lockUntil) return "LOCKED_OUT";
    if (meta.pwHash) {
      const given = await sha256Hex(meta.pwSalt + (url.searchParams.get("pw") ?? ""));
      if (!safeEqual(given, meta.pwHash)) {
        meta.failures += 1;
        if (meta.failures >= LIMITS.passwordFailures) {
          meta.failures = 0;
          meta.lockUntil = Date.now() + LIMITS.lockoutMs;
        }
        await this.ctx.storage.put("meta", meta);
        return "WRONG_PASSWORD";
      }
    }
    if (members.filter((m) => m.role === "guest").length >= meta.maxPlayers - 1) return "ROOM_FULL";
    const id = meta.nextId;
    meta.nextId += 1;
    await this.ctx.storage.put("meta", meta);
    this.adopt(ws, { id, role: "guest" });
    this.sendJson(ws, { t: "welcome", proto: PROTOCOL, id, role: "guest", max: meta.maxPlayers });
    this.sendJson(host.ws, { t: "join", id });
    return null;
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    const me = ws.deserializeAttachment() as Member | null;
    if (!me) return;
    if (!this.allow(me)) {
      const drops = (this.drops.get(me.id) ?? 0) + 1;
      this.drops.set(me.id, drops);
      if (drops > LIMITS.maxDrops) await this.evict(ws, me, "RATE_LIMITED");
      return;
    }
    if (typeof message === "string") {
      const control = parseControl(message, me.role === "host");
      if (!control) return;
      if (control.t === "leave") {
        ws.close(CLOSE.LEFT, "LEFT");
        await this.departed(ws, me);
      } else {
        const target = this.members(ws).find((m) => m.id === control.id);
        if (target) await this.evict(target.ws, target, "KICKED");
      }
      return;
    }
    const limit = me.role === "host" ? LIMITS.hostFrameBytes : LIMITS.guestFrameBytes;
    const frame = message.byteLength > limit ? null : parseClientFrame(message);
    if (!frame) {
      await this.evict(ws, me, "MALFORMED");
      return;
    }
    const members = this.members();
    const recipients = route(
      me.id,
      frame.target,
      members.map((m) => m.id),
    );
    if (recipients.length === 0) return;
    const out = encodeRelayFrame(me.id, frame.channel, frame.mode, frame.payload);
    for (const m of members) {
      if (recipients.includes(m.id)) m.ws.send(out);
    }
  }

  async webSocketClose(ws: WebSocket): Promise<void> {
    const me = ws.deserializeAttachment() as Member | null;
    if (me) await this.departed(ws, me);
  }

  async webSocketError(ws: WebSocket): Promise<void> {
    await this.webSocketClose(ws);
  }

  /** Expiry: a room whose host never connected, or past its maximum life. */
  async alarm(): Promise<void> {
    for (const m of this.members()) this.refuse(m.ws, "ROOM_EXPIRED");
    await this.ctx.storage.deleteAll();
  }

  /** Closes an admitted member's socket and handles their departure. */
  private async evict(ws: WebSocket, me: Member, reason: CloseReason): Promise<void> {
    await this.departed(ws, me);
    this.refuse(ws, reason);
  }

  private async departed(ws: WebSocket, me: Member): Promise<void> {
    ws.serializeAttachment(null);
    this.buckets.delete(me.id);
    this.drops.delete(me.id);
    const others = this.members(ws);
    if (me.role === "host") {
      // The host simulated the match: without it the room cannot continue.
      for (const m of others) {
        this.sendJson(m.ws, { t: "closed", reason: "HOST_LEFT" });
        this.refuse(m.ws, "HOST_LEFT");
      }
      await this.ctx.storage.deleteAll();
      return;
    }
    const host = others.find((m) => m.role === "host");
    if (host) this.sendJson(host.ws, { t: "leave", id: me.id });
  }

  private allow(me: Member): boolean {
    const now = Date.now();
    let bucket = this.buckets.get(me.id);
    if (!bucket) {
      const spec = me.role === "host" ? LIMITS.host : LIMITS.guest;
      bucket = new TokenBucket(spec.capacity, spec.refillPerSecond, now);
      this.buckets.set(me.id, bucket);
    }
    return bucket.take(now);
  }

  /** Open sockets that completed admission, optionally excluding one. */
  private members(except?: WebSocket): Array<Member & { ws: WebSocket }> {
    const out: Array<Member & { ws: WebSocket }> = [];
    for (const ws of this.ctx.getWebSockets()) {
      if (ws === except) continue;
      const m = ws.deserializeAttachment() as Member | null;
      if (m) out.push({ ...m, ws });
    }
    return out;
  }

  private adopt(ws: WebSocket, member: Member): void {
    ws.serializeAttachment(member);
  }

  private refuse(ws: WebSocket, reason: CloseReason): void {
    ws.serializeAttachment(null);
    try {
      this.sendJson(ws, { t: "error", code: reason });
      ws.close(CLOSE[reason], reason);
    } catch {
      // Already closed.
    }
  }

  private sendJson(ws: WebSocket, value: unknown): void {
    try {
      ws.send(JSON.stringify(value));
    } catch {
      // The socket closed under us; its close handler cleans up.
    }
  }
}
