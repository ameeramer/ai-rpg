extends State
## Player Idle state — waiting for input.

var player: Node3D = null


func on_enter(_msg: Dictionary = {}) -> void:
	if player == null:
		player = owner
	FileLogger.log_msg("State -> Idle")
	player.is_moving = false
	player.velocity = Vector3.ZERO
	if player.anim_player and player.anim_player.has_animation("idle"):
		player.anim_player.play("idle")


func on_physics_update(_delta: float) -> void:
	# Apply gravity
	if player == null:
		player = owner
	if not player.is_on_floor():
		player.velocity.y -= 9.8 * _delta
		player.move_and_slide()
