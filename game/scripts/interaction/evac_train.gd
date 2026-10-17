class_name EvacTrain
extends Interactable
## The evacuation train. Once called (`call_flag`) it takes `arrival_seconds`
## to reach the platform — the final hold-out, with station announcements and
## the rumble drawing the enemy toward the platform — then pulls in and opens
## its doors (`arrived_flag`). The map puts the escape zone inside the car.
##
## Local frame: origin at the car's platform-side face, centred, on platform
## level; length along +X; the body extends toward -Z and the doors open
## toward +Z (the platform). Before arrival, edge barriers block the door gaps
## so nobody can step onto the track.

const WIDTH := 2.8
const HEIGHT := 3.0
const SLIDE_FROM := -70.0
const SLIDE_PORTION := 0.12

@export var call_flag := "train_called"
@export var arrived_flag := "train_arrived"
@export var arrival_seconds := 60.0
@export var length := 16.0
@export var door_offsets: PackedFloat32Array = [-4.0, 4.0]
@export var door_width := 1.6

var _visual: Node3D
var _body: StaticBody3D
var _gates: StaticBody3D
var _door_panels: Array[Node3D] = []
var _window_mat: StandardMaterial3D
var _emitter: AudioStreamPlayer3D
var _progress := 0.0
var _arrived := false
var _announce_timer := 0.0
var _rumble_timer := 0.0
var _sync_timer := 0.0


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var shell := MaterialLib.surface("metal")
	var dark := MaterialLib.surface("metal_dark")
	_window_mat = MaterialLib.glow(Color(0.05, 0.05, 0.05), 0.0)
	# Car body: floor, roof, far side, ends, and the platform side around the doors.
	_vbox(Vector3(length, 0.3, WIDTH), Vector3(0, -0.1, -WIDTH * 0.5 - 0.05), dark)
	_vbox(Vector3(length, 0.25, WIDTH), Vector3(0, HEIGHT, -WIDTH * 0.5 - 0.05), shell)
	_vbox(Vector3(length, HEIGHT, 0.1), Vector3(0, HEIGHT * 0.5, -WIDTH - 0.05), shell)
	for sx in [-1, 1]:
		_vbox(Vector3(0.1, HEIGHT, WIDTH), Vector3(sx * length * 0.5, HEIGHT * 0.5, -WIDTH * 0.5 - 0.05), shell)
	var edges := _door_edges()
	for i in range(0, edges.size(), 2):
		var a: float = edges[i]
		var b: float = edges[i + 1]
		if b - a > 0.05:
			_vbox(Vector3(b - a, HEIGHT, 0.1), Vector3((a + b) * 0.5, HEIGHT * 0.5, -0.05), shell)
			if b - a > 1.2:
				var win := MeshInstance3D.new()
				var m := BoxMesh.new()
				m.size = Vector3(b - a - 0.6, 0.8, 0.02)
				win.mesh = m
				win.material_override = _window_mat
				win.position = Vector3((a + b) * 0.5, 1.8, 0.005)
				_visual.add_child(win)
	for x in door_offsets:
		for side in [-1, 1]:
			var panel := Node3D.new()
			panel.position = Vector3(x + side * door_width * 0.25, 0, -0.05)
			_visual.add_child(panel)
			var mi := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(door_width * 0.5, 2.1, 0.06)
			mi.mesh = pm
			mi.material_override = dark
			mi.position = Vector3(0, 1.05, 0)
			panel.add_child(mi)
			panel.set_meta("side", side)
			panel.set_meta("base", panel.position.x)
			_door_panels.append(panel)
	# Interior light, off until arrival.
	var light := OmniLight3D.new()
	light.name = "CarLight"
	light.light_color = Color(0.9, 0.95, 1.0)
	light.light_energy = 0.0
	light.omni_range = 9.0
	light.position = Vector3(0, 2.4, -WIDTH * 0.5)
	_visual.add_child(light)
	# Collision for the car interior (enabled on arrival) and the edge gates.
	_body = StaticBody3D.new()
	_body.collision_layer = 0
	_body.collision_mask = 0
	add_child(_body)
	_col(_body, Vector3(length, 0.3, WIDTH), Vector3(0, -0.1, -WIDTH * 0.5 - 0.05))
	_col(_body, Vector3(length, HEIGHT, 0.1), Vector3(0, HEIGHT * 0.5, -WIDTH - 0.05))
	for sx in [-1, 1]:
		_col(_body, Vector3(0.1, HEIGHT, WIDTH), Vector3(sx * length * 0.5, HEIGHT * 0.5, -WIDTH * 0.5 - 0.05))
	for i in range(0, edges.size(), 2):
		var a2: float = edges[i]
		var b2: float = edges[i + 1]
		if b2 - a2 > 0.05:
			_col(_body, Vector3(b2 - a2, HEIGHT, 0.1), Vector3((a2 + b2) * 0.5, HEIGHT * 0.5, -0.05))
	_gates = StaticBody3D.new()
	_gates.collision_layer = GeoBuilder.LAYER_WORLD
	_gates.collision_mask = 0
	add_child(_gates)
	for x in door_offsets:
		_col(_gates, Vector3(door_width + 0.4, 2.4, 0.2), Vector3(x, 1.2, 0.1))
	_emitter = AudioService.make_emitter("train_arrive", 2.0, 60.0)
	_emitter.position = Vector3(0, 1.5, -WIDTH * 0.5)
	add_child(_emitter)
	_present(0.0, false)


