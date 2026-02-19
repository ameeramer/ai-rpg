extends PanelContainer
## Trade UI — Player-NPC item trading interface.

signal trade_closed()

var _npc_ref: Node3D = null
var _npc_name: String = ""
var _player_offer: Array = []
var _npc_offer: Array = []
var _player_grid: GridContainer
var _npc_grid: GridContainer
var _title_label: Label
var _accept_btn: Button
var _close_btn: Button
var _status_label: Label


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	style.set_border_width_all(3)
	style.border_color = Color(0.55, 0.45, 0.28, 1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	# Header
	var header = HBoxContainer.new()
	vbox.add_child(header)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_title_label.add_theme_font_size_override("font_size", 36)
	header.add_child(_title_label)
	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.custom_minimum_size = Vector2(72, 60)
	_close_btn.add_theme_font_size_override("font_size", 36)
	_close_btn.pressed.connect(_on_close)
	header.add_child(_close_btn)
	# Trade panels side by side
	var trade_row = HBoxContainer.new()
	trade_row.add_theme_constant_override("separation", 16)
	trade_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(trade_row)
	# Your offer
	var your_panel = _make_trade_panel("Your Offer", true)
	trade_row.add_child(your_panel)
	# NPC offer
	var npc_panel = _make_trade_panel("Their Offer", false)
	trade_row.add_child(npc_panel)
	# Status + accept
	_status_label = Label.new()
	_status_label.text = "Tap your items to offer them for trade"
	_status_label.add_theme_font_size_override("font_size", 24)
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)
	_accept_btn = Button.new()
	_accept_btn.text = "Accept Trade"
	_accept_btn.custom_minimum_size = Vector2(240, 66)
	_accept_btn.add_theme_font_size_override("font_size", 28)
	_accept_btn.pressed.connect(_on_accept)
	btn_row.add_child(_accept_btn)


func _make_trade_panel(title: String, is_player: bool) -> VBoxContainer:
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 28)
	if is_player:
		lbl.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	else:
		lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	if is_player:
		_player_grid = grid
	else:
		_npc_grid = grid
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(grid)
	vb.add_child(scroll)
	return vb


func open_trade(npc_name: String, npc: Node3D) -> void:
	_npc_name = npc_name
	_npc_ref = npc
	_title_label.text = "Trade with " + npc_name
	_player_offer.clear()
	_npc_offer.clear()
	_status_label.text = "Tap your items to offer them for trade"
	visible = true
	_refresh_grids()


func _refresh_grids() -> void:
	_clear_grid(_player_grid)
	_clear_grid(_npc_grid)
	# Show player inventory as offer-able items
	var slots = PlayerInventory.get("slots")
	if slots:
		for i in range(slots.size()):
			var slot = slots[i]
			if slot == null:
				continue
			var item = slot.get("item")
			var qty = slot.get("quantity")
			if item == null:
				continue
			var offered = _is_in_offer(_player_offer, i)
			var btn = _make_item_btn(item, qty, offered)
			btn.pressed.connect(_toggle_player_offer.bind(i, item, qty))
			_player_grid.add_child(btn)
	# Show NPC inventory
	var npc_inv = _npc_ref.get("npc_inventory") if _npc_ref else []
	if npc_inv:
		for i in range(npc_inv.size()):
			var entry = npc_inv[i]
			if entry == null:
				continue
			var item = entry.get("item")
			var qty = entry.get("quantity")
			if item == null:
				continue
			var offered = _is_in_offer(_npc_offer, i)
			var btn = _make_item_btn(item, qty, offered)
			_npc_grid.add_child(btn)
	# Show offered items
	_update_offer_display()


func _make_item_btn(item, qty: int, offered: bool) -> Button:
	var btn = Button.new()
	var name = item.call("get_display_name")
	if name == null:
		name = "Item"
	btn.text = "%s\nx%d" % [name, qty]
	btn.custom_minimum_size = Vector2(100, 80)
	btn.add_theme_font_size_override("font_size", 18)
	if offered:
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.2, 0.4, 0.2, 0.9)
		s.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", s)
	return btn


func _toggle_player_offer(slot_idx: int, item, qty: int) -> void:
	var found = -1
	for i in range(_player_offer.size()):
		if _player_offer[i]["slot"] == slot_idx:
			found = i
			break
	if found >= 0:
		_player_offer.remove_at(found)
	else:
		_player_offer.append({"slot": slot_idx, "item": item, "quantity": qty})
	_refresh_grids()


func _is_in_offer(offer: Array, idx: int) -> bool:
	for entry in offer:
		if entry.get("slot") == idx:
			return true
	return false


func _update_offer_display() -> void:
	var count = _player_offer.size()
	if count > 0:
		_status_label.text = "Offering %d item(s). Press Accept to trade." % count
	else:
		_status_label.text = "Tap your items to offer them for trade"


func _clear_grid(grid: GridContainer) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()


func _on_accept() -> void:
	if _player_offer.is_empty():
		_status_label.text = "You haven't offered anything!"
		return
	# Execute trade - remove items from player inventory
	var given = []
	for entry in _player_offer:
		var slot = entry["slot"]
		var qty = entry["quantity"]
		PlayerInventory.call("remove_item_at", slot, qty)
		var iname = entry["item"].call("get_display_name")
		given.append("%s x%d" % [iname, qty])
	GameManager.log_action("You traded: %s to %s" % [", ".join(given), _npc_name])
	_player_offer.clear()
	_npc_offer.clear()
	_status_label.text = "Trade complete!"
	_refresh_grids()


func _on_close() -> void:
	visible = false
	trade_closed.emit()


func setup() -> void:
	pass
