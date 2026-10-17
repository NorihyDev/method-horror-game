class_name SoundSynthMaps
extends SoundSynth
## Recipes for The Black Ward and Last Train (plus the shared helpers they
## add). Split from SoundSynth to keep each recipe file readable; the
## generator instantiates this class, which inherits every base recipe.

# --- The Black Ward -------------------------------------------------------------


## Hummed voice: a nasal fundamental with soft overtones and a slow vibrato.
func hum(seconds: float, freq: float, vibrato: float = 0.006) -> PackedFloat32Array:
	var b := make(seconds)
	var ph := rng.randf()
	for i in b.size():
		var t := float(i) / RATE
		ph += freq * (1.0 + vibrato * sin(t * TAU_F * 5.3)) / RATE
		ph -= floor(ph)
		b[i] = sin(ph * TAU_F) * 0.7 + sin(ph * TAU_F * 2.0) * 0.22 + sin(ph * TAU_F * 3.0) * 0.07
	return b


func r_sister_hum_loop(_v: int) -> PackedFloat32Array:
	# A wordless lullaby through closed lips: slow, minor, slightly off-key.
	var dur := 9.6
	var b := make(dur)
	var melody := [
		[0.0, 293.66, 1.1],
		[1.2, 349.23, 0.9],
		[2.2, 329.63, 1.0],
		[3.3, 293.66, 1.5],
		[5.0, 261.63, 0.9],
		[6.0, 293.66, 0.9],
		[7.0, 220.0, 2.3]
	]
	for n: Array in melody:
		var start: float = n[0]
		var length: float = n[2]
		var voice := hum(length, float(n[1]) * 0.5 * (1.0 + rng.randf_range(-0.008, 0.008)))
		for i in voice.size():
			var x := float(i) / RATE
			voice[i] *= minf(1.0, x / 0.2) * minf(1.0, (length - x) / 0.4)
		lowpass(voice, 1100.0)
		mix_wrap(b, voice, start, 0.55)
	var breath := noise(dur)
	bandpass(breath, 600.0, 900.0, 1.4)
	mix_into(b, breath, 0.0, 0.04)
	return normalize(reverb_loop(b, 0.4, 0.75), 0.55)


func r_sister_step(_v: int) -> PackedFloat32Array:
	# Bare feet and a dragging hem: soft, close, easy to miss.
	var b := make(0.8)
	mix_into(b, thump(0.25, 110.0, 60.0, 0.05), 0.0, 0.6)
	var drag := noise(0.6)
	bandpass(drag, 1800.0, 900.0, 1.0)
	for i in drag.size():
		drag[i] *= sin(float(i) / drag.size() * PI)
	mix_into(b, drag, 0.05, 0.45)
	return normalize(b, 0.55)


func r_sister_hiss(_v: int) -> PackedFloat32Array:
	var dur := 1.5
	var b := noise(dur)
	bandpass(b, 2400.0, 3800.0, 1.2)
	var throat := hum(dur, 160.0, 0.03)
	lowpass(throat, 700.0)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (b[i] * 0.8 + throat[i] * 0.2) * sin(t / dur * PI) * (0.7 + 0.3 * sin(t * TAU_F * 13.0))
	return normalize(reverb(b, 0.3, 0.7, 0.6), 0.75)


func r_sister_shriek(_v: int) -> PackedFloat32Array:
	# A thin wail that breaks downward: she has found where the sound came from.
	var dur := 1.8
	var b := make(dur)
	for k in 4:
		var s := sweep(dur, 1250.0 + k * 41.0, 520.0 + k * 33.0, "tri", 0.6)
		mix_into(b, s, 0.0, 0.3)
	var n := noise(dur)
	bandpass(n, 2600.0, 1400.0, 1.6)
	mix_into(b, n, 0.0, 0.35)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= (0.7 + 0.3 * sin(t * TAU_F * 7.0)) * minf(1.0, t / 0.04) * exp(-maxf(0.0, t - 0.9) * 3.5)
	return normalize(reverb(saturate(b, 1.8), 0.35, 0.8, 0.9), 0.95)


func r_sister_attack(_v: int) -> PackedFloat32Array:
	var b := noise(0.5)
	bandpass(b, 1200.0, 3000.0, 1.5)
	for i in b.size():
		b[i] *= sin(float(i) / b.size() * PI)
	mix_into(b, thump(0.3, 120.0, 60.0, 0.07), 0.32, 0.7)
	return normalize(b, 0.9)


