class_name FlagZone
extends Area3D
## Sets a match flag the first time a player enters (authority only).

@export var flag := ""
var match_ctrl: MatchController


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1
	body_entered.connect(func(body: Node3D) -> void:
		if match_ctrl and match_ctrl.is_authority and body.has_method("get_player_id") and not flag.is_empty():
			match_ctrl.set_flag(flag))


func setup_box(size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)
