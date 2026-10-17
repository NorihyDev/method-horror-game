class_name Watcher
extends CharacterBody3D
## The shared enemy brain. Decisions run on the authority only. Each map picks
## an `EnemyProfile` (senses, speeds, sounds, body), so The Watcher (house),
## The Sister (ward) and The Lineman (station) follow different, readable
## perception rules with one tested state machine (docs/game-design.md#enemies).
##
## The Watcher's rules:
## * Sees in a 120° cone; light makes you visible from farther away, darkness
##   and crouching shorten that distance. No vision through walls.
## * Hears noise (footsteps, doors, misses at the crank, short circuits);
##   walls muffle it. It investigates what it hears.
## * Lamps flicker and its key ring jingles when it is near: the warning cue.
## * It never teleports and never spawns near or in sight of a player.

enum S { PATROL, INVESTIGATE, SEARCH, CHASE, ATTACK, RECOVER, LOST, CHECK_HIDING }

const LAYER_ENEMY := 1 << 2
const ATTACK_RANGE := 1.75
const STRIKE_RANGE := 2.2
const SEARCH_TIME := 11.0
const GRAVITY := 18.0
const SCARE_COOLDOWN := 75.0

var match_ctrl: MatchController
var map: MapBase
var profile: EnemyProfile
var state: S = S.PATROL
var rig: WatcherRig
var agent: NavigationAgent3D

var _diff: DifficultyDefinition
var _rng := RandomNumberGenerator.new()
var _target := Vector3.ZERO
var _has_target := false
var _suspicion: Dictionary = {}
var _chase_pid := 0
var _last_seen_pos := Vector3.ZERO
var _last_seen_time := -100.0
var _state_time := 0.0
var _sense_timer := 0.0
var _repath_timer := 0.0
var _door_timer := 0.0
var _stuck_check_pos := Vector3.ZERO
var _stuck_timer := 0.0
var _stuck_count := 0
var _attack_stage := 0
var _cooldown := 0.0
var _vocal_cooldown := 0.0
var _keys_timer := 12.0
var _lamp_timer := 0.0
var _last_scare := -1000.0
var _visited: Array[Vector3] = []
var _noise_memory: Array[Dictionary] = []
## pid -> {"spot": HidingSpot, "time": float} for players it saw hide.
var _seen_hiding: Dictionary = {}
var _check_spot: HidingSpot
var _pause := 0.0
var _breath: AudioStreamPlayer3D
## Client puppets: last state received from the server.
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_has := false
var _shown_speed := 0.0


## May run before or after entering the tree; the body is built once both
## the tree and the profile are available.
func setup(p_match: MatchController, p_map: MapBase) -> void:
	match_ctrl = p_match
	map = p_map
	_diff = match_ctrl.difficulty
	if profile == null:
		var profile_id := String(map.definition.enemy_profile) if map and map.definition else "watcher"
		profile = EnemyProfile.for_id(profile_id)
	if is_inside_tree() and rig == null:
		_build()


func _ready() -> void:
	_rng.randomize()
	add_to_group("enemies")
	collision_layer = LAYER_ENEMY
	collision_mask = GeoBuilder.LAYER_WORLD | GeoBuilder.LAYER_PROP | DoorEntity.LAYER_DOOR
	floor_max_angle = deg_to_rad(46)
	floor_snap_length = 0.5
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 2.0
	cs.shape = cap
	cs.position.y = 1.0
	add_child(cs)
	if profile != null:
		_build()


func _build() -> void:
	rig = WatcherRig.new()
	rig.style = profile.rig_style
	rig.rotation.y = PI
	add_child(rig)
	rig.foot_planted.connect(_on_foot)
	agent = NavigationAgent3D.new()
	agent.radius = 0.42
	agent.height = 1.9
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.9
	agent.path_max_distance = 3.0
	agent.avoidance_enabled = false
	add_child(agent)
	_breath = AudioService.make_emitter(profile.breath_sound, profile.breath_db, 16.0)
	_breath.position.y = 1.9
	add_child(_breath)
	_breath.play()
	_stuck_check_pos = global_position
	_enter(S.PATROL)


# --- Senses (authority) ---------------------------------------------------------------


