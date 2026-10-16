class_name RewardCalculator
extends RefCounted
## Computes end-of-match coin rewards from the map's reward table and the
## difficulty multiplier. Inputs are authoritative match results, never
## client-supplied amounts. See docs/economy.md for balance assumptions.

## outcome keys: escaped (bool), optional_completed (int), new_collectibles (int),
## first_completion (bool)
static func compute(map_def: MapDefinition, diff: DifficultyDefinition, outcome: Dictionary) -> Dictionary:
	var lines: Array[Dictionary] = []
	var escaped := bool(outcome.get("escaped", false))
	if escaped:
		lines.append({"key": "REWARD_ESCAPE", "amount": map_def.base_escape_reward})
		var optional_count := maxi(0, int(outcome.get("optional_completed", 0)))
		if optional_count > 0:
			lines.append({
				"key": "REWARD_OPTIONAL", "amount": optional_count * map_def.optional_objective_reward,
				"count": optional_count,
			})
		if bool(outcome.get("first_completion", false)):
			lines.append({"key": "REWARD_FIRST", "amount": map_def.first_completion_bonus})
	var collectibles := maxi(0, int(outcome.get("new_collectibles", 0)))
	if collectibles > 0:
		lines.append({
			"key": "REWARD_COLLECTIBLES", "amount": collectibles * map_def.collectible_reward,
			"count": collectibles,
		})
	var subtotal := 0
	for line in lines:
		subtotal += int(line["amount"])
	var total := subtotal
	if escaped and diff.reward_multiplier != 1.0:
		total = int(round(subtotal * diff.reward_multiplier))
		lines.append({"key": "REWARD_DIFFICULTY", "amount": total - subtotal})
	return {"lines": lines, "total": maxi(0, total)}
