extends Node
## Autoload singleton for OSRS-style 28-slot inventory.
## Registered as "PlayerInventory" in project.godot autoloads.
## No class_name — autoloads are accessed by name, not type.

var MAX_SLOTS: int = 28

signal inventory_changed()
signal inventory_full()

var slots: Array = []
var _initialized: bool = false


func _ready() -> void:
	print("[LOG] PlayerInventory._ready() start")
	FileLogger.log_msg("PlayerInventory._ready() start")
	ensure_initialized()
	FileLogger.log_msg("PlayerInventory._ready() done")


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		slots[i] = null
	FileLogger.log_msg("PlayerInventory initialized: %d slots" % MAX_SLOTS)


func add_item(item, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false
	# Try stacking into existing slot first
	if item.is_stackable:
		for i in range(MAX_SLOTS):
			if slots[i] != null and slots[i]["item"].id == item.id:
				slots[i]["quantity"] += quantity
				inventory_changed.emit()
				return true
	# Find an empty slot
	if item.is_stackable:
		var empty = _find_empty_slot()
		if empty == -1:
			inventory_full.emit()
			return false
		slots[empty] = {"item": item, "quantity": quantity}
		inventory_changed.emit()
		return true
	else:
		var added_count: int = 0
		for _q in range(quantity):
			var empty = _find_empty_slot()
			if empty == -1:
				if added_count == 0:
					inventory_full.emit()
					return false
				inventory_changed.emit()
				return true
			slots[empty] = {"item": item, "quantity": 1}
			added_count += 1
		inventory_changed.emit()
		return true


func remove_item_at(slot_idx: int, quantity: int = 1) -> Dictionary:
	if slot_idx < 0 or slot_idx >= MAX_SLOTS or slots[slot_idx] == null:
		return {}
	var slot_data: Dictionary = slots[slot_idx]
	var qty = slot_data["quantity"]
	var to_remove = quantity
	if to_remove > qty:
		to_remove = qty
	slot_data["quantity"] -= to_remove
	if slot_data["quantity"] <= 0:
		slots[slot_idx] = null
	inventory_changed.emit()
	return {"item": slot_data["item"], "quantity": to_remove}


func remove_item_by_id(item_id: int, quantity: int = 1) -> bool:
	var remaining: int = quantity
	for i in range(MAX_SLOTS):
		if remaining <= 0:
			break
		if slots[i] != null and slots[i]["item"].id == item_id:
			var qty = slots[i]["quantity"]
			var to_remove = remaining
			if to_remove > qty:
				to_remove = qty
			slots[i]["quantity"] -= to_remove
			remaining -= to_remove
			if slots[i]["quantity"] <= 0:
				slots[i] = null
	if remaining < quantity:
		inventory_changed.emit()
		return remaining == 0
	return false


func get_slot(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= MAX_SLOTS or slots[slot_idx] == null:
		return {}
	return slots[slot_idx]


func has_item(item_id: int, quantity: int = 1) -> bool:
	var total: int = 0
	for slot in slots:
		if slot != null and slot["item"].id == item_id:
			total += slot["quantity"]
			if total >= quantity:
				return true
	return false


func count_item(item_id: int) -> int:
	var total: int = 0
	for slot in slots:
		if slot != null and slot["item"].id == item_id:
			total += slot["quantity"]
	return total


func swap_slots(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= MAX_SLOTS:
		return
	if to_idx < 0 or to_idx >= MAX_SLOTS:
		return
	var temp = slots[from_idx]
	slots[from_idx] = slots[to_idx]
	slots[to_idx] = temp
	inventory_changed.emit()


func get_used_slots() -> int:
	var count: int = 0
	for slot in slots:
		if slot != null:
			count += 1
	return count


func is_full() -> bool:
	return get_used_slots() >= MAX_SLOTS


func _find_empty_slot() -> int:
	for i in range(MAX_SLOTS):
		if slots[i] == null:
			return i
	return -1


func serialize() -> Dictionary:
	var saved_slots = []
	for i in range(MAX_SLOTS):
		if slots[i] == null:
			saved_slots.append(null)
		else:
			var item = slots[i]["item"]
			var item_id = item.get("id")
			saved_slots.append({
				"item_id": int(item_id) if item_id != null else 0,
				"quantity": slots[i]["quantity"]
			})
	return {"slots": saved_slots}


func deserialize(data: Dictionary) -> void:
	var saved_slots = data.get("slots", [])
	for i in range(MAX_SLOTS):
		if i >= saved_slots.size() or saved_slots[i] == null:
			slots[i] = null
		else:
			var entry = saved_slots[i]
			var item_id = int(entry.get("item_id", 0))
			var qty = int(entry.get("quantity", 1))
			var item = ItemRegistry.call("get_item_by_id", item_id)
			if item != null:
				slots[i] = {"item": item, "quantity": qty}
			else:
				slots[i] = null
				FileLogger.log_msg("PlayerInventory: skipped unknown item id %d" % item_id)
	inventory_changed.emit()
	FileLogger.log_msg("PlayerInventory: deserialized %d slots" % MAX_SLOTS)
