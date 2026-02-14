class_name FoodData
extends ItemData
## Food data resource — heals the player when consumed.

@export_group("Healing")
@export var heal_amount: int = 5  # HP restored on eat
@export var eat_ticks: int = 3    # Game ticks to consume (OSRS: 3 tick eat delay)

@export_group("Cooking")
@export var raw_item_id: int = -1       # ID of the raw version (if this is cooked)
@export var cooked_item_id: int = -1    # ID of the cooked version (if this is raw)
@export var burnt_item_id: int = -1     # ID of the burnt version
@export var required_cooking_level: int = 1
@export var cooking_xp: float = 30.0
@export var burn_stop_level: int = 99   # Level at which you stop burning


func _init() -> void:
	category = "Food"
	is_stackable = false
	max_stack = 1
