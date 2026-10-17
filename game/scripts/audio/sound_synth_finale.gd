class_name SoundSynthFinale
extends SoundSynthMaps
## Recipes for The Silent School and the METHOD Facility. Split from the
## other recipe files to keep each one readable; the generator instantiates
## this class, which inherits every earlier recipe.

## Chime bar pitches, lowest (bar 1) to highest (bar 4): C5, E5, G5, C6.
const CHIME_FREQS: Array[float] = [523.25, 659.25, 783.99, 1046.5]

# --- The Silent School -----------------------------------------------------------


## One struck glockenspiel bar: a bright fundamental and a metallic partial.
func chime_bar(freq: float, seconds: float = 1.8) -> PackedFloat32Array:
	var b := make(seconds)
	mix_into(b, note(seconds, freq, 0.9, 0.55), 0.0, 0.7)
	mix_into(b, note(seconds * 0.6, freq * 2.756, 0.25, 0.3), 0.0, 0.18)
	mix_into(b, burst(0.015, 9000.0, 2500.0, 0.004), 0.0, 0.25)
	return b


func r_chime_1(_v: int) -> PackedFloat32Array:
	return normalize(reverb(chime_bar(CHIME_FREQS[0]), 0.3, 0.7, 0.9), 0.8)


func r_chime_2(_v: int) -> PackedFloat32Array:
	return normalize(reverb(chime_bar(CHIME_FREQS[1]), 0.3, 0.7, 0.9), 0.8)


func r_chime_3(_v: int) -> PackedFloat32Array:
	return normalize(reverb(chime_bar(CHIME_FREQS[2]), 0.3, 0.7, 0.9), 0.8)


func r_chime_4(_v: int) -> PackedFloat32Array:
	return normalize(reverb(chime_bar(CHIME_FREQS[3]), 0.3, 0.7, 0.9), 0.8)


func r_chime_wrong(_v: int) -> PackedFloat32Array:
	# Every bar at once, slightly out of tune, over a dull thud: plainly wrong.
	var b := make(2.4)
	for i in CHIME_FREQS.size():
		mix_into(b, chime_bar(CHIME_FREQS[i] * (1.0 + (i - 1.5) * 0.031), 2.2), i * 0.012, 0.35)
	mix_into(b, thump(0.5, 140.0, 60.0, 0.12), 0.0, 0.8)
	return normalize(reverb(b, 0.4, 0.85, 1.2), 0.9)


func r_music_box_loop(_v: int) -> PackedFloat32Array:
	# A wind-up comb playing a small minor waltz, the spring ticking under it.
	var dur := 9.0
	var b := make(dur)
	var melody := [
		[0.0, 880.0],
		[0.5, 1046.5],
		[1.0, 987.77],
		[1.5, 880.0],
		[2.25, 659.25],
		[3.0, 698.46],
		[3.5, 783.99],
		[4.0, 698.46],
		[4.5, 659.25],
		[5.25, 587.33],
		[6.0, 659.25],
		[6.75, 523.25],
		[7.5, 587.33],
		[8.25, 659.25]
	]
	for n: Array in melody:
		var pluck := note(0.9, float(n[1]) * (1.0 + rng.randf_range(-0.004, 0.004)), 0.4, 0.75)
		mix_wrap(b, pluck, float(n[0]), 0.45)
	var t := 0.0
	while t < dur:
		mix_wrap(b, burst(0.008, 6000.0, 2500.0, 0.002), t, 0.05)
		t += 0.125
	highpass(b, 300.0)
	return normalize(reverb_loop(b, 0.3, 0.6), 0.55)


func r_amb_school_loop(_v: int) -> PackedFloat32Array:
	# Empty classrooms: radiator ticks, wind at the boarded windows, a wall clock.
	var dur := 24.0
	var wind := noise(dur + 1.0)
	bandpass(wind, 300.0, 700.0, 0.7)
	for i in wind.size():
		var s := float(i) / RATE
		wind[i] *= 0.35 + 0.25 * sin(s * TAU_F / 9.0) + 0.1 * sin(s * TAU_F / 2.9)
	var b := loopify(wind, 1.0)
	var room := brown(dur + 1.0)
	lowpass(room, 90.0)
	mix_into(b, loopify(room, 1.0), 0.0, 0.4)
	for k in int(dur):
		mix_wrap(b, burst(0.012, 3500.0, 1200.0, 0.004), float(k), 0.035 if k % 2 == 0 else 0.025)
	for k in 6:
		mix_wrap(b, metal(0.25, rng.randf_range(700.0, 1100.0), 0.05), rng.randf_range(0.0, dur), 0.05)
	return normalize(reverb_loop(b, 0.3, 0.8), 0.5)


