// Configuration from environment variables. Secrets are required in
// production and never have defaults there. See .env.example.

export interface Config {
  host: string;
  port: number;
  dbPath: string;
  ticketSecret: string;
  serverSecret: string;
  publicGameHost: string;
  /** Added to a server's bind port to form the port clients dial (NAT/container mapping). */
  publicGamePortOffset: number;
  protocolVersion: number;
  ticketTtlSeconds: number;
  sessionTtlDays: number;
  roomIdleMinutes: number;
  spawnServers: boolean;
  godotBin: string;
  gamePath: string;
  serverPortMin: number;
  serverPortMax: number;
  /** Seconds a dropped player keeps their slot in a running match (5–300). */
  serverReconnectWindow: number;
  lobbyUrlForServers: string;
  trustProxy: boolean;
  production: boolean;
}

function int(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === "") return fallback;
  const n = Number.parseInt(raw, 10);
  if (!Number.isFinite(n)) throw new Error(`${name} must be an integer`);
  return n;
}

function secret(name: string, production: boolean): string {
  const value = process.env[name] ?? "";
  if (value.length >= 32) return value;
  if (production) throw new Error(`${name} must be set to at least 32 characters in production`);
  // Development only: an ephemeral random secret (tickets die with the process).
  return crypto.randomUUID() + crypto.randomUUID();
}

export function loadConfig(overrides: Partial<Config> = {}): Config {
  const production = process.env.NODE_ENV === "production";
  const cfg: Config = {
    host: process.env.LOBBY_HOST ?? "127.0.0.1",
    port: int("LOBBY_PORT", 8787),
    dbPath: process.env.LOBBY_DB_PATH ?? "data/lobby.sqlite",
    ticketSecret: secret("METHOD_TICKET_SECRET", production),
    serverSecret: secret("METHOD_SERVER_SECRET", production),
    publicGameHost: process.env.PUBLIC_GAME_HOST ?? "127.0.0.1",
    publicGamePortOffset: int("PUBLIC_GAME_PORT_OFFSET", 0),
    protocolVersion: int("METHOD_PROTOCOL_VERSION", 1),
    ticketTtlSeconds: int("TICKET_TTL_SECONDS", 300),
    sessionTtlDays: int("SESSION_TTL_DAYS", 30),
    roomIdleMinutes: int("ROOM_IDLE_MINUTES", 15),
    spawnServers: (process.env.SPAWN_LOCAL_SERVERS ?? "0") === "1",
    godotBin: process.env.GODOT_BIN ?? "godot",
    gamePath: process.env.GAME_PATH ?? "../../game", // "" = exported server binary
    serverPortMin: int("SERVER_PORT_MIN", 24600),
    serverPortMax: int("SERVER_PORT_MAX", 24699),
    serverReconnectWindow: int("SERVER_RECONNECT_WINDOW", 60),
    lobbyUrlForServers: process.env.LOBBY_URL_FOR_SERVERS ?? "http://127.0.0.1:8787",
    trustProxy: (process.env.TRUST_PROXY ?? "0") === "1",
    production,
    ...overrides,
  };
  if (cfg.serverPortMax < cfg.serverPortMin) throw new Error("SERVER_PORT_MAX < SERVER_PORT_MIN");
  return cfg;
}
