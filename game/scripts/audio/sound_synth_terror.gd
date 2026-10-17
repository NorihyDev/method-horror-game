class_name SoundSynthTerror
extends SoundSynthFinale
## Scare sounds: the scream that comes with being caught, and the small
## frights the ScareDirector plays between encounters. Inherits every earlier
## recipe; the generator renders through this class.


## A human-ish shriek: detuned saws through vowel formants, pitch leaping up
## then cracking down, with breath noise and a low body hit under it.
func scream_core(dur: float, f0: float, crack: float) -> PackedFloat32Array:
	var b := make(dur)
	for k in 6:
		var detune := 1.0 + (k - 2.5) * 0.011
		var s := make(dur)
		var phase := 0.0
		for i in s.size():
			var t := float(i) / RATE
			var u := t / dur
			# Leap up fast, hold with a ragged vibrato, crack downward at the end.
			var pitch := f0 * (0.55 + 0.45 * minf(1.0, t / 0.07))
			pitch *= 1.0 + 0.035 * sin(t * TAU_F * (6.5 + k * 0.4)) + 0.02 * sin(t * TAU_F * 31.0)
			pitch *= lerpf(1.0, crack, smoothstep(0.62, 1.0, u))
			phase += pitch * detune / RATE
			s[i] = 2.0 * fmod(phase, 1.0) - 1.0
		mix_into(b, s, 0.0, 0.2)
	# "Ah/ee" formants.
	var f1 := b.duplicate()
	bandpass(f1, 850.0, 700.0, 4.0)
	var f2 := b.duplicate()
	bandpass(f2, 2300.0, 2700.0, 5.0)
	var f3 := b.duplicate()
	bandpass(f3, 3400.0, 3000.0, 6.0)
	var out := make(dur)
	mix_into(out, f1, 0.0, 1.0)
	mix_into(out, f2, 0.0, 0.8)
	mix_into(out, f3, 0.0, 0.5)
	var breath := noise(dur)
	bandpass(breath, 2600.0, 3600.0, 1.2)
	mix_into(out, breath, 0.0, 0.35)
	for i in out.size():
		var t := float(i) / RATE
		out[i] *= minf(1.0, t / 0.02) * (1.0 - smoothstep(dur * 0.8, dur, t))
	return out


func r_scare_scream(_v: int) -> PackedFloat32Array:
	var dur := 2.0
	var b := scream_core(dur, 980.0, 0.6)
	mix_into(b, scale(scream_core(dur, 1310.0, 0.5), 0.6), 0.03, 1.0)
	mix_into(b, thump(0.9, 90.0, 30.0, 0.35), 0.0, 1.6)
	mix_into(b, burst(0.3, 6000.0, 200.0, 0.06), 0.0, 1.0)
	return normalize(reverb(saturate(b, 3.0), 0.25, 0.6, 0.7), 0.98)


func r_scare_scream_far(_v: int) -> PackedFloat32Array:
	var b := scream_core(2.4, 760.0, 0.55)
	lowpass(b, 1800.0)
	return normalize(reverb(b, 0.75, 0.92, 2.2), 0.7)


## Breathy syllables right at the ear: unvoiced formant noise in short bursts.
func r_scare_whisper(_v: int) -> PackedFloat32Array:
	var dur := 2.6
	var b := make(dur)
	var t0 := 0.05
	var centres := [3200.0, 2400.0, 4100.0, 2800.0, 3600.0, 2100.0, 3900.0]
	for k in centres.size():
		var syl := rng.randf_range(0.16, 0.34)
		var n := noise(syl)
		bandpass(n, centres[k], centres[k] * rng.randf_range(0.8, 1.2), 2.5)
		var hiss := noise(syl)
		highpass(hiss, 5000.0)
		mix_into(n, hiss, 0.0, 0.25)
		for i in n.size():
			n[i] *= pow(sin(float(i) / n.size() * PI), 1.5)
		mix_into(b, n, t0, 1.0)
		t0 += syl + rng.randf_range(0.02, 0.12)
		if t0 > dur - 0.4:
			break
	return normalize(reverb(b, 0.15, 0.3, 0.3), 0.75)


