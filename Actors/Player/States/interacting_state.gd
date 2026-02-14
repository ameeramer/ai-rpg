extends State
## Player Interacting state — performing an action on an interactable object.
## Handles repeating actions (e.g., chopping tree tick by tick).

@onready var player: PlayerController = owner as PlayerController

var _target: Node3D = null
var _tick_connection: Callable


func on_enter(msg: Dictionary = {}) -> void:
	_target = msg.get("target", null)
	if _target == null or not _target.has_method("interact"):
		state_machine.transition_to("Idle")
		return

	# Face the target
	var look_pos := _target.global_position
	look_pos.y = player.global_position.y
	if look_pos.distance_to(player.global_position) > 0.01:
		player.look_at(look_pos, Vector3.UP)

	# Start interaction
	_target.interact(player)

	# If it's a repeating action, connect to game tick
	if _target.has_method("is_repeating") and _target.is_repeating():
		_tick_connection = _on_game_tick
		GameManager.game_tick.connect(_tick_connection)

	if player.anim_player:
		var anim_name: String = "interact"
		if _target.has_method("get_animation_name"):
			anim_name = _target.get_animation_name()
		if player.anim_player.has_animation(anim_name):
			player.anim_player.play(anim_name)


func on_exit() -> void:
	if _tick_connection.is_valid() and GameManager.game_tick.is_connected(_tick_connection):
		GameManager.game_tick.disconnect(_tick_connection)

	if _target and _target.has_method("stop_interaction"):
		_target.stop_interaction(player)

	_target = null


func _on_game_tick(_tick: int) -> void:
	if _target == null or not is_instance_valid(_target):
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