## Noise event: `radius` already includes difficulty scaling. `source_pid`
## is the player who made it (0 = the world: machines, the enemy itself).
func hear(pos: Vector3, radius: float, kind: String, source_pid: int = 0) -> void:
	if not _authority() or profile == null:
		return
	radius *= profile.hearing
	var d := global_position.distance_to(pos)
	if d > radius:
		return
	var effective := radius
	if not _clear_line(global_position + Vector3(0, 1.7, 0), pos + Vector3(0, 0.5, 0)):
		effective *= 0.6  # walls and floors muffle sound
	if d > effective:
		return
	_noise_memory.append({"pos": pos, "time": match_ctrl.state.elapsed})
	if _noise_memory.size() > 12:
		_noise_memory.pop_front()
	if profile.hunts_by_sound and source_pid > 0 and d <= effective * profile.hunt_fraction:
		_hunt_sound(source_pid, pos)
		return
	match state:
		S.CHASE, S.ATTACK, S.RECOVER:
			return
		S.CHECK_HIDING:
			return
	var loud := kind in ["short", "clank", "garage", "power"]
	if state == S.INVESTIGATE and not loud and _target.distance_to(pos) < 3.0:
		return
	_target = map.closest_nav_point(pos)
	_has_target = true
	if state != S.INVESTIGATE:
		_vocal(profile.growl_sound, 6.0)
	_enter(S.INVESTIGATE)


## Blind hunters treat a close player-made noise like a sighting: they run at
## where it came from and keep tracking while the noise continues.
func _hunt_sound(pid: int, pos: Vector3) -> void:
	var p := match_ctrl.state.player(pid)
	if p.is_empty() or p["status"] != MatchState.STATUS_ALIVE:
		return
	if state in [S.ATTACK, S.RECOVER, S.CHECK_HIDING]:
		return
	if state == S.CHASE and pid != _chase_pid:
		# Switch prey only to a noise closer than the one it is chasing.
		var cur := match_ctrl.state.player(_chase_pid)
		if not cur.is_empty() and _last_seen_pos.distance_to(global_position) <= pos.distance_to(global_position):
			return
		_chase_pid = pid
	_last_seen_pos = pos
	_last_seen_time = match_ctrl.state.elapsed
	if state == S.CHASE:
		return
	_chase_pid = pid
	_start_chase(pos)


## Called when a player gets into a hiding spot.
func on_player_hid(pid: int, spot: HidingSpot) -> void:
	if not _authority() or profile == null:
		return
	if not profile.sees:
		# A blind hunter knows only if it heard the door close behind you.
		var heard := spot.global_position.distance_to(global_position) <= 3.5 * profile.hearing * 1.6
		if heard and state in [S.CHASE, S.LOST, S.INVESTIGATE]:
			_seen_hiding[pid] = {"spot": spot, "time": match_ctrl.state.elapsed}
		return
	# It only "knows" if it was actively chasing and could see the player.
	if (
		(state == S.CHASE or state == S.ATTACK)
		and _chase_pid == pid
		and match_ctrl.state.elapsed - _last_seen_time < 0.6
	):
		_seen_hiding[pid] = {"spot": spot, "time": match_ctrl.state.elapsed}


func _sense() -> void:
	var elapsed := match_ctrl.state.elapsed
	var eye := global_position + Vector3(0, 1.85, 0)
	var forward := -global_basis.z
	var phase_mult := (
		1.15
		if match_ctrl.state.phase == MatchState.Phase.FINAL
		else (1.05 if match_ctrl.state.phase == MatchState.Phase.ESCALATE else 1.0)
	)
	var best_pid := 0
	var best_pos := Vector3.ZERO
	if not profile.sees:
		_sense_touch(eye)
		return
	for target in match_ctrl.perceivable_players():
		var pid: int = target["pid"]
		if not str(target["hiding"]).is_empty():
			_suspicion[pid] = maxf(0.0, float(_suspicion.get(pid, 0.0)) - 0.6)
			continue
		var pos: Vector3 = target["pos"]
		var chest := pos + Vector3(0, 1.0 if target["crouch"] else 1.35, 0)
		var to := chest - eye
		var d := to.length()
		var light := profile.light_dark
		if target["flashlight"]:
			light = profile.light_flashlight
		elif target["lit"]:
			light = profile.light_lit
		var crouch := profile.crouch_sight if target["crouch"] else 1.0
		var sight_range := profile.base_sight * _diff.enemy_sight * phase_mult * light * crouch
		var can_see := false
		if d <= profile.touch_radius:
			can_see = _clear_line(eye, chest)
		elif d <= sight_range:
			var flat_to := Vector3(to.x, 0, to.z).normalized()
			var flat_fwd := Vector3(forward.x, 0, forward.z).normalized()
			if flat_fwd.dot(flat_to) >= cos(profile.fov_half):
				can_see = _clear_line(eye, chest)
		var s := float(_suspicion.get(pid, 0.0))
		if can_see:
			var rate := 2.2 / maxf(d * 0.35, 0.5)
			if state == S.CHASE and pid == _chase_pid:
				rate = 10.0
			s = minf(1.5, s + rate * 0.15)
			if s >= 1.0 and (best_pid == 0 or d < best_pos.distance_to(eye)):
				best_pid = pid
				best_pos = pos
			elif s >= 0.35 and state in [S.PATROL, S.SEARCH, S.LOST]:
				_target = map.closest_nav_point(pos)
				_has_target = true
				_enter(S.INVESTIGATE)
		else:
			s = maxf(0.0, s - 0.08)
		_suspicion[pid] = s
	if best_pid != 0:
		_last_seen_pos = best_pos
		_last_seen_time = elapsed
		if state != S.CHASE and state != S.ATTACK and state != S.RECOVER:
			_chase_pid = best_pid
			_start_chase(best_pos)
		elif state == S.CHASE:
			_chase_pid = best_pid


