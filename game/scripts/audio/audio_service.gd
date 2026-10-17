extends Node
## Autoload "AudioService": buses, effects, pooled playback, music/ambience
## crossfades and sound captions.

signal caption_requested(text_key: String, direction_deg: float, duration: float)
signal subtitle_requested(speaker_key: String, text_key: String, duration: float)

const SOUND_DIR := "res://assets/audio/generated/"
const BUS_MUSIC := &"Music"
const BUS_AMBIENCE := &"Ambience"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"
const UI_POOL_SIZE := 4

## Sounds that produce a caption when "sound captions" is enabled.
const CAPTIONS := {
	"watcher_step": "CAP_HEAVY_STEPS",
	"watcher_growl": "CAP_GROWL",
	"watcher_screech": "CAP_SCREECH",
	"watcher_keys": "CAP_KEYS",
	"watcher_breath_loop": "CAP_BREATHING",
	"lineman_breath_loop": "CAP_BREATHING",
	"door_creak": "CAP_DOOR",
	"door_close": "CAP_DOOR_SHUT",
	"short_circuit": "CAP_SHORT",
	"distant_impact": "CAP_IMPACT",
	"creak": "CAP_CREAK",
	"garage_loop": "CAP_GARAGE",
	"power_on": "CAP_POWER",
	"crank_clank": "CAP_CLANK",
	"drop": "CAP_DROP",
	"ping": "CAP_PING",
	"sister_hum_loop": "CAP_HUMMING",
	"sister_hiss": "CAP_HISS",
	"sister_shriek": "CAP_SHRIEK",
	"sister_step": "CAP_SHUFFLE",
	"breaker_trip": "CAP_BREAKER_TRIP",
	"generator_start": "CAP_GENERATOR",
	"card_deny": "CAP_CARD_DENIED",
	"lineman_whistle": "CAP_WHISTLE",
	"lineman_step": "CAP_HEAVY_STEPS",
	"lineman_growl": "CAP_GROWL",
	"lineman_screech": "CAP_SCREECH",
	"train_pass": "CAP_TRAIN",
	"train_arrive": "CAP_TRAIN_ARRIVING",
	"signal_bell": "CAP_ALARM_BELL",
	"pa_chime": "CAP_PA",
	"music_box_loop": "CAP_MUSIC_BOX",
	"chime_1": "CAP_CHIME_1",
	"chime_2": "CAP_CHIME_2",
	"chime_3": "CAP_CHIME_3",
	"chime_4": "CAP_CHIME_4",
	"chime_wrong": "CAP_CHIME_WRONG",
	"headmistress_breath_loop": "CAP_SLOW_BREATHING",
	"headmistress_step": "CAP_HEELS",
	"headmistress_chalk": "CAP_CHALK",
	"headmistress_hush": "CAP_HUSH",
	"headmistress_scream": "CAP_SCREAM",
	"subject_breath_loop": "CAP_RASPING",
	"subject_step": "CAP_CHAIN_STEPS",
	"subject_growl": "CAP_GROWL",
	"subject_screech": "CAP_SCREECH",
	"lift_call": "CAP_LIFT_MOTOR",
	"lift_arrive": "CAP_LIFT_ARRIVING",
	"scare_scream_far": "CAP_DISTANT_SCREAM",
	"scare_whisper": "CAP_WHISPER",
	"scare_knock": "CAP_KNOCKING",
	"scare_run": "CAP_RUNNING",
	"scare_breath_close": "CAP_BREATH_BEHIND",
	"bulb_pop": "CAP_BULB",
}

## Looping emitters are re-captioned at most this often while audible.
const LOOP_CAPTION_INTERVAL := 6.0
## An emitter counts as audible within this share of its max distance.
const AUDIBLE_SHARE := 0.75

## Variant counts must match SoundSynth.VARIANTS.
const VARIANTS := {
	"step_wood": 4,
	"step_concrete": 4,
	"step_carpet": 4,
	"step_metal": 4,
	"distant_impact": 3,
	"creak": 3,
	"door_creak": 2,
}

var _cache: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current := ""
var _ambience: AudioStreamPlayer
var _ambience_current := ""
var _ui_pool: Array[AudioStreamPlayer] = []
var _ui_index := 0
var _caption_cooldowns: Dictionary = {}
## Captioned emitters from make_emitter(), checked while they play.
var _emitters: Array[AudioStreamPlayer3D] = []
var _emitter_check := 0.0
var _muffle_target := 20500.0
var _muffle_effect_sfx: AudioEffectLowPassFilter
var _muffle_effect_amb: AudioEffectLowPassFilter
var _compressor: AudioEffectCompressor
var _mono: AudioEffectStereoEnhance
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_setup_buses()
	_music_a = _make_player(BUS_MUSIC)
	_music_b = _make_player(BUS_MUSIC)
	_ambience = _make_player(BUS_AMBIENCE)
	for i in UI_POOL_SIZE:
		_ui_pool.append(_make_player(BUS_UI))
	apply_all()
	Settings.changed.connect(_on_setting_changed)


