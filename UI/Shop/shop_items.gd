extends GridContainer
## Shop item grid — renders item buttons with 3D icons, handles buy/sell.

signal transaction_done()

var _icon_cache: Dictionary = {}
var _viewport: SubViewport
var _cam: Camera3D
var _render_queue: Array = []
var _current_model: Node3D
var _current_tab = "buy"
var _shop_stock: Array = []

func _ready() -> void:
	FileLogger.log_msg("ShopItems._ready() start")
	columns = 6
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_viewport()
	FileLogger.log_msg("ShopItems._ready() done")


func _setup_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(128, 128)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.own_world_3d = true
	add_child(_viewport)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 2.0
	_cam.position = Vector3(0, 0.5, 2.5)
	_cam.look_at(Vector3(0, 0.3, 0), Vector3.UP)
	_viewport.add_child(_cam)
	var ml = DirectionalLight3D.new()
	ml.rotation_degrees = Vector3(-45, 30, 0)
	ml.light_energy = 1.5
	_viewport.add_child(ml)
	var fl = DirectionalLight3D.new()
	fl.rotation_degrees = Vector3(-20, -60, 0)
	fl.light_energy = 0.4
	_viewport.add_child(fl)

func show_items(tab: String, stock: Array) -> void:
	_current_tab = tab
	_shop_stock = stock
	for child in get_children():
		if child != _viewport:
			child.queue_free()
	if tab == "buy":
		_build_buy()
	else:
		_build_sell()


func _build_buy() -> void:
	var to_render: Array = []
	for i in range(_shop_stock.size()):
		var entry = _shop_stock[i]
		var item = entry["item"]
		var price = entry["price"]
		var btn = _make_btn(item, str(price) + " gp", to_render)
		btn.pressed.connect(_on_buy.bind(i))
		add_child(btn)
	_start_renders(to_render)

func _build_sell() -> void:
	var inv = PlayerInventory.get("slots")
	if inv == null:
		return
	var to_render: Array = []
	for i in range(inv.size()):
		if inv[i] == null:
			continue
		var item = inv[i]["item"]
		var qty = inv[i]["quantity"]
		var sp = _sell_price(item)
		var txt = str(sp) + " gp"
		if qty > 1:
			txt = "x" + str(qty) + " " + txt
		var btn = _make_btn(item, txt, to_render)
		btn.pressed.connect(_on_sell.bind(i))
		add_child(btn)
	_start_renders(to_render)


func _sell_price(item) -> int:
	var v = item.get("value")
	if v == null or v <= 1:
		return 1
	var sp = int(v * 0.6)
	return 1 if sp < 1 else sp

func _make_btn(item, price_text: String, render_list: Array) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(144, 144)
	btn.add_theme_stylebox_override("normal", _slot_style(false))
	btn.add_theme_stylebox_override("hover", _slot_style(true))
	btn.add_theme_stylebox_override("pressed", _slot_style(true))
	btn.add_theme_font_size_override("font_size", 21)
	btn.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.expand_icon = true
	var mp = item.get("model_path")
	if mp and mp != "" and _icon_cache.has(mp):
		btn.icon = _icon_cache[mp]
		btn.text = price_text
	elif mp and mp != "":
		btn.text = str(item.get("item_name")).substr(0, 6) + "\n" + price_text
		if not render_list.has(mp):
			render_list.append(mp)
	elif item.get("icon"):
		btn.icon = item.get("icon")
		btn.text = price_text
	else:
		btn.text = str(item.get("item_name")).substr(0, 6) + "\n" + price_text
	return btn

func _slot_style(hover: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	if hover:
		s.bg_color = Color(0.25, 0.22, 0.16, 0.95)
		s.border_color = Color(0.6, 0.5, 0.3, 1)
	else:
		s.bg_color = Color(0.18, 0.15, 0.12, 0.9)
		s.border_color = Color(0.35, 0.3, 0.2, 0.8)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	return s


func _start_renders(paths: Array) -> void:
	for p in paths:
		_render_queue.append(p)
	if not _render_queue.is_empty():
		_process_queue()


func _process_queue() -> void:
	if _render_queue.is_empty():
		show_items(_current_tab, _shop_stock)
		return
	var mp = _render_queue.pop_front()
	if _icon_cache.has(mp):
		_process_queue()
		return
	var scene = load(mp)
	if scene == null:
		_process_queue()
		return
	if _current_model:
		_current_model.queue_free()
	_current_model = scene.instantiate()
	_viewport.add_child(_current_model)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var img = _viewport.get_texture().get_image()
	_icon_cache[mp] = ImageTexture.create_from_image(img)
	_current_model.queue_free()
	_current_model = null
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_process_queue()


func _on_buy(idx: int) -> void:
	if idx >= _shop_stock.size():
		return
	var item = _shop_stock[idx]["item"]
	var price = _shop_stock[idx]["price"]
	var coins = PlayerInventory.call("count_item", 995)
	if coins == null:
		coins = 0
	if coins < price:
		GameManager.log_action("Not enough coins.")
		return
	if PlayerInventory.call("is_full"):
		GameManager.log_action("Inventory full.")
		return
	PlayerInventory.call("remove_item_by_id", 995, price)
	PlayerInventory.call("add_item", item, 1)
	GameManager.log_action("Bought %s for %d gp." % [item.call("get_display_name"), price])
	transaction_done.emit()


func _on_sell(slot: int) -> void:
	var inv = PlayerInventory.get("slots")
	if inv == null or slot >= inv.size() or inv[slot] == null:
		return
	var item = inv[slot]["item"]
	var sp = _sell_price(item)
	PlayerInventory.call("remove_item_at", slot, 1)
	var coins_res = load("res://Data/Items/coins.tres")
	if coins_res:
		PlayerInventory.call("add_item", coins_res, sp)
	GameManager.log_action("Sold %s for %d gp." % [item.call("get_display_name"), sp])
	transaction_done.emit()