## Blind: only bodily contact reveals a player (no cone, no light, no walls).
func _sense_touch(eye: Vector3) -> void:
	for target in match_ctrl.perceivable_players():
		if not str(target["hiding"]).is_empty():
			continue
		var pos: Vector3 = target["pos"]
		if pos.distance_to(global_position) > profile.touch_radius:
			continue
		if not _clear_line(eye, pos + Vector3(0, 1.0, 0)):
			continue
		_last_seen_pos = pos
		_last_seen_time = match_ctrl.state.elapsed
		if state not in [S.CHASE, S.ATTACK, S.RECOVER]:
			_chase_pid = int(target["pid"])
			_start_chase(pos)
		return


func _start_chase(pos: Vector3) -> void:
	_enter(S.CHASE)
	rig.play("alert", 0.1)
	_pause = 0.35
	_vocal(profile.screech_sound, 4.0, true)
	var d := global_position.distance_to(pos)
	var now := match_ctrl.state.elapsed
	if d < 7.0 and now - _last_scare > SCARE_COOLDOWN:
		_last_scare = now
		match_ctrl.world_sound("stinger_scare", pos, -2.0 if Settings.s("jump_scares") == "full" else -12.0, 30.0)
		var app := Session.app
		if app and app.post_fx and Settings.s("jump_scares") == "full":
			app.post_fx.pulse_flash(0.35)


# --- Tick ------------------------------------------------------------------------------


func _physics_process(delta: float) -> void:
	if not _authority() or rig == null:
		return
	if match_ctrl.is_finished() or not match_ctrl.running:
		velocity = Vector3.ZERO
		return
	_state_time += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	_vocal_cooldown = maxf(0.0, _vocal_cooldown - delta)
	_sense_timer -= delta
	if _sense_timer <= 0.0:
		_sense_timer = 0.15
		_sense()
	_tick_cues(delta)
	if _pause > 0.0:
		_pause -= delta
		_move(Vector3.ZERO, 0.0, delta)
		return
	match state:
		S.PATROL:
			_tick_patrol(delta)
		S.INVESTIGATE:
			_tick_investigate(delta)
		S.SEARCH:
			_tick_search(delta)
		S.CHASE:
			_tick_chase(delta)
		S.ATTACK:
			_tick_attack(delta)
		S.RECOVER:
			_move(Vector3.ZERO, 0.0, delta)
			if _state_time > 1.3:
				_enter(S.CHASE if match_ctrl.state.elapsed - _last_seen_time < 1.0 else S.LOST)
		S.LOST:
			_tick_lost(delta)
		S.CHECK_HIDING:
			_tick_check_hiding(delta)


func _tick_patrol(delta: float) -> void:
	if not _has_target or _arrived():
		if _has_target and _state_time > 1.0:
			_visited.append(_target)
			if _visited.size() > 4:
				_visited.pop_front()
			_pause = _rng.randf_range(1.0, 2.5)
			rig.play("search", 0.4)
		_target = _pick_patrol_point()
		_has_target = true
		agent.target_position = _target
	_follow(profile.walk, delta)


func _tick_investigate(delta: float) -> void:
	agent.target_position = _target
	_follow(profile.investigate, delta)
	if _arrived() or _state_time > 25.0:
		_enter(S.SEARCH)


