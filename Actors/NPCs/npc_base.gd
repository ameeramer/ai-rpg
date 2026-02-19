extends CharacterBody3D
## Base NPC script — friendly non-combat NPCs with dialogue and optional shop.
## NO class_name — referenced by script path in .tscn files.

@export var display_name: String = "NPC"
@export var npc_role: String = "talk"
@export var dialogue_lines: Array = []
@export var shop_items: Array = []
@export var shop_prices: Array = []

var _initialized: bool = false


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	collision_layer = 16
	collision_mask = 1
	if not get_node_or_null("NameLabel"):
		_add_name_label()
	FileLogger.log_msg("NPC.init: %s role=%s" % [display_name, npc_role])


func _add_name_label() -> void:
	var label = Label3D.new()
	label.name = "NameLabel"
	label.text = display_name
	label.font_size = 32
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.3, 1.0, 0.3)
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0)
	label.position.y = 2.3
	add_child(label)


func get_dialogue() -> Array:
	return dialogue_lines


func is_merchant() -> bool:
	return npc_role == "merchant"


func is_ai_npc() -> bool:
	return false


func get_shop_stock() -> Array:
	# Returns array of dictionaries: {"item": Resource, "price": int}
	var stock: Array = []
	for i in range(shop_items.size()):
		var item = shop_items[i]
		if item == null:
			continue
		var price = 0
		if i < shop_prices.size():
			price = shop_prices[i]
		else:
			var val = item.get("value")
			if val != null:
				price = val
		stock.append({"item": item, "price": price})
	return stock
