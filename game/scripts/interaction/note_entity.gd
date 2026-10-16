class_name NoteEntity
extends Interactable
## A readable document. Text comes from translation keys; seeded details
## (e.g. which breaker socket is dead) arrive as public state `args`.

signal read_requested(note: NoteEntity)

@export var title_key := ""
@export var body_key := ""
@export var read_flag := ""
@export var style := "paper"


func _ready() -> void:
	prompt_key = "PROMPT_READ"
	var paper := MaterialLib.flat(Color(0.82, 0.78, 0.68), 0.9)
	match style:
		"clipboard":
			add_mesh(box_mesh(Vector3(0.24, 0.012, 0.32)), MaterialLib.surface("dark_wood"))
			add_mesh(box_mesh(Vector3(0.21, 0.004, 0.28)), paper, Transform3D(Basis.IDENTITY, Vector3(0, 0.008, 0.01)))
			add_mesh(
				box_mesh(Vector3(0.08, 0.012, 0.025)),
				MaterialLib.surface("metal"),
				Transform3D(Basis.IDENTITY, Vector3(0, 0.012, -0.14))
			)
		"wall":
			add_mesh(box_mesh(Vector3(0.21, 0.29, 0.004)), paper)
			add_mesh(
				box_mesh(Vector3(0.02, 0.02, 0.01)),
				MaterialLib.flat(Color(0.6, 0.1, 0.1), 0.5),
				Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0.004))
			)
		_:
			add_mesh(box_mesh(Vector3(0.21, 0.004, 0.29)), paper)
			add_mesh(
				box_mesh(Vector3(0.2, 0.004, 0.27)),
				paper,
				Transform3D(Basis(Vector3.UP, 0.25), Vector3(0.03, 0.004, 0.02))
			)
	var size := Vector3(0.3, 0.38, 0.12) if style == "wall" else Vector3(0.35, 0.1, 0.4)
	add_target(size)


func initial_state() -> Dictionary:
	return {"args": []}


func text_args() -> Array:
	return state.get("args", [])


func body_text() -> String:
	var args := text_args()
	var text := tr(body_key)
	if not args.is_empty():
		text = text % args
	return text


func client_intercept(_pid: int, _sub: int) -> bool:
	read_requested.emit(self)
	AudioService.play_2d("page_turn", AudioService.BUS_SFX, -6.0)
	# Still tell the authority when reading completes an optional objective.
	return read_flag.is_empty()


func authority_interact(_ctx: Dictionary) -> void:
	if not read_flag.is_empty():
		match_ctrl.set_flag(read_flag)
