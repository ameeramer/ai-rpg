class_name DropTableEntry
extends Resource
## A single entry in a drop table — used by enemies and gathering nodes.

@export var item: Resource
@export var min_quantity: int = 1
@export var max_quantity: int = 1
@export_range(0.0, 1.0) var drop_chance: float = 1.0  # 1.0 = always drops


func roll() -> Dictionary:
	## Returns {"item": ItemData, "quantity": int} or empty dict if roll fails.
	if randf() <= drop_chance:
		var qty := randi_range(min_quantity, max_quantity)
		return {"item": item, "quantity": qty}
	return {}
