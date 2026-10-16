class_name Interactable
extends Node3D
## Base for every world entity players can interact with.
##
## Rules: `authority_interact()` runs only on the authority (solo process or
## dedicated server) and may only change the world through MatchController.
## `apply_state()` is presentation and must be idempotent: it can be called
## repeatedly with the same state (snapshots, reconnects, checkpoints).

const LAYER_INTERACT := 1 << 3

## Stable id shared by rules, saves and network messages.
@export var entity_id := ""
@export var prompt_key := "PROMPT_USE"
## Seconds the interact button must be held. 0 = instant.
@export var hold_time := 0.0
@export var interact_range := 2.3

var match_ctrl: MatchController
var state: Dictionary = {}


## Default state for a fresh match. Override.
func initial_state() -> Dictionary:
	return {}


## Presentation update. Override.
func apply_state(new_state: Dictionary) -> void:
	state = new_state


## Translated prompt for the focused player, or "" to hide the prompt.
func get_prompt(_player_id: int, _sub: int) -> String:
	return tr(prompt_key)


## Hold time for a given sub-target (fuse socket, ...).
func get_hold_time(_player_id: int, _sub: int) -> float:
	return hold_time


## Whether the interaction is currently possible (client-side UX only; the
## authority re-validates).
func can_interact(_player_id: int, _sub: int) -> bool:
	return true


## Client-side hook before sending a request (e.g. open the keypad UI instead).
## Return true if the client handled it locally without contacting the authority.
func client_intercept(_player_id: int, _sub: int) -> bool:
	return false


## Authority logic. `ctx` keys: player_id, sub, action, args.
func authority_interact(_ctx: Dictionary) -> void:
	pass


## World position used for range validation.
func interact_origin() -> Vector3:
	return global_position


## Whether the authority requires an unobstructed line from the player's eye.
func requires_line_of_sight() -> bool:
	return true


## RIDs of this entity's own physics bodies (excluded from LOS checks).
func collision_rids() -> Array[RID]:
	var out: Array[RID] = []
	_collect_rids(self, out)
	return out


func _collect_rids(n: Node, out: Array[RID]) -> void:
	if n is CollisionObject3D:
		out.append((n as CollisionObject3D).get_rid())
	for c in n.get_children():
		_collect_rids(c, out)


## Creates a raycast target box. `sub` lets one entity expose several targets.
func add_target(size: Vector3, offset: Vector3 = Vector3.ZERO, sub: int = 0, parent: Node3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Target%d" % sub
	body.collision_layer = LAYER_INTERACT
	body.collision_mask = 0
	body.set_meta("interactable", self)
	body.set_meta("sub", sub)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = offset
	(parent if parent else self).add_child(body)
	return body


## Convenience: mesh child with a material.
func add_mesh(mesh: Mesh, material: Material, xform: Transform3D = Transform3D.IDENTITY, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = xform
	(parent if parent else self).add_child(mi)
	return mi


static func box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## Plays a positional sound for everyone. Only the authority should call
## this from gameplay logic; MatchController replicates it to clients once.
func world_sound(sound: String, volume_db: float = 0.0, max_distance: float = 25.0) -> void:
	if match_ctrl:
		match_ctrl.world_sound(sound, interact_origin(), volume_db, max_distance)
