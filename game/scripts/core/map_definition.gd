class_name MapDefinition
extends Resource
## Data describing a playable (or planned) map. The builder script turns it
## into a scene; the rules script owns objectives and item placement.

enum Status { PLAYABLE, COMING_LATER }

@export var id: StringName = &""
@export var title_key: String = ""
@export var description_key: String = ""
@export var location_key: String = ""
@export var status: Status = Status.COMING_LATER
@export var sort_order: int = 0
## Script extending MapBase that builds the level.
@export var builder_script: Script
## Script extending MapRules that declares objectives/zones/items.
@export var rules_script: Script
@export var supported_difficulties: Array[StringName] = [&"story", &"normal", &"hard", &"nightmare"]
@export_range(1, 10) var max_players: int = 10
@export var is_tutorial: bool = false
@export var estimated_minutes: int = 20
## Map that must be escaped first (offline: on this device; online: verified
## by the lobby service). Empty = available from the start.
@export var unlocked_by: StringName = &""
## Preview tint used by the procedural map card.
@export var preview_color: Color = Color(0.2, 0.18, 0.17)
## Translation keys shown on the loading/briefing screen.
@export var briefing_keys: PackedStringArray = []
@export_group("Rewards")
@export var base_escape_reward: int = 100
@export var first_completion_bonus: int = 150
@export var optional_objective_reward: int = 25
@export var collectible_reward: int = 10
@export_group("Atmosphere")
@export var ambience_sound: StringName = &"amb_house_loop"
@export var tension_music: StringName = &"mus_tension_loop"
@export var chase_music: StringName = &"mus_chase_loop"
@export_group("Enemy")
## EnemyProfile id: "watcher", "sister" or "lineman" (scripts/ai/enemy_profile.gd).
@export var enemy_profile: StringName = &"watcher"


func is_playable() -> bool:
	return status == Status.PLAYABLE and builder_script != null