func _tick_search(delta: float) -> void:
	var duration := SEARCH_TIME * _diff.enemy_persistence
	if _state_time > duration:
		_enter(S.PATROL)
		return
	if not _has_target or _arrived():
		_pause = _rng.randf_range(0.8, 1.8)
		rig.play("search", 0.3)
		var center := _last_seen_pos if match_ctrl.state.elapsed - _last_seen_time < 20.0 else global_position
		var offset := Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5))
		_target = map.closest_nav_point(center + offset)
		_has_target = true
		agent.target_position = _target
		_maybe_check_spot_near(center)
		return
	_follow(profile.walk * 1.15, delta)


func _tick_chase(delta: float) -> void:
	var now := match_ctrl.state.elapsed
	var p := match_ctrl.state.player(_chase_pid)
	if p.is_empty() or p["status"] != MatchState.STATUS_ALIVE:
		_enter(S.LOST)
		return
	var hidden_spot := str(p["hiding"])
	if not hidden_spot.is_empty():
		var seen: Dictionary = _seen_hiding.get(_chase_pid, {})
		if not seen.is_empty():
			_check_spot = seen["spot"]
			_enter(S.CHECK_HIDING)
		else:
			_enter(S.LOST)
		return
	var pos := MatchState.array_to_vec(p["pos"])
	# Keeps tracking briefly after losing sight (it knows where you went a moment ago).
	if now - _last_seen_time > profile.track_after_lost:
		_enter(S.LOST)
		return
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = 0.25
		# A blind hunter runs at the last place it heard you, not where you are.
		agent.target_position = map.closest_nav_point(pos if profile.sees else _last_seen_pos)
	var d := global_position.distance_to(pos)
	if d <= ATTACK_RANGE and _cooldown <= 0.0 and now - _last_seen_time < 0.3:
		_enter(S.ATTACK)
		return
	_follow(profile.run, delta)


func _tick_lost(delta: float) -> void:
	agent.target_position = _last_seen_pos
	_follow(profile.investigate * 1.2, delta)
	if _arrived() or _state_time > 12.0:
		_enter(S.SEARCH)


func _tick_attack(delta: float) -> void:
	var p := match_ctrl.state.player(_chase_pid)
	var pos := MatchState.array_to_vec(p.get("pos", [0, 0, 0]))
	_face(pos, delta * 8.0)
	_move(Vector3.ZERO, 0.0, delta)
	var windup := _diff.attack_windup
	if _attack_stage == 0:
		_attack_stage = 1
		rig.play("windup", 0.1, 1.0 / maxf(windup, 0.2))
		_vocal(profile.attack_sound, 0.0, true)
	elif _attack_stage == 1 and _state_time >= windup:
		_attack_stage = 2
		rig.play("strike", 0.05)
		_strike(pos)
	elif _attack_stage == 2 and _state_time >= windup + 0.3:
		_cooldown = _diff.scaled_cooldown(match_ctrl.state.player_count)
		_enter(S.RECOVER)


func _strike(pos: Vector3) -> void:
	var p := match_ctrl.state.player(_chase_pid)
	if p.is_empty() or p["status"] != MatchState.STATUS_ALIVE:
		return
	var to := pos - global_position
	to.y = 0.0
	var in_front := (-global_basis.z).dot(to.normalized()) > 0.25
	var hiding := str(p["hiding"])
	if (
		(to.length() <= STRIKE_RANGE and in_front and hiding.is_empty())
		or (not hiding.is_empty() and _check_spot != null)
	):
		match_ctrl.damage_player(_chase_pid)
		match_ctrl.world_sound("door_close", global_position + Vector3(0, 1.2, 0), 0.0, 20.0)


func _tick_check_hiding(delta: float) -> void:
	if _check_spot == null or not is_instance_valid(_check_spot):
		_enter(S.SEARCH)
		return
	var front := _check_spot.exit_position()
	agent.target_position = map.closest_nav_point(front)
	if global_position.distance_to(front) > 1.2 and _state_time < 10.0:
		_follow(profile.investigate * 1.3, delta)
		return
	_face(_check_spot.global_position, delta * 8.0)
	_move(Vector3.ZERO, 0.0, delta)
	if _state_time < 0.6:
		rig.play("open_door", 0.15)
		return
	var occupant := _check_spot.occupant()
	if occupant != 0:
		# Found: drag them out and strike.
		_chase_pid = occupant
		_check_spot.release(occupant)
		_seen_hiding.erase(occupant)
		_last_seen_time = match_ctrl.state.elapsed
		var p := match_ctrl.state.player(occupant)
		_last_seen_pos = MatchState.array_to_vec(p.get("pos", [0, 0, 0]))
		_check_spot = null
		_enter(S.ATTACK)
	else:
		_check_spot = null
		_enter(S.SEARCH)


