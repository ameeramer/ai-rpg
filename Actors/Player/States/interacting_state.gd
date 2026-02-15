extends State
## Player Interacting state — performing an action on an interactable object.
## Handles repeating actions (e.g., chopping tree tick by tick).
## NOTE: has_method() fails on Android Godot 4.3 — use .call() directly.

@onready var player: PlayerController = owner as PlayerController

var _target: Node3D = null
var _tick_connected: bool = false


func on_enter(msg: Dictionary = {}) -> void:
	_target = msg.get("target", null)
	_tick_connected = false

	if _target == null:
		FileLogger.log_msg("Interacting: no valid target, returning to Idle")
		state_machine.transition_to("Idle")
		return

	# Validate this is an interactable (layer 8) — don't use has_method on Android
	var target_layer: int = _target.get("collision_layer") if _target.get("collision_layer") != null else 0
	if target_layer != 8:
		FileLogger.log_msg("Interacting: target '%s' layer=%d not interactable, returning to Idle" % [_target.name, target_layer])
		state_machine.transition_to("Idle")
		return

	# Check if target can be interacted with before committing
	if _target.get("_is_depleted") or not _target.get("is_active", true):
		var tname: String = _target.get("display_name") if _target.get("display_name") else _target.name
		var verb: String = _target.get("interaction_verb") if _target.get("interaction_verb") else "use"
		FileLogger.log_msg("Interacting: target '%s' is depleted/inactive, returning to Idle" % tname)
		GameManager.log_action("You can't %s this right now." % verb.to_lower())
		state_machine.transition_to("Idle")
		return

	# Face the target
	var look_pos := _target.global_position
	look_pos.y = player.global_position.y
	if look_pos.distance_to(player.global_position) > 0.01:
		player.look_at(look_pos, Vector3.UP)

	# Stop movement
	player.velocity = Vector3.ZERO
	player.is_moving = false

	# Start interaction — call directly, skip has_method (fails on Android)
	FileLogger.log_msg("Interacting: starting interaction with '%s'" % (_target.name))
	var success: bool = _target.call("interact", player)
	if not success:
		FileLogger.log_msg("Interacting: interact() returned false, returning to Idle")
		state_machine.transition_to("Idle")
		return

	# Repeating actions — call directly, all interactables have is_repeating()
	var is_repeating: bool = _target.call("is_repeating")
	if is_repeating:
		GameManager.game_tick.connect(_on_game_tick)
		_tick_connected = true

	if player.anim_player:
		var anim_name: String = _target.call("get_animation_name")
		if player.anim_player.has_animation(anim_name):
			player.anim_player.play(anim_name)


func on_exit() -> void:
	FileLogger.log_msg("Interacting: exiting state")
	if _tick_connected and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
		_tick_connected = false

	if is_instance_valid(_target):
		_target.call("stop_interaction", player)

	_target = null


func on_physics_update(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		state_machine.transition_to("Idle")
		return
	if _target.get("_is_depleted"):
		state_machine.transition_to("Idle")
		return


func _on_game_tick(_tick: int) -> void:
	if _target == null or not is_instance_valid(_target):
		state_machine.transition_to("Idle")
		return

	if _target.get("_is_depleted"):
		state_machine.transition_to("Idle")
		return

	if not player.is_in_range_of(_target):
		state_machine.transition_to("Idle")
		return

	# Tick the interaction — call directly, skip has_method
	var result: Dictionary = _target.call("interaction_tick", player)
	if result.get("completed", false):
		state_machine.transition_to("Idle")