func r_headmistress_step(_v: int) -> PackedFloat32Array:
	# A hard heel on parquet: a sharp click with a short wooden body.
	var b := make(0.5)
	mix_into(b, burst(0.03, 7000.0, 1500.0, 0.01), 0.0, 0.8)
	mix_into(b, thump(0.12, 420.0, 260.0, 0.03), 0.0, 0.5)
	return normalize(reverb(b, 0.25, 0.6, 0.5), 0.7)


func r_headmistress_chalk(_v: int) -> PackedFloat32Array:
	# Chalk dragged across a board, squealing on the down-strokes.
	var dur := 1.6
	var b := noise(dur)
	bandpass(b, 1800.0, 2600.0, 3.0)
	var squeal := sweep(dur, 2400.0, 2900.0, "sine", 1.0)
	for i in b.size():
		var t := float(i) / RATE
		var stroke := maxf(0.0, sin(t * TAU_F * 2.2))
		b[i] = (b[i] * 0.7 + squeal[i] * 0.3 * stroke) * stroke * sin(t / dur * PI)
	return normalize(reverb(b, 0.3, 0.7, 0.8), 0.6)


func r_headmistress_hush(_v: int) -> PackedFloat32Array:
	# "Shhh." Long, close, through teeth.
	var dur := 1.4
	var b := noise(dur)
	bandpass(b, 2600.0, 5200.0, 1.0)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= minf(1.0, t / 0.15) * (1.0 - smoothstep(0.9, dur, t))
	return normalize(reverb(b, 0.3, 0.6, 0.6), 0.7)


func r_headmistress_scream(_v: int) -> PackedFloat32Array:
	var dur := 1.6
	var b := make(dur)
	for k in 3:
		var s := sweep(dur, 1500.0 + k * 57.0, 700.0 + k * 40.0, "saw", 0.7)
		bandpass(s, 900.0, 2600.0, 0.9)
		mix_into(b, s, 0.0, 0.3)
	for i in b.size():
		b[i] *= sin(float(i) / b.size() * PI)
	return normalize(reverb(saturate(b, 1.5), 0.35, 0.8, 0.9), 0.9)


func r_headmistress_breath_loop(_v: int) -> PackedFloat32Array:
	# Slow, measured breathing through the nose: patient, never hurried.
	var dur := 8.0
	var b := noise(dur)
	bandpass(b, 500.0, 1100.0, 1.2)
	for i in b.size():
		var t := float(i) / RATE
		var cycle := fmod(t, 4.0) / 4.0
		b[i] *= pow(sin(cycle * PI), 2.0) * 0.6
	return normalize(reverb_loop(b, 0.3, 0.5), 0.4)


# --- METHOD Facility -----------------------------------------------------------------


func r_amb_facility_loop(_v: int) -> PackedFloat32Array:
	# Ventilation and the mains hum of a building that should be empty.
	var dur := 20.0
	var air := noise(dur + 1.0)
	bandpass(air, 180.0, 420.0, 0.6)
	for i in air.size():
		var t := float(i) / RATE
		air[i] *= 0.5 + 0.2 * sin(t * TAU_F / 7.0)
	var b := loopify(air, 1.0)
	var hum := make(dur)
	for i in hum.size():
		var t := float(i) / RATE
		hum[i] = sin(t * TAU_F * 50.0) * 0.25 + sin(t * TAU_F * 100.0) * 0.12 + sin(t * TAU_F * 150.0) * 0.05
	mix_into(b, hum, 0.0, 0.35)
	for k in 4:
		mix_wrap(b, metal(0.6, rng.randf_range(180.0, 320.0), 0.2), rng.randf_range(0.0, dur), 0.08)
	return normalize(reverb_loop(b, 0.3, 0.85), 0.5)


