class_name MapBase
extends Node3D
## Shared level infrastructure. A map script extends this, builds geometry and
## entities in `build_level()`, and places seeded content in `apply_variant()`.

const WATCHER_SCRIPT := "res://scripts/ai/watcher.gd"
const PLAYER_SCRIPT := "res://scripts/player/player_controller.gd"
const MIN_ENEMY_SPAWN_DISTANCE := 12.0
const NAV_SOURCE_GROUP := &"nav_source"

var definition: MapDefinition
var match_ctrl: MatchController
var builder: GeoBuilder
var nav_region: NavigationRegion3D
var entities_root: Node3D
var players_root: Node3D
var enemies_root: Node3D
var lights_root: Node3D
var world_env: WorldEnvironment
var environment: Environment
## spawn point id -> {"xform": Transform3D, "drawer": String}
var spawn_points: Dictionary = {}
var player_spawns: Array[Transform3D] = []
var enemy_spawns: Array[Transform3D] = []
var patrol_points: Array[Vector3] = []
var prowl_points: Array[Vector3] = []
## room id -> {"aabb": AABB, "surface": String}
var rooms: Dictionary = {}
var lamps: Array[FlickerLight] = []
var power_on := false
var _particles: Array[GPUParticles3D] = []
var _rebake_queued := false


func _init() -> void:
	name = "Level"


## Creates the standard node layout. Call first from build_level().
func prepare() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = GeoBuilder.LAYER_WORLD | GeoBuilder.LAYER_PROP
	# Level geometry and entities (hiding-spot cabinets, locked door panels)
	# both shape the mesh; entities used to be left out, so paths ran
	# straight through lockers and the enemy walked into them.
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = NAV_SOURCE_GROUP
	nm.cell_size = 0.1
	nm.cell_height = 0.1
	# Whole numbers of cells (the baker rounds anything else): 4 cells = 0.4 m
	# radius (the enemy capsule is 0.38; 0.5 sealed 1.1 m doorways and the
	# gaps beside furniture), 3 cells = 0.3 m climb. The epsilon keeps float
	# division from flooring 3 cells to 2.
	nm.agent_radius = 4 * nm.cell_size
	nm.agent_height = 19 * nm.cell_height
	nm.agent_max_climb = 3 * nm.cell_height + 0.000001
	nm.agent_max_slope = 42.0
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	builder = GeoBuilder.new(nav_region)
	lights_root = _child("Lights")
	entities_root = _child("Entities")
	nav_region.add_to_group(NAV_SOURCE_GROUP)
	entities_root.add_to_group(NAV_SOURCE_GROUP)
	players_root = _child("Players")
	enemies_root = _child("Enemies")
	world_env = WorldEnvironment.new()
	world_env.name = "Environment"
	add_child(world_env)


