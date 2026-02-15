extends State
## Player Interacting state — performing an action on an interactable object.
## Handles repeating actions (e.g., chopping tree tick by tick).
## NOTE: has_method() fails on Android Godot 4.3 — use .call() directly.

var player: Node3D = null

var _target: Node3D = null
var _tick_connected: bool = false


func on_enter(msg: Dictionary = {}) -> void:
	if player == null:
		player = owner
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
	var is_depleted_val = _target.get("_is_depleted")
	var is_active_val = _target.get("is_active")
	if is_active_val == null:
		is_active_val = true
	if is_depleted_val or not is_active_val:
		var tname = _target.get("display_name")
		if tname == null:
			tname = _target.name
		var verb = _target.get("interaction_verb")
		if verb == null:
			verb = "use"
		FileLogger.log_msg("Interacting: target '%s' is depleted/inactive, returning to Idle" % str(tname))
		GameManager.log_action("You can't %s this right now." % str(verb).to_lower())
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
	var result = _target.call("interact", player)
	FileLogger.log_msg("Interacting: interact('%s') result=%s type=%d" % [_target.name, str(result), typeof(result)])
	if result == false:
		state_machine.transition_to("Idle")
		return

	# Repeating actions — all gathering nodes repeat
	var repeating = _target.call("is_repeating")
	if repeating == null or repeating == true:
		GameManager.game_tick.connect(_on_game_tick)
		_tick_connected = true

	if player.anim_player:
		var anim_name = _target.call("get_animation_name")
		if anim_name and player.anim_player.has_animation(anim_name):
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
	var tick_result = _target.call("interaction_tick", player)
	if tick_result is Dictionary and tick_result.get("completed", false):
		state_machine.transition_to("Idle")
	elif tick_result == null:
		FileLogger.log_msg("Interacting: interaction_tick returned null")
