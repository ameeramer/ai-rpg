class_name SkillData
extends Resource
## Defines a skill type (e.g., Woodcutting, Attack, Cooking).

@export var id: int = 0
@export var skill_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var max_level: int = 99

## Whether this is a combat skill
@export var is_combat: bool = false

## OSRS XP formula constants
const XP_TABLE_SIZE: int = 100


## Calculate XP required for a given level using OSRS formula.
## Level 1 = 0 XP, Level 2 = 83 XP, etc.
static func xp_for_level(level: int) -> float:
	var total: float = 0.0
	for i in range(1, level):
		total += floorf(i + 300.0 * pow(2.0, i / 7.0))
	return floorf(total / 4.0)


## Get the level for a given amount of XP.
static func level_for_xp(xp: float) -> int:
	for level in range(99, 0, -1):
		if xp >= xp_for_level(level):
			return level
	return 1
