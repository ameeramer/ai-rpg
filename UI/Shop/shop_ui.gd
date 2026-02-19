extends PanelContainer
## Shop UI — centered overlay with Buy/Sell tabs and touch-drag scrolling.

signal shop_closed()

var _shop_stock: Array = []
var _tab = "buy"
var _title_label: Label
var _coins_label: Label
var _buy_btn: Button
var _sell_btn: Button
var _scroll: ScrollContainer
var _items_grid: Node
var _dragging = false
var _drag_start_y = 0.0
var _scroll_start = 0.0


func _ready() -> void:
	FileLogger.log_msg("ShopUI._ready() start")
	_build_ui()
	FileLogger.log_msg("ShopUI._ready() done")


func _build_ui() -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.08, 0.06, 0.95)
	s.set_border_width_all(3)
	s.border_color = Color(0.55, 0.45, 0.28, 1)
	s.set_corner_radius_all(12)
	add_theme_stylebox_override("panel", s)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)
	# Header row
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 84)
	vbox.add_child(header)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_title_label.add_theme_font_size_override("font_size", 45)
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title_label)
	_coins_label = Label.new()
	_coins_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_coins_label.add_theme_font_size_override("font_size", 36)
	_coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_coins_label)
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(90, 78)
	close_btn.add_theme_font_size_override("font_size", 42)
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)
	# Tab row
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	vbox.add_child(tab_row)
	_buy_btn = _make_tab_btn("Buy")
	_buy_btn.pressed.connect(_switch_tab.bind("buy"))
	tab_row.add_child(_buy_btn)
	_sell_btn = _make_tab_btn("Sell")
	_sell_btn.pressed.connect(_switch_tab.bind("sell"))
	tab_row.add_child(_sell_btn)
	# Scroll + grid
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)
	# Load shop items grid as PackedScene
	var sc = load("res://UI/Shop/ShopItems.tscn")
	if sc:
		_items_grid = sc.instantiate()
		_scroll.add_child(_items_grid)
		var sig = _items_grid.get("transaction_done")
		if sig:
			_items_grid.transaction_done.connect(_refresh)


func _make_tab_btn(label: String) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(180, 66)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 33)
	return btn


func _style_tabs() -> void:
	_apply_tab_style(_buy_btn, _tab == "buy")
	_apply_tab_style(_sell_btn, _tab == "sell")


func _apply_tab_style(btn: Button, active: bool) -> void:
	var ts = StyleBoxFlat.new()
	if active:
		ts.bg_color = Color(0.3, 0.25, 0.15, 1)
		ts.border_color = Color(0.7, 0.6, 0.3, 1)
	else:
		ts.bg_color = Color(0.15, 0.12, 0.08, 0.8)
		ts.border_color = Color(0.35, 0.3, 0.2, 0.6)
	ts.set_border_width_all(2)
	ts.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", ts)


func open_shop(npc_name: String, stock: Array) -> void:
	_shop_stock = stock
	_title_label.text = npc_name + "'s Shop"
	_tab = "buy"
	visible = true
	_style_tabs()
	_refresh()


func _switch_tab(tab: String) -> void:
	_tab = tab
	_style_tabs()
	_refresh()


func _refresh() -> void:
	var coins = PlayerInventory.call("count_item", 995)
	if coins == null:
		coins = 0
	_coins_label.text = str(coins) + " gp"
	if _items_grid:
		_items_grid.call("show_items", _tab, _shop_stock)


func _on_close() -> void:
	visible = false
	shop_closed.emit()


func _input(event) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_drag_start_y = event.position.y
			_scroll_start = _scroll.scroll_vertical
		else:
			_dragging = false
	elif event is InputEventScreenDrag and _dragging:
		var dy = _drag_start_y - event.position.y
		_scroll.scroll_vertical = int(_scroll_start + dy)
	elif event is InputEventMouseButton:
		if event.pressed:
			_dragging = true
			_drag_start_y = event.position.y
			_scroll_start = _scroll.scroll_vertical
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var dy = _drag_start_y - event.position.y
		_scroll.scroll_vertical = int(_scroll_start + dy)