func _child(child_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = child_name
	add_child(n)
	return n


# --- Overridable hooks -------------------------------------------------------------


func build_level() -> void:
	prepare()


func apply_variant(_match: MatchController, _variant: Dictionary) -> void:
	pass


func authority_tick(_match: MatchController, _delta: float) -> void:
	pass


## Multiplier for noise heard at `pos` (1 = normal). Maps with loud moving
## sources (trains) lower it nearby; `kind` lets a map exempt its own sources.
func noise_mask(_pos: Vector3, _kind: String) -> float:
	return 1.0


## Presentation of a match flag on every peer (lights, monitors, arrivals).
func on_flag(_match: MatchController, _flag: String) -> void:
	pass


# --- Construction helpers -------------------------------------------------------------


func add_room(id: String, aabb: AABB, surface: String) -> void:
	rooms[id] = {"aabb": aabb, "surface": surface}


func add_entity(ent: Interactable, xform: Transform3D) -> Interactable:
	ent.transform = xform
	entities_root.add_child(ent)
	match_ctrl.register_entity(ent)
	return ent


func add_lamp(
	pos: Vector3,
	room: String,
	energy: float = 1.2,
	color: Color = Color(1.0, 0.8, 0.58),
	needs_power: bool = true,
	shadows: bool = false,
	light_range: float = 6.5
) -> FlickerLight:
	var lamp := FlickerLight.new()
	lamp.position = pos
	lamp.room = room
	lamp.energy = energy
	lamp.color = color
	lamp.needs_power = needs_power
	lamp.cast_shadows = shadows
	lamp.light_range = light_range
	lights_root.add_child(lamp)
	lamps.append(lamp)
	return lamp


## Cold light leaking through window boards. Disabled on low light quality.
func add_moonlight(pos: Vector3, target: Vector3, energy: float = 1.6) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.light_color = Color(0.55, 0.65, 0.9)
	s.light_energy = energy
	s.spot_range = 9.0
	s.spot_angle = 32.0
	s.spot_attenuation = 1.2
	s.light_specular = 0.1
	s.set_meta("moonlight", true)
	lights_root.add_child(s)
	s.look_at_from_position(pos, target, Vector3.UP)
	return s


func add_dust(aabb: AABB, amount: int = 60) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.visibility_aabb = AABB(-aabb.size * 0.5, aabb.size)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = aabb.size * 0.5
	mat.gravity = Vector3(0, -0.005, 0)
	mat.direction = Vector3(1, 0.2, 0.3)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.01
	mat.initial_velocity_max = 0.05
	mat.turbulence_enabled = false
	mat.scale_min = 0.6
	mat.scale_max = 1.4
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.012)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.albedo_color = Color(0.9, 0.85, 0.75, 0.35)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = qm
	p.draw_pass_1 = quad
	p.position = aabb.get_center()
	lights_root.add_child(p)
	_particles.append(p)
	_apply_particles()


func configure_environment(ambient: Color, ambient_energy: float, fog_color: Color, fog_density: float) -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.005, 0.006, 0.01)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = ambient
	environment.ambient_light_energy = ambient_energy
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	environment.fog_enabled = true
	environment.fog_light_color = fog_color
	environment.fog_density = fog_density
	environment.fog_sky_affect = 0.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 1.2
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.78
	environment.adjustment_contrast = 1.06
	world_env.environment = environment
	apply_graphics_settings()
	if not Settings.changed.is_connected(_on_setting):
		Settings.changed.connect(_on_setting)


func _on_setting(_key: String, _v: Variant) -> void:
	apply_graphics_settings()


func apply_graphics_settings() -> void:
	if environment:
		environment.tonemap_exposure = Settings.f("exposure")
		environment.glow_enabled = Settings.b("glow")
		environment.fog_density = 0.035 if Settings.s("draw_distance") == "near" else 0.022
	var high_lights := Settings.s("light_quality") == "high"
	for child in lights_root.get_children():
		if child is SpotLight3D and child.has_meta("moonlight"):
			child.visible = high_lights or Settings.s("quality_preset") != "low"
			(child as SpotLight3D).shadow_enabled = high_lights and Settings.s("shadows") != "off"
	_apply_particles()


func _apply_particles() -> void:
	var mode := Settings.s("particles")
	for p in _particles:
		p.emitting = mode != "off"
		p.visible = mode != "off"
		p.amount_ratio = 1.0 if mode == "high" else 0.4


## Finalizes geometry and bakes navigation synchronously.
func finalize() -> void:
	builder.commit()
	nav_region.bake_navigation_mesh(false)
	_dress.call_deferred()


## Decals go in once the level's colliders are in the physics world.
func _dress() -> void:
	if not is_inside_tree():
		await tree_entered
	for i in 2:
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	var id := String(definition.id) if definition else String(name)
	DecalScatter.scatter(self, hash(id), id == "tutorial")


## Re-bakes navigation (e.g. after a locked door opens). Runs on a thread.
func rebake_navigation() -> void:
	# Doors unlocked while a bake runs share one follow-up bake (each used to
	# start its own the moment the first finished; all but one were dropped
	# and the enemy's paths kept treating those doors as walls).
	if nav_region.is_baking():
		if _rebake_queued:
			return
		_rebake_queued = true
		await nav_region.bake_finished
		_rebake_queued = false
	nav_region.bake_navigation_mesh(true)


# --- Queries -------------------------------------------------------------------------------


func room_at(pos: Vector3) -> String:
	for id in rooms:
		var aabb: AABB = rooms[id]["aabb"]
		if aabb.grow(0.05).has_point(pos + Vector3(0, 0.1, 0)):
			return id
	return ""


