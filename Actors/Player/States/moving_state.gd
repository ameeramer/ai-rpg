extends State
## Player Moving state — pathfinding to a target position.

@onready var player: PlayerController = owner as PlayerController

var _interact_on_arrive: bool = false
var _interact_target: Node3D = null


func on_enter(msg: Dictionary = {}) -> void:
	_interact_on_arrive = msg.get("interact_on_arrive", false)
	_interact_target = msg.get("interact_target", null)

	var target: Vector3 = msg.get("target", player.global_position)
	player.set_nav_target(target)
	FileLogger.log_msg("State -> Moving to %s%s" % [str(target), " (then interact)" if _interact_on_arrive else ""])


func on_physics_update(delta: float) -> void:
	if player.is_at_target():
		_arrive()
		return

	# If we have an interact target, check if we're close enough
	if _interact_on_arrive and _interact_target and is_instance_valid(_interact_target):
		if player.is_in_range_of(_interact_target):
			_arrive()
			return

	player.move_toward_target(delta)


func on_exit() -> void:
	player.velocity = Vector3.ZERO


func _arrive() -> void:
	if _interact_on_arrive and _interact_target and is_instance_valid(_interact_target):
		# Route to Combat for enemies (layer 4), Interacting for everything else
		var target_layer: int = _interact_target.get("collision_layer") if _interact_target.get("collision_layer") != null else 0
		if target_layer == 4:
			# Use .get("_is_dead") instead of has_method("is_dead") — has_method fails on Android
			var is_dead = _interact_target.get("_is_dead")
			if is_dead != null and is_dead:
				state_machine.transition_to("Idle")
			else:
				state_machine.transition_to("Combat", {"target": _interact_target})
		else:
			state_machine.transition_to("Interacting", {"target": _interact_target})
	else:
		state_machine.transition_to("Idle")
