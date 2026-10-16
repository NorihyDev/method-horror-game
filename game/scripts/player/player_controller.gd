class_name PlayerController
extends CharacterBody3D
## Local first-person player. Movement is simulated locally for
## responsiveness and reported to the authority, which derives noise and
## validates interaction range from the reported position.

signal focus_changed(prompt: String, entity: Interactable, sub: int)
signal hold_progress_changed(progress: float)
signal stamina_changed(value: float)
signal battery_changed(value: float)
signal hiding_changed(hidden: bool)
signal damaged(hits: int)
signal died

const LAYER_PLAYER := 1 << 1
const STAND_HEIGHT := 1.75
const CROUCH_HEIGHT := 1.15
const EYE_STAND := 1.62
const EYE_CROUCH := 1.02
const RADIUS := 0.33
const WALK_SPEED := 2.7
const SPRINT_SPEED := 4.7
const CROUCH_SPEED := 1.35
const ACCEL := 13.0
const DECEL := 16.0
const AIR_CONTROL := 0.3
const GRAVITY := 18.0
const STAMINA_DRAIN := 0.17
const STAMINA_REGEN := 0.11
const STAMINA_REGEN_DELAY := 1.0
const STAMINA_MIN_TO_SPRINT := 0.25
const BATTERY_SECONDS := 240.0
const INTERACT_REACH := 2.4
const MOUSE_K := 0.0022
const TOUCH_K := 0.0042
const PAD_K := 2.8
const PITCH_LIMIT := deg_to_rad(84)

var player_id := 1
var match_ctrl: MatchController
var map: MapBase
var touch: Node = null
var input_enabled := true

var head: Node3D
var camera: Camera3D
var viewmodel: Viewmodel
var flashlight: SpotLight3D
var flashlight_on := true
var battery := 1.0
var stamina := 1.0
var crouching := false
var sprinting := false
var hidden_spot: HiddenInfo
var dead := false
var escaped := false

var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _ray: RayCast3D
var _yaw := 0.0
var _pitch := 0.0
var _focus: Interactable
var _focus_sub := 0
var _focus_prompt := ""
var _hold := 0.0
var _hold_target := 0.0
var _hold_consumed := false
var _sprint_toggle := false
var _stamina_delay := 0.0
var _exhausted := false
var _bob_phase := 0.0
var _step_accum := 0.0
var _shake := 0.0
var _stumble := 0.0
var _air_time := 0.0
var _pad_look_ramp := 0.0
var _flicker_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _report_timer := 0.0


class HiddenInfo:
	var spot: HidingSpot
	var base_yaw := 0.0
	var saved_transform: Transform3D


func get_player_id() -> int:
	return player_id


func _ready() -> void:
	_rng.randomize()
	add_to_group("players")
	collision_layer = LAYER_PLAYER
	collision_mask = GeoBuilder.LAYER_WORLD | GeoBuilder.LAYER_PROP | DoorEntity.LAYER_DOOR
	floor_max_angle = deg_to_rad(46)
	floor_snap_length = 0.45
	floor_stop_on_slope = true
	wall_min_slide_angle = deg_to_rad(10)
	_capsule = CapsuleShape3D.new()
	_capsule.radius = RADIUS
	_capsule.height = STAND_HEIGHT
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position.y = STAND_HEIGHT * 0.5
	add_child(_shape)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_STAND
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.04
	camera.far = 60.0
	camera.current = true
	head.add_child(camera)
	viewmodel = Viewmodel.new()
	camera.add_child(viewmodel)
	flashlight = viewmodel.flashlight
	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -INTERACT_REACH)
	_ray.collision_mask = Interactable.LAYER_INTERACT | GeoBuilder.LAYER_WORLD | DoorEntity.LAYER_DOOR
	_ray.collide_with_areas = false
	_ray.add_exception(self)
	camera.add_child(_ray)
	_yaw = rotation.y
	rotation = Vector3.ZERO
	_apply_settings()
	Settings.changed.connect(func(_k: String, _v: Variant) -> void: _apply_settings())
	_apply_cosmetics()
	Saves.profile_changed.connect(_apply_cosmetics)


