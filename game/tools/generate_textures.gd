extends SceneTree
## Renders tileable procedural surface textures (albedo + normal) into
## res://assets/generated/textures. High = 512 px, low = 256 px.
## Usage: godot --headless --path game --script res://tools/generate_textures.gd

const OUT := "res://assets/generated/textures"
const SIZE := 512

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var t0 := Time.get_ticks_msec()
	_emit("wallpaper", _wallpaper(), 3.0)
	_emit("wood_floor", _wood_floor(), 4.0)
	_emit("plaster", _plaster(), 2.0)
	_emit("concrete", _concrete(), 3.0)
	_emit("tile", _tile(), 4.0)
	_emit("metal", _metal(), 2.0)
	_emit("dark_wood", _dark_wood(), 3.0)
	_emit("fabric", _fabric(), 2.0)
	_emit("blocks", _blocks(), 5.0)
	_emit("carpet", _carpet(), 2.0)
	_emit("wall_tile", _wall_tile(), 3.0)
	print("Textures generated in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


func _emit(tex_name: String, layers: Dictionary, bump: float) -> void:
	var albedo: Image = layers["albedo"]
	var height: Image = layers["height"]
	var normal := height.duplicate() as Image
	normal.convert(Image.FORMAT_RGBA8)
	normal.bump_map_to_normal_map(bump)
	_save(albedo, tex_name + "_albedo")
	_save(normal, tex_name + "_normal")
	print("  " + tex_name)


func _save(img: Image, base: String) -> void:
	img.save_png("%s/%s.png" % [OUT, base])
	var lo := img.duplicate() as Image
	lo.resize(SIZE / 2, SIZE / 2, Image.INTERPOLATE_LANCZOS)
	lo.save_png("%s/%s_lo.png" % [OUT, base])


func _noise(freq: float, octaves: int, seed_value: int, type: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = type
	n.frequency = freq
	n.fractal_octaves = octaves
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	return n.get_seamless_image(SIZE, SIZE, false, false, 0.12, true)


func _cellular(freq: float, seed_value: int) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = freq
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	return n.get_seamless_image(SIZE, SIZE, false, false, 0.12, true)


static func v(img: Image, x: int, y: int) -> float:
	return img.get_pixel(posmod(x, SIZE), posmod(y, SIZE)).r


func _new_pair() -> Array[Image]:
	var a := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var h := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	return [a, h]


func _wallpaper() -> Dictionary:
	var pair := _new_pair()
	var stain := _noise(0.006, 4, 11)
	var fine := _noise(0.08, 3, 12)
	var base := Color(0.46, 0.43, 0.37)
	var stripe := Color(0.38, 0.35, 0.3)
	for y in SIZE:
		for x in SIZE:
			# Vertical stripes with a repeating diamond motif.
			var sx := float(x % 64) / 64.0
			var stripe_mask := 1.0 if (sx > 0.42 and sx < 0.58) else 0.0
			var mx := float(x % 64) - 32.0
			var my := float(y % 96) - 48.0
			var diamond := 1.0 if (absf(mx) / 14.0 + absf(my) / 22.0) < 1.0 and (absf(mx) / 10.0 + absf(my) / 16.0) > 1.0 else 0.0
			var c := base.lerp(stripe, maxf(stripe_mask * 0.6, diamond * 0.8))
			var s := v(stain, x, y)
			var f := v(fine, x, y)
			c = c.darkened(clampf((s - 0.62) * 0.9, 0.0, 0.22))
			c = c.lerp(Color(0.32, 0.27, 0.2), clampf((0.36 - s) * 1.2, 0.0, 0.25))
			c = c.darkened((f - 0.5) * 0.12)
			pair[0].set_pixel(x, y, c)
			pair[1].set_pixel(x, y, Color.from_hsv(0, 0, 0.5 + diamond * 0.06 + (f - 0.5) * 0.1))
	return {"albedo": pair[0], "height": pair[1]}


func _wood_floor() -> Dictionary:
	var pair := _new_pair()
	var grain := _noise(0.02, 3, 21)
	var fine := _noise(0.2, 2, 22)
	var stain := _noise(0.008, 3, 23)
	var plank_h := 64
	_rng.seed = 24
	var plank_tints: Array[float] = []
	var plank_offsets: Array[int] = []
	for i in SIZE / plank_h:
		plank_tints.append(_rng.randf_range(-0.08, 0.08))
		plank_offsets.append(_rng.randi_range(0, SIZE))
	for y in SIZE:
		var row := y / plank_h
		var in_row := y % plank_h
		for x in SIZE:
			var px := (x + plank_offsets[row]) % SIZE
			var seam := in_row < 2 or (px % 256) < 2
			var g := v(grain, x * 4, y / 3 + row * 31)
			var rings := 0.5 + 0.5 * sin(g * 40.0 + float(x) * 0.02)
			var c := Color(0.32, 0.22, 0.14).lerp(Color(0.42, 0.3, 0.19), rings * 0.6)
			c = c.lightened(plank_tints[row])
			c = c.darkened(clampf((v(stain, x, y) - 0.5) * 0.8, 0.0, 0.35))
			c = c.darkened((v(fine, x, y) - 0.5) * 0.15)
			var h := 0.55 + rings * 0.05 + (v(fine, x, y) - 0.5) * 0.08
			if seam:
				c = c.darkened(0.7)
				h = 0.1
			pair[0].set_pixel(x, y, c)
			pair[1].set_pixel(x, y, Color(h, h, h))
	return {"albedo": pair[0], "height": pair[1]}


func _plaster() -> Dictionary:
	var pair := _new_pair()
	var n1 := _noise(0.01, 5, 31)
	var n2 := _noise(0.12, 2, 32)
	var crack := _cellular(0.02, 33)
	var mask := _noise(0.01, 2, 34)
	for y in SIZE:
		for x in SIZE:
			var a := v(n1, x, y)
			var b := v(n2, x, y)
			var cr := v(crack, x, y)
			var c := Color(0.62, 0.6, 0.55).darkened(clampf((a - 0.55) * 0.6, 0.0, 0.2))
			c = c.darkened((b - 0.5) * 0.1)
			var h := 0.5 + (b - 0.5) * 0.25
			if cr < 0.025 and v(mask, x, y) > 0.62:
				c = c.darkened(0.4)
				h = 0.3
			pair[0].set_pixel(x, y, c)
			pair[1].set_pixel(x, y, Color(h, h, h))
	return {"albedo": pair[0], "height": pair[1]}


func _concrete() -> Dictionary:
	var pair := _new_pair()
	var n1 := _noise(0.008, 5, 41)
	var n2 := _noise(0.25, 2, 42)
	var pits := _noise(0.3, 1, 43)
	for y in SIZE:
		for x in SIZE:
			var a := v(n1, x, y)
			var b := v(n2, x, y)
			var p := v(pits, x, y)
			var c := Color(0.36, 0.36, 0.35).darkened(clampf((a - 0.5) * 0.9, -0.15, 0.45))
			c = c.darkened((b - 0.5) * 0.25)
			var h := 0.5 + (b - 0.5) * 0.3
			if p < 0.12:
				c = c.darkened(0.3)
				h -= 0.2
			if a < 0.3:
				c = c.lerp(Color(0.25, 0.22, 0.17), 0.4)
			pair[0].set_pixel(x, y, c)
			pair[1].set_pixel(x, y, Color(h, h, h))
	return {"albedo": pair[0], "height": pair[1]}


func _tile() -> Dictionary:
	var pair := _new_pair()
	var dirt := _noise(0.01, 4, 51)
	var fine := _noise(0.15, 2, 52)
	var tile := 64
	for y in SIZE:
		for x in SIZE:
			var tx := x / tile
			var ty := y / tile
			var lx := x % tile
			var ly := y % tile
			var grout := lx < 3 or ly < 3
			var checker := (tx + ty) % 2 == 0
			var c := Color(0.7, 0.68, 0.62) if checker else Color(0.16, 0.16, 0.16)
			var d := v(dirt, x, y)
			c = c.lerp(Color(0.3, 0.26, 0.2), clampf((d - 0.45) * 0.9, 0.0, 0.5))
			c = c.darkened((v(fine, x, y) - 0.5) * 0.1)
			var h := 0.6
			if grout:
				c = Color(0.22, 0.2, 0.18).darkened(clampf(d - 0.4, 0.0, 0.4))
				h = 0.35
			pair[0].set_pixel(x, y, c)
			pair[1].set_pixel(x, y, Color(h, h, h))
	return {"albedo": pair[0], "height": pair[1]}


func _metal() -> Dictionary:
	var pair := _new_pair()
	var brush := _noise(0.4, 2, 61)
	var rust := _noise(0.012, 5, 62)
	var drips := _noise(0.05, 2, 63)
	for y in SIZE:
		for x in SIZE:
			var b := v(brush, x / 8, y * 2)
			var r := v(rust, x, y)
			var c := Color(0.42, 0.43, 0.44).darkened((b - 0.5) * 0.2)
			var rust_amt := clampf((r - 0.55) * 2.2, 0.0, 1.0)
			var drip := v(drips, x / 6, y / 40)
			if drip > 0.72:
				rust_amt = maxf(rust_amt, (drip - 0.72) * 2.5)
			c = c.lerp(Color(0.35, 0.18, 0.08), rust_amt * 0.8)
			var h := 0.5 + (b - 0.5) * 0.05 + rust_amt * 0.15
			pair[0].set_pixel(x, y, c)
			pair[1].set_pixel(x, y, Color(h, h, h))
	return {"albedo": pair[0], "height": pair[1]}


func _dark_wood() -> Dictionary:
	var pair := _new_pair()
	var grain := _noise(0.03, 4, 71)
	var fine := _noise(0.3, 2, 72)
	for y in SIZE:
		for x in SIZE:
			var g := v(grain, x * 5, y / 2)
			var rings := 0.5 + 0.5 * sin(g * 30.0)
			var c := Color(0.16, 0.1, 0.07).lerp(Color(0.26, 0.17, 0.11), rings * 0.7)
			c = c.darkened((v(fine, x, y) - 0.5) * 0.2)
			var h := 0.5 + rings * 0.08
			pair[0].set_pixel(x, y, c)
			pair[1].set_pixel(x, y, Color(h, h, h))
	return {"albedo": pair[0], "height": pair[1]}


func _fabric() -> Dictionary:
	var pair := _new_pair()
	var n := _noise(0.01, 4, 81)
	for y in SIZE:
		for x in SIZE:
			var weave := 0.5 + 0.25 * sin(x * 1.6) * sin(y * 1.6) + 0.25 * sin((x + y) * 0.8)
			var c := Color(0.3, 0.25, 0.24).darkened(clampf((v(n, x, y) - 0.5) * 0.7, -0.1, 0.35))
			c = c.darkened((weave - 0.5) * 0.2)
			pair[0].set_pixel(x, y, c)
			pair[1].set_pixel(x, y, Color(weave, weave, weave))
	return {"albedo": pair[0], "height": pair[1]}


func _blocks() -> Dictionary:
	var pair := _new_pair()
	var dirt := _noise(0.01, 4, 91)
	var fine := _noise(0.2, 2, 92)
	var bw := 128
	var bh := 64
	for y in SIZE:
		var row := y / bh
		for x in SIZE:
			var ox := (x + (bw / 2 if row % 2 == 1 else 0)) % SIZE
			var mortar := (ox % bw) < 4 or (y % bh) < 4
			var d := v(dirt, x, y)
			var c := Color(0.5, 0.5, 0.48).darkened(clampf((d - 0.45) * 0.8, 0.0, 0.4))
			c = c.darkened((v(fine, x, y) - 0.5) * 0.25)
			var h := 0.6 + (v(fine, x, y) - 0.5) * 0.15
			if mortar:
				c = Color(0.3, 0.3, 0.29).darkened(clampf(d - 0.4, 0.0, 0.3))
				h = 0.3
			pair[0].set_pixel(x, y, c)
			pair[1].set_pixel(x, y, Color(h, h, h))
	return {"albedo": pair[0], "height": pair[1]}


func _carpet() -> Dictionary:
	var pair := _new_pair()
	var n := _noise(0.015, 4, 101)
	var fuzz := _noise(0.5, 1, 102)
	for y in SIZE:
		for x in SIZE:
			# Faded border pattern repeating every 256 px.
			var lx := absf(float(x % 256) - 128.0)
			var ly := absf(float(y % 256) - 128.0)
			var ring := maxf(lx, ly)
			var band := 1.0 if (ring > 100.0 and ring < 112.0) or (lx + ly < 40.0) else 0.0
			var c := Color(0.3, 0.1, 0.09).lerp(Color(0.45, 0.38, 0.28), band * 0.7)
			c = c.darkened(clampf((v(n, x, y) - 0.45) * 0.8, -0.1, 0.4))
			var f := v(fuzz, x, y)
			c = c.darkened((f - 0.5) * 0.25)
			pair[0].set_pixel(x, y, c)
			pair[1].set_pixel(x, y, Color(f, f, f))
	return {"albedo": pair[0], "height": pair[1]}


func _wall_tile() -> Dictionary:
	var pair := _new_pair()
	var dirt := _noise(0.012, 4, 111)
	var fine := _noise(0.2, 2, 112)
	var tw := 64
	var th := 32
	for y in SIZE:
		var row := y / th
		for x in SIZE:
			var ox := (x + (tw / 2 if row % 2 == 1 else 0)) % SIZE
			var grout := (ox % tw) < 2 or (y % th) < 2
			var d := v(dirt, x, y)
			var c := Color(0.74, 0.74, 0.7).darkened(clampf((d - 0.5) * 0.7, 0.0, 0.3))
			c = c.lerp(Color(0.5, 0.45, 0.35), clampf((d - 0.65) * 1.2, 0.0, 0.3))
			c = c.darkened((v(fine, x, y) - 0.5) * 0.06)
			var h := 0.62
			if grout:
				c = Color(0.36, 0.34, 0.3).darkened(clampf(d - 0.4, 0.0, 0.3))
				h = 0.38
			pair[0].set_pixel(x, y, c)
			pair[1].set_pixel(x, y, Color(h, h, h))
	return {"albedo": pair[0], "height": pair[1]}
