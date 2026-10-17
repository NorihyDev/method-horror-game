class_name DifficultyDefinition
extends Resource
## Explicit, data-driven difficulty rules. See docs/game-design.md#difficulty.

@export var id: StringName = &"normal"
@export var title_key: String = "DIFF_NORMAL"
@export var description_key: String = "DIFF_NORMAL_DESC"
@export var sort_order: int = 1

@export_group("Enemy")
## Multiplies the enemy's walk/run speed.
@export_range(0.5, 2.0) var enemy_speed: float = 1.0
## Multiplies every noise radius the enemy can hear.
@export_range(0.3, 2.0) var enemy_hearing: float = 1.0
## Multiplies sight range.
@export_range(0.3, 2.0) var enemy_sight: float = 1.0
## Multiplies how long the enemy keeps searching / chasing after losing you.
@export_range(0.3, 2.5) var enemy_persistence: float = 1.0
## Seconds between attacks.
@export_range(0.5, 6.0) var attack_cooldown: float = 2.2
## Seconds of visible wind-up before a strike lands.
@export_range(0.3, 1.5) var attack_windup: float = 0.65
## Seconds before the enemy starts hunting after the match begins.
@export_range(0.0, 300.0) var grace_period: float = 50.0
## Rage: per minute since it arrived, the enemy's senses and patrol speed
## grow by this fraction (its chase speed by 40 % of it)...
@export_range(0.0, 0.1) var rage_per_minute: float = 0.0
## ...up to this much. Taking your time gets more dangerous.
@export_range(0.0, 0.5) var rage_cap: float = 0.0

@export_group("Player")
## Hits a player can take before being downed (multiplayer) or killed (solo).
@export_range(1, 5) var player_hits: int = 2
@export_range(0.2, 3.0) var battery_drain: float = 1.0
## Extra spare batteries placed in the map (can be negative).
@export_range(-2, 4) var extra_batteries: int = 1
## Seconds a hold-to-revive takes.
@export_range(1.0, 10.0) var revive_time: float = 4.0
## Seconds a downed player survives without help.
@export_range(5.0, 120.0) var bleedout_time: float = 45.0
## Width of the timing window for timing puzzles (fraction of the cycle).
@export_range(0.05, 0.5) var timing_window: float = 0.16

@export_group("Assistance")
## Seconds after an objective activates before hint tiers unlock. 0 disables.
@export var hint_delay: float = 120.0
@export var checkpoints_enabled: bool = true

@export_group("Rewards")
@export_range(0.5, 3.0) var reward_multiplier: float = 1.0


## Per-player-count scaling used by cooperative matches.
## Rage multiplier (>= 1) after `minutes` with the enemy in the building.
func rage(minutes: float) -> float:
	return 1.0 + minf(rage_cap, rage_per_minute * maxf(0.0, minutes))


func scaled_hearing(player_count: int) -> float:
	return enemy_hearing * (1.0 + 0.08 * maxf(0, player_count - 1))


func scaled_cooldown(player_count: int) -> float:
	return attack_cooldown * maxf(0.7, 1.0 - 0.05 * maxf(0, player_count - 1))


func scaled_extra_batteries(player_count: int) -> int:
	return extra_batteries + int(floor(0.5 * maxf(0, player_count - 1)))
