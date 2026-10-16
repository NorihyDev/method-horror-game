class_name ItemDefinition
extends Resource
## Inventory item data. Gameplay logic refers to items by `id` only.

@export var id: StringName = &""
@export var name_key: String = ""
@export var description_key: String = ""
## Key items cannot be destroyed; if dropped somewhere unreachable they return
## to a recovery point.
@export var is_key_item: bool = true
@export var is_consumable: bool = false
@export var stack_max: int = 1
@export var icon_color: Color = Color(0.85, 0.82, 0.74)
## Procedural preview shape used by the inspect view: box, cylinder, gear, key, belt, battery, fuse, card.
@export var shape: StringName = &"box"
