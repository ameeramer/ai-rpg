extends State
## Player Interacting state — performing an action on an interactable object.
## Handles repeating actions (e.g., chopping tree tick by tick).

@onready var player: PlayerController = owner as PlayerController

var _target: Node3D = null
var _tick_connected: bool = false


func on_enter(msg: Dictionary = {}) -> void:
	_target = msg.get("target", null)
	_tick_connected = false

	if _target == null or not _target.has_method("interact"):
		FileLogger.log_msg("Interacting: no valid target, returning to Idle")
		state_machine.transition_to("Idle")
		return

	# Check if target can be interacted with before committing
	if _target is Interactable and (not _target.is_active or _target._is_depleted):
		FileLogger.log_msg("Interacting: target '%s' is depleted/inactive, returning to Idle" % _target.display_name)
		GameManager.log_action("You can't %s this right now." % _target.interaction_verb.to_lower())
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

	# Start interaction
	FileLogger.log_msg("Interacting: starting interaction with '%s'" % (_target.name))
	var success: bool = _target.interact(player)
	if not success:
		FileLogger.log_msg("Interacting: interact() returned false, returning to Idle")
		state_machine.transition_to("Idle")
		return

	# If it's a repeating action, connect to game tick
	if _target.has_method("is_repeating") and _target.is_repeating():
		GameManager.game_tick.connect(_on_game_tick)
		_tick_connected = true

	if player.anim_player:
		var anim_name: String = "interact"
		if _target.has_method("get_animation_name"):
			anim_name = _target.get_animation_name()
		if player.anim_player.has_animation(anim_name):
			player.anim_player.play(anim_name)


func on_exit() -> void:
	FileLogger.log_msg("Interacting: exiting state")
	if _tick_connected and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
		_tick_connected = false

	if is_instance_valid(_target) and _target.has_method("stop_interaction"):
		_target.stop_interaction(player)

	_target = null


func on_physics_update(_delta: float) -> void:
	# Safety: if target became invalid or depleted while interacting, go to idle
	if _target == null or not is_instance_valid(_target):
		state_machine.transition_to("Idle")
		return
	if _target is Interactable and _target._is_depleted:
		state_machine.transition_to("Idle")
		return


func _on_game_tick(_tick: int) -> void:
	if _target == null or not is_instance_valid(_target):
		state_machine.transition_to("Idle")
		return

	# Check if target was depleted
	if _target is Interactable and _target._is_depleted:
		state_machine.transition_to("Idle")
		return

	if not player.is_in_range_of(_target):
		state_machine.transition_to("Idle")
		return

	# Tick the interaction
	if _target.has_method("interaction_tick"):
		var result: Dictionary = _target.interaction_tick(player)
		if result.get("completed", false):
			state_machine.transition_to("Idle")