func r_monitor_beep(_v: int) -> PackedFloat32Array:
	var b := tone(0.12, 980.0, "sine")
	mix_into(b, tone(0.12, 1960.0, "sine"), 0.0, 0.15)
	return normalize(fade(b, 0.004, 0.05), 0.4)


func r_breaker_flip(_v: int) -> PackedFloat32Array:
	var b := make(0.6)
	mix_into(b, burst(0.05, 5000.0, 400.0, 0.012), 0.0, 1.0)
	mix_into(b, metal(0.3, 520.0, 0.04), 0.0, 0.5)
	mix_into(b, thump(0.2, 140.0, 70.0, 0.04), 0.01, 0.6)
	return normalize(b, 0.75)


func r_breaker_trip(_v: int) -> PackedFloat32Array:
	# A main breaker throwing itself open under a bad load: bang, sparks, buzz dying.
	var b := make(2.4)
	mix_into(b, thump(0.6, 90.0, 35.0, 0.2), 0.0, 1.0)
	mix_into(b, burst(0.4, 9000.0, 300.0, 0.08), 0.0, 0.9)
	for k in 10:
		mix_into(b, burst(0.02, 10000.0, 2500.0, 0.003), rng.randf_range(0.05, 0.5), rng.randf_range(0.3, 0.8))
	var buzz := sweep(1.8, 120.0, 40.0, "saw", 0.6)
	lowpass(buzz, 900.0)
	env_perc(buzz, 0.01, 0.6)
	mix_into(b, buzz, 0.15, 0.4)
	return normalize(reverb(b, 0.3, 0.7, 0.8), 0.95)


func r_generator_start(_v: int) -> PackedFloat32Array:
	var b := make(4.0)
	for k in 3:
		var crank := sweep(0.35, 40.0, 70.0, "saw", 1.0)
		lowpass(crank, 400.0)
		env_perc(crank, 0.02, 0.15)
		mix_into(b, crank, k * 0.45, 0.6)
	var engine := r_generator_loop(0)
	var ramp := engine.slice(0, int(2.6 * RATE))
	for i in ramp.size():
		ramp[i] *= minf(1.0, float(i) / (0.8 * RATE))
	mix_into(b, ramp, 1.4, 0.9)
	return normalize(b, 0.85)


func r_generator_loop(_v: int) -> PackedFloat32Array:
	var dur := 2.0
	var b := make(dur)
	for h in [1, 2, 3, 5]:
		var t := tone(dur, 30.0 * h, "saw")
		lowpass(t, 600.0)
		mix_into(b, t, 0.0, 0.4 / h)
	for i in b.size():
		b[i] *= 0.75 + 0.25 * sin(float(i) / RATE * TAU_F * 15.0)
	var n := noise(dur + 0.2)
	bandpass(n, 300.0, 500.0, 1.0)
	mix_into(b, loopify(n, 0.1), 0.0, 0.15)
	return normalize(b, 0.6)


func r_card_accept(_v: int) -> PackedFloat32Array:
	var b := make(0.7)
	for k in 2:
		var t := tone(0.07, 1760.0, "square")
		lowpass(t, 4000.0)
		mix_into(b, fade(t, 0.003, 0.01), k * 0.1, 0.4)
	mix_into(b, thump(0.25, 160.0, 80.0, 0.04), 0.25, 0.7)
	mix_into(b, metal(0.25, 900.0, 0.03), 0.25, 0.3)
	return normalize(b, 0.6)


func r_card_deny(_v: int) -> PackedFloat32Array:
	var b := tone(0.45, 160.0, "square")
	lowpass(b, 1200.0)
	return normalize(fade(b, 0.005, 0.05), 0.5)


func r_amb_ward_loop(_v: int) -> PackedFloat32Array:
	# Fluorescent hum, air handling, a slow drip somewhere down the corridor.
	var dur := 24.0
	var air := noise(dur + 1.0)
	bandpass(air, 250.0, 450.0, 0.7)
	lowpass(air, 800.0)
	for i in air.size():
		air[i] *= 0.45 + 0.15 * sin(float(i) / RATE * TAU_F / 7.0)
	var b := loopify(air, 1.0)
	for h in [1, 2, 3]:
		mix_into(b, tone(dur, 120.0 * h, "sine"), 0.0, 0.05 / h)
	for k in 7:
		var drip := note(0.4, rng.randf_range(1400.0, 2100.0), 0.05, 0.2)
		mix_wrap(b, drip, rng.randf_range(0.0, dur), 0.12)
	return normalize(reverb_loop(b, 0.25, 0.7), 0.5)