func _apply_settings() -> void:
	camera.fov = Settings.f("fov")
	flashlight.shadow_enabled = Settings.s("shadows") != "off"
	camera.far = 45.0 if Settings.s("draw_distance") == "near" else 70.0


func _apply_cosmetics() -> void:
	var item := Saves.equipped_item(CosmeticCatalog.SLOT_FLASHLIGHT)
	if not item.is_empty():
		viewmodel.set_style(item["beam"], item["body"])


func setup(p_match: MatchController, p_map: MapBase, pid: int) -> void:
	match_ctrl = p_match
	map = p_map
	player_id = pid


func place(xform: Transform3D) -> void:
	global_position = xform.origin
	_yaw = xform.basis.get_euler().y
	_pitch = 0.0
	velocity = Vector3.ZERO


# --- Input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = (event as InputEventMouseMotion).screen_relative
		_look(rel * MOUSE_K * Settings.f("mouse_sensitivity"))
	elif event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("crouch") and Settings.s("crouch_mode") == "toggle":
		set_crouch(not crouching)
	elif event.is_action_pressed("sprint") and Settings.s("sprint_mode") == "toggle":
		_sprint_toggle = not _sprint_toggle


func _look(delta_rad: Vector2) -> void:
	var invert := -1.0 if Settings.b("invert_y") else 1.0
	_yaw -= delta_rad.x
	_pitch = clampf(_pitch - delta_rad.y * invert, -PITCH_LIMIT, PITCH_LIMIT)
	if hidden_spot:
		_yaw = clampf(_yaw, hidden_spot.base_yaw - deg_to_rad(40), hidden_spot.base_yaw + deg_to_rad(40))
		_pitch = clampf(_pitch, deg_to_rad(-25), deg_to_rad(25))


func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	AudioService.play_2d("flashlight_click", AudioService.BUS_SFX, -6.0)
	battery_changed.emit(battery)


func toggle_sprint() -> void:
	_sprint_toggle = not _sprint_toggle


func set_crouch(on: bool) -> void:
	if on == crouching:
		return
	if not on and not _has_headroom():
		return
	crouching = on


func _has_headroom() -> bool:
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var probe := CapsuleShape3D.new()
	probe.radius = RADIUS * 0.9
	probe.height = STAND_HEIGHT - 0.1
	params.shape = probe
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, STAND_HEIGHT * 0.5 + 0.05, 0))
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	return space.intersect_shape(params, 1).is_empty()


func _gather_move() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch and touch.has_method("move_vector"):
		var t: Vector2 = touch.call("move_vector")
		if t.length() > v.length():
			v = t
	return v.limit_length(1.0)


