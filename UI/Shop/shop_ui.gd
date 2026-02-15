extends VBoxContainer
## Shop UI — buy/sell items from merchant NPCs.

signal shop_closed()

var _shop_stock: Array = []
var _shop_grid: GridContainer
var _player_grid: GridContainer
var _coins_label: Label
var _title_label: Label
var _stock_buttons: Array = []
var _inv_buttons: Array = []


func _ready() -> void:
	FileLogger.log_msg("ShopUI._ready() start")
	add_theme_constant_override("separation", 8)
	_build_ui()
	FileLogger.log_msg("ShopUI._ready() done")


func _build_ui() -> void:
	_title_label = _add_label(45, Color(0.3, 1.0, 0.3))
	_coins_label = _add_label(39, Color(1, 0.85, 0.3))
	_add_label(36, Color(0.7, 0.65, 0.5)).text = "-- Shop Stock --"
	var shop_scroll = ScrollContainer.new()
	shop_scroll.custom_minimum_size = Vector2(0, 300)
	add_child(shop_scroll)
	_shop_grid = _make_grid()
	shop_scroll.add_child(_shop_grid)
	_add_label(36, Color(0.7, 0.65, 0.5)).text = "-- Your Items (tap to sell) --"
	var inv_scroll = ScrollContainer.new()
	inv_scroll.custom_minimum_size = Vector2(0, 300)
	add_child(inv_scroll)
	_player_grid = _make_grid()
	inv_scroll.add_child(_player_grid)

func _add_label(size: int, color: Color) -> Label:
	var lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)
	return lbl

func _make_grid() -> GridContainer:
	var g = GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	return g


func open_shop(npc_name: String, stock: Array) -> void:
	_shop_stock = stock
	_title_label.text = npc_name + "'s Shop"
	visible = true
	refresh()


func refresh() -> void:
	_update_coins()
	_build_shop_buttons()
	_build_inv_buttons()


func _update_coins() -> void:
	var coins = PlayerInventory.call("count_item", 995)
	if coins == null:
		coins = 0
	_coins_label.text = "Coins: %d" % coins


func _build_shop_buttons() -> void:
	for child in _shop_grid.get_children():
		child.queue_free()
	_stock_buttons.clear()
	var btn_style = _make_slot_style()
	for i in range(_shop_stock.size()):
		var entry = _shop_stock[i]
		var item = entry["item"]
		var price = entry["price"]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(144, 144)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_font_size_override("font_size", 27)
		btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		var name_str = item.call("get_display_name")
		btn.text = str(name_str).substr(0, 5) + "\n" + str(price) + "gp"
		btn.tooltip_text = "%s - %d gp" % [name_str, price]
		btn.pressed.connect(_on_buy.bind(i))
		_shop_grid.add_child(btn)
		_stock_buttons.append(btn)


func _build_inv_buttons() -> void:
	for child in _player_grid.get_children():
		child.queue_free()
	_inv_buttons.clear()
	var inv_slots = PlayerInventory.get("slots")
	if inv_slots == null:
		return
	var btn_style = _make_slot_style()
	for i in range(inv_slots.size()):
		var slot = inv_slots[i]
		if slot == null:
			continue
		var item = slot["item"]
		var qty = slot["quantity"]
		var sell_price = item.get("value")
		if sell_price == null:
			sell_price = 0
		sell_price = int(sell_price * 0.6)
		if sell_price < 1:
			sell_price = 1
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(144, 144)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_font_size_override("font_size", 27)
		btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		var name_str = item.call("get_display_name")
		var label_text = str(name_str).substr(0, 5)
		if qty > 1:
			label_text += " x" + str(qty)
		label_text += "\n" + str(sell_price) + "gp"
		btn.text = label_text
		btn.pressed.connect(_on_sell.bind(i))
		_player_grid.add_child(btn)
		_inv_buttons.append(btn)


func _on_buy(stock_idx: int) -> void:
	if stock_idx >= _shop_stock.size():
		return
	var entry = _shop_stock[stock_idx]
	var item = entry["item"]
	var price = entry["price"]
	var coins = PlayerInventory.call("count_item", 995)
	if coins == null:
		coins = 0
	if coins < price:
		GameManager.log_action("You don't have enough coins.")
		return
	var full = PlayerInventory.call("is_full")
	if full:
		GameManager.log_action("Your inventory is full.")
		return
	PlayerInventory.call("remove_item_by_id", 995, price)
	PlayerInventory.call("add_item", item, 1)
	var name_str = item.call("get_display_name")
	GameManager.log_action("You buy a %s for %d coins." % [name_str, price])
	refresh()


func _on_sell(inv_slot: int) -> void:
	var inv_slots = PlayerInventory.get("slots")
	if inv_slots == null or inv_slot >= inv_slots.size():
		return
	var slot = inv_slots[inv_slot]
	if slot == null:
		return
	var item = slot["item"]
	var sell_price = item.get("value")
	if sell_price == null:
		sell_price = 0
	sell_price = int(sell_price * 0.6)
	if sell_price < 1:
		sell_price = 1
	PlayerInventory.call("remove_item_at", inv_slot, 1)
	var coins_item = load("res://Data/Items/coins.tres")
	if coins_item:
		PlayerInventory.call("add_item", coins_item, sell_price)
	var name_str = item.call("get_display_name")
	GameManager.log_action("You sell a %s for %d coins." % [name_str, sell_price])
	refresh()


func _make_slot_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.15, 0.12, 0.9)
	s.border_color = Color(0.35, 0.3, 0.2, 0.8)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	return s
