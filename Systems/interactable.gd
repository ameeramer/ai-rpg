class_name Interactable
extends StaticBody3D
## Base class for all interactable objects in the world.
## Subclass this for trees, rocks, fishing spots, NPCs, etc.

@export var display_name: String = "Object"
@export var interaction_verb: String = "Use"  # "Chop", "Mine", "Fish", etc.
@export var ticks_per_action: int = 4  # Game ticks per gathering attempt
@export var required_skill: String = ""  # Skill name required (empty = none)
@export var required_level: int = 1
@export var xp_reward: float = 0.0
@export var drop_table: Array[DropTableEntry] = []

## Whether this object can be interacted with right now
@export var is_active: bool = true

## Respawn time in game ticks (0 = no respawn needed)
@export var respawn_ticks: int = 0

signal interaction_started(player: Node3D)
signal interaction_completed(player: Node3D)
signal depleted()
signal respawned()

var _ticks_remaining: int = 0
var _is_depleted: bool = false
var _respawn_counter: int = 0


func _ready() -> void:
	add_to_group("interactables")


func interact(player: Node3D) -> bool:
	FileLogger.log_msg("interact(%s) is_active=%s _is_depleted=%s" % [display_name, str(is_active), str(_is_depleted)])
	if not is_active or _is_depleted:
		GameManager.log_action("You can't %s this right now." % interaction_verb.to_lower())
		return false

	# Check skill requirement
	if required_skill != "":
		var skills_node := player.get_node_or_null("PlayerSkills")
		var has_scr = skills_node.get_script() if skills_node else null
		var is_init = skills_node.get("_initialized") if skills_node else null
		FileLogger.log_msg("interact: skill=%s node=%s script=%s init=%s" % [required_skill, str(skills_node != null), str(has_scr != null), str(is_init)])
		if skills_node and has_scr and is_init:
			# Script loaded and initialized — safe to read skill data directly
			var levels_dict = skills_node.get("skill_levels")
			FileLogger.log_msg("interact: skill_levels=%s" % str(levels_dict))
			var level: int = 1
			if levels_dict and levels_dict is Dictionary:
				level = levels_dict.get(required_skill, 1)
			FileLogger.log_msg("interact: level=%d required=%d" % [level, required_level])
			if level < required_level:
				GameManager.log_action("You need level %d %s to %s this." % [
					required_level, required_skill, interaction_verb.to_lower()
				])
				return false
		elif skills_node and has_scr and not is_init:
			FileLogger.log_msg("interact: skills has script but NOT initialized — skipping check")
		elif skills_node and not has_scr:
			FileLogger.log_msg("interact: skills node exists but NO script — skipping check")

	_ticks_remaining = ticks_per_action
	GameManager.log_action("You begin to %s the %s." % [interaction_verb.to_lower(), display_name])
	interaction_started.emit(player)
	return true


func is_repeating() -> bool:
	return true


func get_animation_name() -> String:
	return "interact"


func stop_interaction(_player: Node3D) -> void:
	_ticks_remaining = 0


func interaction_tick(player: Node3D) -> Dictionary:
	if _is_depleted or not is_active:
		return {"completed": true}

	_ticks_remaining -= 1
	if _ticks_remaining <= 0:
		return _complete_action(player)
	return {"completed": false}


func _complete_action(player: Node3D) -> Dictionary:
	# Roll drop table
	for entry in drop_table:
		var drop := entry.roll()
		if not drop.is_empty():
			_give_item_to_player(player, drop["item"], drop["quantity"])

	# Grant XP — guard with _initialized, not get_script()
	if xp_reward > 0.0 and required_skill != "":
		var skills_node := player.get_node_or_null("PlayerSkills")
		if skills_node and skills_node.get("_initialized"):
			skills_node.call("add_xp", required_skill, xp_reward)

	interaction_completed.emit(player)

	# Reset for next action cycle
	_ticks_remaining = ticks_per_action

	# Check if object should deplete (override in subclass)
	if _should_deplete():
		_deplete()
		return {"completed": true}

	return {"completed": false}


func _give_item_to_player(player: Node3D, item: ItemData, quantity: int) -> void:
	var inventory := player.get_node_or_null("PlayerInventory")
	if inventory and inventory.get("_initialized"):
		var added = inventory.call("add_item", item, quantity)
		if added == false:
			GameManager.log_action("Your inventory is full.")
		else:
			GameManager.log_action("You get some %s." % item.get_display_name())


func _should_deplete() -> bool:
	return false


func _deplete() -> void:
	_is_depleted = true
	depleted.emit()

	if respawn_ticks > 0:
		_respawn_counter = respawn_ticks
		GameManager.game_tick.connect(_respawn_tick)


func _respawn_tick(_tick: int) -> void:
	_respawn_counter -= 1
	if _respawn_counter <= 0:
		_is_depleted = false
		GameManager.game_tick.disconnect(_respawn_tick)
		respawned.emit()
