class_name InspectSpot
extends Interactable
## Something worth a closer look (a collapsed stairway, a sealed exit): sets a
## flag the first time and tells the player what they found. Its geometry is
## part of the level; this only provides the focus target.

@export var flag := ""
@export var message := ""
@export var target_size := Vector3(2.0, 2.0, 0.6)


func _ready() -> void:
	prompt_key = "PROMPT_EXAMINE"
	add_target(target_size)


func authority_interact(ctx: Dictionary) -> void:
	if not flag.is_empty():
		match_ctrl.set_flag(flag)
	if not message.is_empty():
		match_ctrl.notify_player(int(ctx["player_id"]), message)