func _vbox(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	_visual.add_child(mi)


func _col(owner: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	owner.add_child(cs)


## Platform-side wall segments between door gaps, as [from, to, from, to, ...].
func _door_edges() -> Array:
	var cuts: Array = []
	var sorted := Array(door_offsets)
	sorted.sort()
	var x := -length * 0.5
	for d: float in sorted:
		cuts.append(x)
		cuts.append(d - door_width * 0.5)
		x = d + door_width * 0.5
	cuts.append(x)
	cuts.append(length * 0.5)
	return cuts


func initial_state() -> Dictionary:
	return {"progress": 0.0, "arrived": false}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	_progress = clampf(float(new_state.get("progress", 0.0)), 0.0, 1.0)
	var arrived := bool(new_state.get("arrived", false))
	if arrived and not _arrived and is_inside_tree():
		_emitter.play()
	_arrived = arrived
	_present(_progress, _arrived)


## Seconds left before the doors open (shown to players).
func seconds_left() -> int:
	return maxi(0, ceili((1.0 - _progress) * arrival_seconds))


func _present(progress: float, arrived: bool) -> void:
	var slide := clampf((progress - (1.0 - SLIDE_PORTION)) / SLIDE_PORTION, 0.0, 1.0)
	_visual.visible = slide > 0.0 or arrived
	_visual.position.x = lerpf(SLIDE_FROM, 0.0, 1.0 - pow(1.0 - slide, 3.0)) if not arrived else 0.0
	_body.collision_layer = GeoBuilder.LAYER_WORLD if arrived else 0
	_gates.collision_layer = 0 if arrived else GeoBuilder.LAYER_WORLD
	for panel in _door_panels:
		var shift := int(panel.get_meta("side")) * door_width * 0.45 if arrived else 0.0
		panel.position.x = float(panel.get_meta("base")) + shift
	_window_mat.albedo_color = Color(0.75, 0.8, 0.7) if arrived else Color(0.05, 0.05, 0.05)
	_window_mat.emission = _window_mat.albedo_color
	_window_mat.emission_energy_multiplier = 1.4 if arrived else 0.0
	var light := _visual.get_node_or_null("CarLight") as OmniLight3D
	if light:
		light.light_energy = 1.6 if arrived else 0.0


func get_prompt(_pid: int, _sub: int) -> String:
	return ""


func requires_line_of_sight() -> bool:
	return false


## Called by the map on the authority each physics tick.
func authority_tick(delta: float) -> void:
	if _arrived or not match_ctrl.state.has_flag(call_flag):
		return
	var p := minf(1.0, _progress + delta / maxf(arrival_seconds, 1.0))
	var platform := global_position + Vector3(0, 1.5, 0)
	_announce_timer -= delta
	if _announce_timer <= 0.0 and p < 1.0:
		_announce_timer = 15.0
		match_ctrl.world_sound("pa_chime", platform, 0.0, 50.0)
		match_ctrl.notify_all("TRAIN_ETA", [maxi(1, ceili((1.0 - p) * arrival_seconds))])
	_rumble_timer -= delta
	if _rumble_timer <= 0.0:
		_rumble_timer = 3.0
		# The approaching train is loud: whatever hunts down here comes to look.
		match_ctrl.emit_noise(platform, 40.0 * p + 10.0, "train")
	_sync_timer -= delta
	if p >= 1.0:
		match_ctrl.set_entity_state(entity_id, {"progress": 1.0, "arrived": true})
		match_ctrl.set_flag(arrived_flag)
		match_ctrl.notify_all("TRAIN_ARRIVED")
	elif _sync_timer <= 0.0:
		_sync_timer = 0.25
		match_ctrl.set_entity_state(entity_id, {"progress": p, "arrived": false})
	else:
		_progress = p
		match_ctrl.state.entities[entity_id] = {"progress": p, "arrived": false}
		_present(p, false)
