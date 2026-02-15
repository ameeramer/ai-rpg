extends State
## Player Idle state — waiting for input.

@onready var player: Node3D = owner as Node3D


func on_enter(_msg: Dictionary = {}) -> void:
	FileLogger.log_msg("State -> Idle")
	player.is_moving = false
	player.velocity = Vector3.ZERO
	if player.anim_player and player.anim_player.has_animation("idle"):
		player.anim_player.play("idle")


func on_physics_update(_delta: float) -> void:
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= 9.8 * _delta
		player.move_and_slide()
