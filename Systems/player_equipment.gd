extends Node
## Autoload singleton for OSRS-style equipment system.
## Registered as "PlayerEquipment" in project.godot autoloads.
## No class_name — autoloads are accessed by name, not type.

signal equipment_changed()

var slots: Dictionary = {}
var _initialized: bool = false

var SLOT_NAMES: Array = [
	"Head", "Cape", "Amulet", "Weapon", "Body",
	"Shield", "Legs", "Hands", "Feet", "Ring"
]


func _ready() -> void:
	FileLogger.log_msg("PlayerEquipment._ready() start")
	ensure_initialized()
	FileLogger.log_msg("PlayerEquipment._ready() done")


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	for slot_name in SLOT_NAMES:
		slots[slot_name] = null
	FileLogger.log_msg("PlayerEquipment initialized: %d slots" % SLOT_NAMES.size())


func equip_item(item, from_slot_idx: int) -> bool:
	if item == null:
		return false
	var equippable = item.get("is_equippable")
	if not equippable:
		return false
	# Determine which equipment slot this item goes in
	var target_slot = _get_slot_for_item(item)
	if target_slot == "":
		return false
	# Check level requirements
	if not _meets_requirements(item):
		return false
	# Unequip existing item in that slot first
	var old_item = slots[target_slot]
	slots[target_slot] = item
	# Remove the item from inventory
	PlayerInventory.call("remove_item_at", from_slot_idx, 1)
	# Put old item back in inventory if there was one
	if old_item != null:
		var added = PlayerInventory.call("add_item", old_item, 1)
		if not added:
			# Inventory full — put back old item and return the new one
			slots[target_slot] = old_item
			PlayerInventory.call("add_item", item, 1)
			GameManager.log_action("Your inventory is full.")
			return false
	equipment_changed.emit()
	GameManager.log_action("You equip the %s." % item.call("get_display_name"))
	return true


func unequip_slot(slot_name: String) -> bool:
	if not slots.has(slot_name):
		return false
	var item = slots[slot_name]
	if item == null:
		return false
	var added = PlayerInventory.call("add_item", item, 1)
	if not added:
		GameManager.log_action("Your inventory is full.")
		return false
	slots[slot_name] = null
	equipment_changed.emit()
	GameManager.log_action("You unequip the %s." % item.call("get_display_name"))
	return true


func get_slot(slot_name: String):
	if slots.has(slot_name):
		return slots[slot_name]
	return null


func _get_slot_for_item(item) -> String:
	var cat = item.get("category")
	if cat == "Weapon" or cat == "Tool":
		return "Weapon"
	if cat == "Armor":
		var eq_slot = item.get("equipment_slot")
		if eq_slot != null and slots.has(eq_slot):
			return eq_slot
		return "Body"
	return ""


func _meets_requirements(item) -> bool:
	var cat = item.get("category")
	if cat == "Weapon" or cat == "Tool":
		var req = item.get("required_attack_level")
		if req != null and req > 1:
			var lvl = PlayerSkills.call("get_level", "Attack")
			if lvl < req:
				GameManager.log_action("You need Attack level %d." % req)
				return false
	elif cat == "Armor":
		var req = item.get("required_defence_level")
		if req != null and req > 1:
			var lvl = PlayerSkills.call("get_level", "Defence")
			if lvl < req:
				GameManager.log_action("You need Defence level %d." % req)
				return false
	return true


func get_attack_bonus() -> int:
	var total: int = 0
	for slot_name in SLOT_NAMES:
		var item = slots[slot_name]
		if item == null:
			continue
		var val = item.get("attack_bonus")
		if val != null:
			total += val
	return total


func get_strength_bonus() -> int:
	var total: int = 0
	for slot_name in SLOT_NAMES:
		var item = slots[slot_name]
		if item == null:
			continue
		var val = item.get("strength_bonus")
		if val != null:
			total += val
	return total


func get_defence_bonus() -> int:
	var total: int = 0
	for slot_name in SLOT_NAMES:
		var item = slots[slot_name]
		if item == null:
			continue
		var val = item.get("defence_bonus")
		if val != null:
			total += val
	return total


func get_weapon() -> Object:
	return slots.get("Weapon", null)


func serialize() -> Dictionary:
	var saved_slots = {}
	for slot_name in SLOT_NAMES:
		var item = slots[slot_name]
		if item == null:
			saved_slots[slot_name] = null
		else:
			var item_id = item.get("id")
			saved_slots[slot_name] = int(item_id) if item_id != null else 0
	return {"slots": saved_slots}


func deserialize(data: Dictionary) -> void:
	var saved_slots = data.get("slots", {})
	for slot_name in SLOT_NAMES:
		if saved_slots.has(slot_name) and saved_slots[slot_name] != null:
			var item_id = int(saved_slots[slot_name])
			var item = ItemRegistry.call("get_item_by_id", item_id)
			if item != null:
				slots[slot_name] = item
			else:
				slots[slot_name] = null
				FileLogger.log_msg("PlayerEquipment: skipped unknown item id %d in %s" % [item_id, slot_name])
		else:
			slots[slot_name] = null
	equipment_changed.emit()
	FileLogger.log_msg("PlayerEquipment: deserialized equipment")
