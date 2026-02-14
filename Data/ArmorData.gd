class_name ArmorData
extends ItemData
## Armor data resource — extends ItemData with defensive stats.

@export_group("Defence Bonuses")
@export var defence_bonus: int = 0
@export var ranged_defence: int = 0
@export var magic_defence: int = 0

@export_group("Stat Requirements")
@export var required_defence_level: int = 1

@export_group("Slot")
@export_enum("Head", "Body", "Legs", "Feet", "Hands", "Shield", "Cape", "Ring", "Amulet") var equipment_slot: String = "Body"

@export_group("Other Bonuses")
@export var prayer_bonus: int = 0
@export var strength_bonus: int = 0


func _init() -> void:
	category = "Armor"
	is_equippable = true
	is_stackable = false
	max_stack = 1