func _gather_look(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length() > 0.0:
		var curve := stick * pow(stick.length(), 0.6) if Settings.b("look_acceleration") else stick
		_pad_look_ramp = minf(1.0, _pad_look_ramp + delta * 2.5) if Settings.b("look_acceleration") else 1.0
		var ramp := lerpf(0.55, 1.25, _pad_look_ramp)
		_look(curve * PAD_K * Settings.f("pad_sensitivity") * ramp * delta)
	else:
		_pad_look_ramp = 0.0
	if touch and touch.has_method("consume_look"):
		var d: Vector2 = touch.call("consume_look")
		if d != Vector2.ZERO:
			_look(d * TOUCH_K * Settings.f("touch_sensitivity"))


func _wants_sprint() -> bool:
	var held := Input.is_action_pressed("sprint") or (touch != null and bool(touch.call("is_held", "sprint")))
	if Settings.s("sprint_mode") == "toggle":
		return _sprint_toggle
	return held


func _wants_interact() -> bool:
	return Input.is_action_pressed("interact") or (touch != null and bool(touch.call("is_held", "interact")))


# --- Simulation ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead or escaped:
		_tick_presentation(delta, Vector2.ZERO)
		return
	if hidden_spot:
		if input_enabled:
			_gather_look(delta)
		_update_hidden_camera(delta)
		_tick_interaction(delta)
		_tick_battery(delta)
		_report(delta)
		return
	var move := _gather_move() if input_enabled else Vector2.ZERO
	if input_enabled:
		_gather_look(delta)
		if Settings.s("crouch_mode") == "hold":
			set_crouch(Input.is_action_pressed("crouch") or (touch != null and bool(touch.call("is_held", "crouch"))))
	var want_sprint := input_enabled and _wants_sprint() and move.y < -0.2 and not crouching
	if _exhausted and stamina >= STAMINA_MIN_TO_SPRINT:
		_exhausted = false
	sprinting = want_sprint and not _exhausted and stamina > 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
		_stamina_delay = STAMINA_REGEN_DELAY
		if stamina <= 0.0:
			_exhausted = true
			_sprint_toggle = false
	else:
		_stamina_delay -= delta
		if _stamina_delay <= 0.0:
			stamina = minf(1.0, stamina + STAMINA_REGEN * delta)
	stamina_changed.emit(stamina)

	var speed := CROUCH_SPEED if crouching else (SPRINT_SPEED if sprinting else WALK_SPEED)
	if _stumble > 0.0:
		_stumble -= delta
		speed *= 0.6
	var basis := Basis(Vector3.UP, _yaw)
	var wish := basis * Vector3(move.x, 0, move.y)
	var target := wish * speed
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var rate := (ACCEL if wish.length() > 0.01 else DECEL) * (1.0 if is_on_floor() else AIR_CONTROL)
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		if _air_time > 0.35:
			_land(_air_time)
		_air_time = 0.0
		velocity.y = minf(velocity.y, 0.0)
	else:
		_air_time += delta
		velocity.y -= GRAVITY * delta
	_update_capsule(delta)
	move_and_slide()
	_tick_footsteps(delta, horizontal.length())
	_tick_presentation(delta, move)
	_tick_interaction(delta)
	_tick_battery(delta)
	_report(delta)


func _update_capsule(delta: float) -> void:
	var target_h := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	_capsule.height = move_toward(_capsule.height, target_h, delta * 3.0)
	_shape.position.y = _capsule.height * 0.5


func _tick_presentation(delta: float, move: Vector2) -> void:
	var eye := EYE_CROUCH if crouching else EYE_STAND
	if dead:
		eye = 0.3
	var bob := Vector3.ZERO
	var speed := Vector2(velocity.x, velocity.z).length()
	var motion_ok := Settings.b("head_bob") and not Settings.motion_reduced()
	if is_on_floor() and speed > 0.3 and motion_ok:
		_bob_phase += delta * speed * 2.1
		var amp := 0.045 if sprinting else 0.028
		bob = Vector3(sin(_bob_phase) * amp * 0.6, absf(cos(_bob_phase)) * amp, 0)
	else:
		_bob_phase = lerpf(_bob_phase, roundf(_bob_phase / PI) * PI, delta * 4.0)
	var breathe := sin(Time.get_ticks_msec() / 1000.0 * (2.4 if stamina < 0.4 else 1.3)) * (0.006 if motion_ok else 0.0)
	head.position = head.position.lerp(Vector3(bob.x, eye + bob.y + breathe, 0), clampf(delta * 10.0, 0.0, 1.0))
	var shake_off := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		if Settings.b("camera_shake") and not Settings.motion_reduced():
			shake_off = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake * 0.02
	if not hidden_spot:
		head.rotation = Vector3(_pitch, _yaw, 0)
		var tilt := -move.x * deg_to_rad(1.2) if motion_ok else 0.0
		camera.rotation.z = lerpf(camera.rotation.z, tilt, delta * 6.0)
	camera.position = shake_off
	viewmodel.update_motion(delta, speed, sprinting, crouching, is_on_floor(), _bob_phase if motion_ok else 0.0)


func _land(air: float) -> void:
	if Settings.b("head_bob") and not Settings.motion_reduced():
		head.position.y -= clampf(air * 0.08, 0.02, 0.12)
	_play_step(0.0)


func _tick_footsteps(_delta: float, speed: float) -> void:
	if not is_on_floor() or speed < 0.4:
		return
	_step_accum += speed * get_physics_process_delta_time()
	var stride := 0.9 if sprinting else (0.55 if crouching else 0.75)
	if _step_accum >= stride:
		_step_accum = 0.0
		_play_step(-14.0 if crouching else (-4.0 if sprinting else -9.0))


func _play_step(volume_db: float) -> void:
	var surface := map.surface_at(global_position) if map else "wood"
	var sound := {"wood": "step_wood", "carpet": "step_carpet", "metal": "step_metal"}.get(surface, "step_concrete") as String
	AudioService.play_2d(sound, AudioService.BUS_SFX, volume_db, _rng.randf_range(0.92, 1.06))


func _tick_battery(delta: float) -> void:
	var drain := match_ctrl.difficulty.battery_drain if match_ctrl else 1.0
	if flashlight_on and battery > 0.0:
		battery = maxf(0.0, battery - delta / BATTERY_SECONDS * drain)
		battery_changed.emit(battery)
	var energy := 0.0
	if flashlight_on:
		energy = 3.0
		if battery <= 0.0:
			# Never fully dark: a weak, unreliable beam keeps navigation possible.
			energy = 0.4
		elif battery < 0.15:
			_flicker_timer -= delta
			if _flicker_timer <= 0.0:
				_flicker_timer = _rng.randf_range(0.05, 0.6)
				energy = 3.0 * (_rng.randf_range(0.2, 0.7) if _rng.randf() < 0.4 else 1.0)
			else:
				energy = flashlight.light_energy
	var near_enemy := _enemy_proximity()
	if flashlight_on and near_enemy > 0.0 and not Settings.b("reduced_flashing") and _rng.randf() < near_enemy * 0.15:
		energy *= _rng.randf_range(0.1, 0.6)
	flashlight.visible = flashlight_on
	flashlight.light_energy = lerpf(flashlight.light_energy, energy, clampf(delta * 25.0, 0.0, 1.0))
	viewmodel.set_lens_glow(flashlight.light_energy / 3.0 if flashlight_on else 0.0)


func _enemy_proximity() -> float:
	if match_ctrl == null:
		return 0.0
	var best := 0.0
	for e in match_ctrl.enemies:
		if is_instance_valid(e):
			var d := (e as Node3D).global_position.distance_to(global_position)
			best = maxf(best, clampf(1.0 - d / 8.0, 0.0, 1.0))
	return best


func recharge_flashlight() -> void:
	battery = 1.0
	battery_changed.emit(battery)
	AudioService.play_2d("battery_insert", AudioService.BUS_SFX, -4.0)
	viewmodel.play_use()


func _report(delta: float) -> void:
	if match_ctrl == null:
		return
	_report_timer -= delta
	if match_ctrl.is_authority:
		match_ctrl.report_motion(player_id, global_position, _yaw, Vector2(velocity.x, velocity.z).length(),
			crouching, sprinting, flashlight_on and battery > 0.0)
	elif _report_timer <= 0.0 and match_ctrl.net:
		_report_timer = 0.05
		match_ctrl.net.call("send_motion", global_position, _yaw, Vector2(velocity.x, velocity.z).length(),
			crouching, sprinting, flashlight_on and battery > 0.0)


# --- Interaction -------------------------------------------------------------------

func _tick_interaction(delta: float) -> void:
	var ent: Interactable = null
	var sub := 0
	if hidden_spot:
		ent = hidden_spot.spot
	elif input_enabled:
		_ray.force_raycast_update()
		if _ray.is_colliding():
			var col := _ray.get_collider()
			if col and col.has_meta("interactable"):
				var candidate: Variant = col.get_meta("interactable")
				if candidate is Interactable and is_instance_valid(candidate):
					ent = candidate
					sub = int(col.get_meta("sub", 0))
	var prompt := ent.get_prompt(player_id, sub) if ent else ""
	if ent != _focus or sub != _focus_sub or prompt != _focus_prompt:
		_focus = ent
		_focus_sub = sub
		_focus_prompt = prompt
		_hold = 0.0
		_hold_consumed = false
		focus_changed.emit(prompt, ent, sub)
	if _focus == null or not input_enabled or prompt.is_empty():
		_set_hold(0.0)
		return
	_hold_target = _focus.get_hold_time(player_id, _focus_sub)
	if _wants_interact():
		if _hold_consumed:
			return
		_hold += delta
		if _hold_target <= 0.0 or _hold >= _hold_target:
			_hold_consumed = true
			_set_hold(0.0)
			_activate(_focus, _focus_sub)
		else:
			_set_hold(_hold / _hold_target)
	else:
		_hold = 0.0
		_hold_consumed = false
		_set_hold(0.0)


func _set_hold(v: float) -> void:
	hold_progress_changed.emit(v)


func _activate(ent: Interactable, sub: int) -> void:
	viewmodel.play_reach()
	if ent.client_intercept(player_id, sub):
		return
	if ent is PickupEntity:
		viewmodel.play_pickup()
	var args := {}
	if ent is GarageMotor and (ent as GarageMotor).is_crank_ready():
		args = (ent as GarageMotor).crank_args()
	match_ctrl.request_interact(ent.entity_id, sub, "use", args)


## Re-evaluates the prompt (e.g. after inventory changes).
func refresh_focus() -> void:
	_focus_prompt = "\u0000"


# --- Hiding ---------------------------------------------------------------------------

func set_hidden_in(spot: Interactable) -> void:
	if spot is HidingSpot:
		var info := HiddenInfo.new()
		info.spot = spot
		info.saved_transform = global_transform
		info.base_yaw = spot.global_rotation.y + PI
		hidden_spot = info
		_yaw = info.base_yaw
		_pitch = 0.0
		collision_layer = 0
		velocity = Vector3.ZERO
		crouching = false
		viewmodel.visible = false
		flashlight_on = false
		AudioService.set_muffled(true)
		hiding_changed.emit(true)
	elif hidden_spot:
		var exit := hidden_spot.spot.exit_position()
		hidden_spot = null
		global_position = exit
		collision_layer = LAYER_PLAYER
		head.rotation = Vector3(_pitch, _yaw, 0)
		viewmodel.visible = true
		AudioService.set_muffled(false)
		hiding_changed.emit(false)


func _update_hidden_camera(delta: float) -> void:
	var view := hidden_spot.spot.view_transform()
	global_position = global_position.lerp(view.origin - Vector3(0, EYE_STAND, 0), clampf(delta * 8.0, 0.0, 1.0))
	head.position = head.position.lerp(Vector3(0, EYE_STAND, 0), clampf(delta * 8.0, 0.0, 1.0))
	head.rotation = Vector3(_pitch, _yaw, 0)


func is_hidden() -> bool:
	return hidden_spot != null


# --- Damage / death ----------------------------------------------------------------------

func on_damaged(hits: int) -> void:
	_shake = 1.0
	_stumble = 1.4
	AudioService.play_2d("player_hurt", AudioService.BUS_SFX, -2.0)
	_vibrate(0.8)
	damaged.emit(hits)


func on_shocked() -> void:
	_shake = 0.6
	_vibrate(0.5)


func on_died() -> void:
	if dead:
		return
	dead = true
	input_enabled = false
	viewmodel.visible = false
	flashlight_on = false
	var t := create_tween()
	t.tween_property(head, "rotation:z", deg_to_rad(70), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	died.emit()


func on_escaped() -> void:
	escaped = true
	input_enabled = false


func _vibrate(strength: float) -> void:
	var k := Settings.f("haptics") * strength
	if k <= 0.01:
		return
	if AppInfo.is_mobile():
		Input.vibrate_handheld(int(160 * k), clampf(k, 0.0, 1.0))
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, 0.3 * k, 0.8 * k, 0.35)


func yaw() -> float:
	return _yaw
