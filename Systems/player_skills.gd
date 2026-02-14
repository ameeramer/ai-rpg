class_name PlayerSkills
extends Node
## OSRS-style skills system. Tracks XP and levels for all skills.

signal xp_gained(skill_name: String, amount: float, total_xp: float)
signal level_up(skill_name: String, new_level: int)

## All skill names in the game
const SKILL_NAMES: Array[String] = [
	"Attack", "Strength", "Defence", "Hitpoints",
	"Ranged", "Prayer", "Magic",
	"Cooking", "Woodcutting", "Fishing", "Mining",
	"Smithing", "Crafting", "Firemaking",
	"Agility", "Thieving"
]

## Combat skills that receive XP from fighting
const COMBAT_SKILLS: Array[String] = [
	"Attack", "Strength", "Defence", "Hitpoints",
	"Ranged", "Prayer", "Magic"
]

## XP stored per skill
var skill_xp: Dictionary = {}

## Cached levels
var skill_levels: Dictionary = {}


func _ready() -> void:
	# Initialize all skills at level 1 (0 XP), Hitpoints at level 10
	for skill in SKILL_NAMES:
		if skill == "Hitpoints":
			skill_xp[skill] = SkillData.xp_for_level(10)
			skill_levels[skill] = 10
		else:
			skill_xp[skill] = 0.0
			skill_levels[skill] = 1


## Get current level for a skill.
func get_level(skill_name: String) -> int:
	return skill_levels.get(skill_name, 1)


## Get current XP for a skill.
func get_xp(skill_name: String) -> float:
	return skill_xp.get(skill_name, 0.0)


## Get XP needed for next level.
func get_xp_to_next_level(skill_name: String) -> float:
	var current_level := get_level(skill_name)
	if current_level >= 99:
		return 0.0
	var next_level_xp := SkillData.xp_for_level(current_level + 1)
	return next_level_xp - get_xp(skill_name)


## Get progress percentage to next level (0.0 to 1.0).
func get_level_progress(skill_name: String) -> float:
	var current_level := get_level(skill_name)
	if current_level >= 99:
		return 1.0
	var current_level_xp := SkillData.xp_for_level(current_level)
	var next_level_xp := SkillData.xp_for_level(current_level + 1)
	var xp := get_xp(skill_name)
	return (xp - current_level_xp) / (next_level_xp - current_level_xp)


## Add XP to a skill.
func add_xp(skill_name: String, amount: float) -> void:
	if not skill_xp.has(skill_name):
		push_warning("Unknown skill: %s" % skill_name)
		return

	skill_xp[skill_name] += amount
	xp_gained.emit(skill_name, amount, skill_xp[skill_name])

	# Check for level up
	var new_level := SkillData.level_for_xp(skill_xp[skill_name])
	if new_level > skill_levels[skill_name]:
		var old_level := skill_levels[skill_name]
		skill_levels[skill_name] = new_level
		level_up.emit(skill_name, new_level)
		GameManager.log_action("Congratulations! Your %s level is now %d!" % [skill_name, new_level])

		# Update max HP if Hitpoints leveled
		if skill_name == "Hitpoints":
			_update_max_hp()


## Add combat XP, split between Attack/Strength/Defence and Hitpoints.
## In OSRS, you get 4 XP per damage in your chosen style + 1.33 HP XP.
func add_combat_xp(total_xp: float) -> void:
	# Split: 75% to chosen combat style, 25% to Hitpoints
	var combat_xp := total_xp * 0.75
	var hp_xp := total_xp * 0.25

	# Default to Attack for now — TODO: combat style selection
	add_xp("Attack", combat_xp)
	add_xp("Hitpoints", hp_xp)


## Get total combat level.
func get_combat_level() -> int:
	var base := 0.25 * (get_level("Defence") + get_level("Hitpoints") + floorf(get_level("Prayer") / 2.0))
	var melee := 0.325 * (get_level("Attack") + get_level("Strength"))
	var ranged := 0.325 * (floorf(get_level("Ranged") / 2.0) + get_level("Ranged"))
	var magic := 0.325 * (floorf(get_level("Magic") / 2.0) + get_level("Magic"))
	return int(base + max(melee, max(ranged, magic)))


func _update_max_hp() -> void:
	var player := get_parent()
	if player and "max_hitpoints" in player:
		player.max_hitpoints = get_level("Hitpoints")
		player.hitpoints = player.max_hitpoints