# --- Last Train ---------------------------------------------------------------------


func r_lineman_breath_loop(_v: int) -> PackedFloat32Array:
	# Rasping breath behind a dust mask.
	var dur := 5.6
	var b := make(dur)
	for k in 2:
		var start := k * 2.8
		var draw := noise(1.2)
		bandpass(draw, 1500.0, 2200.0, 2.0)
		for i in draw.size():
			draw[i] *= sin(float(i) / draw.size() * PI) * (0.6 + 0.4 * sin(float(i) / RATE * 90.0))
		mix_into(b, draw, start, 0.6)
		var out := noise(1.3)
		bandpass(out, 900.0, 500.0, 1.8)
		for i in out.size():
			out[i] *= sin(float(i) / out.size() * PI)
		mix_into(b, out, start + 1.35, 0.7)
	return normalize(reverb_loop(b, 0.3, 0.6), 0.7)


func r_lineman_step(_v: int) -> PackedFloat32Array:
	# Steel-capped boots on concrete and grit.
	var b := make(0.7)
	mix_into(b, thump(0.35, 95.0, 45.0, 0.08), 0.0, 1.0)
	mix_into(b, burst(0.15, 6000.0, 800.0, 0.03), 0.0, 0.7)
	for k in 5:
		mix_into(b, burst(0.01, 9000.0, 3000.0, 0.002), rng.randf_range(0.01, 0.12), 0.3)
	return normalize(b, 0.85)


func r_lineman_whistle(_v: int) -> PackedFloat32Array:
	# A guard's two-note whistle, echoing down the tunnel.
	var b := make(2.6)
	for k in 2:
		var f := 2350.0 if k == 0 else 1980.0
		var w := tone(0.45, f, "sine")
		var trill := noise(0.45)
		bandpass(trill, f, f, 8.0)
		for i in w.size():
			var x := float(i) / RATE
			w[i] = (w[i] + trill[i] * 0.4) * (0.75 + 0.25 * sin(x * TAU_F * 28.0)) * minf(1.0, x / 0.02)
		mix_into(b, fade(w, 0.01, 0.08), k * 0.5, 0.5)
	return normalize(reverb(b, 0.55, 0.9, 1.6), 0.6)


func r_lineman_growl(_v: int) -> PackedFloat32Array:
	var dur := 1.6
	var b := sweep(dur, 70.0, 58.0, "saw", 1.0)
	var grit := noise(dur)
	bandpass(grit, 900.0, 1400.0, 1.2)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (b[i] * 0.7 + grit[i] * 0.4) * sin(t / dur * PI) * (0.6 + 0.4 * sin(t * TAU_F * 6.0))
	lowpass(b, 1400.0)
	return normalize(reverb(saturate(b, 2.2), 0.3, 0.8, 0.9), 0.85)


func r_lineman_screech(_v: int) -> PackedFloat32Array:
	# Half shout, half the squeal of a wheel flange.
	var dur := 1.5
	var b := make(dur)
	for k in 3:
		mix_into(b, sweep(dur, 1900.0 + k * 90.0, 2300.0 + k * 70.0, "saw", 0.5), 0.0, 0.18)
	mix_into(b, sweep(dur, 300.0, 220.0, "saw", 1.0), 0.0, 0.35)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= minf(1.0, t / 0.03) * exp(-maxf(0.0, t - 0.8) * 4.0)
	highpass(b, 150.0)
	return normalize(reverb(saturate(b, 2.0), 0.4, 0.85, 1.0), 0.95)


func r_train_pass(_v: int) -> PackedFloat32Array:
	# A train that should not exist rolls through: rumble, wheel beats, flange squeal.
	var dur := 9.0
	var rumble := brown(dur)
	lowpass(rumble, 180.0)
	var b := make(dur)
	mix_into(b, rumble, 0.0, 1.0)
	for k in 18:
		var at := 1.5 + k * 0.33
		mix_into(b, thump(0.12, 70.0, 40.0, 0.03), at, 0.5)
		mix_into(b, thump(0.12, 72.0, 42.0, 0.03), at + 0.09, 0.4)
	var squeal := sweep(4.0, 3100.0, 2700.0, "sine", 1.0)
	env_perc(squeal, 0.6, 1.4)
	mix_into(b, squeal, 3.0, 0.12)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= sin(clampf(t / dur, 0.0, 1.0) * PI)
	return normalize(reverb(b, 0.35, 0.9, 1.4), 0.95)


