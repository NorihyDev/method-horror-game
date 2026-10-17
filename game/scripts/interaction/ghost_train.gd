class_name GhostTrain
extends Interactable
## A train that should not exist rolls through on the far track every minute
## or two: a moving sound source. While it passes it drowns out every other
## noise near the tracks (for everyone — players can use the cover) and its
## own rumble draws the enemy to the platform edge.
##
## Authority schedules passes; each pass is public state {"start": match
## time, "dir": ±1}, so every peer animates the same moving emitter and lit
## windows from the synced match clock.

@export var track_from := Vector3.ZERO
@export var track_to := Vector3(40, 0, 0)
@export var pass_seconds := 9.0
@export var mask_radius := 14.0
@export var first_pass := 50.0
@export var interval := Vector2(70.0, 110.0)
## Where its rumble is "heard from" for enemies: projected onto the platform
## edge (z, y) and clamped along it, so nothing tries to walk into the tracks.
@export var lure_z := 0.0
@export var lure_y := 0.0
@export var lure_x_range := Vector2(-1000.0, 1000.0)

var _emitter: AudioStreamPlayer3D
var _carriage: Node3D
var _next_at := -1.0
var _noise_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _playing_start := -1.0


func _ready() -> void:
	_rng.seed = 7741
	_emitter = AudioService.make_emitter("train_pass", 6.0, 55.0)
	add_child(_emitter)
	_carriage = Node3D.new()
	_carriage.visible = false
	add_child(_carriage)
	var glow := MaterialLib.glow(Color(0.55, 0.6, 0.55), 1.6)
	var dark := MaterialLib.flat(Color(0.03, 0.03, 0.035), 0.9)
	for car in 3:
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(15.5, 3.0, 2.7)
		body.mesh = bm
		body.material_override = dark
		body.position = Vector3(car * -16.0, 1.6, 0)
		_carriage.add_child(body)
		for w in 5:
			var win := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(1.6, 0.7, 2.75)
			win.mesh = wm
			win.material_override = glow
			win.position = Vector3(car * -16.0 - 6.0 + w * 3.0, 2.0, 0)
			_carriage.add_child(win)


func initial_state() -> Dictionary:
	return {"start": -1.0, "dir": 1}


func get_prompt(_pid: int, _sub: int) -> String:
	return ""


## World position of the passing train's middle, or null when none is passing.
func current_position(now: float) -> Variant:
	var start := float(state.get("start", -1.0))
	if start < 0.0 or now < start or now > start + pass_seconds:
		return null
	var t := (now - start) / pass_seconds
	if int(state.get("dir", 1)) < 0:
		t = 1.0 - t
	return track_from.lerp(track_to, t)


func masks(pos: Vector3, now: float) -> bool:
	var p: Variant = current_position(now)
	return p is Vector3 and (p as Vector3).distance_to(pos) <= mask_radius


func _process(_delta: float) -> void:
	if match_ctrl == null:
		return
	var now := match_ctrl.state.elapsed
	var p: Variant = current_position(now)
	if p == null:
		_carriage.visible = false
		return
	var start := float(state.get("start", -1.0))
	if not is_equal_approx(start, _playing_start):
		_playing_start = start
		_emitter.play(clampf(now - start, 0.0, 1.0))
	_emitter.global_position = p
	var dir := (track_to - track_from).normalized() * float(int(state.get("dir", 1)))
	_carriage.visible = true
	_carriage.global_position = p
	# Rotate the carriage's long axis (local +X) onto the direction of travel.
	_carriage.global_rotation = Vector3(0, atan2(-dir.z, dir.x), 0)


## Called by the map on the authority each physics tick.
func authority_tick(delta: float) -> void:
	var now := match_ctrl.state.elapsed
	if _next_at < 0.0:
		_next_at = now + first_pass
	var p: Variant = current_position(now)
	if p is Vector3:
		_noise_timer -= delta
		if _noise_timer <= 0.0:
			_noise_timer = 1.5
			var at: Vector3 = p
			var lure := Vector3(clampf(at.x, lure_x_range.x, lure_x_range.y), lure_y, lure_z)
			match_ctrl.emit_noise(lure, 26.0, "train")
		return
	if now >= _next_at:
		_next_at = now + pass_seconds + _rng.randf_range(interval.x, interval.y)
		match_ctrl.set_entity_state(entity_id, {"start": now, "dir": 1 if _rng.randf() < 0.5 else -1})
