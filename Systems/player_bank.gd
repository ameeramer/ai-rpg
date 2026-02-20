extends Node
## Autoload singleton for bank storage. Infinite slots, auto-stacking.

signal bank_changed()

var _items: Array = []
var _initialized: bool = false

func _ready() -> void:
	ensure_initialized()

func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	FileLogger.log_msg("PlayerBank initialized")

func deposit(item, qty: int = 1) -> bool:
	if item == null or qty <= 0:
		return false
	var item_id = item.get("id")
	if item_id == null:
		return false
	# Stack if same item exists
	for entry in _items:
		if entry["item"].get("id") == item_id:
			entry["quantity"] += qty
			bank_changed.emit()
			return true
	_items.append({"item": item, "quantity": qty})
	bank_changed.emit()
	return true

func withdraw(idx: int, qty: int = 1) -> bool:
	if idx < 0 or idx >= _items.size():
		return false
	var entry = _items[idx]
	var item = entry["item"]
	var available = entry["quantity"]
	var to_take = qty
	if to_take > available:
		to_take = available
	var added = PlayerInventory.call("add_item", item, to_take)
	if not added:
		return false
	entry["quantity"] -= to_take
	if entry["quantity"] <= 0:
		_items.remove_at(idx)
	bank_changed.emit()
	return true

func get_items() -> Array:
	return _items

func get_item_count() -> int:
	return _items.size()

func serialize() -> Dictionary:
	var saved = []
	for entry in _items:
		var item = entry["item"]
		var item_id = item.get("id")
		saved.append({
			"item_id": int(item_id) if item_id != null else 0,
			"quantity": entry["quantity"]
		})
	return {"items": saved}

func deserialize(data: Dictionary) -> void:
	_items.clear()
	var saved = data.get("items", [])
	for entry in saved:
		var item_id = int(entry.get("item_id", 0))
		var qty = int(entry.get("quantity", 1))
		var item = ItemRegistry.call("get_item_by_id", item_id)
		if item != null:
			_items.append({"item": item, "quantity": qty})
		else:
			FileLogger.log_msg("PlayerBank: skipped unknown item id %d" % item_id)
	bank_changed.emit()
	FileLogger.log_msg("PlayerBank: deserialized %d items" % _items.size())
