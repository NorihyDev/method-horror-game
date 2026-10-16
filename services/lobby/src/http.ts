// Minimal HTTP API over node:http. TLS is terminated by a reverse proxy in
// deployment (docs/deployment.md); this process listens on localhost.

import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { ApiError, type LobbyService, type User } from "./service.ts";
import { LIMITS, RateLimiter, type Limit } from "./ratelimit.ts";
import { verifyServerRequest } from "./security.ts";
import type { Config } from "./config.ts";

const MAX_BODY = 8 * 1024;
const REDACT = /token|ticket|password|secret|authorization/i;

export interface AppDeps {
  cfg: Config;
  service: LobbyService;
  limiter: RateLimiter;
  version: string;
}

type Handler = (ctx: Ctx) => Promise<unknown> | unknown;

interface Ctx {
  req: IncomingMessage;
  body: Record<string, unknown>;
  raw: string;
  params: Record<string, string>;
  ip: string;
  user?: User;
  token?: string;
}

interface Route {
  method: string;
  pattern: RegExp;
  keys: string[];
  auth: "none" | "user" | "server";
  handler: Handler;
}

export function createApp(deps: AppDeps): Server {
  const { cfg, service, limiter } = deps;
  const routes: Route[] = [];
  const route = (method: string, path: string, auth: Route["auth"], handler: Handler) => {
    const keys: string[] = [];
    const pattern = new RegExp(
      "^" + path.replace(/:([a-z_]+)/g, (_m, k: string) => {
        keys.push(k);
        return "([A-Za-z0-9_-]{1,64})";
      }) + "$",
    );
    routes.push({ method, pattern, keys, auth, handler });
  };
  const limit = (key: string, l: Limit) => {
    const wait = limiter.take(key, l);
    if (wait > 0) throw new ApiError(429, "RATE_LIMITED", wait);
  };

  route("GET", "/healthz", "none", () => ({ ok: true, version: deps.version, protocol: cfg.protocolVersion }));

  route("POST", "/v1/guest", "none", (c) => {
    limit(`guest:ip:${c.ip}`, LIMITS.guestPerIp);
    const g = service.createGuest(c.body.name, c.body.color);
    return { status: 201, body: { user_id: g.user.id, name: g.user.name, color: g.user.color, token: g.token, expires_at: g.expiresAt } };
  });
  route("GET", "/v1/me", "user", (c) => c.user);
  route("PATCH", "/v1/me", "user", (c) => service.updateProfile(c.user!, c.body.name, c.body.color));
  route("POST", "/v1/logout", "user", (c) => {
    service.logout(c.token!);
    return { ok: true };
  });
  route("DELETE", "/v1/me", "user", (c) => {
    service.deleteAccount(c.user!);
    return { ok: true };
  });

  route("POST", "/v1/rooms", "user", async (c) => {
    limit(`create:user:${c.user!.id}`, LIMITS.createPerUser);
    limit(`create:ip:${c.ip}`, LIMITS.createPerIp);
    return { status: 201, body: await service.createRoom(c.user!, c.body) };
  });
  route("POST", "/v1/rooms/join", "user", async (c) => {
    limit(`join:user:${c.user!.id}`, LIMITS.joinPerUser);
    limit(`join:ip:${c.ip}`, LIMITS.joinPerIp);
    if (!limiter.peek(`badcode:user:${c.user!.id}`, LIMITS.badCodePerUser)) throw new ApiError(429, "RATE_LIMITED", 300);
    try {
      return await service.joinRoom(c.user!, c.body.code, c.body.password);
    } catch (err) {
      if (err instanceof ApiError && (err.code === "ROOM_NOT_FOUND" || err.code === "PASSWORD_WRONG")) {
        limiter.take(`badcode:user:${c.user!.id}`, LIMITS.badCodePerUser);
      }
      throw err;
    }
  });
  route("POST", "/v1/rooms/:room_id/ticket", "user", (c) => service.ticketFor(c.user!, c.params.room_id!));
  route("POST", "/v1/rooms/:room_id/leave", "user", (c) => {
    service.leaveRoom(c.user!, c.params.room_id!);
    return { ok: true };
  });
  route("POST", "/v1/rooms/:room_id/close", "user", (c) => {
    service.closeRoom(c.user!, c.params.room_id!);
    return { ok: true };
  });

  route("GET", "/v1/wallet", "user", (c) => service.wallet(c.user!));
  route("POST", "/v1/shop/purchase", "user", (c) => service.purchase(c.user!, c.body.item_id, c.body.idempotency_key));

  route("POST", "/v1/internal/rooms/:room_id/status", "server", (c) => {
    service.serverStatus(c.params.room_id!, c.body.state);
    return { ok: true };
  });
  route("POST", "/v1/internal/match-result", "server", (c) => service.recordMatch(c.body));

  return createServer(async (req, res) => {
    const started = Date.now();
    const url = new URL(req.url ?? "/", "http://localhost");
    const ip = clientIp(req, cfg.trustProxy);
    let status = 500;
    let code = "";
    try {
      const match = findRoute(routes, req.method ?? "GET", url.pathname);
      if (!match) throw new ApiError(404, "NOT_FOUND");
      const { r, params } = match;
      const raw = await readBody(req);
      const body = parseJson(raw);
      const ctx: Ctx = { req, body, raw, params, ip };
      if (r.auth === "user") {
        const header = req.headers.authorization ?? "";
        ctx.token = header.startsWith("Bearer ") ? header.slice(7) : undefined;
        ctx.user = service.authenticate(ctx.token);
        limit(`api:user:${ctx.user.id}`, LIMITS.apiPerUser);
        const proto = Number(req.headers["x-method-protocol"] ?? cfg.protocolVersion);
        if (proto !== cfg.protocolVersion) throw new ApiError(426, "VERSION_MISMATCH");
      } else if (r.auth === "server") {
        const ok = verifyServerRequest(
          cfg.serverSecret, req.method ?? "", url.pathname, String(req.headers["x-method-timestamp"] ?? ""), raw,
          String(req.headers["x-method-signature"] ?? ""), Math.floor(Date.now() / 1000),
        );
        if (!ok) throw new ApiError(401, "UNAUTHORIZED");
      }
      const result = await r.handler(ctx);
      const wrapped = result as { status?: number; body?: unknown } | undefined;
      if (wrapped && typeof wrapped === "object" && "status" in wrapped && "body" in wrapped) {
        status = wrapped.status ?? 200;
        send(res, status, wrapped.body);
      } else {
        status = 200;
        send(res, 200, result ?? { ok: true });
      }
    } catch (err) {
      if (err instanceof ApiError) {
        status = err.status;
        code = err.code;
        if (err.retryAfter > 0) res.setHeader("Retry-After", String(err.retryAfter));
        send(res, err.status, { error: err.code });
      } else {
        status = 500;
        code = "INTERNAL";
        console.error(JSON.stringify({ level: "error", msg: "unhandled", error: String(err) }));
        send(res, 500, { error: "INTERNAL" });
      }
    } finally {
      log({ level: "info", method: req.method, path: redactPath(url.pathname), status, code, ms: Date.now() - started });
    }
  });
}

