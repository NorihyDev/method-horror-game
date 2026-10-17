extends SceneTree
## Renders procedural decal textures (RGBA, 256 px) into
## res://assets/generated/decals: blood splatters, a drag smear, bloody
## handprints, drips running down a wall, claw scratches, tally marks and
## water stains. MapBase scatters them through the rooms.
## Usage: godot --headless --path game --script res://tools/generate_decals.gd

const OUT := "res://assets/generated/decals"
const SIZE := 256
const BLOOD := Color(0.24, 0.015, 0.012)
const OLD_BLOOD := Color(0.13, 0.03, 0.02)
const GRIME := Color(0.07, 0.06, 0.045)

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_noise.frequency = 0.035
	_noise.fractal_octaves = 4
	for i in 3:
		_save(_splatter(100 + i, BLOOD if i < 2 else OLD_BLOOD), "blood_splat_%d" % (i + 1))
	_save(_smear(), "blood_smear")
	_save(_handprints(), "handprints")
	_save(_drips(), "blood_drips")
	_save(_scratches(), "scratches")
	_save(_tally(), "tally_marks")
	_save(_stain(301), "water_stain")
	_save(_stain(302), "grime")
	print("Decals generated")
	quit(0)


func _save(img: Image, base: String) -> void:
	img.save_png("%s/%s.png" % [OUT, base])
	print("  " + base)


func _blank() -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Adds `a` alpha of colour `c` at (x, y), keeping the strongest coverage.
static func _ink(img: Image, x: int, y: int, c: Color, a: float) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE or a <= 0.0:
		return
	var old := img.get_pixel(x, y)
	if a > old.a:
		img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0)))


func _blob(img: Image, cx: float, cy: float, r: float, c: Color, ragged: float) -> void:
	for y in range(int(cy - r * 1.6), int(cy + r * 1.6) + 1):
		for x in range(int(cx - r * 1.6), int(cx + r * 1.6) + 1):
			var d := Vector2(x - cx, y - cy).length()
			var edge := r * (1.0 + ragged * _noise.get_noise_2d(x * 3.0, y * 3.0))
			if d < edge:
				# Pooled blood is darker and thicker in the middle.
				var depth := clampf(1.0 - d / maxf(edge, 0.001), 0.0, 1.0)
				_ink(img, x, y, c.darkened(0.35 * depth), 0.75 + 0.25 * smoothstep(0.0, 0.3, depth))


func _splatter(seed_value: int, c: Color) -> Image:
	_rng.seed = seed_value
	_noise.seed = seed_value
	var img := _blank()
	var mid := Vector2(SIZE, SIZE) * 0.5
	_blob(img, mid.x, mid.y, _rng.randf_range(26, 38), c, 0.45)
	for i in 34:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(30, 115) * (1.0 if _rng.randf() < 0.7 else 0.6)
		var p := mid + Vector2.from_angle(ang) * dist
		_blob(img, p.x, p.y, _rng.randf_range(1.5, 7.0) * (1.0 - dist / 160.0), c, 0.3)
		# Streaks pointing outward from the impact.
		if _rng.randf() < 0.35:
			for k in int(dist * 0.25):
				var q := mid + Vector2.from_angle(ang) * (dist - k * 1.2)
				_ink(img, int(q.x), int(q.y), c, 0.6 * (1.0 - float(k) / (dist * 0.25)))
	return img


func _smear() -> Image:
	_rng.seed = 200
	_noise.seed = 200
	var img := _blank()
	# Something heavy dragged from left to right, fading out.
	for x in range(10, SIZE - 10):
		var t := float(x) / SIZE
		var width := lerpf(44.0, 14.0, t) * (1.0 + 0.25 * _noise.get_noise_1d(x * 4.0))
		var cy := SIZE * 0.5 + 18.0 * _noise.get_noise_1d(x * 0.8)
		for y in range(int(cy - width), int(cy + width)):
			var across := absf(y - cy) / width
			var streak := 0.5 + 0.5 * _noise.get_noise_2d(x * 0.6, y * 9.0)
			_ink(
				img,
				x,
				y,
				BLOOD.darkened(0.2 * streak),
				minf(1.0, 1.4 * (1.0 - t * 0.7) * (1.0 - across * across) * (0.6 + 0.4 * streak))
			)
	return img


