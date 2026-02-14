class_name WeaponData
extends ItemData
## Weapon data resource — extends ItemData with combat stats.

@export_group("Combat Stats")
@export var attack_damage: int = 1
@export var attack_speed: float = 2.4  # Seconds between attacks (OSRS: 4 ticks = 2.4s default)
@export var attack_range: float = 1.5  # Melee range in world units

@export_group("Stat Requirements")
@export var required_attack_level: int = 1
@export var required_strength_level: int = 1
@export var required_ranged_level: int = 1
@export var required_magic_level: int = 1

@export_group("Bonuses")
@export var attack_bonus: int = 0
@export var strength_bonus: int = 0
@export var ranged_bonus: int = 0
@export var magic_bonus: int = 0

@export_group("Style")
@export_enum("Melee", "Ranged", "Magic") var combat_style: String = "Melee"
@export_enum("Slash", "Stab", "Crush", "Ranged", "Magic") var attack_type: String = "Slash"

## Animation to play when attacking
@export var attack_animation: String = "attack_slash"


func _init() -> void:
	category = "Weapon"
	is_equippable = true
	is_stackable = false
	max_stack = 1
