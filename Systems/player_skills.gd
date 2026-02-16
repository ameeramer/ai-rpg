extends Node
## Autoload singleton for OSRS-style skills system.
## Registered as "PlayerSkills" in project.godot autoloads.
## No class_name — autoloads are accessed by name, not type.

signal xp_gained(skill_name, amount, total_xp)
signal level_up(skill_name, new_level)

var SKILL_NAMES = [
	"Attack", "Strength", "Defence", "Hitpoints",
	"Ranged", "Prayer", "Magic",
	"Cooking", "Woodcutting", "Fishing", "Mining",
	"Smithing", "Crafting", "Firemaking",
	"Agility", "Thieving"
]

var skill_xp: Dictionary = {}
var skill_levels: Dictionary = {}
var _initialized: bool = false


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	for skill in SKILL_NAMES:
		if skill == "Hitpoints":
			skill_xp[skill] = _xp_for_level(10)
			skill_levels[skill] = 10
		else:
			skill_xp[skill] = 0.0
			skill_levels[skill] = 1
	FileLogger.log_msg("PlayerSkills initialized: %d skills" % skill_levels.size())


func get_level(skill_name: String) -> int:
	return skill_levels.get(skill_name, 1)


func get_xp(skill_name: String) -> float:
	return skill_xp.get(skill_name, 0.0)


func get_xp_to_next_level(skill_name: String) -> float:
	var current_level = get_level(skill_name)
	if current_level >= 99:
		return 0.0
	return _xp_for_level(current_level + 1) - get_xp(skill_name)


func get_level_progress(skill_name: String) -> float:
	var current_level = get_level(skill_name)
	if current_level >= 99:
		return 1.0
	var current_level_xp = _xp_for_level(current_level)
	var next_level_xp = _xp_for_level(current_level + 1)
	return (get_xp(skill_name) - current_level_xp) / (next_level_xp - current_level_xp)


func add_xp(skill_name: String, amount: float) -> void:
	if not skill_xp.has(skill_name):
		return
	skill_xp[skill_name] += amount
	xp_gained.emit(skill_name, amount, skill_xp[skill_name])
	var new_level = _level_for_xp(skill_xp[skill_name])
	if new_level > skill_levels[skill_name]:
		skill_levels[skill_name] = new_level
		level_up.emit(skill_name, new_level)
		GameManager.log_action("Congratulations! Your %s level is now %d!" % [skill_name, new_level])
		if skill_name == "Hitpoints":
			_update_player_hp(new_level)


func add_combat_xp(total_xp: float) -> void:
	add_xp("Attack", total_xp * 0.75)
	add_xp("Hitpoints", total_xp * 0.25)


func get_combat_level() -> int:
	var base = 0.25 * (get_level("Defence") + get_level("Hitpoints") + floorf(get_level("Prayer") / 2.0))
	var melee = 0.325 * (get_level("Attack") + get_level("Strength"))
	var ranged = 0.325 * (floorf(get_level("Ranged") / 2.0) + get_level("Ranged"))
	var magic = 0.325 * (floorf(get_level("Magic") / 2.0) + get_level("Magic"))
	return int(base + max(melee, max(ranged, magic)))


func _xp_for_level(level: int) -> float:
	var total: float = 0.0
	for i in range(1, level):
		total += floorf(i + 300.0 * pow(2.0, i / 7.0))
	return floorf(total / 4.0)


func _level_for_xp(xp: float) -> int:
	for level in range(99, 0, -1):
		if xp >= _xp_for_level(level):
			return level
	return 1


func serialize() -> Dictionary:
	return {"skill_xp": skill_xp.duplicate()}


func deserialize(data: Dictionary) -> void:
	var saved_xp = data.get("skill_xp", {})
	for skill in SKILL_NAMES:
		if saved_xp.has(skill):
			skill_xp[skill] = float(saved_xp[skill])
	for skill in SKILL_NAMES:
		skill_levels[skill] = _level_for_xp(skill_xp[skill])
	FileLogger.log_msg("PlayerSkills: deserialized %d skills" % SKILL_NAMES.size())


func _update_player_hp(new_level: int) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		player.max_hitpoints = new_level
		player.hitpoints = new_level