func _process(delta: float) -> void:
	var cutoff := _muffle_effect_sfx.cutoff_hz
	if absf(cutoff - _muffle_target) > 10.0:
		var next := lerpf(cutoff, _muffle_target, clampf(delta * 6.0, 0.0, 1.0))
		_muffle_effect_sfx.cutoff_hz = next
		_muffle_effect_amb.cutoff_hz = next
	_emitter_check -= delta
	if _emitter_check <= 0.0:
		_emitter_check = 0.5
		_caption_emitters()


## Long sounds from emitters (humming, passing trains, motors) caption while
## they play within earshot, not just when they start.
func _caption_emitters() -> void:
	# Freed emitters drop out here (a typed filter lambda cannot take a freed object).
	for i in range(_emitters.size() - 1, -1, -1):
		if not is_instance_valid(_emitters[i]):
			_emitters.remove_at(i)
	if _emitters.is_empty() or not Settings.b("sound_captions"):
		return
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam == null:
		return
	for e in _emitters:
		if not e.is_inside_tree() or not e.playing:
			continue
		if e.global_position.distance_to(cam.global_position) > e.max_distance * AUDIBLE_SHARE:
			continue
		_maybe_caption(str(e.get_meta("sound", "")), e.global_position, e, LOOP_CAPTION_INTERVAL)


func _setup_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_AMBIENCE, BUS_SFX, BUS_UI]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")
	_compressor = AudioEffectCompressor.new()
	_compressor.threshold = -22.0
	_compressor.ratio = 6.0
	_compressor.gain = 6.0
	_mono = AudioEffectStereoEnhance.new()
	_mono.pan_pullout = 0.0
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, _compressor, 0)
	AudioServer.add_bus_effect(0, _mono, 1)
	AudioServer.add_bus_effect(0, limiter, 2)
	_muffle_effect_sfx = AudioEffectLowPassFilter.new()
	_muffle_effect_sfx.cutoff_hz = 20500.0
	_muffle_effect_amb = AudioEffectLowPassFilter.new()
	_muffle_effect_amb.cutoff_hz = 20500.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(BUS_SFX), _muffle_effect_sfx)
	AudioServer.add_bus_effect(AudioServer.get_bus_index(BUS_AMBIENCE), _muffle_effect_amb)


func apply_all() -> void:
	_set_bus_volume(&"Master", Settings.f("vol_master"))
	_set_bus_volume(BUS_MUSIC, Settings.f("vol_music"))
	_set_bus_volume(BUS_AMBIENCE, Settings.f("vol_ambience"))
	_set_bus_volume(BUS_SFX, Settings.f("vol_sfx"))
	_set_bus_volume(BUS_UI, Settings.f("vol_ui"))
	AudioServer.set_bus_mute(0, Settings.b("mute"))
	AudioServer.set_bus_effect_enabled(0, 0, Settings.s("dynamic_range") == "night")
	AudioServer.set_bus_effect_enabled(0, 1, Settings.b("mono_audio"))


## Preview a volume without persisting (settings screen sliders).
func preview_volume(key: String, value: float) -> void:
	var bus: StringName = (
		{
			"vol_master": &"Master",
			"vol_music": BUS_MUSIC,
			"vol_ambience": BUS_AMBIENCE,
			"vol_sfx": BUS_SFX,
			"vol_ui": BUS_UI,
		}
		. get(key, &"")
	)
	if bus != &"":
		_set_bus_volume(bus, value)


func _set_bus_volume(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001 if bus != &"Master" else Settings.b("mute"))


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key.begins_with("vol_") or key in ["mute", "dynamic_range", "mono_audio"]:
		apply_all()


## Returns a stream by base name. Variant sounds pick a random variant when
## `variant` < 0.
func stream(sound: String, variant: int = -1) -> AudioStream:
	var file_name := sound
	if VARIANTS.has(sound):
		var count: int = VARIANTS[sound]
		var v := variant if variant >= 0 else _rng.randi_range(0, count - 1)
		file_name = "%s_%d" % [sound, (v % count) + 1]
	if _cache.has(file_name):
		return _cache[file_name]
	var path := SOUND_DIR + file_name + ".wav"
	if not ResourceLoader.exists(path):
		Log.warn("audio", "Missing sound", {"name": file_name})
		_cache[file_name] = null
		return null
	var res: AudioStream = load(path)
	if res is AudioStreamWAV and sound.ends_with("_loop"):
		var wav: AudioStreamWAV = res
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_cache[file_name] = res
	return res


