class_name InventoryUI
extends GridContainer
## Renders the 28-slot inventory grid. Each slot is a TextureButton.

const SLOT_SIZE := Vector2(48, 48)

var _inventory: PlayerInventory
var _slot_buttons: Array[Button] = []


func _ready() -> void:
	columns = 4  # 4 columns x 7 rows = 28 slots
	_create_slots()


func setup(inventory: PlayerInventory) -> void:
	_inventory = inventory
	_inventory.inventory_changed.connect(refresh)
	refresh()


func _create_slots() -> void:
	for i in range(PlayerInventory.MAX_SLOTS):
		var btn := Button.new()
		btn.custom_minimum_size = SLOT_SIZE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
				# Fallback: show item name
				btn.text = item.item_name.substr(0, 4)
				if qty > 1:
					btn.text += "\n" + str(qty)


func _on_slot_pressed(slot_index: int) -> void:
	if _inventory == null:
		return

	var slot_data := _inventory.get_slot(slot_index)
	if slot_data.is_empty():
		return

	var item: ItemData = slot_data["item"]
	# TODO: Show item context menu (Use, Drop, Examine)
	GameManager.log_action("Selected: %s" % item.get_display_name())
