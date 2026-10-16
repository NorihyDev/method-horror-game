extends Screen
## Cosmetic shop (local wallet). Cosmetics never affect gameplay. No real-money
## purchases, ads or loot boxes exist in this build.

var _list: VBoxContainer
var _coins: Label
var _preview_title: Label
var _preview_desc: Label
var _preview_swatch: ColorRect
var _preview_badge: BadgeIcon
var _action: Button
var _selected := ""


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(ThemeFactory.BG, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := safe_root(40)
	var col := UI.vbox(12)
	root.add_child(col)
	var top := UI.hbox(12)
	top.add_child(UI.button("BACK", func() -> void: app.back(), false, 120))
	var t := UI.heading("SHOP_TITLE")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var coins := UI.coin_label(Saves.wallet.balance, ThemeFactory.FONT_H2)
	_coins = coins.get_child(1)
	top.add_child(coins)
	col.add_child(top)
	col.add_child(UI.para("SHOP_NOTE", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT))
	var body := UI.hbox(24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_list = UI.vbox(6)
	var scroll := UI.scroll(_list)
	scroll.custom_minimum_size.x = 520
	body.add_child(scroll)
	var preview := UI.panel(20)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(preview)
	var pv := UI.vbox(12)
	preview.add_child(pv)
	pv.add_child(UI.caption("SHOP_PREVIEW"))
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(300, 160)
	pv.add_child(stage)
	_preview_swatch = ColorRect.new()
	_preview_swatch.position = Vector2(0, 0)
	_preview_swatch.size = Vector2(300, 160)
	stage.add_child(_preview_swatch)
	_preview_badge = BadgeIcon.new()
	_preview_badge.position = Vector2(90, 20)
	_preview_badge.size = Vector2(120, 120)
	stage.add_child(_preview_badge)
	_preview_title = UI.label("", ThemeFactory.FONT_H2)
	pv.add_child(_preview_title)
	_preview_desc = UI.para("", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_DIM)
	pv.add_child(_preview_desc)
	_action = UI.button("", _on_action, true, 260)
	pv.add_child(_action)
	_fill()


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	for slot in Saves.catalog.slots():
		_list.add_child(UI.caption("SHOP_SLOT_" + slot.to_upper()))
		for item in Saves.catalog.items_in(slot):
			var id: String = item["id"]
			var owned := Saves.wallet.is_owned(id)
			var equipped := Saves.wallet.equipped_in(slot, Saves.catalog) == id
			var state := tr("SHOP_EQUIPPED") if equipped else (tr("SHOP_OWNED") if owned else str(int(item["price"])))
			var b := UI.button("%s   —   %s" % [tr(item["name_key"]), state], func() -> void: _select(id), false, 500)
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_list.add_child(b)
	if _selected.is_empty():
		_selected = Saves.catalog.items()[1]["id"]
	_select(_selected)
	_coins.text = str(Saves.wallet.balance)


func _select(id: String) -> void:
	_selected = id
	var item := Saves.catalog.get_item(id)
	_preview_title.text = tr(item["name_key"])
	_preview_desc.text = tr(str(item["name_key"]) + "_DESC")
	if item["slot"] == CosmeticCatalog.SLOT_FLASHLIGHT:
		_preview_swatch.color = (item["beam"] as Color).darkened(0.25)
		_preview_badge.shape = "none"
		_preview_badge.tint = item["body"]
	else:
		_preview_swatch.color = ThemeFactory.SURFACE_2
		_preview_badge.shape = item.get("shape", "none")
		_preview_badge.tint = item.get("tint", Color.WHITE)
	var owned := Saves.wallet.is_owned(id)
	var equipped := Saves.wallet.equipped_in(item["slot"], Saves.catalog) == id
	_action.disabled = equipped
	if equipped:
		_action.text = tr("SHOP_EQUIPPED")
	elif owned:
		_action.text = tr("SHOP_EQUIP")
	else:
		_action.text = tr("SHOP_BUY") % int(item["price"])


func _on_action() -> void:
	var item := Saves.catalog.get_item(_selected)
	if Saves.wallet.is_owned(_selected):
		Saves.equip(_selected)
		_fill()
		return
	var price := int(item["price"])
	if Saves.wallet.balance < price:
		app.alert("SHOP_INSUFFICIENT_TITLE", tr("SHOP_INSUFFICIENT_BODY") % [price - Saves.wallet.balance])
		return
	var id := _selected
	app.confirm("SHOP_CONFIRM_TITLE", "SHOP_CONFIRM_BODY", "SHOP_CONFIRM", func() -> void:
		var result := Saves.purchase(id)
		match result:
			Wallet.PurchaseResult.OK:
				Saves.equip(id)
				app.toast(tr("SHOP_PURCHASED") % tr(item["name_key"]))
			Wallet.PurchaseResult.INSUFFICIENT_FUNDS:
				app.toast(tr("SHOP_INSUFFICIENT_TITLE"))
			_:
				app.toast(tr("SHOP_FAILED"))
		_fill(), false, [tr(item["name_key"]), price])
