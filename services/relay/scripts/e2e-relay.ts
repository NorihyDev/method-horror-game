/**
 * Two real Godot clients through a running relay:
 *   GODOT_BIN=/path/to/godot RELAY_URL=http://127.0.0.1:8787 node scripts/e2e-relay.ts
 *   GODOT_BIN=... RELAY_URL=https://method-horror-relay.<you>.workers.dev node scripts/e2e-relay.ts
 * Starts the owner bot (creates a room and hosts the match), reads its room
 * code, then starts the guest bot with that code. Both drive the game's real
 * screens (tests/e2e/online_bot.gd). Exits 0 when both bots succeed.
 */
import { spawn, type ChildProcess } from "node:child_process";
import { resolve } from "node:path";

const godot = process.env.GODOT_BIN;
if (!godot) {
  console.error("Set GODOT_BIN to the Godot 4.7.2 console binary.");
  process.exit(2);
}
const relay = process.env.RELAY_URL ?? "http://127.0.0.1:8787";
const gameDir = resolve(import.meta.dirname, "../../../game");
const keepLogs = process.env.E2E_KEEP_LOGS === "1";
const TIMEOUT_MS = 12 * 60 * 1000;

function bot(role: string, extra: string[], onEvent: (name: string, data: string) => void): Promise<number> {
  return new Promise((resolveExit) => {
    const child: ChildProcess = spawn(
      godot as string,
      ["--headless", "--path", gameDir, "--", "--bot", `--role=${role}`, `--relay=${relay}`, ...extra],
      { stdio: ["ignore", "pipe", "pipe"] },
    );
    const onLine = (line: string): void => {
      const m = line.match(/^BOT_EVENT (\S+) ?(.*)$/);
      if (m) {
        console.log(`[${role}] ${m[1]} ${m[2]}`.trimEnd());
        onEvent(m[1], m[2]);
      } else if (line.includes("BOT_FAIL") || line.includes("SCRIPT ERROR") || keepLogs) {
        console.log(`[${role}] ${line}`);
      }
    };
    let buffer = "";
    const feed = (chunk: Buffer): void => {
      buffer += chunk.toString();
      let i: number;
      while ((i = buffer.indexOf("\n")) >= 0) {
        onLine(buffer.slice(0, i).replace(/\r$/, ""));
        buffer = buffer.slice(i + 1);
      }
    };
    child.stdout?.on("data", feed);
    child.stderr?.on("data", feed);
    const timer = setTimeout(() => child.kill(), TIMEOUT_MS);
    child.on("exit", (code) => {
      clearTimeout(timer);
      resolveExit(code ?? 1);
    });
  });
}

const health = await fetch(`${relay}/v1/health`).catch(() => null);
if (!health || !health.ok) {
  console.error(`relay not reachable at ${relay}`);
  process.exit(2);
}
console.log(`e2e: relay ${relay}`);

let guestDone = null as Promise<number> | null;
const ownerDone = bot("owner", [], (name, data) => {
  if (name === "code" && !guestDone) guestDone = bot("guest", [`--code=${data.trim()}`], () => {});
});
const ownerCode = await ownerDone;
const guestCode = guestDone ? await guestDone : 1;
console.log(`e2e: owner exit ${ownerCode}, guest exit ${guestCode}`);
if (ownerCode === 0 && guestCode === 0) {
  console.log("e2e: PASSED");
  process.exit(0);
}
console.log("e2e: FAILED");
process.exit(1);
