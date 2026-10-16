class_name InventoryPanel
extends OverlayPanel
## Inventory with a rotating 3D inspect view. Items are used contextually in
## the world (look at the fuse panel holding a fuse); batteries can be used
## here. Dropped items land on the floor and stay recoverable.

var match_ctrl: MatchController
var player_id := 1
var _selected := 0
var _icons: Array[ItemIcon] = []
var _name: Label
var _desc: Label
var _use: Button
var _drop: Button
var _viewport: SubViewport
var _pivot: Node3D


func build() -> void:
	panel.custom_minimum_size = Vector2(820, 0)
	header("INV_TITLE")
	var row := UI.hbox(24)
	body.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	row.add_child(grid)
	for i in Inventory.DEFAULT_CAPACITY:
		var b := Button.new()
		b.custom_minimum_size = Vector2(88, 88)
		b.focus_mode = Control.FOCUS_ALL
		var icon := ItemIcon.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(icon)
		_icons.append(icon)
		var idx := i
		b.pressed.connect(func() -> void:
			AudioService.play_ui("ui_click")
			_select(idx))
		b.focus_entered.connect(func() -> void: _select(idx))
		grid.add_child(b)
	var detail := UI.vbox(10)
	detail.custom_minimum_size.x = 380
	row.add_child(detail)
	var vpc := SubViewportContainer.new()
	vpc.custom_minimum_size = Vector2(380, 220)
	vpc.stretch = true
	detail.add_child(vpc)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(380, 220)
	vpc.add_child(_viewport)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.08, 0.36)
	cam.fov = 40
	_viewport.add_child(cam)
	cam.look_at(Vector3(0, 0.02, 0))
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8, 0.6, 0)
	light.light_energy = 1.4
	_viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	_viewport.add_child(env)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_name = UI.label("", ThemeFactory.FONT_H2)
	_name.add_theme_font_override("font", ThemeFactory.title_font())
	detail.add_child(_name)
	_desc = UI.para("", ThemeFactory.FONT_BODY - 2)
	detail.add_child(_desc)
	var actions := UI.hbox(10)
	_use = UI.button("INV_USE", _on_use, false, 112)
	_drop = UI.button("INV_DROP", _on_drop, false, 112)
	actions.add_child(_use)
	actions.add_child(_drop)
	actions.add_child(UI.button("CLOSE", func() -> void: close(), false, 112))
	detail.add_child(actions)
	body.add_child(UI.para("INV_CONTEXT_HINT", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT))
	match_ctrl.inventory_changed.connect(func(pid: int) -> void:
		if pid == player_id and is_inside_tree():
			_refresh())
	_refresh()


func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotate_y(delta * 0.8)


func _refresh() -> void:
	var inv := match_ctrl.inventory(player_id)
	for i in _icons.size():
		if inv and i < inv.slots.size():
			_icons[i].item_id = inv.slots[i]["id"]
			_icons[i].count = int(inv.slots[i]["count"])
		else:
			_icons[i].item_id = ""
			_icons[i].count = 0
	_select(clampi(_selected, 0, maxi(0, (inv.slots.size() if inv else 0) - 1)))


func _select(idx: int) -> void:
	_selected = idx
	for i in _icons.size():
		_icons[i].selected = i == idx
	var inv := match_ctrl.inventory(player_id)
	var item := inv.item_at(idx) if inv else ""
	for c in _pivot.get_children():
		c.queue_free()
	if item.is_empty():
		_name.text = tr("INV_EMPTY")
		_desc.text = tr("INV_EMPTY_DESC")
		_use.disabled = true
		_drop.disabled = true
		return
	var def: ItemDefinition = Session.item(item)
	_name.text = tr(def.name_key) if def else item
	_desc.text = tr(def.description_key) if def else ""
	_use.disabled = item != "battery"
	_use.tooltip_text = "" if item == "battery" else "INV_USE_CONTEXT"
	_drop.disabled = false
	var model := ItemVisuals.build(item)
	model.scale = Vector3.ONE * 1.6
	_pivot.add_child(model)


func _on_use() -> void:
	var item := match_ctrl.inventory(player_id).item_at(_selected)
	if not item.is_empty():
		match_ctrl.request_use_item(item)


func _on_drop() -> void:
	var item := match_ctrl.inventory(player_id).item_at(_selected)
	if not item.is_empty():
		match_ctrl.request_drop(item)
