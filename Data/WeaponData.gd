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
## Weapon category determines available attack styles (OSRS-style)
## sword = Stab/Accurate, Slash/Aggressive, Slash/Defensive
## scimitar = Chop/Accurate, Slash/Aggressive, Lunge/Controlled, Block/Defensive
## axe = Chop/Accurate, Hack/Aggressive, Smash/Aggressive(Crush), Block/Defensive
## mace = Pound/Accurate, Pummel/Aggressive, Spike/Controlled, Block/Defensive
## unarmed = Punch/Accurate, Kick/Aggressive, Block/Defensive
@export_enum("sword", "scimitar", "axe", "mace", "unarmed") var weapon_category: String = "sword"

## Animation to play when attacking
@export var attack_animation: String = "attack_slash"


func _init() -> void:
	category = "Weapon"
	is_equippable = true
	is_stackable = false
	max_stack = 1
