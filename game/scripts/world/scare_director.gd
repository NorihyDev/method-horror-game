class_name ScareDirector
extends Node
## Frights between encounters, for the local player only: whispers at the
## ear, knocking in the walls, something running past, lamps bursting, the
## flashlight dying with breathing behind you, and a figure at the end of the
## corridor that is gone when the beam reaches it.
##
## Everything here is presentation: no scare changes the shared match state,
## hurts anyone or moves the real enemy, so it is safe in co-op and keeps the
## "readable rules" pillar (the real threat never teleports). Scares never
## fire during a chase, while hiding, or when the enemy is close: they fill
## the quiet, they don't stack on top of danger.
##
## Also plays the scream when the local player is caught.

const KINDS: Array[String] = [
	"whisper", "knock", "run_past", "lights_out", "flashlight_fail", "phantom", "distant_scream", "door_slam"
]
## Relative chance of each kind (same order as KINDS).
const WEIGHTS: Array[float] = [1.0, 1.0, 0.9, 1.1, 0.8, 1.2, 0.7, 0.8]
## Mild kinds: the only ones left when jump scares are set to "reduced".
const MILD: Array[String] = ["whisper", "knock", "distant_scream", "door_slam"]
const FIRST_AFTER := 25.0
## Seconds between scares on Normal, before phase escalation.
const BASE_GAP := Vector2(48.0, 90.0)
const DIFFICULTY_GAP := {"story": 1.5, "normal": 1.0, "hard": 0.8, "nightmare": 0.6}
const SAFE_ENEMY_DISTANCE := 10.0
const PHANTOM_LIFE := 1.2

var match_ctrl: MatchController
var player: PlayerController
var map: MapBase
var post_fx: PostFX
var fired: Array[String] = []
var _next := FIRST_AFTER
var _elapsed := 0.0
var _last := ""
var _rng := RandomNumberGenerator.new()
var _phantom: Node3D
var _phantom_age := 0.0
var _lamps: Array[FlickerLight] = []


func setup(p_match: MatchController, p_player: PlayerController, p_map: MapBase, p_fx: PostFX) -> void:
	match_ctrl = p_match
	player = p_player
	map = p_map
	post_fx = p_fx
	_rng.randomize()
	_next = FIRST_AFTER + _rng.randf_range(0.0, 20.0)
	for lamp in map.find_children("*", "FlickerLight", true, false):
		_lamps.append(lamp as FlickerLight)


static func full() -> bool:
	return Settings.s("jump_scares") == "full"


func _process(delta: float) -> void:
	if match_ctrl == null or not is_instance_valid(player):
		return
	if _phantom:
		_tick_phantom(delta)
	if not match_ctrl.running:
		return
	_elapsed += delta
	if _elapsed < _next:
		return
	if not _quiet_moment():
		# Try again soon: the moment will come.
		_next = _elapsed + 6.0
		return
	var kind := pick_kind()
	if trigger(kind):
		fired.append(kind)
		_last = kind
		_next = _elapsed + gap()
	else:
		_next = _elapsed + 4.0


## Seconds until the next scare: shorter on harder difficulties and later phases.
func gap() -> float:
	var k: float = DIFFICULTY_GAP.get(String(match_ctrl.difficulty.id), 1.0)
	k *= pow(0.85, float(match_ctrl.state.phase))
	return _rng.randf_range(BASE_GAP.x, BASE_GAP.y) * k


func _quiet_moment() -> bool:
	if player.dead or player.downed or player.escaped or player.is_hidden() or not player.input_enabled:
		return false
	for e in match_ctrl.enemies:
		if not is_instance_valid(e):
			continue
		if (e as Node3D).global_position.distance_to(player.global_position) < SAFE_ENEMY_DISTANCE:
			return false
		if e is Watcher and (e as Watcher).state in [Watcher.S.CHASE, Watcher.S.ATTACK]:
			return false
	return true


func pick_kind() -> String:
	var total := 0.0
	var pool: Array[int] = []
	for i in KINDS.size():
		if KINDS[i] == _last or (not full() and not KINDS[i] in MILD):
			continue
		pool.append(i)
		total += WEIGHTS[i]
	var r := _rng.randf() * total
	for i in pool:
		r -= WEIGHTS[i]
		if r <= 0.0:
			return KINDS[i]
	return KINDS[pool.back()] if not pool.is_empty() else "whisper"