func _hand(img: Image, at: Vector2, angle: float, scale: float, alpha: float) -> void:
	var rot := func(p: Vector2) -> Vector2: return at + p.rotated(angle) * scale
	var palm: Vector2 = rot.call(Vector2.ZERO)
	_blob(img, palm.x, palm.y, 15.0 * scale, Color(BLOOD, 1.0), 0.15)
	var fingers := [Vector2(-12, -26), Vector2(-4, -31), Vector2(5, -30), Vector2(13, -24), Vector2(20, -2)]
	var lengths := [11.0, 13.0, 12.0, 9.0, 10.0]
	for i in fingers.size():
		var base: Vector2 = fingers[i] * 0.62
		var tip: Vector2 = fingers[i]
		for k in 8:
			var p: Vector2 = rot.call(base.lerp(tip, k / 7.0))
			_blob(img, p.x, p.y, (3.6 - k * 0.12) * scale * lengths[i] / 12.0, BLOOD, 0.1)
	# Fade the print unevenly, like a hand pressed once and dragged.
	for y in SIZE:
		for x in SIZE:
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and Vector2(x, y).distance_to(at) < 60.0 * scale:
				c.a *= alpha * clampf(0.9 + 0.25 * _noise.get_noise_2d(x * 5.0, y * 5.0), 0.0, 1.0)
				img.set_pixel(x, y, c)


func _handprints() -> Image:
	_rng.seed = 210
	_noise.seed = 210
	var img := _blank()
	_hand(img, Vector2(90, 150), -0.25, 1.6, 1.0)
	_hand(img, Vector2(175, 95), 0.3, 1.5, 0.75)
	return img


func _drips() -> Image:
	_rng.seed = 220
	_noise.seed = 220
	var img := _blank()
	# A smear along the top with drips running down.
	for x in range(30, SIZE - 30):
		var h := 14.0 + 8.0 * _noise.get_noise_1d(x * 3.0)
		for y in range(20, int(20 + h)):
			_ink(img, x, y, BLOOD, 0.85)
	for i in 11:
		var x := _rng.randf_range(36, SIZE - 36)
		var length := _rng.randf_range(50, SIZE - 50)
		var w := _rng.randf_range(2.0, 4.5)
		for y in range(30, int(30 + length)):
			var t := (y - 30) / length
			var cx := x + 1.5 * sin(y * 0.05 + i)
			var ww := w * (1.0 - 0.5 * t)
			for xx in range(int(cx - ww), int(cx + ww) + 1):
				_ink(img, xx, y, BLOOD.darkened(0.2 * t), 0.9)
		_blob(img, x, 30 + length, w * 1.4, BLOOD.darkened(0.2), 0.1)
	return img


func _scratches() -> Image:
	_rng.seed = 230
	var img := _blank()
	var c := Color(0.02, 0.018, 0.015)
	for set_i in 2:
		var start := Vector2(_rng.randf_range(40, 100), _rng.randf_range(30, 70)) + Vector2(set_i * 70, set_i * 40)
		var dir := Vector2(_rng.randf_range(0.2, 0.6), 1.0).normalized()
		for claw in 4:
			var p := start + Vector2(claw * 13.0, claw * -3.0)
			var length := _rng.randf_range(110, 160)
			for k in int(length):
				var q := p + dir * k + Vector2(sin(k * 0.08 + claw) * 2.0, 0)
				var t := k / length
				var depth := sin(t * PI)
				for w in range(-1, 2):
					_ink(img, int(q.x) + w, int(q.y), c, depth * (0.9 if w == 0 else 0.45))
				# Torn paper edge beside each gouge.
				_ink(img, int(q.x) + 2, int(q.y), Color(0.42, 0.38, 0.3), depth * 0.5)
	return img


func _tally() -> Image:
	_rng.seed = 240
	var img := _blank()
	var c := Color(0.03, 0.025, 0.02)
	# Days counted on the wall: groups of five, rows of them.
	for row in 3:
		for group in 4:
			var origin := Vector2(24 + group * 56, 30 + row * 74)
			for m in 5:
				var a := origin + Vector2(m * 9.0, 0)
				var b := a + Vector2(_rng.randf_range(-2, 2), 46)
				if m == 4:
					a = origin + Vector2(-4, 8)
					b = origin + Vector2(38, 36)
				for k in 50:
					var q := a.lerp(b, k / 49.0)
					_ink(img, int(q.x), int(q.y), c, 0.85)
					_ink(img, int(q.x) + 1, int(q.y), c, 0.5)
	return img


func _stain(seed_value: int) -> Image:
	_noise.seed = seed_value
	var img := _blank()
	var mid := Vector2(SIZE, SIZE) * 0.5
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x, y).distance_to(mid) / (SIZE * 0.5)
			var n := _noise.get_noise_2d(x, y)
			var a := clampf((0.62 - d + 0.3 * n) * 1.6, 0.0, 1.0)
			# Tide line: darker ring at the edge of the dried water.
			var ring := 1.0 - smoothstep(0.0, 0.1, absf(0.62 - d + 0.3 * n))
			_ink(img, x, y, GRIME, a * 0.55 + ring * 0.35)
	return img
