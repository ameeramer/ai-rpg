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

	if player.anim_player and player.anim_player.has_animation("walk"):
		player.anim_player.play("walk")


func on_physics_update(delta: float) -> void:
	if player.is_at_target():
		_arrive()
		return

	# If we have an interact target, check if we're close enough
	if _interact_on_arrive and _interact_target and player.is_in_range_of(_interact_target):
		_arrive()
		return

	player.move_toward_target(delta)


func on_exit() -> void:
	player.velocity = Vector3.ZERO


func _arrive() -> void:
	if _interact_on_arrive and _interact_target:
		state_machine.transition_to("Interacting", {"target": _interact_target})
	else:
		state_machine.transition_to("Idle")
