# gdlint: disable=max-public-methods
class_name SoundSynth
extends RefCounted
## Original procedural sound design for METHOD HORROR placeholder audio.
##
## Everything is synthesized from noise, oscillators, filters and envelopes,
## so the output is original and freely usable by METHOD. Quality limits:
## no recorded foley, limited timbral realism; see docs/asset-manifest.md.
## Run `game/tools/generate_audio.gd` to (re)render the WAV files.

const RATE := 22050
const TAU_F := TAU

## name -> loop?  Variants are rendered as name_1..name_n via VARIANTS.
const SOUNDS := {
	"step_wood": false,
	"step_concrete": false,
	"step_carpet": false,
	"step_metal": false,
	"door_creak": false,
	"door_close": false,
	"door_locked": false,
	"unlock": false,
	"pickup": false,
	"drop": false,
	"switch": false,
	"fuse_insert": false,
	"short_circuit": false,
	"power_on": false,
	"hum_loop": true,
	"light_buzz_loop": true,
	"spark": false,
	"keypad_beep": false,
	"keypad_error": false,
	"keypad_success": false,
	"crank_clank": false,
	"crank_ok": false,
	"motor_loop": true,
	"garage_loop": true,
	"watcher_breath_loop": true,
	"watcher_step": false,
	"watcher_screech": false,
	"watcher_growl": false,
	"watcher_attack": false,
	"watcher_keys": false,
	"player_breath_loop": true,
	"heartbeat_loop": true,
	"player_hurt": false,
	"amb_house_loop": true,
	"amb_basement_loop": true,
	"mus_tension_loop": true,
	"mus_chase_loop": true,
	"mus_menu_loop": true,
	"ui_hover": false,
	"ui_click": false,
	"ui_back": false,
	"ui_confirm": false,
	"stinger_scare": false,
	"distant_impact": false,
	"creak": false,
	"page_turn": false,
	"locker_open": false,
	"locker_close": false,
	"flashlight_click": false,
	"battery_insert": false,
	"escape_sting": false,
	"defeat_sting": false,
	"ping": false,
	"drawer": false,
	"workbench": false,
	"revive": false,
	"tape_voice": false,
	"sister_hum_loop": true,
	"sister_step": false,
	"sister_hiss": false,
	"sister_shriek": false,
	"sister_attack": false,
	"monitor_beep": false,
	"breaker_flip": false,
	"breaker_trip": false,
	"generator_start": false,
	"generator_loop": true,
	"card_accept": false,
	"card_deny": false,
	"amb_ward_loop": true,
	"lineman_breath_loop": true,
	"lineman_step": false,
	"lineman_whistle": false,
	"lineman_growl": false,
	"lineman_screech": false,
	"train_pass": false,
	"train_arrive": false,
	"lever_pull": false,
	"signal_bell": false,
	"relay_click": false,
	"pa_chime": false,
	"radio_static": false,
	"amb_station_loop": true,
}

const VARIANTS := {
	"step_wood": 4,
	"step_concrete": 4,
	"step_carpet": 4,
	"step_metal": 4,
	"distant_impact": 3,
	"creak": 3,
	"door_creak": 2,
}

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1337) -> void:
	rng.seed = seed_value


func render(sound: String, variant: int = 0) -> PackedFloat32Array:
	rng.seed = hash(sound) + variant * 7919
	var method := "r_" + sound
	if not has_method(method):
		push_error("No recipe for " + sound)
		return PackedFloat32Array()
	var out: PackedFloat32Array = call(method, variant)
	return out


static func to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


# --- DSP helpers ------------------------------------------------------------


static func make(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	b.fill(0.0)
	return b


func noise(seconds: float) -> PackedFloat32Array:
	var b := make(seconds)
	for i in b.size():
		b[i] = rng.randf() * 2.0 - 1.0
	return b


## Brown-ish noise (integrated white noise with leak).
func brown(seconds: float) -> PackedFloat32Array:
	var b := make(seconds)
	var y := 0.0
	for i in b.size():
		y = y * 0.985 + (rng.randf() * 2.0 - 1.0) * 0.15
		b[i] = y
	return b


static func lowpass(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU_F * cutoff / RATE)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = y
	return b


static func highpass(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU_F * cutoff / RATE)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = b[i] - y
	return b


## State-variable band-pass with a linear center sweep.
static func bandpass(b: PackedFloat32Array, f_start: float, f_end: float, q: float) -> PackedFloat32Array:
	var low := 0.0
	var band := 0.0
	var damp := 1.0 / maxf(q, 0.5)
	var n := b.size()
	for i in n:
		var fc := lerpf(f_start, f_end, float(i) / maxf(1.0, n - 1))
		var fk := 2.0 * sin(PI * minf(fc, RATE * 0.22) / RATE)
		low += fk * band
		var high := b[i] - low - damp * band
		band += fk * high
		b[i] = band
	return b


static func env_perc(b: PackedFloat32Array, attack: float, decay: float, offset: float = 0.0) -> PackedFloat32Array:
	var a_n := maxf(1.0, attack * RATE)
	var start := int(offset * RATE)
	for i in b.size():
		var t := i - start
		var e := 0.0
		if t < 0:
			e = 0.0
		elif t < a_n:
			e = t / a_n
		else:
			e = exp(-(t - a_n) / (decay * RATE))
		b[i] *= e
	return b


static func fade(b: PackedFloat32Array, fade_in: float, fade_out: float) -> PackedFloat32Array:
	var n := b.size()
	var fi := int(fade_in * RATE)
	var fo := int(fade_out * RATE)
	for i in mini(fi, n):
		b[i] *= float(i) / fi
	for i in mini(fo, n):
		b[n - 1 - i] *= float(i) / fo
	return b


static func mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, at_seconds: float, gain: float) -> void:
	var off := int(at_seconds * RATE)
	for i in src.size():
		var j := off + i
		if j >= 0 and j < dst.size():
			dst[j] += src[i] * gain


