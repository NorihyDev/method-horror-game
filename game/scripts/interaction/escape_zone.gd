class_name EscapeZone
extends Area3D
## Players entering this volume escape, once the exit condition flag is set.
## Detection runs on the authority only.

@export var required_flag := "garage_open"
var match_ctrl: MatchController


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1
	monitoring = true
	body_entered.connect(_on_body_entered)


func setup_box(size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)


func _on_body_entered(body: Node3D) -> void:
	_check(body)


func _physics_process(_delta: float) -> void:
	if match_ctrl == null or not match_ctrl.is_authority or not match_ctrl.running:
		return
	if not required_flag.is_empty() and not match_ctrl.state.has_flag(required_flag):
		return
	for body in get_overlapping_bodies():
		_check(body)


func _check(body: Node3D) -> void:
	if match_ctrl == null or not match_ctrl.is_authority:
		return
	if not required_flag.is_empty() and not match_ctrl.state.has_flag(required_flag):
		return
	if body.has_method("get_player_id"):
		match_ctrl.player_escaped(int(body.call("get_player_id")))
