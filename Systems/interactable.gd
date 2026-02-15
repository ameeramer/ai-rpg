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
@export var drop_table: Array = []

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

	# Check skill requirement via autoload singleton
	if required_skill != "":
		var level: int = PlayerSkills.get_level(required_skill)
		FileLogger.log_msg("interact: skill=%s level=%d required=%d" % [required_skill, level, required_level])
		if level < required_level:
			GameManager.log_action("You need level %d %s to %s this." % [
				required_level, required_skill, interaction_verb.to_lower()
			])
			return false

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

	# Grant XP via autoload singleton
	if xp_reward > 0.0 and required_skill != "":
		PlayerSkills.add_xp(required_skill, xp_reward)
		FileLogger.log_msg("XP: %s +%.1f" % [required_skill, xp_reward])

	interaction_completed.emit(player)

	# Reset for next action cycle
	_ticks_remaining = ticks_per_action

	# Check if object should deplete (override in subclass)
	if _should_deplete():
		_deplete()
		return {"completed": true}

	return {"completed": false}


func _give_item_to_player(_player: Node3D, item: Resource, quantity: int) -> void:
	var added = PlayerInventory.add_item(item, quantity)
	if added:
		GameManager.log_action("You get some %s." % item.get_display_name())
	else:
		GameManager.log_action("Your inventory is full.")


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