## Three slow knocks on a wall, the last one harder.
func r_scare_knock(_v: int) -> PackedFloat32Array:
	var b := make(2.6)
	for k in 3:
		var hit := make(0.4)
		mix_into(hit, thump(0.35, 160.0, 90.0, 0.06), 0.0, 1.0)
		mix_into(hit, burst(0.08, 2500.0, 300.0, 0.015), 0.0, 0.6)
		mix_into(b, hit, 0.1 + k * 0.62, 0.7 + 0.25 * k)
	return normalize(reverb(b, 0.3, 0.6, 0.8), 0.95)


## Something heavy sprinting past: fast irregular footfalls.
func r_scare_run(_v: int) -> PackedFloat32Array:
	var dur := 2.2
	var b := make(dur)
	var t := 0.0
	while t < dur - 0.4:
		var step := make(0.3)
		mix_into(step, thump(0.25, 95.0, 45.0, 0.07), 0.0, 1.0)
		mix_into(step, burst(0.1, 1800.0, 80.0, 0.03), 0.0, 0.7)
		mix_into(b, step, t, rng.randf_range(0.7, 1.0))
		t += rng.randf_range(0.17, 0.24)
	return normalize(reverb(b, 0.25, 0.6, 0.6), 0.9)


## One sharp breath in, close behind the head.
func r_scare_breath_close(_v: int) -> PackedFloat32Array:
	var dur := 1.5
	var b := noise(dur)
	bandpass(b, 700.0, 1600.0, 1.4)
	var wet := noise(dur)
	bandpass(wet, 2500.0, 3500.0, 3.0)
	mix_into(b, wet, 0.0, 0.3)
	for i in b.size():
		var x := float(i) / RATE
		var inhale := smoothstep(0.0, 0.35, x) * (1.0 - smoothstep(0.45, 0.6, x))
		var exhale := smoothstep(0.75, 0.85, x) * (1.0 - smoothstep(0.9, 1.45, x)) * 0.7
		b[i] *= inhale + exhale
	return normalize(b, 0.8)


## A bulb bursting: glassy crack and a sprinkle of fragments.
func r_bulb_pop(_v: int) -> PackedFloat32Array:
	var b := make(1.2)
	mix_into(b, burst(0.15, 9000.0, 1500.0, 0.03), 0.0, 1.0)
	mix_into(b, thump(0.2, 220.0, 120.0, 0.04), 0.0, 0.5)
	for k in 9:
		var tink := tone(0.12, rng.randf_range(3500.0, 7000.0), "sine")
		env_perc(tink, 0.001, 0.03)
		mix_into(b, tink, 0.12 + rng.randf_range(0.0, 0.6), rng.randf_range(0.08, 0.25))
	return normalize(reverb(b, 0.3, 0.6, 0.6), 0.85)


## A short orchestral stab for a hit or a figure that vanishes.
func r_scare_hit(_v: int) -> PackedFloat32Array:
	var dur := 1.3
	var b := make(dur)
	for f in [92.5, 98.0, 138.6, 196.0, 207.7, 277.2, 293.7, 415.3]:
		mix_into(b, tone(dur, f, "saw", rng.randf_range(-0.006, 0.006)), 0.0, 0.1)
	lowpass(b, 4200.0)
	mix_into(b, burst(0.4, 7000.0, 150.0, 0.08), 0.0, 1.0)
	mix_into(b, thump(0.6, 60.0, 30.0, 0.2), 0.0, 1.2)
	env_perc(b, 0.002, 0.3)
	return normalize(reverb(saturate(b, 2.2), 0.3, 0.7, 0.9), 0.95)


## A rising, dissonant swell under a figure that is watching.
func r_phantom_drone(_v: int) -> PackedFloat32Array:
	var dur := 2.4
	var b := make(dur)
	for f in [55.0, 58.3, 82.4, 116.5]:
		mix_into(b, tone(dur, f, "saw", rng.randf_range(-0.003, 0.003)), 0.0, 0.2)
	var air := noise(dur)
	bandpass(air, 300.0, 2400.0, 0.8)
	mix_into(b, air, 0.0, 0.4)
	lowpass(b, 1600.0)
	for i in b.size():
		var t := float(i) / b.size()
		b[i] *= t * t
	return normalize(reverb(b, 0.4, 0.8, 0.8), 0.8)