function findRoute(routes: Route[], method: string, path: string): { r: Route; params: Record<string, string> } | null {
  for (const r of routes) {
    if (r.method !== method) continue;
    const m = r.pattern.exec(path);
    if (!m) continue;
    const params: Record<string, string> = {};
    r.keys.forEach((k, i) => (params[k] = m[i + 1] ?? ""));
    return { r, params };
  }
  return null;
}

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks: Buffer[] = [];
    req.on("data", (c: Buffer) => {
      size += c.length;
      if (size > MAX_BODY) {
        reject(new ApiError(413, "BODY_TOO_LARGE"));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function parseJson(raw: string): Record<string, unknown> {
  if (raw.trim() === "") return {};
  try {
    const v = JSON.parse(raw);
    if (v && typeof v === "object" && !Array.isArray(v)) return v as Record<string, unknown>;
  } catch {
    // fall through
  }
  throw new ApiError(400, "INVALID_JSON");
}

function send(res: ServerResponse, status: number, body: unknown): void {
  const text = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
  });
  res.end(text);
}

function clientIp(req: IncomingMessage, trustProxy: boolean): string {
  if (trustProxy) {
    const fwd = String(req.headers["x-forwarded-for"] ?? "").split(",")[0]?.trim();
    if (fwd) return fwd;
  }
  return req.socket.remoteAddress ?? "unknown";
}

function redactPath(path: string): string {
  return path.replace(/room_[A-Za-z0-9_-]+/g, "room_*");
}

export function log(entry: Record<string, unknown>): void {
  const clean: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(entry)) clean[k] = REDACT.test(k) ? "[redacted]" : v;
  console.log(JSON.stringify({ t: new Date().toISOString(), ...clean }));
}
