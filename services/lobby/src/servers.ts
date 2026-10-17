// Game server allocation.
//
// LocalSpawner starts one headless Godot dedicated server per room on this
// host (development and single-VPS deployments). Secrets are passed through
// the environment, never on the command line (visible in process lists).
// A container/fleet allocator can implement the same interface later.

import { spawn, type ChildProcess } from "node:child_process";
import { resolve } from "node:path";

export interface RoomLaunch {
  roomId: string;
  code: string;
  mapId: string;
  difficultyId: string;
  maxPlayers: number;
  /** Maps the room owner has unlocked; the game server refuses switching to others. */
  allowedMaps: string[];
}

export interface Allocation {
  host: string;
  port: number;
}

export interface Allocator {
  allocate(launch: RoomLaunch, onExit: (roomId: string) => void): Promise<Allocation>;
  release(roomId: string): void;
  active(): number;
  shutdown(): void;
}

export interface SpawnerOptions {
  godotBin: string;
  gamePath: string;
  publicHost: string;
  portMin: number;
  portMax: number;
  ticketSecret: string;
  serverSecret: string;
  lobbyUrl: string;
  maxServers?: number;
  reconnectWindow?: number;
  /** Clients dial bindPort + publicPortOffset (port forwarding / container mapping). */
  publicPortOffset?: number;
}

export class LocalSpawner implements Allocator {
  private procs = new Map<string, { port: number; child: ChildProcess }>();
  private opts: SpawnerOptions;

  constructor(opts: SpawnerOptions) {
    this.opts = opts;
  }

  active(): number {
    return this.procs.size;
  }

  async allocate(launch: RoomLaunch, onExit: (roomId: string) => void): Promise<Allocation> {
    if (this.procs.size >= (this.opts.maxServers ?? 20)) throw new Error("NO_CAPACITY");
    const used = new Set([...this.procs.values()].map((p) => p.port));
    let port = -1;
    for (let p = this.opts.portMin; p <= this.opts.portMax; p++) {
      if (!used.has(p)) {
        port = p;
        break;
      }
    }
    if (port < 0) throw new Error("NO_CAPACITY");
    // An exported dedicated-server binary embeds the game: no --path then.
    const args = [
      "--headless", ...(this.opts.gamePath ? ["--path", resolve(this.opts.gamePath)] : []), "--",
      "--server", `--port=${port}`, `--room=${launch.roomId}`, `--code=${launch.code}`,
      `--map=${launch.mapId}`, `--difficulty=${launch.difficultyId}`, `--max-players=${launch.maxPlayers}`,
      `--reconnect-window=${this.opts.reconnectWindow ?? 60}`,
      `--allowed-maps=${launch.allowedMaps.join(",")}`,
    ];
    const child = spawn(this.opts.godotBin, args, {
      env: {
        ...process.env,
        METHOD_TICKET_SECRET: this.opts.ticketSecret,
        METHOD_SERVER_SECRET: this.opts.serverSecret,
        METHOD_LOBBY_URL: this.opts.lobbyUrl,
      },
      stdio: ["ignore", "pipe", "pipe"],
    });
    const tag = `[server ${launch.roomId}:${port}]`;
    child.stdout?.on("data", (d: Buffer) => process.stdout.write(`${tag} ${d}`));
    child.stderr?.on("data", (d: Buffer) => process.stderr.write(`${tag} ${d}`));
    child.on("exit", (code) => {
      this.procs.delete(launch.roomId);
      console.log(JSON.stringify({ level: "info", msg: "game server exited", room: launch.roomId, code }));
      onExit(launch.roomId);
    });
    this.procs.set(launch.roomId, { port, child });
    return { host: this.opts.publicHost, port: port + (this.opts.publicPortOffset ?? 0) };
  }

  release(roomId: string): void {
    const p = this.procs.get(roomId);
    if (p) p.child.kill("SIGTERM");
  }

  shutdown(): void {
    for (const id of [...this.procs.keys()]) this.release(id);
  }
}

/** Test/manual allocator: pretends a server exists at a fixed address. */
export class FixedAllocator implements Allocator {
  allocated: RoomLaunch[] = [];
  released: string[] = [];
  private host: string;
  private port: number;
  constructor(host = "127.0.0.1", port = 24600) {
    this.host = host;
    this.port = port;
  }
  async allocate(launch: RoomLaunch): Promise<Allocation> {
    this.allocated.push(launch);
    return { host: this.host, port: this.port };
  }
  release(roomId: string): void {
    this.released.push(roomId);
  }
  active(): number {
    return this.allocated.length - this.released.length;
  }
  shutdown(): void {}
}
