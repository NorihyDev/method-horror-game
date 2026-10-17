import { type Env, RoomDO } from "./room.ts";
import { LIMITS, PROTOCOL, generateCode, isValidCode, parseCreate } from "./protocol.ts";

export { RoomDO };

/**
 * METHOD HORROR relay Worker.
 *   POST /v1/rooms                  create a private room -> { code, host_token, max_players }
 *   GET  /v1/rooms/:code/ws         WebSocket into that room's Durable Object
 *   GET  /v1/health                 { ok, proto }
 * One Durable Object per room, addressed by its 6-digit code.
 */
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/v1/health") return Response.json({ ok: true, proto: PROTOCOL });
    if (url.pathname === "/v1/rooms" && request.method === "POST") return createRoom(request, env);
    const ws = url.pathname.match(/^\/v1\/rooms\/([^/]+)\/ws$/);
    if (ws) {
      if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
        return Response.json({ error: "UPGRADE_REQUIRED" }, { status: 426 });
      }
      const code = ws[1];
      if (!isValidCode(code)) return Response.json({ error: "ROOM_NOT_FOUND" }, { status: 404 });
      const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
      return stub.fetch(new Request(`https://room/ws${url.search}`, request));
    }
    return Response.json({ error: "NOT_FOUND" }, { status: 404 });
  },
} satisfies ExportedHandler<Env>;

async function createRoom(request: Request, env: Env): Promise<Response> {
  const length = Number(request.headers.get("Content-Length") ?? "0");
  if (length > LIMITS.createBodyBytes) return Response.json({ error: "BAD_REQUEST" }, { status: 413 });
  let body: unknown;
  try {
    const text = await request.text();
    if (text.length > LIMITS.createBodyBytes) return Response.json({ error: "BAD_REQUEST" }, { status: 413 });
    body = JSON.parse(text);
  } catch {
    return Response.json({ error: "BAD_REQUEST" }, { status: 400 });
  }
  const parsed = parseCreate(body);
  if ("error" in parsed) {
    return Response.json({ error: parsed.error }, { status: parsed.error === "VERSION" ? 426 : 400 });
  }
  for (let attempt = 0; attempt < 6; attempt++) {
    const code = generateCode((n) => crypto.getRandomValues(new Uint8Array(n)));
    const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
    const res = await stub.fetch("https://room/create", {
      method: "POST",
      body: JSON.stringify({ max_players: parsed.max_players, password: parsed.password }),
    });
    if (res.status === 201) {
      const { host_token } = (await res.json()) as { host_token: string };
      return Response.json({ code, host_token, max_players: parsed.max_players, proto: PROTOCOL }, { status: 201 });
    }
  }
  return Response.json({ error: "NO_CODE" }, { status: 503 });
}
