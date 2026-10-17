class_name FlickerLight
extends Node3D
## A practical lamp: emissive bulb + OmniLight3D. Flickers subtly on its own
## and strongly when the Watcher is near (the enemy's established warning cue).
## "Reduced flashing" replaces hard flicker with slow dimming.

const NEAR_ENEMY := 9.0

@export var color := Color(1.0, 0.82, 0.6)
@export var energy := 1.2
@export var light_range := 6.5
@export var room := ""
## Lamps that need mains power stay dark until power is restored.
@export var needs_power := true
@export var cast_shadows := false

var light: OmniLight3D
var bulb_mat: StandardMaterial3D
var powered := false
var switched_on := true
var enemy_proximity := 0.0
var _flicker := 1.0
var _timer := 0.0
## Scare: seconds left of a forced blackout (presentation only).
var _blackout := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	light = OmniLight3D.new()
	light.light_color = color
	light.omni_range = light_range
	light.omni_attenuation = 1.4
	light.light_energy = energy
	light.shadow_enabled = false
	light.light_specular = 0.3
	add_child(light)
	bulb_mat = MaterialLib.glow(color, 3.0)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	sphere.radial_segments = 10
	sphere.rings = 5
	bulb.mesh = sphere
	bulb.material_override = bulb_mat
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bulb)
	apply_quality()
	Settings.changed.connect(_on_setting)
	_refresh()


func _on_setting(key: String, _v: Variant) -> void:
	if key in ["shadows", "light_quality"]:
		apply_quality()


func apply_quality() -> void:
	if light == null:
		return
	light.shadow_enabled = cast_shadows and Settings.s("shadows") == "high" and Settings.s("light_quality") == "high"


func is_on() -> bool:
	return (powered or not needs_power) and switched_on


func set_powered(on: bool) -> void:
	powered = on
	_refresh()


func set_switched(on: bool) -> void:
	switched_on = on
	_refresh()


func _refresh() -> void:
	if light == null:
		return
	var on := is_on()
	visible = true
	light.visible = on
	bulb_mat.emission_energy_multiplier = 3.0 if on else 0.0
	bulb_mat.albedo_color = color if on else Color(0.15, 0.14, 0.12)


## The bulb dies for a while, with a violent stutter first.
func scare_blackout(seconds: float) -> void:
	_blackout = seconds


func _process(delta: float) -> void:
	if not is_on():
		return
	if _blackout > 0.0:
		_blackout -= delta
		var dying := _blackout > 0.0 and _rng.randf() < 0.1 and not Settings.b("reduced_flashing")
		light.light_energy = energy * (0.8 if dying else 0.0)
		bulb_mat.emission_energy_multiplier = 2.0 if dying else 0.0
		return
	_timer -= delta
	var reduced := Settings.b("reduced_flashing")
	if _timer <= 0.0:
		var chaos := clampf(enemy_proximity, 0.0, 1.0)
		if reduced:
			_timer = 0.25
			_flicker = lerpf(1.0, 0.35, chaos)
		elif _rng.randf() < 0.02 + chaos * 0.5:
			_flicker = _rng.randf_range(0.0, 0.5)
			_timer = _rng.randf_range(0.03, 0.12)
		else:
			_flicker = _rng.randf_range(0.9, 1.0) * (1.0 - chaos * 0.35)
			_timer = _rng.randf_range(0.08, 0.4)
	var k := light.light_energy / maxf(energy, 0.001)
	k = lerpf(k, _flicker, clampf(delta * (6.0 if reduced else 30.0), 0.0, 1.0))
	light.light_energy = energy * k
	bulb_mat.emission_energy_multiplier = 3.0 * k