## Plays one scare now. False when this spot doesn't allow it (no wall to
## knock on, no lamp nearby, no clear corridor for the figure...).
func trigger(kind: String) -> bool:
	match kind:
		"whisper":
			_at_ear("scare_whisper", -4.0)
			return true
		"knock":
			return _knock()
		"run_past":
			return _run_past()
		"lights_out":
			return _lights_out()
		"flashlight_fail":
			return _flashlight_fail()
		"phantom":
			return _spawn_phantom()
		"distant_scream":
			var dir := Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
			_sound("scare_scream_far", player.global_position + dir * 18.0 + Vector3(0, 1.5, 0), 0.0, 45.0)
			return true
		"door_slam":
			return _door_slam()
	return false


# --- Kinds -------------------------------------------------------------------------


func _eye() -> Vector3:
	return player.camera.global_position


func _forward() -> Vector3:
	return -player.camera.global_basis.z


func _sound(sound: String, pos: Vector3, db: float, max_distance: float) -> AudioStreamPlayer3D:
	return AudioService.play_3d(sound, map, pos, db if full() else db - 8.0, max_distance)


func _at_ear(sound: String, db: float) -> void:
	var side := player.camera.global_basis.x * (0.35 if _rng.randf() < 0.5 else -0.35)
	_sound(sound, _eye() - _forward() * 0.8 + side, db, 8.0)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, GeoBuilder.LAYER_WORLD)
	q.exclude = [player.get_rid()]
	return map.get_world_3d().direct_space_state.intersect_ray(q)


func _knock() -> bool:
	var basis := player.camera.global_basis
	for dir in [basis.x, -basis.x, -basis.z, basis.z]:
		var flat := Vector3(dir.x, 0, dir.z).normalized()
		var hit := _ray(_eye(), _eye() + flat * 3.5)
		if not hit.is_empty():
			_sound("scare_knock", hit["position"], 2.0, 14.0)
			return true
	return false


func _run_past() -> bool:
	var back := -Vector3(_forward().x, 0, _forward().z).normalized()
	var side := back.cross(Vector3.UP)
	var start := player.global_position + back * 5.0 - side * 5.0 + Vector3(0, 1.0, 0)
	var p := _sound("scare_run", start, 4.0, 22.0)
	if p == null:
		return false
	create_tween().tween_property(p, "global_position", start + side * 10.0, 2.2)
	return true


func _lights_out() -> bool:
	var near: Array[FlickerLight] = []
	for lamp in _lamps:
		if is_instance_valid(lamp) and lamp.is_on() and lamp.global_position.distance_to(player.global_position) < 11.0:
			near.append(lamp)
	if near.is_empty():
		return false
	var blackout := _rng.randf_range(5.0, 8.0)
	for lamp in near:
		lamp.scare_blackout(blackout)
	_sound("bulb_pop", near[0].global_position, 0.0, 18.0)
	if full():
		_after(blackout * 0.6, func() -> void: _at_ear("scare_breath_close", -2.0))
	return true


func _flashlight_fail() -> bool:
	if not player.flashlight_on:
		return false
	player.scare_flashlight(2.2)
	_after(1.0, func() -> void: _at_ear("scare_breath_close", 0.0))
	return true


func _door_slam() -> bool:
	var best: DoorEntity
	var best_d := 15.0
	for ent in match_ctrl.entities.values():
		if ent is DoorEntity:
			var d := (ent as Node3D).global_position.distance_to(player.global_position)
			if d > 4.0 and d < best_d:
				best = ent
				best_d = d
	if best == null:
		return false
	_sound("door_close", best.global_position + Vector3(0, 1.2, 0), 6.0, 30.0)
	return true


