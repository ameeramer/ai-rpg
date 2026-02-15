class_name InventoryUI
extends GridContainer
## Renders the 28-slot inventory grid with OSRS-style slot buttons.

const SLOT_SIZE := Vector2(88, 88)

## Use Node instead of PlayerInventory — `is PlayerInventory` fails on Android
var _inventory: Node
var _slot_buttons: Array[Button] = []


func _ready() -> void:
	columns = 4  # 4 columns x 7 rows = 28 slots
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	_create_slots()


## Accept Node — typed PlayerInventory param fails on Android (type check crash)
func setup(inventory: Node) -> void:
	_inventory = inventory
	_inventory.inventory_changed.connect(refresh)
	refresh()


func _create_slots() -> void:
	var slot_normal := StyleBoxFlat.new()
	slot_normal.bg_color = Color(0.18, 0.15, 0.12, 0.9)
	slot_normal.border_width_left = 1
	slot_normal.border_width_top = 1
	slot_normal.border_width_right = 1
	slot_normal.border_width_bottom = 1
	slot_normal.border_color = Color(0.35, 0.3, 0.2, 0.8)
	slot_normal.corner_radius_top_left = 3
	slot_normal.corner_radius_top_right = 3
	slot_normal.corner_radius_bottom_right = 3
	slot_normal.corner_radius_bottom_left = 3

	var slot_hover := StyleBoxFlat.new()
	slot_hover.bg_color = Color(0.25, 0.22, 0.16, 0.95)
	slot_hover.border_width_left = 1
	slot_hover.border_width_top = 1
	slot_hover.border_width_right = 1
	slot_hover.border_width_bottom = 1
	slot_hover.border_color = Color(0.6, 0.5, 0.3, 1)
	slot_hover.corner_radius_top_left = 3
	slot_hover.corner_radius_top_right = 3
	slot_hover.corner_radius_bottom_right = 3
	slot_hover.corner_radius_bottom_left = 3

	for i in range(PlayerInventory.MAX_SLOTS):
		var btn := Button.new()
		btn.custom_minimum_size = SLOT_SIZE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.add_theme_stylebox_override("normal", slot_normal)
		btn.add_theme_stylebox_override("hover", slot_hover)
		btn.add_theme_stylebox_override("pressed", slot_hover)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		btn.text = ""
		btn.pressed.connect(_on_slot_pressed.bind(i))
		add_child(btn)
		_slot_buttons.append(btn)


func refresh() -> void:
	if _inventory == null:
		return

	for i in range(PlayerInventory.MAX_SLOTS):
		var slot_data := _inventory.get_slot(i)
		var btn := _slot_buttons[i]

		if slot_data.is_empty():
			btn.text = ""
			btn.icon = null
			btn.tooltip_text = "Empty"
		else:
			var item: ItemData = slot_data["item"]
			var qty: int = slot_data["quantity"]
			btn.tooltip_text = item.get_display_name()

			if item.icon:
				btn.icon = item.icon
				btn.text = str(qty) if qty > 1 else ""
			else:
				# Show item name (up to 6 chars)
				var display := item.item_name.substr(0, 6)
				if qty > 1:
					display += "\nx" + str(qty)
				btn.text = display


func _on_slot_pressed(slot_index: int) -> void:
	if _inventory == null:
		return

	var slot_data := _inventory.get_slot(slot_index)
	if slot_data.is_empty():
		return

	var item: ItemData = slot_data["item"]
	GameManager.log_action("Selected: %s" % item.get_display_name())
