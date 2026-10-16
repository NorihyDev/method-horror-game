class_name IntensityController
extends Node
## Chooses music and body sounds from threat proximity, enemy state and match
## phase. Changes are crossfaded and rate-limited so music never flip-flops.

const MIN_STATE_TIME := 6.0

enum Level { CALM, TENSION, CHASE }

var match_ctrl: MatchController
var player: PlayerController
var level: Level = Level.CALM
var _since_change := 99.0
var _heartbeat: AudioStreamPlayer
var _breath: AudioStreamPlayer
var _timer := 0.0


func setup(p_match: MatchController, p_player: PlayerController) -> void:
	match_ctrl = p_match
	player = p_player
	_heartbeat = AudioStreamPlayer.new()
	_heartbeat.bus = AudioService.BUS_SFX
	_heartbeat.stream = AudioService.stream("heartbeat_loop")
	_heartbeat.volume_db = -60.0
	add_child(_heartbeat)
	_breath = AudioStreamPlayer.new()
	_breath.bus = AudioService.BUS_SFX
	_breath.stream = AudioService.stream("player_breath_loop")
	_breath.volume_db = -60.0
	add_child(_breath)


func _process(delta: float) -> void:
	if match_ctrl == null or player == null:
		return
	_since_change += delta
	_timer -= delta
	var nearest := INF
	var chasing_me := false
	for e in match_ctrl.enemies:
		if is_instance_valid(e):
			var d := (e as Node3D).global_position.distance_to(player.global_position)
			nearest = minf(nearest, d)
			if e is Watcher and (e as Watcher).state in [Watcher.S.CHASE, Watcher.S.ATTACK] and d < 25.0:
				chasing_me = true
	# Body sounds: heartbeat when it is close, breathing when exhausted.
	var heart := clampf(1.0 - (nearest - 3.0) / 9.0, 0.0, 1.0) if nearest < INF else 0.0
	_fade(_heartbeat, heart, delta, -8.0)
	_heartbeat.pitch_scale = lerpf(1.0, 1.6, heart)
	_fade(_breath, clampf((0.4 - player.stamina) / 0.4, 0.0, 1.0), delta, -6.0)
	if _timer > 0.0:
		return
	_timer = 0.5
	var wanted := Level.CALM
	if chasing_me:
		wanted = Level.CHASE
	elif match_ctrl.state.phase >= MatchState.Phase.ESCALATE or nearest < 18.0 or match_ctrl.state.has_flag("enemy_arrived"):
		wanted = Level.TENSION
	if wanted != level and (_since_change >= MIN_STATE_TIME or wanted == Level.CHASE):
		level = wanted
		_since_change = 0.0
		var def := match_ctrl.map_def
		match level:
			Level.CHASE:
				AudioService.play_music(String(def.chase_music), 0.8, -2.0)
			Level.TENSION:
				AudioService.play_music(String(def.tension_music), 3.0, -6.0)
			_:
				AudioService.stop_music(3.0)


func _fade(p: AudioStreamPlayer, k: float, delta: float, max_db: float) -> void:
	if k > 0.01 and not p.playing:
		p.play()
	var target := lerpf(-50.0, max_db, k) if k > 0.01 else -60.0
	p.volume_db = move_toward(p.volume_db, target, delta * 40.0)
	if k <= 0.01 and p.volume_db <= -59.0 and p.playing:
		p.stop()


func stop() -> void:
	_heartbeat.stop()
	_breath.stop()