func r_train_arrive(_v: int) -> PackedFloat32Array:
	# The evacuation train: approach, long brake squeal, stop, doors hiss open.
	var dur := 8.0
	var b := make(dur)
	var rumble := brown(dur)
	lowpass(rumble, 200.0)
	for i in rumble.size():
		var t := float(i) / RATE
		rumble[i] *= minf(1.0, t / 2.0) * (1.0 - smoothstep(4.5, 6.2, t))
	mix_into(b, rumble, 0.0, 1.0)
	var brake := sweep(3.2, 2600.0, 1900.0, "sine", 0.8)
	mix_into(brake, sweep(3.2, 3300.0, 2500.0, "sine", 0.8), 0.0, 0.5)
	env_perc(brake, 0.3, 1.6)
	mix_into(b, brake, 2.6, 0.18)
	var hiss := noise(1.2)
	highpass(hiss, 2500.0)
	env_perc(hiss, 0.02, 0.5)
	mix_into(b, hiss, 6.3, 0.35)
	mix_into(b, r_card_accept(0), 6.2, 0.4)
	return normalize(reverb(b, 0.35, 0.9, 1.4), 0.95)


func r_lever_pull(_v: int) -> PackedFloat32Array:
	var b := make(0.9)
	var scrape := noise(0.3)
	bandpass(scrape, 1400.0, 700.0, 1.5)
	env_perc(scrape, 0.01, 0.12)
	mix_into(b, scrape, 0.0, 0.5)
	mix_into(b, metal(0.6, 330.0, 0.12), 0.22, 0.6)
	mix_into(b, thump(0.3, 110.0, 55.0, 0.06), 0.22, 0.9)
	return normalize(b, 0.8)


func r_signal_bell(_v: int) -> PackedFloat32Array:
	# Signal box alarm bell: wrong route. Loud on purpose.
	var b := make(2.2)
	for k in 16:
		mix_into(b, metal(0.18, 1650.0, 0.06), k * 0.12, 0.45)
	return normalize(reverb(b, 0.4, 0.8, 1.0), 0.9)


func r_relay_click(_v: int) -> PackedFloat32Array:
	var b := make(1.0)
	for k in 6:
		mix_into(b, burst(0.02, 7000.0, 1500.0, 0.004), k * 0.11 + rng.randf_range(0.0, 0.03), 0.6)
	mix_into(b, r_keypad_success(0), 0.7, 0.3)
	return normalize(b, 0.6)


func r_pa_chime(_v: int) -> PackedFloat32Array:
	var b := make(2.0)
	mix_into(b, note(1.4, 659.25, 0.5, 0.25), 0.0, 0.6)
	mix_into(b, note(1.4, 523.25, 0.5, 0.25), 0.5, 0.6)
	bandpass(b, 300.0, 3500.0, 0.5)
	return normalize(reverb(b, 0.5, 0.9, 1.2), 0.55)


func r_radio_static(_v: int) -> PackedFloat32Array:
	var b := noise(1.6)
	bandpass(b, 1200.0, 2600.0, 0.8)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= 0.4 + 0.6 * absf(sin(t * TAU_F * 3.1))
	mix_into(b, r_keypad_beep(0), 1.3, 0.6)
	return normalize(fade(b, 0.02, 0.1), 0.5)


func r_amb_station_loop(_v: int) -> PackedFloat32Array:
	# Tunnel air pushed by trains far away, and water finding its way down.
	var dur := 24.0
	var wind := noise(dur + 1.0)
	bandpass(wind, 120.0, 260.0, 0.6)
	lowpass(wind, 500.0)
	for i in wind.size():
		var t := float(i) / RATE
		wind[i] *= 0.5 + 0.35 * sin(t * TAU_F / 11.0) + 0.15 * sin(t * TAU_F / 3.7)
	var b := loopify(wind, 1.0)
	var deep := brown(dur + 1.0)
	lowpass(deep, 70.0)
	mix_into(b, loopify(deep, 1.0), 0.0, 0.5)
	for k in 9:
		var drip := note(0.5, rng.randf_range(900.0, 1500.0), 0.08, 0.2)
		mix_wrap(b, drip, rng.randf_range(0.0, dur), 0.1)
	return normalize(reverb_loop(b, 0.35, 0.85), 0.55)
