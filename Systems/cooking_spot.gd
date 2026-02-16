extends StaticBody3D
## Cooking fire/range interactable — cooks raw food in player's inventory.
## NO class_name — referenced by script path in .tscn files.

@export var display_name: String = "Cooking Fire"
@export var interaction_verb: String = "Cook"
@export var ticks_per_action: int = 4
@export var is_active: bool = true

var _is_depleted: bool = false
var _ticks_remaining: int = 0
var _cooking_item_id: int = -1
var _cooking_slot: int = -1
var _initialized: bool = false

signal interaction_started(player)
signal interaction_completed(player)


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	collision_layer = 8
	FileLogger.log_msg("CookingSpot.init: %s" % display_name)


func interact(player) -> bool:
	if not is_active:
		return false
	# Find cookable raw food in inventory
	var found = _find_cookable_item()
	if found.is_empty():
		GameManager.log_action("You have nothing to cook.")
		return false
	_cooking_slot = found["slot"]
	_cooking_item_id = found["item_id"]
	_ticks_remaining = ticks_per_action
	var item_name = found["name"]
	GameManager.log_action("You begin cooking %s." % item_name)
	interaction_started.emit(player)
	return true


func is_repeating() -> bool:
	return true


func stop_interaction(_player) -> void:
	_ticks_remaining = 0
	_cooking_slot = -1


func interaction_tick(player) -> Dictionary:
	_ticks_remaining -= 1
	if _ticks_remaining > 0:
		return {"completed": false}
	return _cook_one(player)


func _cook_one(player) -> Dictionary:
	var inv_slots = PlayerInventory.get("slots")
	if inv_slots == null:
		return {"completed": true}
	# Find the raw food again (slot may have shifted)
	var found = _find_cookable_item()
	if found.is_empty():
		GameManager.log_action("You have nothing left to cook.")
		return {"completed": true}
	var slot_idx = found["slot"]
	var raw_item = found["item"]
	var cooked_id = raw_item.get("cooked_item_id")
	var cooking_lvl = raw_item.get("required_cooking_level")
	if cooking_lvl == null:
		cooking_lvl = 1
	var burn_stop = raw_item.get("burn_stop_level")
	if burn_stop == null:
		burn_stop = 99
	var cooking_xp = raw_item.get("cooking_xp")
	if cooking_xp == null:
		cooking_xp = 30.0
	var player_lvl = PlayerSkills.call("get_level", "Cooking")
	# Roll for burn
	var burn_chance = 0.5 - (player_lvl - cooking_lvl) * 0.03
	if player_lvl >= burn_stop:
		burn_chance = 0.0
	if burn_chance < 0.05:
		burn_chance = 0.05
	if player_lvl >= burn_stop:
		burn_chance = 0.0
	# Remove raw item
	PlayerInventory.call("remove_item_at", slot_idx, 1)
	if randf() < burn_chance:
		# Burnt!
		var burnt = load("res://Data/Food/burnt_food.tres")
		if burnt:
			PlayerInventory.call("add_item", burnt, 1)
		GameManager.log_action("You accidentally burn the %s." % found["name"])
	else:
		# Success — add cooked item
		if cooked_id != null and cooked_id > 0:
			var cooked = _load_cooked_item(cooked_id)
			if cooked:
				PlayerInventory.call("add_item", cooked, 1)
				GameManager.log_action("You cook the %s." % found["name"])
			else:
				GameManager.log_action("You cook something but it vanishes...")
		else:
			GameManager.log_action("You cook the %s." % found["name"])
		PlayerSkills.call("add_xp", "Cooking", cooking_xp)
	# Check for more to cook
	var more = _find_cookable_item()
	if more.is_empty():
		return {"completed": true}
	_ticks_remaining = ticks_per_action
	return {"completed": false}


func _find_cookable_item() -> Dictionary:
	var inv_slots = PlayerInventory.get("slots")
	if inv_slots == null:
		return {}
	for i in range(inv_slots.size()):
		if inv_slots[i] == null:
			continue
		var item = inv_slots[i]["item"]
		var cooked_id = item.get("cooked_item_id")
		if cooked_id != null and cooked_id > 0:
			var name_str = item.call("get_display_name")
			return {"slot": i, "item": item, "item_id": item.get("id"), "name": name_str}
	return {}


func _load_cooked_item(cooked_id: int):
	# Map known cooked item IDs to .tres paths
	var paths = {
		315: "res://Data/Food/shrimps.tres",
		333: "res://Data/Food/trout.tres"
	}
	var path = paths.get(cooked_id, "")
	if path != "":
		return load(path)
	return null
