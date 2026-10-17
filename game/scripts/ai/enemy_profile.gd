class_name EnemyProfile
extends RefCounted
## Senses, movement and presentation of one enemy type. The shared state
## machine (`Watcher`) reads these values, so each map's creature behaves by a
## different, readable rule without forking the AI. Rules per creature are
## documented in docs/game-design.md#enemies.

var id := "watcher"
var name_key := "ENEMY_WATCHER"
var rig_style := "watcher"

# Sight ----------------------------------------------------------------------
## False = blind: only touch-range contact counts as "seeing".
var sees := true
var base_sight := 13.0
var fov_half := deg_to_rad(60.0)
## Sight range multipliers by how lit the target is.
var light_flashlight := 1.35
var light_lit := 1.25
var light_dark := 0.55
var crouch_sight := 0.75
var touch_radius := 1.6

# Hearing --------------------------------------------------------------------
## Multiplier on every noise radius it hears.
var hearing := 1.0
## Hunts the source of nearby player-made noise as if it had seen them.
var hunts_by_sound := false
## Player noise within this fraction of its (muffled) radius starts a hunt.
var hunt_fraction := 0.55
## Seconds it keeps tracking after the last sighting / heard noise.
var track_after_lost := 1.4

# Movement -------------------------------------------------------------------
var walk := 1.35
var investigate := 2.1
var run := 4.05

# Presentation ---------------------------------------------------------------
var breath_sound := "watcher_breath_loop"
var breath_db := -3.0
var step_sound := "watcher_step"
## Periodic positional cue while not hunting (keys, beeps, a whistle).
var cue_sound := "watcher_keys"
var cue_interval := Vector2(9.0, 18.0)
var growl_sound := "watcher_growl"
var screech_sound := "watcher_screech"
var attack_sound := "watcher_attack"
## Head-mounted lamp that lights what it looks at (visible beam = warning cue).
var headlamp := false

# Special rules ----------------------------------------------------------------
## Cannot move while a living player looks at it in light (their flashlight
## on it, or it standing in a lit room).
var freezes_when_watched := false
## How far a watching player's gaze holds it, and how wide their gaze counts.
var watched_range := 20.0
var watched_fov_half := deg_to_rad(32.0)


static func for_id(profile_id: String) -> EnemyProfile:
	match profile_id:
		"sister":
			return sister()
		"lineman":
			return lineman()
		"headmistress":
			return headmistress()
		"subject":
			return subject_dark()
	return watcher()


## Map 1. Sight cone that reaches farther when you are lit; hears noise.
static func watcher() -> EnemyProfile:
	return EnemyProfile.new()


## Map 2. Blind; hunts by sound. Light is irrelevant, silence is safety:
## standing still or crouch-walking is almost inaudible, walking within a few
## meters or any loud action draws a direct hunt. She hums while wandering.
static func sister() -> EnemyProfile:
	var p := EnemyProfile.new()
	p.id = "sister"
	p.name_key = "ENEMY_SISTER"
	p.rig_style = "sister"
	p.sees = false
	p.touch_radius = 1.9
	p.hearing = 1.35
	p.hunts_by_sound = true
	p.hunt_fraction = 0.55
	p.track_after_lost = 2.6
	p.walk = 1.2
	p.investigate = 2.4
	p.run = 4.3
	p.breath_sound = "sister_hum_loop"
	p.breath_db = -5.0
	p.step_sound = "sister_step"
	p.cue_sound = ""
	p.growl_sound = "sister_hiss"
	p.screech_sound = "sister_shriek"
	p.attack_sound = "sister_attack"
	return p


## Map 3. A narrow headlamp beam it sees along — far, but only where it
## points; your own light level does not matter. Ordinary hearing, which
## passing trains drown out for everyone near the tracks.
static func lineman() -> EnemyProfile:
	var p := EnemyProfile.new()
	p.id = "lineman"
	p.name_key = "ENEMY_LINEMAN"
	p.rig_style = "lineman"
	p.base_sight = 17.0
	p.fov_half = deg_to_rad(28.0)
	p.light_flashlight = 1.0
	p.light_lit = 1.0
	p.light_dark = 1.0
	p.crouch_sight = 0.8
	p.hearing = 0.9
	p.track_after_lost = 1.8
	p.walk = 1.45
	p.investigate = 2.2
	p.run = 4.0
	p.breath_sound = "lineman_breath_loop"
	p.step_sound = "lineman_step"
	p.cue_sound = "lineman_whistle"
	p.cue_interval = Vector2(12.0, 22.0)
	p.growl_sound = "lineman_growl"
	p.screech_sound = "lineman_screech"
	p.attack_sound = "watcher_attack"
	p.headlamp = true
	return p


## Map 4. Sees and hears like the Watcher but moves only while nobody is
## looking at her in light: hold her with a flashlight or a lit room, and she
## is fast the moment every gaze leaves her. Heels clicking on the parquet.
static func headmistress() -> EnemyProfile:
	var p := EnemyProfile.new()
	p.id = "headmistress"
	p.name_key = "ENEMY_HEADMISTRESS"
	p.rig_style = "headmistress"
	p.base_sight = 14.0
	p.light_flashlight = 1.3
	p.light_lit = 1.2
	p.hearing = 1.1
	p.walk = 1.6
	p.investigate = 2.6
	p.run = 4.6
	p.track_after_lost = 1.6
	p.breath_sound = "headmistress_breath_loop"
	p.breath_db = -8.0
	p.step_sound = "headmistress_step"
	p.cue_sound = "headmistress_chalk"
	p.cue_interval = Vector2(10.0, 20.0)
	p.growl_sound = "headmistress_hush"
	p.screech_sound = "headmistress_scream"
	p.attack_sound = "watcher_attack"
	p.freezes_when_watched = true
	return p


## Map 5 before the power returns: Subject Zero is blind in the dark and
## hunts by sound like the Sister (the facility's first trial).
static func subject_dark() -> EnemyProfile:
	var p := sister()
	p.id = "subject"
	p.name_key = "ENEMY_SUBJECT"
	p.rig_style = "subject"
	p.hearing = 1.25
	p.walk = 1.3
	p.breath_sound = "subject_breath_loop"
	p.breath_db = -4.0
	p.step_sound = "subject_step"
	p.growl_sound = "subject_growl"
	p.screech_sound = "subject_screech"
	p.attack_sound = "watcher_attack"
	return p


## Map 5 once the lights are on: Subject Zero's eyes work again. It sees like
## the Watcher (farther when you are lit) and keeps its sharp hearing.
static func subject_lit() -> EnemyProfile:
	var p := watcher()
	p.id = "subject"
	p.name_key = "ENEMY_SUBJECT"
	p.rig_style = "subject"
	p.base_sight = 14.0
	p.hearing = 1.15
	p.walk = 1.4
	p.investigate = 2.3
	p.run = 4.2
	p.breath_sound = "subject_breath_loop"
	p.breath_db = -4.0
	p.step_sound = "subject_step"
	p.cue_sound = ""
	p.growl_sound = "subject_growl"
	p.screech_sound = "subject_screech"
	p.attack_sound = "watcher_attack"
	return p