## Searching where it lost you: if you hid close by moments ago, it may check
## that exact spot (chance scales with difficulty persistence).
func _maybe_check_spot_near(center: Vector3) -> void:
	var chance := clampf(0.2 * _diff.enemy_persistence, 0.0, 0.8)
	for e in match_ctrl.entities.values():
		if e is HidingSpot:
			var spot: HidingSpot = e
			if spot.occupant() != 0 and spot.global_position.distance_to(center) < 4.5 and _rng.randf() < chance:
				_check_spot = spot
				_enter(S.CHECK_HIDING)
				return


# --- Movement --------------------------------------------------------------------------


func _follow(speed: float, delta: float) -> void:
	if agent.is_navigation_finished():
		_move(Vector3.ZERO, 0.0, delta)
		return
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		_move(Vector3.ZERO, 0.0, delta)
		return
	_face(global_position + dir, delta * 6.0)
	var phase_mult := 1.12 if match_ctrl.state.phase == MatchState.Phase.FINAL else 1.0
	_move(dir.normalized(), speed * _diff.enemy_speed * phase_mult, delta)
	_open_doors_ahead(dir.normalized())
	_check_stuck(delta)


func _move(dir: Vector3, speed: float, delta: float) -> void:
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, 12.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 12.0 * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_update_anim()


func _face(point: Vector3, rate: float) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return
	var target_yaw := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(rate, 0.0, 1.0))


func _update_anim() -> void:
	if state in [S.ATTACK, S.CHECK_HIDING] or (_pause > 0.0 and rig.current() in ["alert", "search", "open_door"]):
		return
	if state == S.RECOVER:
		rig.play("recover", 0.15)
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 2.6:
		rig.play("run", 0.2, speed / 4.0)
	elif speed > 0.3:
		rig.play("walk", 0.25, speed / profile.walk)
	elif state == S.SEARCH:
		rig.play("search", 0.3)
	else:
		rig.play("idle", 0.4)


func _arrived() -> bool:
	return _has_target and (agent.is_navigation_finished() or global_position.distance_to(_target) < 1.0)


func _open_doors_ahead(dir: Vector3) -> void:
	_door_timer -= get_physics_process_delta_time()
	if _door_timer > 0.0:
		return
	_door_timer = 0.2
	var from := global_position + Vector3(0, 1.1, 0)
	var q := PhysicsRayQueryParameters3D.create(
		from, from + dir * 1.4, DoorEntity.LAYER_DOOR | Interactable.LAYER_INTERACT
	)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var n: Node = hit["collider"]
	while n and not n is DoorEntity:
		n = n.get_parent()
	if n is DoorEntity:
		var door: DoorEntity = n
		if not door.is_locked() and not door.is_open():
			door.enemy_open()
			match_ctrl.emit_noise(door.interact_origin(), 6.0, "door")
			rig.play("open_door", 0.1)
			_pause = 0.45


func _check_stuck(delta: float) -> void:
	_stuck_timer += delta
	if _stuck_timer < 1.0:
		return
	_stuck_timer = 0.0
	var moved := global_position.distance_to(_stuck_check_pos)
	_stuck_check_pos = global_position
	if moved > 0.25:
		_stuck_count = 0
		return
	_stuck_count += 1
	if _stuck_count == 2:
		agent.target_position = map.closest_nav_point(agent.target_position)
	elif _stuck_count == 4:
		_target = _pick_patrol_point()
		agent.target_position = _target
		if state == S.INVESTIGATE or state == S.LOST:
			_enter(S.SEARCH)
	elif _stuck_count >= 7:
		# Recover onto the navigation mesh (small correction, never a relocation).
		var snap := map.closest_nav_point(global_position)
		if snap.distance_to(global_position) < 1.5:
			global_position = snap
		_stuck_count = 0


func _pick_patrol_point() -> Vector3:
	var points := map.patrol_points
	if points.is_empty():
		return global_position
	# Rooms with recent noise are favored; otherwise wander away from recent spots.
	var now := match_ctrl.state.elapsed
	var best := points[0]
	var best_score := -INF
	for p in points:
		var score := _rng.randf_range(0.0, 10.0)
		for v in _visited:
			if v.distance_to(p) < 3.0:
				score -= 8.0
		for n in _noise_memory:
			var age := now - float(n["time"])
			if age < 60.0 and (n["pos"] as Vector3).distance_to(p) < 8.0:
				score += 6.0 * (1.0 - age / 60.0)
		if p.distance_to(global_position) < 2.5:
			score -= 10.0
		if score > best_score:
			best_score = score
			best = p
	return map.closest_nav_point(best)


