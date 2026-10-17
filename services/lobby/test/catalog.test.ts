import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { MAP_PREREQUISITE, MAP_REWARDS, PLAYABLE_MAPS } from "../src/catalog.ts";

// The verified wallet pays from this service's table; the game shows rewards
// from its map resources. They must never disagree.
const MAPS_DIR = resolve(import.meta.dirname, "../../../game/resources/maps");

function field(text: string, name: string): string | undefined {
  return new RegExp(`^${name} = (.+)$`, "m").exec(text)?.[1]?.trim();
}

test("reward table and playable maps mirror the game's map resources", () => {
  const playable = new Set<string>();
  for (const file of readdirSync(MAPS_DIR).filter((f) => f.endsWith(".tres"))) {
    const text = readFileSync(join(MAPS_DIR, file), "utf8");
    const id = field(text, "id")?.replace(/^&"|"$/g, "") ?? "";
    if (field(text, "status") !== "0" || field(text, "is_tutorial") === "true") continue;
    playable.add(id);
    const table = MAP_REWARDS[id];
    assert.ok(table, `${id} is playable in the game but missing from the lobby reward table`);
    assert.equal(table.escape, Number(field(text, "base_escape_reward")), `${id} escape reward`);
    assert.equal(table.first, Number(field(text, "first_completion_bonus")), `${id} first-completion bonus`);
    assert.equal(table.optional, Number(field(text, "optional_objective_reward")), `${id} optional reward`);
    assert.equal(table.collectible, Number(field(text, "collectible_reward")), `${id} collectible reward`);
    const prereq = field(text, "unlocked_by")?.replace(/^&"|"$/g, "");
    assert.equal(MAP_PREREQUISITE[id], prereq, `${id} unlock prerequisite`);
  }
  assert.deepEqual([...PLAYABLE_MAPS].sort(), [...playable].sort(), "online map list matches the game");
});