## A dark figure down the corridor, gone when the light reaches it.
func _spawn_phantom() -> bool:
	if _phantom:
		return false
	var flat := Vector3(_forward().x, 0, _forward().z).normalized()
	var free := 14.0
	var wall := _ray(_eye(), _eye() + flat * 14.0)
	if not wall.is_empty():
		free = _eye().distance_to(wall["position"]) - 0.9
	if free < 4.5:
		return false
	var spot := map.closest_nav_point(player.global_position + flat * _rng.randf_range(4.5, minf(free, 11.0)))
	if absf(spot.y - player.global_position.y) > 0.8:
		return false
	if not _ray(_eye(), spot + Vector3(0, 1.5, 0)).is_empty():
		return false
	_phantom = _make_figure()
	map.add_child(_phantom)
	_phantom.global_position = spot
	var look := player.global_position - spot
	_phantom.rotation.y = atan2(-look.x, -look.z)
	_shade(_phantom)
	_phantom_age = 0.0
	_sound("phantom_drone", spot + Vector3(0, 1.6, 0), -4.0, 18.0)
	return true


func _make_figure() -> Node3D:
	var root := Node3D.new()
	root.name = "Phantom"
	var rig := WatcherRig.new()
	rig.name = "Rig"
	rig.style = _enemy_style()
	rig.rotation.y = PI
	# A head taller than a person.
	rig.scale = Vector3(1.0, 1.1, 1.0)
	root.add_child(rig)
	return root


## Near-black all over, so only the room's light catches its edges, and two
## pale eyes that catch no light at all. Runs once the figure stands in the
## world (the rig builds its body on entering the tree).
func _shade(root: Node3D) -> void:
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0.045, 0.042, 0.045)
	shade.roughness = 0.75
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = shade
	var rig := root.get_node("Rig") as WatcherRig
	var head := rig.joints.get("head") as Node3D
	if head == null:
		return
	var toward := player.global_position - root.global_position
	toward = Vector3(toward.x, 0, toward.z).normalized()
	var side := toward.cross(Vector3.UP)
	var glow := MaterialLib.glow(Color(0.85, 0.9, 0.8), 4.0)
	for x in [-0.045, 0.045]:
		var eye := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.022
		ball.height = 0.044
		eye.mesh = ball
		eye.material_override = glow
		root.add_child(eye)
		eye.global_position = head.global_position + toward * 0.22 + side * x + Vector3(0, 0.08, 0)


func _enemy_style() -> String:
	for e in match_ctrl.enemies:
		if e is Watcher and (e as Watcher).profile:
			return (e as Watcher).profile.rig_style
	return "watcher"


func _tick_phantom(delta: float) -> void:
	_phantom_age += delta
	var to := _phantom.global_position + Vector3(0, 1.2, 0) - _eye()
	var lit := player.flashlight_on and _forward().dot(to.normalized()) > cos(deg_to_rad(11.0))
	if _phantom_age > PHANTOM_LIFE or (lit and _phantom_age > 0.3):
		var seen := _forward().dot(to.normalized()) > 0.5
		_phantom.queue_free()
		_phantom = null
		if seen:
			AudioService.play_2d("scare_hit", AudioService.BUS_SFX, -3.0 if full() else -12.0)
			if post_fx and full():
				post_fx.pulse_flash(0.2)
				post_fx.pulse_tear(0.6)


func _after(seconds: float, what: Callable) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(
		func() -> void:
			if is_inside_tree() and is_instance_valid(player) and not player.dead:
				what.call()
	)


# --- Being caught ----------------------------------------------------------------------


## The local player was struck down: turn them to face it and scream.
func caught() -> void:
	var enemy := _nearest_enemy()
	if enemy:
		player.face_point(enemy.global_position + Vector3(0, 1.7, 0))
	AudioService.play_2d("scare_scream", AudioService.BUS_SFX, 0.0 if full() else -12.0)
	if post_fx:
		post_fx.damage = 1.0
		if full():
			post_fx.pulse_tear(1.0)
			post_fx.pulse_flash(0.3)


## A survivable hit: a sharp stab and a tear across the view.
func hurt() -> void:
	AudioService.play_2d("scare_hit", AudioService.BUS_SFX, -4.0 if full() else -14.0)
	if post_fx and full():
		post_fx.pulse_tear(0.5)


func _nearest_enemy() -> Node3D:
	var best: Node3D
	var best_d := 6.0
	for e in match_ctrl.enemies:
		if is_instance_valid(e):
			var d := (e as Node3D).global_position.distance_to(player.global_position)
			if d < best_d:
				best = e
				best_d = d
	return best
