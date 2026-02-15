extends Node
## Autoload singleton for OSRS-style 28-slot inventory.
## Registered as "PlayerInventory" in project.godot autoloads.
## No class_name — autoloads are accessed by name, not type.

var MAX_SLOTS: int = 28

signal item_added(item, quantity, slot_idx)
signal item_removed(item, quantity, slot_idx)
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
	if item.is_stackable:
		for i in range(MAX_SLOTS):
			if slots[i] != null and slots[i]["item"].id == item.id:
				slots[i]["quantity"] += quantity
				item_added.emit(item, quantity, i)
				inventory_changed.emit()
				return true
	if item.is_stackable:
		var slot := _find_empty_slot()
		if slot == -1:
			inventory_full.emit()
			return false
		slots[slot] = {"item": item, "quantity": quantity}
		item_added.emit(item, quantity, slot)
		inventory_changed.emit()
		return true
	else:
		var added_count := 0
		for _q in range(quantity):
			var slot := _find_empty_slot()
			if slot == -1:
				if added_count == 0:
					inventory_full.emit()
					return false
				inventory_changed.emit()
				return true
			slots[slot] = {"item": item, "quantity": 1}
			item_added.emit(item, 1, slot)
			added_count += 1
		inventory_changed.emit()
		return true


func remove_item_at(slot: int, quantity: int = 1) -> Dictionary:
	if slot < 0 or slot >= MAX_SLOTS or slots[slot] == null:
		return {}
	var slot_data: Dictionary = slots[slot]
	var removed_qty := min(quantity, slot_data["quantity"])
	slot_data["quantity"] -= removed_qty
	if slot_data["quantity"] <= 0:
		slots[slot] = null
	item_removed.emit(slot_data["item"], removed_qty, slot)
	inventory_changed.emit()
	return {"item": slot_data["item"], "quantity": removed_qty}


func remove_item_by_id(item_id: int, quantity: int = 1) -> bool:
	var remaining := quantity
	for i in range(MAX_SLOTS):
		if remaining <= 0:
			break
		if slots[i] != null and slots[i]["item"].id == item_id:
			var can_remove := min(remaining, slots[i]["quantity"])
			slots[i]["quantity"] -= can_remove
			remaining -= can_remove
			if slots[i]["quantity"] <= 0:
				slots[i] = null
	if remaining < quantity:
		inventory_changed.emit()
		return remaining == 0
	return false


func get_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= MAX_SLOTS or slots[slot] == null:
		return {}
	return slots[slot]


func has_item(item_id: int, quantity: int = 1) -> bool:
	var total := 0
	for slot in slots:
		if slot != null and slot["item"].id == item_id:
			total += slot["quantity"]
			if total >= quantity:
				return true
	return false


func count_item(item_id: int) -> int:
	var total := 0
	for slot in slots:
		if slot != null and slot["item"].id == item_id:
			total += slot["quantity"]
	return total


func swap_slots(from: int, to: int) -> void:
	if from < 0 or from >= MAX_SLOTS or to < 0 or to >= MAX_SLOTS:
		return
	var temp = slots[from]
	slots[from] = slots[to]
	slots[to] = temp
	inventory_changed.emit()


func get_used_slots() -> int:
	var count := 0
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
