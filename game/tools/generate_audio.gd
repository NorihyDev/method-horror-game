extends SceneTree
## Renders every SoundSynth recipe to res://assets/audio/generated/*.wav.
## Usage: godot --headless --path game --script res://tools/generate_audio.gd [-- --only=name]

const Synth = preload("res://scripts/audio/sound_synth.gd")
const MapSynth = preload("res://scripts/audio/sound_synth_terror.gd")
const OUT_DIR := "res://assets/audio/generated"


func _initialize() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var synth := MapSynth.new()
	var started := Time.get_ticks_msec()
	var count := 0
	for sound in Synth.SOUNDS:
		if not only.is_empty() and sound != only:
			continue
		var variants: int = Synth.VARIANTS.get(sound, 1)
		for v in variants:
			var file_name: String = sound if variants == 1 else "%s_%d" % [sound, v + 1]
			var samples: PackedFloat32Array = synth.render(sound, v)
			if samples.is_empty():
				push_error("Empty render: " + file_name)
				continue
			var wav: AudioStreamWAV = Synth.to_wav(samples, Synth.SOUNDS[sound])
			var path := "%s/%s.wav" % [OUT_DIR, file_name]
			var err := wav.save_to_wav(path)
			if err != OK:
				push_error("Failed to save %s: %s" % [path, error_string(err)])
			else:
				count += 1
				print("  %-28s %6.2fs" % [file_name, samples.size() / float(Synth.RATE)])
	print("Generated %d sounds in %.1fs" % [count, (Time.get_ticks_msec() - started) / 1000.0])
	quit(0)