## Wrap-around mix for seamless loops.
static func mix_wrap(dst: PackedFloat32Array, src: PackedFloat32Array, at_seconds: float, gain: float) -> void:
	var off := int(at_seconds * RATE)
	var n := dst.size()
	for i in src.size():
		dst[(off + i) % n] += src[i] * gain


static func normalize(b: PackedFloat32Array, peak: float = 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var g := peak / m
	for i in b.size():
		b[i] *= g
	return b


static func saturate(b: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	for i in b.size():
		b[i] = tanh(b[i] * drive)
	return b


static func scale(b: PackedFloat32Array, g: float) -> PackedFloat32Array:
	for i in b.size():
		b[i] *= g
	return b


## Makes a buffer seamless: crossfades the last `xfade` seconds into the start
## and trims them off.
static func loopify(b: PackedFloat32Array, xfade: float) -> PackedFloat32Array:
	var x := int(xfade * RATE)
	var n := b.size() - x
	var out := b.slice(0, n)
	for i in x:
		var t := float(i) / x
		out[i] = out[i] * t + b[n + i] * (1.0 - t)
	return out


## Small Schroeder reverb; returns a new buffer with `tail` seconds appended.
static func reverb(b: PackedFloat32Array, mix: float, room: float, tail: float) -> PackedFloat32Array:
	var n := b.size() + int(tail * RATE)
	var dry := make(float(n) / RATE)
	for i in b.size():
		dry[i] = b[i]
	var wet := make(float(n) / RATE)
	var comb_delays := [1116, 1188, 1277, 1356]
	for d in comb_delays:
		var delay := int(d * 0.5)
		var line := PackedFloat32Array()
		line.resize(delay)
		line.fill(0.0)
		var idx := 0
		var filt := 0.0
		for i in n:
			var outv := line[idx]
			filt = outv * 0.6 + filt * 0.4
			line[idx] = dry[i] + filt * room
			idx = (idx + 1) % delay
			wet[i] += outv * 0.25
	for d in [556, 441]:
		var delay := int(d * 0.5)
		var line := PackedFloat32Array()
		line.resize(delay)
		line.fill(0.0)
		var idx := 0
		for i in n:
			var buf_out := line[idx]
			var inp := wet[i]
			line[idx] = inp + buf_out * 0.5
			wet[i] = buf_out - inp * 0.5
			idx = (idx + 1) % delay
	for i in n:
		dry[i] = dry[i] * (1.0 - mix) + wet[i] * mix
	return dry


## Loop-safe reverb: renders the tail and wraps it onto the start.
static func reverb_loop(b: PackedFloat32Array, mix: float, room: float) -> PackedFloat32Array:
	var n := b.size()
	var r := reverb(b, mix, room, 2.0)
	var out := r.slice(0, n)
	for i in r.size() - n:
		out[i % n] += r[n + i]
	return out


func tone(seconds: float, freq: float, wave: String = "sine", detune: float = 0.0) -> PackedFloat32Array:
	var b := make(seconds)
	var ph := rng.randf()
	var f := freq * (1.0 + detune)
	for i in b.size():
		ph += f / RATE
		ph -= floor(ph)
		match wave:
			"sine":
				b[i] = sin(ph * TAU_F)
			"saw":
				b[i] = ph * 2.0 - 1.0
			"square":
				b[i] = 1.0 if ph < 0.5 else -1.0
			"tri":
				b[i] = 4.0 * absf(ph - 0.5) - 1.0
	return b


func sweep(seconds: float, f0: float, f1: float, wave: String = "sine", curve: float = 1.0) -> PackedFloat32Array:
	var b := make(seconds)
	var ph := 0.0
	var n := b.size()
	for i in n:
		var t := pow(float(i) / n, curve)
		var f := lerpf(f0, f1, t)
		ph += f / RATE
		ph -= floor(ph)
		match wave:
			"sine":
				b[i] = sin(ph * TAU_F)
			"saw":
				b[i] = ph * 2.0 - 1.0
			"tri":
				b[i] = 4.0 * absf(ph - 0.5) - 1.0
	return b


## Inharmonic metallic ring.
func metal(seconds: float, base: float, decay: float) -> PackedFloat32Array:
	var b := make(seconds)
	var ratios := [1.0, 2.76, 5.4, 8.93]
	for k in ratios.size():
		var f: float = base * ratios[k] * (1.0 + rng.randf_range(-0.02, 0.02))
		var amp: float = 1.0 / (k + 1)
		var ph := rng.randf()
		for i in b.size():
			ph += f / RATE
			b[i] += sin(ph * TAU_F) * amp * exp(-float(i) / (decay * RATE / (1.0 + k * 0.6)))
	return b


## Stick-slip friction creak: pulse train with jittered rate through a resonator.
func creak_core(seconds: float, rate0: float, rate1: float, center: float) -> PackedFloat32Array:
	var b := make(seconds)
	var ph := 0.0
	var n := b.size()
	for i in n:
		var t := float(i) / n
		var r := lerpf(rate0, rate1, t) * (1.0 + 0.35 * sin(t * 37.0) + rng.randf_range(-0.25, 0.25))
		ph += r / RATE
		if ph >= 1.0:
			ph -= 1.0
			b[i] = rng.randf_range(0.6, 1.0)
	bandpass(b, center, center * 1.15, 9.0)
	var env_shape := make(seconds)
	for i in n:
		var t := float(i) / n
		env_shape[i] = sin(t * PI) * (0.7 + 0.3 * sin(t * 11.0))
	for i in n:
		b[i] *= env_shape[i]
	return b


func thump(seconds: float, f0: float, f1: float, decay: float) -> PackedFloat32Array:
	var b := sweep(seconds, f0, f1, "sine", 0.4)
	return env_perc(b, 0.002, decay)


func burst(seconds: float, lp: float, hp: float, decay: float) -> PackedFloat32Array:
	var b := noise(seconds)
	if hp > 0.0:
		highpass(b, hp)
	if lp > 0.0:
		lowpass(b, lp)
	return env_perc(b, 0.001, decay)


func note(seconds: float, freq: float, decay: float, brightness: float = 0.4) -> PackedFloat32Array:
	# Plucked/piano-ish tone: few harmonics with faster decay for upper partials.
	var b := make(seconds)
	for h in [1, 2, 3, 5]:
		var amp: float = pow(brightness, h - 1)
		var ph := rng.randf()
		var f: float = freq * h * (1.0 + 0.0015 * h * h)
		for i in b.size():
			ph += f / RATE
			b[i] += sin(ph * TAU_F) * amp * exp(-float(i) / (decay * RATE / h))
	for i in mini(int(0.004 * RATE), b.size()):
		b[i] *= float(i) / (0.004 * RATE)
	return b


# --- Recipes ------------------------------------------------------------------


func r_step_wood(v: int) -> PackedFloat32Array:
	var b := make(0.3)
	mix_into(b, thump(0.25, 110.0 + v * 7.0, 60.0, 0.05), 0.0, 0.9)
	mix_into(b, burst(0.12, 2600.0 + v * 200.0, 500.0, 0.018), 0.0, 0.5)
	if v % 2 == 0:
		mix_into(b, scale(creak_core(0.12, 180.0, 120.0, 900.0 + v * 60.0), 0.25), 0.04, 1.0)
	return normalize(b, 0.8)


func r_step_concrete(v: int) -> PackedFloat32Array:
	var b := make(0.25)
	mix_into(b, thump(0.2, 90.0, 55.0, 0.035), 0.0, 0.6)
	mix_into(b, burst(0.18, 6500.0, 1800.0 + v * 150.0, 0.03), 0.0, 0.8)
	mix_into(b, burst(0.1, 5000.0, 2500.0, 0.015), 0.035 + v * 0.004, 0.35)
	return normalize(b, 0.75)


func r_step_carpet(v: int) -> PackedFloat32Array:
	var b := make(0.25)
	mix_into(b, thump(0.2, 80.0, 50.0, 0.04), 0.0, 0.7)
	mix_into(b, burst(0.2, 1200.0 + v * 80.0, 200.0, 0.05), 0.0, 0.5)
	return normalize(b, 0.55)


func r_step_metal(v: int) -> PackedFloat32Array:
	var b := make(0.5)
	mix_into(b, metal(0.5, 320.0 + v * 35.0, 0.09), 0.0, 0.5)
	mix_into(b, thump(0.2, 120.0, 70.0, 0.04), 0.0, 0.7)
	mix_into(b, burst(0.05, 7000.0, 2500.0, 0.008), 0.0, 0.5)
	return normalize(b, 0.8)


func r_door_creak(v: int) -> PackedFloat32Array:
	var dur := 1.3 + v * 0.3
	var b := creak_core(dur, 55.0 + v * 15.0, 110.0, 700.0 + v * 250.0)
	var body := creak_core(dur, 30.0, 60.0, 260.0)
	mix_into(b, body, 0.0, 0.6)
	return normalize(reverb(b, 0.25, 0.6, 0.5), 0.8)


func r_door_close(_v: int) -> PackedFloat32Array:
	var b := make(0.8)
	mix_into(b, thump(0.5, 95.0, 45.0, 0.12), 0.0, 1.0)
	mix_into(b, burst(0.3, 1800.0, 80.0, 0.05), 0.0, 0.7)
	mix_into(b, metal(0.3, 900.0, 0.03), 0.02, 0.2)
	return normalize(reverb(b, 0.25, 0.65, 0.4), 0.85)


func r_door_locked(_v: int) -> PackedFloat32Array:
	var b := make(0.6)
	for k in 3:
		mix_into(b, metal(0.15, 1100.0 + k * 90.0, 0.02), k * 0.11, 0.6)
		mix_into(b, thump(0.1, 140.0, 90.0, 0.02), k * 0.11, 0.6)
	return normalize(b, 0.75)


func r_unlock(_v: int) -> PackedFloat32Array:
	var b := make(0.5)
	mix_into(b, metal(0.2, 1500.0, 0.025), 0.0, 0.6)
	mix_into(b, burst(0.05, 8000.0, 2000.0, 0.006), 0.0, 0.6)
	mix_into(b, metal(0.25, 1200.0, 0.04), 0.18, 0.7)
	mix_into(b, thump(0.1, 160.0, 100.0, 0.02), 0.18, 0.5)
	return normalize(b, 0.75)


func r_pickup(_v: int) -> PackedFloat32Array:
	var b := make(0.45)
	var swish := noise(0.3)
	bandpass(swish, 900.0, 3200.0, 1.5)
	env_perc(swish, 0.08, 0.08)
	mix_into(b, swish, 0.0, 0.6)
	mix_into(b, metal(0.3, 1800.0, 0.04), 0.12, 0.25)
	return normalize(b, 0.6)


func r_drop(_v: int) -> PackedFloat32Array:
	var b := make(0.8)
	mix_into(b, thump(0.3, 150.0, 70.0, 0.05), 0.0, 0.9)
	var t := 0.0
	for k in 4:
		mix_into(b, metal(0.2, 700.0 + rng.randf_range(0, 600), 0.02), t, 0.5 / (k + 1))
		t += 0.07 + rng.randf_range(0.0, 0.08)
	return normalize(b, 0.85)


func r_switch(_v: int) -> PackedFloat32Array:
	var b := make(0.15)
	mix_into(b, burst(0.05, 9000.0, 2500.0, 0.004), 0.0, 0.8)
	mix_into(b, metal(0.1, 2600.0, 0.012), 0.0, 0.4)
	mix_into(b, thump(0.06, 200.0, 120.0, 0.01), 0.004, 0.4)
	return normalize(b, 0.7)


func r_fuse_insert(_v: int) -> PackedFloat32Array:
	var b := make(0.4)
	mix_into(b, burst(0.06, 8000.0, 1500.0, 0.006), 0.0, 0.7)
	mix_into(b, thump(0.2, 130.0, 80.0, 0.04), 0.01, 0.8)
	mix_into(b, metal(0.2, 2100.0, 0.02), 0.0, 0.3)
	return normalize(b, 0.75)


func r_short_circuit(_v: int) -> PackedFloat32Array:
	var b := make(1.6)
	for k in 70:
		var at := rng.randf_range(0.0, 0.7) * pow(rng.randf(), 0.6)
		mix_into(b, burst(0.03, 9000.0, 1500.0, 0.004), at, rng.randf_range(0.3, 1.0))
	mix_into(b, burst(0.8, 3000.0, 30.0, 0.15), 0.25, 1.2)
	mix_into(b, thump(0.6, 70.0, 40.0, 0.2), 0.25, 1.0)
	var hum := tone(0.5, 50.0, "saw")
	lowpass(hum, 400.0)
	env_perc(hum, 0.01, 0.12)
	mix_into(b, hum, 0.0, 0.35)
	return normalize(reverb(saturate(b, 1.6), 0.25, 0.7, 0.6), 0.95)


func r_power_on(_v: int) -> PackedFloat32Array:
	var b := make(2.2)
	for k in 3:
		mix_into(b, burst(0.04, 8000.0, 1200.0, 0.005), k * 0.12, 0.7)
		mix_into(b, thump(0.1, 180.0, 110.0, 0.02), k * 0.12, 0.5)
	var hum := make(1.9)
	for h in [1, 2, 3, 5]:
		mix_into(hum, tone(1.9, 50.0 * h, "sine"), 0.0, 0.4 / h)
	for i in hum.size():
		hum[i] *= minf(1.0, float(i) / (0.9 * RATE))
	mix_into(b, hum, 0.3, 0.6)
	var whine := sweep(1.6, 300.0, 1200.0, "sine", 0.5)
	env_perc(whine, 0.5, 0.6)
	mix_into(b, whine, 0.3, 0.06)
	return normalize(fade(b, 0.0, 0.4), 0.8)


func r_hum_loop(_v: int) -> PackedFloat32Array:
	var b := make(2.0)
	for h in [1, 2, 3, 4, 6]:
		var t := tone(2.0, 50.0 * h, "sine")
		mix_into(b, t, 0.0, 0.5 / h)
	var n := noise(2.1)
	lowpass(n, 500.0)
	mix_into(b, loopify(n, 0.1), 0.0, 0.08)
	return normalize(b, 0.5)


func r_light_buzz_loop(_v: int) -> PackedFloat32Array:
	var b := make(1.0)
	var buzz := tone(1.0, 100.0, "saw")
	highpass(buzz, 800.0)
	for i in b.size():
		var mod := 0.7 + 0.3 * sin(float(i) / RATE * TAU_F * 4.0)
		b[i] = buzz[i] * mod
	mix_into(b, tone(1.0, 200.0, "sine"), 0.0, 0.2)
	return normalize(b, 0.4)


func r_spark(_v: int) -> PackedFloat32Array:
	var b := make(0.5)
	for k in 14:
		mix_into(b, burst(0.02, 10000.0, 2500.0, 0.003), rng.randf_range(0.0, 0.25), rng.randf_range(0.3, 1.0))
	return normalize(b, 0.6)


func r_keypad_beep(_v: int) -> PackedFloat32Array:
	var b := tone(0.09, 1320.0, "square")
	lowpass(b, 3500.0)
	return normalize(fade(b, 0.003, 0.02), 0.45)


func r_keypad_error(_v: int) -> PackedFloat32Array:
	var b := make(0.5)
	for k in 2:
		var t := tone(0.17, 220.0, "square")
		lowpass(t, 1800.0)
		mix_into(b, fade(t, 0.005, 0.02), k * 0.22, 0.6)
	return normalize(b, 0.55)


func r_keypad_success(_v: int) -> PackedFloat32Array:
	var b := make(0.7)
	var freqs := [880.0, 1108.7, 1318.5]
	for k in 3:
		var t := tone(0.14, freqs[k], "square")
		lowpass(t, 3000.0)
		mix_into(b, fade(t, 0.004, 0.03), k * 0.12, 0.5)
	mix_into(b, metal(0.3, 900.0, 0.05), 0.4, 0.3)
	return normalize(b, 0.55)


func r_crank_clank(_v: int) -> PackedFloat32Array:
	var b := make(1.0)
	mix_into(b, metal(0.8, 210.0, 0.18), 0.0, 1.0)
	mix_into(b, thump(0.3, 110.0, 60.0, 0.07), 0.0, 0.8)
	for k in 5:
		mix_into(b, burst(0.03, 6000.0, 1500.0, 0.004), 0.05 + k * 0.045, 0.5)
	return normalize(reverb(b, 0.3, 0.7, 0.6), 0.95)


func r_crank_ok(_v: int) -> PackedFloat32Array:
	var b := make(1.1)
	for k in 6:
		var pop := burst(0.12, 900.0, 40.0, 0.05)
		mix_into(b, pop, k * (0.12 - k * 0.01), 1.0 - k * 0.1)
	mix_into(b, thump(0.5, 70.0, 45.0, 0.15), 0.0, 0.8)
	return normalize(saturate(b, 1.5), 0.85)


func r_motor_loop(_v: int) -> PackedFloat32Array:
	var dur := 2.0
	var b := make(dur)
	var pulse_rate := 18.0
	var pulses := int(dur * pulse_rate)
	for k in pulses:
		mix_wrap(b, burst(0.08, 700.0, 30.0, 0.03), k / pulse_rate, 0.8)
	var whine := tone(dur, 120.0, "saw")
	lowpass(whine, 900.0)
	mix_into(b, whine, 0.0, 0.15)
	return normalize(b, 0.7)


func r_garage_loop(_v: int) -> PackedFloat32Array:
	var dur := 2.0
	var b := r_motor_loop(0)
	scale(b, 0.6)
	for k in 16:
		mix_wrap(b, metal(0.12, 600.0 + rng.randf_range(0, 400), 0.02), k * dur / 16.0, 0.35)
	var rumble := brown(dur + 0.2)
	lowpass(rumble, 180.0)
	mix_into(b, loopify(rumble, 0.2), 0.0, 1.2)
	return normalize(b, 0.8)


func r_watcher_breath_loop(_v: int) -> PackedFloat32Array:
	var dur := 6.4
	var b := make(dur)
	for k in 2:
		var start := k * 3.2
		var inhale := noise(1.3)
		bandpass(inhale, 500.0, 900.0, 2.5)
		for i in inhale.size():
			inhale[i] *= sin(float(i) / inhale.size() * PI)
		mix_into(b, inhale, start, 0.7)
		var exhale := noise(1.6)
		bandpass(exhale, 700.0, 300.0, 2.0)
		var growl := tone(1.6, 62.0 + k * 4.0, "saw")
		lowpass(growl, 500.0)
		for i in exhale.size():
			var e := sin(float(i) / exhale.size() * PI)
			exhale[i] = (exhale[i] * 0.8 + growl[i] * 0.35 * (0.6 + 0.4 * sin(float(i) / RATE * 47.0))) * e
		mix_into(b, exhale, start + 1.45, 0.9)
	return normalize(reverb_loop(b, 0.2, 0.5), 0.75)


func r_watcher_step(_v: int) -> PackedFloat32Array:
	var b := make(0.9)
	mix_into(b, thump(0.5, 75.0, 38.0, 0.12), 0.0, 1.0)
	mix_into(b, burst(0.2, 1200.0, 60.0, 0.05), 0.0, 0.6)
	var drag := noise(0.45)
	bandpass(drag, 2200.0, 1400.0, 1.2)
	for i in drag.size():
		drag[i] *= sin(float(i) / drag.size() * PI) * 0.6
	mix_into(b, drag, 0.12, 0.35)
	return normalize(b, 0.9)


func r_watcher_screech(_v: int) -> PackedFloat32Array:
	var dur := 1.6
	var b := make(dur)
	for k in 5:
		var s := sweep(dur, 380.0 + k * 37.0, 920.0 + k * 53.0, "saw", 0.35)
		mix_into(b, s, 0.0, 0.25)
	var n := noise(dur)
	bandpass(n, 1500.0, 3200.0, 1.5)
	mix_into(b, n, 0.0, 0.5)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= (0.65 + 0.35 * sin(t * TAU_F * 23.0)) * minf(1.0, t / 0.05) * exp(-maxf(0.0, t - 0.7) * 3.0)
	return normalize(reverb(saturate(b, 2.5), 0.3, 0.7, 0.8), 0.95)


func r_watcher_growl(_v: int) -> PackedFloat32Array:
	var dur := 1.8
	var b := sweep(dur, 85.0, 70.0, "saw", 1.0)
	var n := noise(dur)
	lowpass(n, 400.0)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (b[i] * 0.6 + n[i] * 0.8) * (0.55 + 0.45 * sin(t * TAU_F * 9.0 + sin(t * 5.0)))
	lowpass(b, 900.0)
	for i in b.size():
		b[i] *= sin(float(i) / b.size() * PI)
	return normalize(reverb(saturate(b, 2.0), 0.25, 0.6, 0.6), 0.85)


func r_watcher_attack(_v: int) -> PackedFloat32Array:
	var b := noise(0.45)
	bandpass(b, 400.0, 2600.0, 1.8)
	for i in b.size():
		b[i] *= sin(float(i) / b.size() * PI)
	mix_into(b, thump(0.3, 90.0, 50.0, 0.08), 0.3, 0.8)
	return normalize(b, 0.9)


func r_watcher_keys(_v: int) -> PackedFloat32Array:
	# The caretaker's key ring: an audible cue that the Watcher is near.
	var b := make(1.2)
	for k in 9:
		mix_into(b, metal(0.25, 2400.0 + rng.randf_range(-400, 600), 0.03), rng.randf_range(0.0, 0.8), 0.35)
	return normalize(reverb(b, 0.35, 0.6, 0.4), 0.6)


func r_player_breath_loop(_v: int) -> PackedFloat32Array:
	var dur := 2.4
	var b := make(dur)
	for k in 2:
		var breath := noise(0.9)
		bandpass(breath, 1200.0 if k == 0 else 800.0, 900.0, 1.5)
		for i in breath.size():
			breath[i] *= pow(sin(float(i) / breath.size() * PI), 1.5)
		mix_into(b, breath, k * 1.2 + 0.05, 0.8 if k == 0 else 1.0)
	return normalize(b, 0.55)


func r_heartbeat_loop(_v: int) -> PackedFloat32Array:
	var b := make(1.0)
	mix_into(b, thump(0.25, 60.0, 40.0, 0.06), 0.0, 1.0)
	mix_into(b, thump(0.25, 55.0, 38.0, 0.05), 0.28, 0.7)
	lowpass(b, 200.0)
	return normalize(b, 0.8)


func r_player_hurt(_v: int) -> PackedFloat32Array:
	var b := make(1.6)
	mix_into(b, thump(0.5, 80.0, 40.0, 0.15), 0.0, 1.0)
	mix_into(b, burst(0.3, 2000.0, 100.0, 0.06), 0.0, 0.7)
	var ring := tone(1.6, 3800.0, "sine")
	env_perc(ring, 0.02, 0.5)
	mix_into(b, ring, 0.05, 0.12)
	return normalize(b, 0.9)


func r_amb_house_loop(_v: int) -> PackedFloat32Array:
	var dur := 24.0
	var wind := noise(dur + 1.0)
	bandpass(wind, 300.0, 300.0, 0.8)
	lowpass(wind, 700.0)
	for i in wind.size():
		var t := float(i) / RATE
		wind[i] *= 0.35 + 0.3 * sin(t * TAU_F / 6.0) + 0.2 * sin(t * TAU_F / 2.3 + 1.0)
	var b := loopify(wind, 1.0)
	var drone := make(dur)
	mix_into(drone, tone(dur, 41.0, "sine"), 0.0, 0.5)
	mix_into(drone, tone(dur, 55.0, "sine"), 0.0, 0.25)
	for i in drone.size():
		drone[i] *= 0.6 + 0.4 * sin(float(i) / RATE * TAU_F / 12.0)
	mix_into(b, drone, 0.0, 0.5)
	for k in 4:
		mix_wrap(b, scale(creak_core(0.6, 30.0, 70.0, 500.0 + k * 140.0), 0.25), 3.0 + k * 5.5, 1.0)
	return normalize(reverb_loop(b, 0.15, 0.6), 0.6)


func r_amb_basement_loop(_v: int) -> PackedFloat32Array:
	var dur := 16.0
	var b := make(dur)
	for h in [1, 2, 3]:
		mix_into(b, tone(dur, 50.0 * h, "sine"), 0.0, 0.18 / h)
	var air := noise(dur + 0.5)
	lowpass(air, 250.0)
	mix_into(b, loopify(air, 0.5), 0.0, 0.5)
	for k in 11:
		var drip := sweep(0.12, 1400.0 + rng.randf_range(0, 900), 700.0, "sine", 0.5)
		env_perc(drip, 0.002, 0.03)
		mix_wrap(b, drip, rng.randf_range(0.0, dur), 0.18)
	for k in 3:
		mix_wrap(b, metal(0.6, 140.0 + k * 30.0, 0.15), 2.0 + k * 5.0, 0.15)
	return normalize(reverb_loop(b, 0.3, 0.75), 0.55)


func r_mus_tension_loop(_v: int) -> PackedFloat32Array:
	var dur := 32.0
	var b := make(dur)
	# Beating low cluster (A1 / Bb1), slow swells.
	for f in [55.0, 58.27, 82.41]:
		var t := tone(dur, f, "saw")
		lowpass(t, 260.0)
		mix_into(b, t, 0.0, 0.3)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= 0.45 + 0.35 * sin(t * TAU_F / 16.0 - PI / 2.0) * -1.0
	# Glassy high pad, quiet, phasing.
	var pad := make(dur)
	mix_into(pad, tone(dur, 880.0, "sine"), 0.0, 0.5)
	mix_into(pad, tone(dur, 932.33, "sine"), 0.0, 0.5)
	for i in pad.size():
		var t := float(i) / RATE
		pad[i] *= 0.5 + 0.5 * sin(t * TAU_F / 8.0)
	mix_into(b, pad, 0.0, 0.05)
	# Sparse low "pulse" figures.
	for k in 4:
		var n := note(3.0, 110.0 if k % 2 == 0 else 116.54, 0.8, 0.25)
		mix_wrap(b, n, 4.0 + k * 8.0, 0.18)
	return normalize(reverb_loop(b, 0.35, 0.78), 0.6)


func r_mus_chase_loop(_v: int) -> PackedFloat32Array:
	var dur := 8.0
	var b := make(dur)
	var bpm := 150.0
	var beat := 60.0 / bpm
	var steps := int(dur / (beat / 2.0))
	for k in steps:
		var at := k * beat / 2.0
		var f := 55.0 if k % 8 < 6 else 58.27
		var hit := tone(0.2, f, "saw")
		lowpass(hit, 500.0)
		env_perc(hit, 0.003, 0.08)
		mix_wrap(b, hit, at, 0.7)
		if k % 4 == 0:
			mix_wrap(b, thump(0.3, 70.0, 40.0, 0.09), at, 0.9)
		if k % 8 == 6:
			mix_wrap(b, metal(0.5, 440.0, 0.2), at, 0.25)
	for k in 2:
		var stab := make(0.8)
		for f in [220.0, 233.08, 311.13]:
			mix_into(stab, tone(0.8, f, "saw"), 0.0, 0.2)
		lowpass(stab, 2000.0)
		env_perc(stab, 0.01, 0.25)
		mix_wrap(b, stab, 1.5 + k * 4.0, 0.35)
	return normalize(saturate(b, 1.3), 0.75)


func r_mus_menu_loop(_v: int) -> PackedFloat32Array:
	var dur := 24.0
	var b := make(dur)
	var drone := tone(dur, 55.0, "tri")
	lowpass(drone, 200.0)
	mix_into(b, drone, 0.0, 0.25)
	# A minor with a flat second for unease.
	var melody := [440.0, 523.25, 466.16, 440.0, 329.63, 349.23, 329.63, 0.0]
	for k in melody.size():
		if melody[k] > 0.0:
			mix_wrap(b, note(4.0, melody[k], 1.4, 0.3), k * 3.0 + 0.5, 0.22)
			if k % 2 == 0:
				mix_wrap(b, note(4.0, melody[k] / 2.0, 1.8, 0.2), k * 3.0 + 0.5, 0.12)
	return normalize(reverb_loop(b, 0.45, 0.82), 0.55)


func r_ui_hover(_v: int) -> PackedFloat32Array:
	var b := tone(0.03, 2200.0, "sine")
	return normalize(fade(b, 0.002, 0.02), 0.2)


func r_ui_click(_v: int) -> PackedFloat32Array:
	var b := make(0.12)
	mix_into(b, burst(0.03, 7000.0, 1500.0, 0.004), 0.0, 0.6)
	mix_into(b, fade(tone(0.06, 900.0, "sine"), 0.001, 0.05), 0.0, 0.4)
	return normalize(b, 0.4)


func r_ui_back(_v: int) -> PackedFloat32Array:
	var b := make(0.14)
	mix_into(b, burst(0.03, 5000.0, 1000.0, 0.004), 0.0, 0.5)
	mix_into(b, fade(tone(0.08, 520.0, "sine"), 0.001, 0.06), 0.0, 0.4)
	return normalize(b, 0.35)


func r_ui_confirm(_v: int) -> PackedFloat32Array:
	var b := make(0.35)
	mix_into(b, fade(tone(0.12, 660.0, "sine"), 0.002, 0.08), 0.0, 0.4)
	mix_into(b, fade(tone(0.2, 990.0, "sine"), 0.002, 0.15), 0.09, 0.35)
	return normalize(reverb(b, 0.2, 0.5, 0.2), 0.4)


func r_stinger_scare(_v: int) -> PackedFloat32Array:
	var dur := 2.2
	var b := make(dur)
	for f in [110.0, 116.54, 155.56, 233.08, 246.94, 329.63, 349.23]:
		var t := tone(dur, f, "saw", rng.randf_range(-0.004, 0.004))
		mix_into(b, t, 0.0, 0.12)
	lowpass(b, 3200.0)
	mix_into(b, burst(0.6, 5000.0, 100.0, 0.12), 0.0, 1.0)
	mix_into(b, thump(0.8, 70.0, 35.0, 0.25), 0.0, 1.0)
	env_perc(b, 0.004, 0.55)
	return normalize(reverb(saturate(b, 1.8), 0.35, 0.8, 1.0), 0.95)


func r_distant_impact(v: int) -> PackedFloat32Array:
	var b := make(1.0)
	mix_into(b, thump(0.6, 70.0 + v * 8.0, 35.0, 0.2), 0.0, 1.0)
	mix_into(b, burst(0.4, 600.0, 30.0, 0.08), 0.0, 0.8)
	lowpass(b, 500.0)
	return normalize(reverb(b, 0.55, 0.85, 1.5), 0.7)


func r_creak(v: int) -> PackedFloat32Array:
	var b := creak_core(0.7 + v * 0.25, 25.0 + v * 10.0, 60.0, 450.0 + v * 220.0)
	return normalize(reverb(b, 0.3, 0.7, 0.6), 0.6)


func r_page_turn(_v: int) -> PackedFloat32Array:
	var b := noise(0.5)
	bandpass(b, 2500.0, 5000.0, 1.0)
	for i in b.size():
		var t := float(i) / b.size()
		b[i] *= sin(t * PI) * (0.5 + 0.5 * absf(sin(t * 40.0)))
	return normalize(b, 0.4)


func r_locker_open(_v: int) -> PackedFloat32Array:
	var b := make(0.9)
	mix_into(b, metal(0.7, 260.0, 0.15), 0.0, 0.7)
	mix_into(b, scale(creak_core(0.5, 60.0, 120.0, 1600.0), 0.4), 0.0, 1.0)
	mix_into(b, burst(0.04, 7000.0, 1500.0, 0.005), 0.0, 0.6)
	return normalize(b, 0.75)


func r_locker_close(_v: int) -> PackedFloat32Array:
	var b := make(0.9)
	mix_into(b, metal(0.8, 230.0, 0.2), 0.0, 0.9)
	mix_into(b, thump(0.3, 120.0, 70.0, 0.05), 0.0, 0.8)
	return normalize(reverb(b, 0.2, 0.6, 0.3), 0.8)


func r_flashlight_click(_v: int) -> PackedFloat32Array:
	var b := make(0.1)
	mix_into(b, burst(0.03, 9000.0, 2000.0, 0.003), 0.0, 0.7)
	mix_into(b, metal(0.06, 3100.0, 0.008), 0.0, 0.3)
	return normalize(b, 0.5)


func r_battery_insert(_v: int) -> PackedFloat32Array:
	var b := make(0.5)
	var slide := noise(0.2)
	bandpass(slide, 1500.0, 3000.0, 2.0)
	env_perc(slide, 0.05, 0.05)
	mix_into(b, slide, 0.0, 0.5)
	mix_into(b, r_switch(0), 0.22, 0.8)
	return normalize(b, 0.6)


func r_escape_sting(_v: int) -> PackedFloat32Array:
	var dur := 3.5
	var b := make(dur)
	for f in [220.0, 277.18, 329.63, 440.0]:
		var t := tone(dur, f, "tri")
		mix_into(b, t, 0.0, 0.2)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= minf(1.0, t / 0.8) * exp(-maxf(0.0, t - 1.2) * 1.2)
	return normalize(reverb(b, 0.4, 0.8, 1.0), 0.6)


func r_defeat_sting(_v: int) -> PackedFloat32Array:
	var dur := 3.5
	var b := make(dur)
	for f in [110.0, 116.54, 130.81]:
		mix_into(b, sweep(dur, f, f * 0.8, "saw", 1.0), 0.0, 0.25)
	lowpass(b, 900.0)
	env_perc(b, 0.05, 1.2)
	mix_into(b, thump(1.0, 60.0, 30.0, 0.4), 0.0, 0.8)
	return normalize(reverb(b, 0.4, 0.8, 1.0), 0.8)


func r_ping(_v: int) -> PackedFloat32Array:
	var b := make(0.8)
	mix_into(b, note(0.6, 1046.5, 0.2, 0.2), 0.0, 0.5)
	mix_into(b, note(0.6, 1318.5, 0.25, 0.2), 0.1, 0.5)
	return normalize(b, 0.5)


func r_drawer(_v: int) -> PackedFloat32Array:
	var b := make(0.7)
	var slide := noise(0.45)
	bandpass(slide, 700.0, 1100.0, 1.4)
	for i in slide.size():
		slide[i] *= sin(float(i) / slide.size() * PI) * (0.6 + 0.4 * absf(sin(float(i) / RATE * 70.0)))
	mix_into(b, slide, 0.0, 0.7)
	mix_into(b, thump(0.2, 140.0, 80.0, 0.03), 0.42, 0.6)
	return normalize(b, 0.6)


func r_workbench(_v: int) -> PackedFloat32Array:
	var b := make(1.4)
	for k in 6:
		mix_into(b, metal(0.25, 700.0 + rng.randf_range(0, 900), 0.04), k * 0.18, 0.4)
		mix_into(b, burst(0.04, 6000.0, 1200.0, 0.006), k * 0.18, 0.4)
	mix_into(b, r_unlock(0), 1.1, 0.5)
	return normalize(b, 0.7)


func r_revive(_v: int) -> PackedFloat32Array:
	var b := make(1.2)
	var breath := noise(0.8)
	bandpass(breath, 600.0, 1600.0, 1.5)
	env_perc(breath, 0.05, 0.3)
	mix_into(b, breath, 0.0, 0.6)
	mix_into(b, note(1.0, 659.25, 0.4, 0.2), 0.2, 0.3)
	return normalize(b, 0.55)


## Unintelligible voice-like babble through an old tape: glottal pulses shaped
## by moving vowel formants. Subtitles carry the actual words.
func r_tape_voice(_v: int) -> PackedFloat32Array:
	var dur := 4.2
	var b := make(dur)
	var formants := [[700.0, 1200.0], [400.0, 2000.0], [300.0, 800.0], [550.0, 1700.0], [450.0, 1000.0]]
	var ph := 0.0
	var syl_len := 0.17
	var n := b.size()
	var src := make(dur)
	for i in n:
		var t := float(i) / RATE
		var pitch := 115.0 + 18.0 * sin(t * 2.1) + 8.0 * sin(t * 7.3)
		ph += pitch / RATE
		if ph >= 1.0:
			ph -= 1.0
		src[i] = (1.0 - ph) * 2.0 - 1.0
	var syllables := int(dur / syl_len)
	for k in syllables:
		var f: Array = formants[rng.randi_range(0, formants.size() - 1)]
		var a := int(k * syl_len * RATE)
		var e := mini(n, int((k + 1) * syl_len * RATE))
		if e <= a or rng.randf() < 0.18:
			continue
		var seg := src.slice(a, e)
		var f1 := seg.duplicate()
		bandpass(f1, f[0], f[0] * 1.1, 5.0)
		var f2 := seg.duplicate()
		bandpass(f2, f[1], f[1] * 0.95, 6.0)
		for i in seg.size():
			var env := sin(float(i) / seg.size() * PI)
			b[a + i] = (f1[i] + f2[i] * 0.6) * env
	var hiss := noise(dur)
	highpass(hiss, 3000.0)
	mix_into(b, hiss, 0.0, 0.04)
	lowpass(b, 3200.0)
	highpass(b, 250.0)
	return normalize(fade(b, 0.05, 0.2), 0.7)
