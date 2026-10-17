// Entry point: node src/main.ts (Node 24+, runs TypeScript via type stripping).

import { loadConfig } from "./config.ts";
import { openDb } from "./db.ts";
import { LobbyService } from "./service.ts";
import { RateLimiter } from "./ratelimit.ts";
import { createApp, log } from "./http.ts";
import { FixedAllocator, LocalSpawner, type Allocator } from "./servers.ts";

const VERSION = "0.2.0";
const cfg = loadConfig();
const db = openDb(cfg.dbPath);
const allocator: Allocator = cfg.spawnServers
  ? new LocalSpawner({
      godotBin: cfg.godotBin,
      gamePath: cfg.gamePath,
      publicHost: cfg.publicGameHost,
      portMin: cfg.serverPortMin,
      portMax: cfg.serverPortMax,
      ticketSecret: cfg.ticketSecret,
      serverSecret: cfg.serverSecret,
      lobbyUrl: cfg.lobbyUrlForServers,
      reconnectWindow: cfg.serverReconnectWindow,
      publicPortOffset: cfg.publicGamePortOffset,
    })
  : new FixedAllocator(cfg.publicGameHost, cfg.serverPortMin);
const service = new LobbyService(db, cfg, allocator);
const limiter = new RateLimiter();
const app = createApp({ cfg, service, limiter, version: VERSION });

const maintenance = setInterval(() => {
  service.expireRooms();
  service.cleanup();
  limiter.prune();
}, 60_000);

app.listen(cfg.port, cfg.host, () => {
  log({
    level: "info", msg: "lobby listening", host: cfg.host, port: cfg.port, spawn_servers: cfg.spawnServers,
    production: cfg.production,
  });
  if (!cfg.production && !process.env.METHOD_TICKET_SECRET) {
    log({ level: "warn", msg: "using ephemeral development secrets; set METHOD_TICKET_SECRET/METHOD_SERVER_SECRET" });
  }
});

function shutdown(): void {
  clearInterval(maintenance);
  allocator.shutdown();
  app.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 3000).unref();
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