func _enter(s: S) -> void:
	state = s
	_state_time = 0.0
	_attack_stage = 0
	_has_target = s in [S.INVESTIGATE] and _has_target
	match s:
		S.SEARCH:
			_has_target = false
		S.LOST:
			_vocal(profile.growl_sound, 8.0)


# --- Presentation cues ----------------------------------------------------------------


func _tick_cues(delta: float) -> void:
	rig.set_lens_intensity(net_lens())
	_keys_timer -= delta
	if _keys_timer <= 0.0:
		_keys_timer = _rng.randf_range(profile.cue_interval.x, profile.cue_interval.y)
		if not profile.cue_sound.is_empty() and state in [S.PATROL, S.SEARCH, S.INVESTIGATE]:
			match_ctrl.world_sound(profile.cue_sound, global_position + Vector3(0, 1.0, 0), -4.0, 18.0)


## Presentation on every peer: a blind hunter stops humming while it hunts,
## so sudden silence is the warning.
func _tick_voice(delta: float) -> void:
	if _breath == null or profile == null or profile.sees:
		return
	var hunting := state in [S.CHASE, S.ATTACK, S.LOST] if _authority() else _shown_speed > 2.6
	var target_db := -40.0 if hunting else profile.breath_db
	_breath.volume_db = move_toward(_breath.volume_db, target_db, delta * 30.0)


func _vocal(sound: String, cooldown: float, force: bool = false) -> void:
	if _vocal_cooldown > 0.0 and not force:
		return
	_vocal_cooldown = cooldown
	match_ctrl.world_sound(sound, global_position + Vector3(0, 1.9, 0), 0.0, 30.0)


func _on_foot() -> void:
	# Local presentation on every peer (driven by animation, not replicated).
	var speed := Vector2(velocity.x, velocity.z).length() if _authority() else _shown_speed
	var step := profile.step_sound if profile else "watcher_step"
	AudioService.play_3d(step, get_parent(), global_position, -4.0 if speed > 2.6 else -8.0, 24.0)


## Sight/hearing line: walls, doors and large furniture block it.
func _clear_line(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(
		from, to, GeoBuilder.LAYER_WORLD | GeoBuilder.LAYER_PROP | DoorEntity.LAYER_DOOR
	)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _authority() -> bool:
	return match_ctrl != null and match_ctrl.is_authority


## Debug summary for the dev objective inspector.
func debug_text() -> String:
	return (
		"%s: %s  target=%s  chase=%d  susp=%s"
		% [
			profile.id if profile else "enemy",
			S.keys()[state],
			str(_target.snapped(Vector3.ONE * 0.1)),
			_chase_pid,
			str(_suspicion)
		]
	)


# --- Presentation on every peer / client puppets ------------------------------------------


func _process(delta: float) -> void:
	if map == null:
		return
	_tick_voice(delta)
	if not _authority() and _net_has:
		var before := global_position
		global_position = global_position.lerp(_net_pos, clampf(delta * 10.0, 0.0, 1.0))
		rotation.y = lerp_angle(rotation.y, _net_yaw, clampf(delta * 10.0, 0.0, 1.0))
		_shown_speed = (global_position - before).length() / maxf(delta, 0.001)
	_lamp_timer -= delta
	if _lamp_timer <= 0.0:
		_lamp_timer = 0.25
		for lamp in map.lamps:
			lamp.enemy_proximity = clampf(
				1.0 - lamp.global_position.distance_to(global_position) / FlickerLight.NEAR_ENEMY, 0.0, 1.0
			)


## Client puppet update from the server (15 Hz, unreliable).
func apply_net(pos: Vector3, yaw: float, anim: String, lens: float) -> void:
	_net_pos = pos
	_net_yaw = yaw
	if not _net_has:
		global_position = pos
		rotation.y = yaw
	_net_has = true
	if rig and anim in WatcherRig.ANIMS:
		rig.play(anim, 0.2)
	if rig:
		rig.set_lens_intensity(lens)


func net_anim() -> String:
	return rig.current() if rig else "idle"


func net_lens() -> float:
	return 1.0 if state in [S.CHASE, S.ATTACK] else 0.2