func r_subject_breath_loop(_v: int) -> PackedFloat32Array:
	# A wet rasp through a damaged throat, with clicks between breaths.
	var dur := 7.0
	var b := brown(dur)
	bandpass(b, 300.0, 900.0, 1.4)
	for i in b.size():
		var t := float(i) / RATE
		var cycle := fmod(t, 3.5) / 3.5
		b[i] *= (0.3 + 0.7 * pow(sin(cycle * PI), 3.0)) * (0.8 + 0.2 * sin(t * TAU_F * 31.0))
	for k in 6:
		mix_wrap(b, burst(0.01, 4000.0, 1500.0, 0.003), rng.randf_range(0.0, dur), 0.25)
	return normalize(reverb_loop(b, 0.25, 0.5), 0.55)


func r_subject_step(_v: int) -> PackedFloat32Array:
	# A bare foot slapping the floor and a broken restraint chain clinking.
	var b := make(0.7)
	mix_into(b, thump(0.18, 160.0, 70.0, 0.04), 0.0, 0.8)
	mix_into(b, burst(0.04, 3000.0, 500.0, 0.015), 0.0, 0.35)
	mix_into(b, metal(0.3, 1900.0 + rng.randf_range(-100.0, 100.0), 0.05), 0.06, 0.2)
	return normalize(reverb(b, 0.25, 0.6, 0.5), 0.65)


func r_subject_growl(_v: int) -> PackedFloat32Array:
	var dur := 1.8
	var b := sweep(dur, 95.0, 70.0, "saw", 1.0)
	lowpass(b, 600.0)
	var grit := noise(dur)
	bandpass(grit, 200.0, 800.0, 1.0)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (b[i] * 0.7 + grit[i] * 0.3) * sin(t / dur * PI) * (0.6 + 0.4 * sin(t * TAU_F * 17.0))
	return normalize(reverb(saturate(b, 2.0), 0.3, 0.7, 0.7), 0.85)


func r_subject_screech(_v: int) -> PackedFloat32Array:
	# A shriek with a metallic ring: the apparatus over its eye resonates.
	var dur := 1.7
	var b := make(dur)
	for k in 4:
		var s := sweep(dur, 1700.0 + k * 61.0, 600.0 + k * 45.0, "tri", 0.65)
		mix_into(b, s, 0.0, 0.28)
	mix_into(b, metal(1.2, 1240.0, 0.4), 0.05, 0.25)
	for i in b.size():
		b[i] *= sin(float(i) / b.size() * PI)
	return normalize(reverb(saturate(b, 1.4), 0.35, 0.85, 1.0), 0.9)


func r_lift_call(_v: int) -> PackedFloat32Array:
	# A contactor slams in and a big motor winds up somewhere above.
	var dur := 3.2
	var b := make(dur)
	mix_into(b, r_relay_click(0), 0.0, 0.6)
	var motor := sweep(2.6, 70.0, 140.0, "saw", 0.8)
	lowpass(motor, 900.0)
	for i in motor.size():
		motor[i] *= minf(1.0, float(i) / RATE / 0.8)
	mix_into(b, motor, 0.5, 0.45)
	return normalize(reverb(b, 0.35, 0.85, 1.2), 0.85)


func r_lift_arrive(_v: int) -> PackedFloat32Array:
	# Cables running, the motor winding down, a bell, then the gates rattle open.
	var dur := 7.0
	var b := make(dur)
	var motor := sweep(4.0, 150.0, 60.0, "saw", 1.2)
	lowpass(motor, 800.0)
	for i in motor.size():
		motor[i] *= 1.0 - smoothstep(3.0, 4.0, float(i) / RATE)
	mix_into(b, motor, 0.0, 0.5)
	var cable := noise(4.0)
	bandpass(cable, 900.0, 1500.0, 1.2)
	mix_into(b, cable, 0.0, 0.12)
	mix_into(b, note(1.6, 1318.5, 0.9, 0.5), 4.2, 0.5)
	for k in 8:
		mix_into(b, metal(0.12, 700.0 + k * 35.0, 0.04), 5.0 + k * 0.1, 0.35)
	return normalize(reverb(b, 0.35, 0.9, 1.3), 0.9)