func surface_at(pos: Vector3) -> String:
	var r := room_at(pos)
	return str(rooms[r]["surface"]) if not r.is_empty() else "concrete"


## True if a powered lamp lights the room containing `pos`.
func is_lit_at(pos: Vector3) -> bool:
	var r := room_at(pos)
	if r.is_empty():
		return false
	for lamp in lamps:
		if lamp.room == r and lamp.is_on():
			return true
	return false


func set_power(on: bool) -> void:
	power_on = on
	for lamp in lamps:
		lamp.set_powered(on)


func closest_nav_point(pos: Vector3) -> Vector3:
	var map_rid := nav_region.get_navigation_map()
	if not map_rid.is_valid() or NavigationServer3D.map_get_iteration_id(map_rid) == 0:
		return pos
	var p := NavigationServer3D.map_get_closest_point(map_rid, pos)
	# Map iterations are asynchronous; an unsynced map answers (0,0,0).
	if p == Vector3.ZERO and pos.length() > 1.0:
		return pos
	if p.y - pos.y > 0.45:
		# Snapped onto a furniture top (a small unreachable island): prefer the
		# floor around the point instead.
		for r: float in [0.7, 1.2, 1.8]:
			for k in 8:
				var a := TAU * k / 8.0
				var q := NavigationServer3D.map_get_closest_point(map_rid, pos + Vector3(cos(a) * r, 0, sin(a) * r))
				if absf(q.y - pos.y) < 0.45:
					return q
	return p


func navigation_ready() -> bool:
	var map_rid := nav_region.get_navigation_map()
	if not map_rid.is_valid() or NavigationServer3D.map_get_iteration_id(map_rid) == 0 or player_spawns.is_empty():
		return false
	var probe := player_spawns[0].origin
	return NavigationServer3D.map_get_closest_point(map_rid, probe).distance_to(probe) < 2.0


func wait_for_navigation(max_frames: int = 240) -> void:
	for i in max_frames:
		if navigation_ready():
			return
		await get_tree().physics_frame


## A point outside the house near `target`, for prowling sounds before the enemy arrives.
func prowl_point(target: Vector3, rng: RandomNumberGenerator) -> Vector3:
	if prowl_points.is_empty():
		return target + Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))
	var best := prowl_points[0]
	var best_d := INF
	for p in prowl_points:
		var d := p.distance_to(target) + rng.randf_range(0.0, 6.0)
		if d < best_d:
			best_d = d
			best = p
	return best


## Spawns the enemy at a valid point far from (and out of sight of) every player.
func spawn_enemy(mc: MatchController, _rng: RandomNumberGenerator) -> Node:
	var candidates: Array[Transform3D] = enemy_spawns.duplicate()
	candidates.shuffle()
	for xf in candidates:
		if _spawn_is_safe(mc, xf.origin):
			var script: Script = load(WATCHER_SCRIPT)
			var enemy: Node3D = script.new()
			enemies_root.add_child(enemy)
			enemy.global_transform = xf
			enemy.call("setup", mc, self)
			return enemy
	return null


func _spawn_is_safe(mc: MatchController, pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for pid in mc.state.players:
		var p: Dictionary = mc.state.players[pid]
		if p["status"] != MatchState.STATUS_ALIVE:
			continue
		var ppos := MatchState.array_to_vec(p["pos"])
		if ppos.distance_to(pos) < MIN_ENEMY_SPAWN_DISTANCE:
			return false
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 1.6, 0), ppos + Vector3(0, 1.4, 0), 1 | 16)
		if space.intersect_ray(q).is_empty():
			return false
	return true


## Spawn point metadata: id -> {"xform": Transform3D, "drawer": entity id or ""}
func add_spawn_point(id: String, xform: Transform3D, drawer: String = "") -> void:
	spawn_points[id] = {"xform": xform, "drawer": drawer}


