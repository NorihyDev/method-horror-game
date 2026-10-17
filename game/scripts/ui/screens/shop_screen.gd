extends Screen
## Cosmetic shop with two wallets: offline coins kept on this device, and the
## verified online wallet held by the lobby service (earned in online
## matches). Cosmetics never affect gameplay; anything owned in either wallet
## can be worn. No real-money purchases, ads or loot boxes exist.

enum Source { LOCAL, ONLINE }

var _list: VBoxContainer
var _coins: Label
var _note: Label
var _status: Label
var _preview_title: Label
var _preview_desc: Label
var _preview_swatch: ColorRect
var _preview_badge: BadgeIcon
var _action: Button
var _tab_local: Button
var _tab_online: Button
var _selected := ""
var _source: Source = Source.LOCAL
var _lobby: LobbyClient
var _online_ready := false
var _busy := false


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
	var tabs := UI.hbox(8)
	_tab_local = UI.button("SHOP_WALLET_LOCAL", func() -> void: _switch(Source.LOCAL), false, 240)
	_tab_local.toggle_mode = true
	tabs.add_child(_tab_local)
	var online_reason := LobbyClient.availability_for(LobbyClient.configured_url())
	_tab_online = UI.button("SHOP_WALLET_ONLINE", func() -> void: _switch(Source.ONLINE), false, 240)
	_tab_online.toggle_mode = true
	_tab_online.disabled = not online_reason.is_empty()
	_tab_online.tooltip_text = online_reason
	tabs.add_child(_tab_online)
	_status = UI.label("", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_DIM)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tabs.add_child(_status)
	col.add_child(tabs)
	_note = UI.para("SHOP_NOTE", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT)
	col.add_child(_note)
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
	_switch(Source.LOCAL)


# --- Wallets ------------------------------------------------------------------------------


func _switch(source: Source) -> void:
	_source = source
	_tab_local.set_pressed_no_signal(source == Source.LOCAL)
	_tab_online.set_pressed_no_signal(source == Source.ONLINE)
	_note.text = "SHOP_NOTE" if source == Source.LOCAL else "SHOP_ONLINE_NOTE"
	_fill()
	if source == Source.ONLINE and not _online_ready:
		_refresh_online()


func _balance() -> int:
	return Saves.wallet.balance if _source == Source.LOCAL else maxi(Saves.online_balance, 0)


func _owned_here(id: String) -> bool:
	return Saves.wallet.is_owned(id) if _source == Source.LOCAL else Saves.online_owned.has(id)


func _refresh_online() -> void:
	if _busy:
		return
	_busy = true
	_status.text = "SHOP_ONLINE_LOADING"
	if _lobby == null:
		_lobby = LobbyClient.new()
		add_child(_lobby)
	var g := await _lobby.ensure_guest(Saves.display_name(), Saves.avatar_color_index())
	if not is_inside_tree():
		return
	if not bool(g["ok"]):
		_busy = false
		_status.text = OnlineFlow.describe_error(str(g["error"]))
		return
	var w := await _lobby.wallet()
	if not is_inside_tree():
		return
	_busy = false
	if int(w["status"]) != 200:
		_status.text = tr("SHOP_ONLINE_UNREACHABLE")
		return
	Saves.set_online_wallet(int(w["json"].get("balance", 0)), w["json"].get("owned", []))
	_online_ready = true
	_status.text = ""
	_fill()


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	for slot in Saves.catalog.slots():
		_list.add_child(UI.caption("SHOP_SLOT_" + slot.to_upper()))
		for item in Saves.catalog.items_in(slot):
			var id: String = item["id"]
			var equipped := Saves.equipped_id(slot) == id
			var state := str(int(item["price"]))
			if equipped:
				state = tr("SHOP_EQUIPPED")
			elif _owned_here(id):
				state = tr("SHOP_OWNED")
			elif Saves.is_owned_anywhere(id):
				state = tr("SHOP_OWNED_OTHER")
			var b := UI.button("%s   —   %s" % [tr(item["name_key"]), state], func() -> void: _select(id), false, 500)
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_list.add_child(b)
	if _selected.is_empty():
		_selected = Saves.catalog.items()[1]["id"]
	_select(_selected)
	var known := _source == Source.LOCAL or _online_ready or Saves.online_balance >= 0
	_coins.text = str(_balance()) if known else "—"


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
	var equipped := Saves.equipped_id(item["slot"]) == id
	_action.disabled = equipped or (_source == Source.ONLINE and not _online_ready and not Saves.is_owned_anywhere(id))
	if equipped:
		_action.text = tr("SHOP_EQUIPPED")
	elif Saves.is_owned_anywhere(id):
		_action.text = tr("SHOP_EQUIP")
	else:
		_action.text = tr("SHOP_BUY" if _source == Source.LOCAL else "SHOP_BUY_ONLINE") % int(item["price"])


func _on_action() -> void:
	var item := Saves.catalog.get_item(_selected)
	if Saves.is_owned_anywhere(_selected):
		Saves.equip(_selected)
		_fill()
		return
	var price := int(item["price"])
	if _balance() < price:
		app.alert("SHOP_INSUFFICIENT_TITLE", tr("SHOP_INSUFFICIENT_BODY") % [price - _balance()])
		return
	var id := _selected
	var body := "SHOP_CONFIRM_BODY" if _source == Source.LOCAL else "SHOP_CONFIRM_BODY_ONLINE"
	app.confirm(
		"SHOP_CONFIRM_TITLE",
		body,
		"SHOP_CONFIRM",
		func() -> void:
			if _source == Source.LOCAL:
				_buy_local(id, item)
			else:
				_buy_online(id, item),
		false,
		[tr(item["name_key"]), price]
	)


func _buy_local(id: String, item: Dictionary) -> void:
	var result := Saves.purchase(id)
	match result:
		Wallet.PurchaseResult.OK:
			Saves.equip(id)
			app.toast(tr("SHOP_PURCHASED") % tr(item["name_key"]))
		Wallet.PurchaseResult.INSUFFICIENT_FUNDS:
			app.toast(tr("SHOP_INSUFFICIENT_TITLE"))
		_:
			app.toast(tr("SHOP_FAILED"))
	_fill()


func _buy_online(id: String, item: Dictionary) -> void:
	if _busy or _lobby == null:
		return
	_busy = true
	_status.text = "SHOP_ONLINE_BUYING"
	# One key per purchase attempt: a lost reply retried with the same key
	# can never charge twice.
	var key := Crypto.new().generate_random_bytes(12).hex_encode()
	var r := await _lobby.purchase(id, key)
	if int(r["status"]) == 0:
		r = await _lobby.purchase(id, key)
	if not is_inside_tree():
		return
	_busy = false
	_status.text = ""
	if int(r["status"]) == 200:
		Saves.set_online_wallet(int(r["json"].get("balance", 0)), r["json"].get("owned", []))
		Saves.equip(id)
		app.toast(tr("SHOP_PURCHASED") % tr(item["name_key"]))
	else:
		var code := str(r["json"].get("error", ""))
		app.alert(
			"SHOP_FAILED",
			OnlineFlow.describe_error("NET_" + code if not code.is_empty() else "NET_SERVICE_UNREACHABLE")
		)
	_fill()
