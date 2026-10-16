class_name MenuDiorama
extends Node3D
## Main menu backdrop: a short hallway with one failing bulb. A tall figure
## stands in the far doorway and is only legible when the bulb stutters.
## Reduced motion: static camera. Reduced flashing: slow dimming instead.

var _camera: Camera3D
var _lamp: FlickerLight
var _figure: WatcherRig
var _t := 0.0
var _cam_base := Vector3(1.6, 1.55, 6.4)


func _ready() -> void:
	var b := GeoBuilder.new(self)
	b.room = "menu"
	b.floor_rect(0, 0, 3.2, 10, 0.0, "wood_floor")
	b.ceiling_rect(0, 0, 3.2, 10, 2.8, "ceiling")
	b.wall_z(0, 0, 10, 0, 2.8, "exterior", "wallpaper")
	b.wall_z(3.2, 0, 10, 0, 2.8, "wallpaper", "exterior", [{"from": 3.0, "to": 4.1, "top": 2.15}])
	b.wall_x(0, 0, 3.2, 0, 2.8, "exterior", "wallpaper", [{"from": 1.0, "to": 2.2, "top": 2.2}])
	b.wall_x(10, 0, 3.2, 0, 2.8, "wallpaper", "exterior")
	b.box(Vector3(1.6, 1.1, -1.2), Vector3(3.2, 2.2, 0.1), "exterior", false)
	PropFactory.rng.seed = 7
	PropFactory.cabinet(b, Vector3(0.3, 0, 5.0), 90, 1.0, 0.85, 0.4)
	PropFactory.picture(b, Vector3(0.09, 1.65, 3.0), 90, 0.5, 0.7, -5.0)
	PropFactory.picture(b, Vector3(3.11, 1.6, 6.5), -90, 0.6, 0.45, 3.0)
	PropFactory.chair(b, Vector3(2.5, 0, 7.5), 200, true)
	PropFactory.debris(b, Vector3(1.6, 0, 5), 1.2, 8)
	PropFactory.radiator(b, Vector3(0.12, 0, 7.6), 90, 0.9)
	b.commit()
	var sign_label := Label3D.new()
	sign_label.text = "METHOD"
	sign_label.font_size = 64
	sign_label.pixel_size = 0.004
	sign_label.modulate = Color(0.6, 0.08, 0.06)
	sign_label.shaded = true
	sign_label.position = Vector3(3.15, 2.05, 4.6)
	sign_label.rotation.y = -PI / 2
	add_child(sign_label)
	_lamp = FlickerLight.new()
	_lamp.needs_power = false
	_lamp.energy = 1.4
	_lamp.light_range = 7.0
	_lamp.position = Vector3(1.6, 2.3, 4.2)
	add_child(_lamp)
	var emergency := OmniLight3D.new()
	emergency.light_color = Color(0.9, 0.12, 0.08)
	emergency.light_energy = 0.6
	emergency.omni_range = 4.0
	emergency.position = Vector3(1.6, 2.4, 0.6)
	add_child(emergency)
	_figure = WatcherRig.new()
	_figure.position = Vector3(1.6, 0, -0.55)
	add_child(_figure)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.18, 0.2, 0.26)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.fog_enabled = true
	e.fog_light_color = Color(0.02, 0.02, 0.03)
	e.fog_density = 0.06
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.adjustment_enabled = true
	e.adjustment_saturation = 0.75
	env.environment = e
	add_child(env)
	_camera = Camera3D.new()
	_camera.fov = 62
	_camera.current = true
	_camera.position = _cam_base
	add_child(_camera)
	_camera.look_at(Vector3(1.6, 1.3, 0.0))


func _process(delta: float) -> void:
	_t += delta
	if not Settings.motion_reduced():
		_camera.position = _cam_base + Vector3(sin(_t * 0.13) * 0.25, sin(_t * 0.21) * 0.05, sin(_t * 0.09) * 0.4)
		_camera.look_at(Vector3(1.6 + sin(_t * 0.1) * 0.15, 1.3, 0.0))
	# The figure is only readable when the bulb dips.
	_lamp.enemy_proximity = 0.35 + 0.25 * sin(_t * 0.5)
	_figure.set_lens_intensity(clampf(1.0 - _lamp.light.light_energy / maxf(_lamp.energy, 0.01), 0.0, 1.0))
