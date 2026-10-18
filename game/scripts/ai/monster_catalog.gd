class_name MonsterCatalog
extends RefCounted
## Imported monster models, one per enemy style (and so per map). Built from
## third-party packs by tools/monsters/ (see docs/monsters.md). When a model
## is missing, WatcherRig falls back to its procedural body.

## style -> {scene, height (m, rest), target height (m), head bone, lamp?}
const MODELS := {
	# The House: an emaciated thing in a top hat.
	"watcher":
	{
		"scene": "res://assets/monsters/frankie/frankie.glb",
		"source_height": 4.201,
		"height": 1.9,
		"head": "head",
	},
	# The Black Ward: a plague doctor.
	"sister":
	{
		"scene": "res://assets/monsters/doctor/doctor.glb",
		"source_height": 2.003,
		"height": 2.0,
		"head": "head",
	},
	# Last Train: a miner whose helmet lamp sweeps the tunnels.
	"lineman":
	{
		"scene": "res://assets/monsters/miner/miner.glb",
		"source_height": 2.0,
		"height": 1.98,
		"head": "head",
		"lamp": Vector3(0.0, 0.17, 0.09),
	},
	# The Silent School: a clown.
	"headmistress":
	{
		"scene": "res://assets/monsters/clown/clown.glb",
		"source_height": 1.86,
		"height": 1.95,
		"head": "head",
	},
	# METHOD Facility: Subject Zero, a creature.
	"subject":
	{
		"scene": "res://assets/monsters/gravvok/gravvok.glb",
		"source_height": 8.479,
		"height": 2.05,
		"head": "",
	},
}


static func entry(style: String) -> Dictionary:
	var e: Dictionary = MODELS.get(style, {})
	if e.is_empty() or not ResourceLoader.exists(str(e["scene"])):
		return {}
	return e
