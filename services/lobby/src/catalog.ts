// Prices and reward table for the VERIFIED wallet. Mirrors
// game/scripts/progression/cosmetic_catalog.gd and the map reward values in
// game/resources/maps/*.tres. Clients never supply prices or amounts.

export const CATALOG: Record<string, { slot: string; price: number }> = {
  flashlight_standard: { slot: "flashlight", price: 0 },
  flashlight_sodium: { slot: "flashlight", price: 150 },
  flashlight_surgical: { slot: "flashlight", price: 300 },
  flashlight_method: { slot: "flashlight", price: 600 },
  badge_none: { slot: "badge", price: 0 },
  badge_eye: { slot: "badge", price: 120 },
  badge_key: { slot: "badge", price: 200 },
  badge_star: { slot: "badge", price: 400 },
};

export const MAP_REWARDS: Record<string, { escape: number; first: number; optional: number; collectible: number }> = {
  house: { escape: 100, first: 150, optional: 25, collectible: 10 },
  black_ward: { escape: 120, first: 175, optional: 25, collectible: 10 },
  last_train: { escape: 140, first: 200, optional: 25, collectible: 10 },
  silent_school: { escape: 150, first: 225, optional: 25, collectible: 10 },
  method_facility: { escape: 160, first: 250, optional: 30, collectible: 15 },
};

export const DIFFICULTY_MULTIPLIER: Record<string, number> = {
  story: 0.75,
  normal: 1,
  hard: 1.5,
  nightmare: 2,
};

export const PLAYABLE_MAPS = new Set(Object.keys(MAP_REWARDS));

/** Map that must be escaped (online, verified) before a room can use this one. */
export const MAP_PREREQUISITE: Record<string, string> = {
  black_ward: "house",
  last_train: "black_ward",
  silent_school: "last_train",
  method_facility: "silent_school",
};
export const DIFFICULTIES = new Set(Object.keys(DIFFICULTY_MULTIPLIER));

export interface PlayerOutcome {
  escaped: boolean;
  optionalCompleted: number;
  firstCompletion: boolean;
}

/** Same rules as RewardCalculator.compute (collectibles stay local in this version). */
export function computeReward(mapId: string, difficultyId: string, o: PlayerOutcome): number {
  const table = MAP_REWARDS[mapId];
  const mult = DIFFICULTY_MULTIPLIER[difficultyId];
  if (!table || mult === undefined || !o.escaped) return 0;
  let subtotal = table.escape + Math.max(0, Math.min(10, Math.floor(o.optionalCompleted))) * table.optional;
  if (o.firstCompletion) subtotal += table.first;
  return Math.max(0, Math.round(subtotal * mult));
}
