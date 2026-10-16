class_name DynamicResolution
extends Node
## Optional bounded dynamic 3D resolution. Lowers the internal render scale
## when frames run long, never below 60% of the user's chosen scale and never
## above it. UI stays at native resolution because only 3D is scaled.

const MIN_FACTOR := 0.6
const ADJUST_INTERVAL := 0.5

var active_in_gameplay := false
var _avg_ms := 16.0
var _timer := 0.0
var _factor := 1.0


func _process(delta: float) -> void:
	if not active_in_gameplay or not Settings.b("dynamic_resolution"):
		if _factor != 1.0:
			_factor = 1.0
			_apply()
		return
	_avg_ms = lerpf(_avg_ms, delta * 1000.0, 0.08)
	_timer += delta
	if _timer < ADJUST_INTERVAL:
		return
	_timer = 0.0
	var cap := Settings.effective_frame_cap()
	var target_ms := 1000.0 / float(cap if cap > 0 else 60)
	if _avg_ms > target_ms * 1.12:
		_factor = maxf(MIN_FACTOR, _factor - 0.05)
		_apply()
	elif _avg_ms < target_ms * 0.8 and _factor < 1.0:
		_factor = minf(1.0, _factor + 0.025)
		_apply()


func _apply() -> void:
	get_tree().root.scaling_3d_scale = Settings.effective_render_scale() * _factor


func current_factor() -> float:
	return _factor