func spawn_pickup(mc: MatchController, id: String, item: String, spawn_id: String) -> void:
	var sp: Dictionary = spawn_points.get(spawn_id, {})
	if sp.is_empty():
		Log.error("map", "Unknown spawn point", {"spawn": spawn_id})
		return
	var pickup := PickupEntity.new()
	pickup.entity_id = id
	pickup.item_id = item
	var drawer_id := str(sp.get("drawer", ""))
	var drawer: DrawerEntity = mc.entities.get(drawer_id) as DrawerEntity
	if drawer:
		pickup.transform = sp["xform"]
		drawer.tray.add_child(pickup)
		mc.register_entity(pickup)
	else:
		add_entity(pickup, sp["xform"])
	if mc.state.entities.has(id):
		pickup.apply_state(mc.state.entities[id])


## Authority helper for apply_variant(): records a seeded pickup.
func place_pickup_state(mc: MatchController, id: String, item: String, spawn_id: String) -> void:
	if not mc.state.entities.has(id):
		mc.state.entities[id] = {"kind": "pickup", "item": item, "spawn": spawn_id, "taken": false}


## Authority helper: sets public state for an entity unless restored from a snapshot.
func seed_state(mc: MatchController, id: String, value: Dictionary) -> void:
	if not mc.state.entities.has(id):
		mc.state.entities[id] = value


func spawn_dropped_item(mc: MatchController, id: String, item: String, pos: Vector3) -> void:
	var pickup := PickupEntity.new()
	pickup.entity_id = id
	pickup.item_id = item
	pickup.dropped = true
	add_entity(pickup, Transform3D(Basis.IDENTITY, pos))
	if not mc.state.entities.has(id):
		mc.state.entities[id] = {"kind": "dropped", "item": item, "pos": MatchState.vec_to_array(pos), "taken": false}
	pickup.apply_state(mc.state.entities[id])


## Finds a floor point in front of the player that is not inside geometry.
func safe_drop_position(player_pos: Vector3, yaw: float) -> Vector3:
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var space := get_world_3d().direct_space_state
	# Furniture counts too: an item used to drop inside a counter, out of sight.
	var solid := GeoBuilder.LAYER_WORLD | GeoBuilder.LAYER_PROP
	for dist: float in [0.8, 0.5, 0.0]:
		var p := player_pos + forward * dist + Vector3(0, 1.0, 0)
		var q := PhysicsRayQueryParameters3D.create(player_pos + Vector3(0, 1.0, 0), p, solid | DoorEntity.LAYER_DOOR)
		if dist > 0.0 and not space.intersect_ray(q).is_empty():
			continue
		var down := PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -3.0, 0), solid)
		var hit := space.intersect_ray(down)
		if not hit.is_empty():
			return hit["position"] + Vector3(0, 0.02, 0)
	return player_pos + Vector3(0, 0.02, 0)


## A player fits here: floor just below, no wall or furniture in the way.
## Physics only, so it works right after the level is built (before the
## navigation mesh is ready).
func _standable(p: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var space := get_world_3d().direct_space_state
	var solid := GeoBuilder.LAYER_WORLD | GeoBuilder.LAYER_PROP
	var down := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p + Vector3(0, -0.4, 0), solid)
	if space.intersect_ray(down).is_empty():
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	q.shape = cap
	q.transform = Transform3D(Basis(), p + Vector3(0, 0.95, 0))
	q.collision_mask = solid
	return space.intersect_shape(q, 1).is_empty()


func player_spawn(index: int) -> Transform3D:
	if player_spawns.is_empty():
		return Transform3D.IDENTITY
	var n := player_spawns.size()
	if index < n:
		return player_spawns[index]
	# More players than spawn points (up to 10): the nearest free spot around
	# a shared spawn point, on walkable floor and apart from everyone else.
	var taken: Array[Vector3] = []
	for k in index:
		taken.append(player_spawn(k).origin)
	var t: Transform3D = player_spawns[index % n]
	for radius: float in [0.8, 1.2, 1.6, 2.0]:
		for step in 8:
			var a := TAU * step / 8.0
			var p := t.origin + (t.basis.x * cos(a) + t.basis.z * sin(a)) * radius
			if not _standable(p):
				continue
			var free := true
			for q in taken:
				free = free and p.distance_to(q) > 0.6
			if free:
				return Transform3D(t.basis, p)
	return t
