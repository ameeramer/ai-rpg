extends PanelContainer
## Bank UI — Two-panel deposit/withdraw interface.

signal bank_closed()

var _bank_grid: GridContainer
var _inv_grid: GridContainer
var _title_label: Label
var _close_btn: Button
var _status_label: Label

func _ready() -> void:
	_build_ui()
	var sig = PlayerInventory.get("inventory_changed")
	if sig:
		PlayerInventory.inventory_changed.connect(_refresh)
	var bsig = PlayerBank.get("bank_changed")
	if bsig:
		PlayerBank.bank_changed.connect(_refresh)

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
	_title_label.text = "Bank"
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
	# Two panels side by side
	var panels_row = HBoxContainer.new()
	panels_row.add_theme_constant_override("separation", 16)
	panels_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(panels_row)
	# Bank panel (left)
	var bank_panel = _make_panel("Bank", true)
	panels_row.add_child(bank_panel)
	# Inventory panel (right)
	var inv_panel = _make_panel("Inventory", false)
	panels_row.add_child(inv_panel)
	# Status
	_status_label = Label.new()
	_status_label.text = "Click bank items to withdraw, inventory items to deposit"
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)

func _make_panel(title: String, is_bank: bool) -> VBoxContainer:
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 28)
	if is_bank:
		lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	else:
		lbl.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	if is_bank:
		_bank_grid = grid
	else:
		_inv_grid = grid
	return vb

func open_bank() -> void:
	visible = true
	_refresh()

func _refresh() -> void:
	if not visible:
		return
	_clear_grid(_bank_grid)
	_clear_grid(_inv_grid)
	# Bank items
	var bank_items = PlayerBank.call("get_items")
	if bank_items:
		for i in range(bank_items.size()):
			var entry = bank_items[i]
			if entry == null:
				continue
			var item = entry.get("item")
			var qty = entry.get("quantity")
			if item == null:
				continue
			var btn = _make_item_btn(item, qty)
			btn.pressed.connect(_on_withdraw.bind(i))
			_bank_grid.add_child(btn)
	# Inventory items
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
			var btn = _make_item_btn(item, qty)
			btn.pressed.connect(_on_deposit.bind(i))
			_inv_grid.add_child(btn)

func _make_item_btn(item, qty: int) -> Button:
	var btn = Button.new()
	var iname = item.call("get_display_name")
	if iname == null:
		iname = "Item"
	btn.text = "%s\nx%d" % [iname, qty]
	btn.custom_minimum_size = Vector2(100, 80)
	btn.add_theme_font_size_override("font_size", 18)
	return btn

func _on_deposit(slot_idx: int) -> void:
	var slot = PlayerInventory.call("get_slot", slot_idx)
	if slot == null or slot.is_empty():
		return
	var item = slot.get("item")
	var qty = slot.get("quantity")
	if item == null:
		return
	PlayerInventory.call("remove_item_at", slot_idx, qty)
	PlayerBank.call("deposit", item, qty)
	var iname = item.call("get_display_name")
	if iname == null:
		iname = "item"
	_status_label.text = "Deposited %s x%d" % [iname, qty]

func _on_withdraw(bank_idx: int) -> void:
	if PlayerInventory.call("is_full"):
		_status_label.text = "Inventory is full!"
		return
	var items = PlayerBank.call("get_items")
	if items == null or bank_idx >= items.size():
		return
	var entry = items[bank_idx]
	var item = entry.get("item")
	var qty = entry.get("quantity")
	if item == null:
		return
	# Withdraw 1 at a time for non-stackable, all for stackable
	var take = qty
	var stackable = item.get("is_stackable")
	if not stackable:
		take = 1
	PlayerBank.call("withdraw", bank_idx, take)
	var iname = item.call("get_display_name")
	if iname == null:
		iname = "item"
	_status_label.text = "Withdrew %s x%d" % [iname, take]

func _clear_grid(grid: GridContainer) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()

func _on_close() -> void:
	visible = false
	bank_closed.emit()

func setup() -> void:
	pass
