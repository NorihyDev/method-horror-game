class_name CharacterCatalog
extends RefCounted
## Playable characters: who your teammates see you as in co-op (the local
## player is first person). Built from photos of real people who agreed to
## it; see docs/characters.md. Purely visual, free, no gameplay effect.

const DEFAULT := "norihy"
## In picker order: Norihy first.
const CHARACTERS := {
	"norihy":
	{
		"name": "Norihy",
		"scene": "res://assets/characters/norihy/norihy.glb",
		"portrait": "res://assets/characters/norihy/portrait.png",
	},
	"punky":
	{
		"name": "Punky",
		"scene": "res://assets/characters/punky/punky.glb",
		"portrait": "res://assets/characters/punky/portrait.png",
	},
	"tsila":
	{
		"name": "Tsila",
		"scene": "res://assets/characters/tsila/tsila.glb",
		"portrait": "res://assets/characters/tsila/portrait.png",
	},
	"mianja":
	{
		"name": "Mianja",
		"scene": "res://assets/characters/mianja/mianja.glb",
		"portrait": "res://assets/characters/mianja/portrait.png",
	},
	"paulino":
	{
		"name": "Paulino",
		"scene": "res://assets/characters/paulino/paulino.glb",
		"portrait": "res://assets/characters/paulino/portrait.png",
	},
	"nox":
	{
		"name": "Nox",
		"scene": "res://assets/characters/nox/nox.glb",
		"portrait": "res://assets/characters/nox/portrait.png",
	},
	"ninja":
	{
		"name": "Ninja",
		"scene": "res://assets/characters/ninja/ninja.glb",
		"portrait": "res://assets/characters/ninja/portrait.png",
	},
}


static func ids() -> PackedStringArray:
	return PackedStringArray(CHARACTERS.keys())


## Untrusted input (another player's choice) -> a known id.
static func sanitize(value: Variant) -> String:
	var id := str(value) if value is String or value is StringName else ""
	return id if CHARACTERS.has(id) else DEFAULT


static func scene_path(id: String) -> String:
	return str(CHARACTERS[sanitize(id)]["scene"])


static func display_name(id: String) -> String:
	return str(CHARACTERS[sanitize(id)]["name"])


static func portrait(id: String) -> Texture2D:
	var path := str(CHARACTERS[sanitize(id)]["portrait"])
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
