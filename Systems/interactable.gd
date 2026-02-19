extends StaticBody3D
## Base interactable + gathering node logic (flattened for Android).
## NO class_name — referenced by script path in .tscn files.
## Handles interaction, repeating tick actions, depletion, respawn,
## and gathering-specific success rolls + mesh swapping.

@export var display_name: String = "Object"
@export var interaction_verb: String = "Use"
@export var ticks_per_action: int = 4
@export var required_skill: String = ""
@export var required_level: int = 1
@export var xp_reward: float = 0.0
@export var drop_table: Array = []
@export var is_active: bool = true
@export var respawn_ticks: int = 0

## Model sizing — set desired height in meters, 0 = no scaling
@export var model_height = 0.0
@export var depleted_model_height = 0.0

## Gathering-specific exports
@export var min_gathers: int = 1
@export var max_gathers: int = 5
@export var base_success_chance: float = 0.5

signal interaction_started(player)
signal interaction_completed(player)
signal depleted()
signal respawned()

var _ticks_remaining: int = 0
var _is_depleted: bool = false
var _respawn_counter: int = 0
var _gathers_remaining: int = 0
var _active_mesh: Node3D
var _depleted_mesh: Node3D
var _initialized: bool = false


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	collision_layer = 8
	_gathers_remaining = randi_range(min_gathers, max_gathers)
	_active_mesh = get_node_or_null("ActiveMesh")
	_depleted_mesh = get_node_or_null("DepletedMesh")
	if _depleted_mesh:
		_depleted_mesh.visible = false
	respawned.connect(_on_respawned)
	FileLogger.log_msg("Interactable.init: %s verb=%s" % [display_name, interaction_verb])


func interact(player: Node3D) -> bool:
	FileLogger.log_msg("interact(%s) active=%s depleted=%s" % [display_name, str(is_active), str(_is_depleted)])
	if not is_active or _is_depleted:
		GameManager.log_action("You can't %s this right now." % interaction_verb.to_lower())
		return false
	if required_skill != "":
		var level: int = PlayerSkills.get_level(required_skill)
		if level < required_level:
			GameManager.log_action("You need level %d %s to %s this." % [required_level, required_skill, interaction_verb.to_lower()])
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
	# Roll for success based on skill level
	var chance := base_success_chance
	if required_skill != "":
		var level: int = PlayerSkills.get_level(required_skill)
		chance = min(0.95, base_success_chance + (level - required_level) * 0.02)
	if randf() > chance:
		_ticks_remaining = ticks_per_action
		return {"completed": false}

	# Success — give drops
	for entry in drop_table:
		var drop = entry.call("roll")
		if drop and not drop.is_empty():
			var item = drop["item"]
			var qty = drop["quantity"]
			var added = PlayerInventory.call("add_item", item, qty)
			if added:
				GameManager.log_action("You get some %s." % item.call("get_display_name"))
			else:
				GameManager.log_action("Your inventory is full.")

	# Grant XP
	if xp_reward > 0.0 and required_skill != "":
		PlayerSkills.add_xp(required_skill, xp_reward)

	interaction_completed.emit(player)
	_gathers_remaining -= 1
	_ticks_remaining = ticks_per_action

	if _gathers_remaining <= 0:
		_deplete()
		return {"completed": true}
	return {"completed": false}


func _deplete() -> void:
	_is_depleted = true
	if _active_mesh:
		_active_mesh.visible = false
	if _depleted_mesh:
		_depleted_mesh.visible = true
	depleted.emit()
	if respawn_ticks > 0:
		_respawn_counter = respawn_ticks
		GameManager.game_tick.connect(_respawn_tick)


func _respawn_tick(_tick) -> void:
	_respawn_counter -= 1
	if _respawn_counter <= 0:
		_is_depleted = false
		GameManager.game_tick.disconnect(_respawn_tick)
		_on_respawned()
		respawned.emit()


func _on_respawned() -> void:
	_gathers_remaining = randi_range(min_gathers, max_gathers)
	if _active_mesh:
		_active_mesh.visible = true
	if _depleted_mesh:
		_depleted_mesh.visible = false