func play_ui(sound: String, volume_db: float = 0.0) -> void:
	var s := stream(sound)
	if s == null:
		return
	var p := _ui_pool[_ui_index]
	_ui_index = (_ui_index + 1) % _ui_pool.size()
	p.stream = s
	p.volume_db = volume_db
	p.play()


## Non-positional one-shot (player's own sounds). Returns the player.
func play_2d(sound: String, bus: StringName = BUS_SFX, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var s := stream(sound)
	if s == null:
		return null
	var p := _make_player(bus)
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Positional one-shot attached to `parent` (usually the level root).
func play_3d(
	sound: String,
	parent: Node,
	position: Vector3,
	volume_db: float = 0.0,
	max_distance: float = 30.0,
	pitch: float = 1.0
) -> AudioStreamPlayer3D:
	var s := stream(sound)
	if s == null or parent == null or not parent.is_inside_tree():
		return null
	var p := AudioStreamPlayer3D.new()
	p.bus = BUS_SFX
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch * _rng.randf_range(0.96, 1.04)
	p.max_distance = max_distance
	p.unit_size = 4.0
	p.attenuation_filter_cutoff_hz = 3500.0
	p.attenuation_filter_db = -18.0
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.global_position = position
	p.play()
	_maybe_caption(sound, position, p)
	return p


## Looping positional emitter owned by the caller.
func make_emitter(sound: String, volume_db: float = 0.0, max_distance: float = 20.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = BUS_SFX
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 3.0
	p.attenuation_filter_cutoff_hz = 3000.0
	p.attenuation_filter_db = -20.0
	if CAPTIONS.has(sound):
		p.set_meta("sound", sound)
		_emitters.append(p)
	return p


func play_music(sound: String, fade_time: float = 2.0, volume_db: float = 0.0) -> void:
	if sound == _music_current:
		return
	_music_current = sound
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	if not sound.is_empty():
		incoming.stream = stream(sound)
		incoming.volume_db = -60.0
		incoming.play()
		create_tween().tween_property(incoming, "volume_db", volume_db, fade_time)
	if outgoing.playing:
		var t := create_tween()
		t.tween_property(outgoing, "volume_db", -60.0, fade_time)
		t.tween_callback(outgoing.stop)


func stop_music(fade_time: float = 1.5) -> void:
	play_music("", fade_time)


func play_ambience(sound: String, fade_time: float = 2.0, volume_db: float = 0.0) -> void:
	if sound == _ambience_current and _ambience.playing:
		return
	_ambience_current = sound
	var t := create_tween()
	if _ambience.playing:
		t.tween_property(_ambience, "volume_db", -60.0, fade_time * 0.5)
	t.tween_callback(
		func() -> void:
			if sound.is_empty():
				_ambience.stop()
				return
			_ambience.stream = stream(sound)
			_ambience.volume_db = -60.0
			_ambience.play()
	)
	if not sound.is_empty():
		t.tween_property(_ambience, "volume_db", volume_db, fade_time)


func stop_all_world() -> void:
	stop_music(1.0)
	play_ambience("", 1.0)
	set_muffled(false)


## Muffles SFX/ambience, e.g. while hiding in a locker.
func set_muffled(on: bool) -> void:
	_muffle_target = 900.0 if on else 20500.0


## Plays a voice-like clip and shows a subtitle with a speaker label.
func play_dialogue(sound: String, speaker_key: String, text_key: String, duration: float) -> void:
	play_2d(sound, BUS_SFX, -4.0)
	if Settings.b("subtitles"):
		subtitle_requested.emit(speaker_key, text_key, duration)


func _maybe_caption(sound: String, position: Vector3, _player: Node, cooldown: float = 2.5) -> void:
	if CAPTIONS.has(sound):
		caption_at(CAPTIONS[sound], position, cooldown)


## Shows a sound caption (when enabled) for a cue that is not a single sound
## id, e.g. a state of a repeating sound. Rate-limited per caption.
func caption_at(text_key: String, position: Vector3, cooldown: float = 2.5) -> void:
	if not Settings.b("sound_captions"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_caption_cooldowns.get(text_key, 0.0)):
		return
	_caption_cooldowns[text_key] = now + cooldown
	var direction := 0.0
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam:
		var local := cam.global_transform.affine_inverse() * position
		direction = rad_to_deg(atan2(local.x, -local.z))
	caption_requested.emit(text_key, direction, 2.5)


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p
