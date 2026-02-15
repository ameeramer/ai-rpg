extends State
## Player Combat state — OSRS-style tick-based auto-attack.

@onready var player: PlayerController = owner as PlayerController

var _target: Node3D = null
var _ticks_since_attack: int = 0
var _attack_speed_ticks: int = 4  # Default: 4 ticks (2.4s)
var _tick_connected: bool = false


func on_enter(msg: Dictionary = {}) -> void:
	_target = msg.get("target", null)
	_ticks_since_attack = _attack_speed_ticks  # Attack immediately on first tick
	_tick_connected = false

	if _target == null:
		state_machine.transition_to("Idle")
		return

	# Stop movement
	player.velocity = Vector3.ZERO
	player.is_moving = false

	_attack_speed_ticks = 4

	# Connect to game tick
	GameManager.game_tick.connect(_on_game_tick)
	_tick_connected = true

	var target_name := _target.display_name if _target is EnemyBase else _target.name
	GameManager.log_action("You attack the %s." % target_name)


func on_exit() -> void:
	if _tick_connected and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
		_tick_connected = false
	_target = null


func on_physics_update(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		state_machine.transition_to("Idle")
		return

	# Check if target died
	if _target is EnemyBase and _target.is_dead():
		state_machine.transition_to("Idle")
		return

	# Face the target
	var look_pos := _target.global_position
	look_pos.y = player.global_position.y
	if look_pos.distance_to(player.global_position) > 0.01:
		player.look_at(look_pos, Vector3.UP)

	# If target moved out of range, chase them
	if not player.is_in_range_of(_target):
		player.set_nav_target(_target.global_position)
		player.move_toward_target(delta)


func _on_game_tick(_tick: int) -> void:
	if _target == null or not is_instance_valid(_target):
		state_machine.transition_to("Idle")
		return

	if _target is EnemyBase and _target.is_dead():
		state_machine.transition_to("Idle")
		return

	_ticks_since_attack += 1

	if _ticks_since_attack >= _attack_speed_ticks and player.is_in_range_of(_target):
		_perform_attack()
		_ticks_since_attack = 0


func _perform_attack() -> void:
	if _target.has_method("take_damage"):
		var max_hit := _calculate_max_hit()
		var damage := randi_range(0, max_hit)
		_target.take_damage(damage)

		var target_name := _target.display_name if _target is EnemyBase else _target.name
		if damage > 0:
			GameManager.log_action("You hit the %s for %d damage." % [target_name, damage])
		else:
			GameManager.log_action("You miss the %s." % target_name)

		# Play tween attack animation
		player.play_attack_animation()

		# Check if target is dead
		if _target.has_method("is_dead") and _target.is_dead():
			GameManager.log_action("You defeated the %s!" % target_name)
			state_machine.transition_to("Idle")


func _calculate_max_hit() -> int:
	var strength_level: int = 1
	var strength_bonus: int = 0

	var skills_node := player.get_node_or_null("PlayerSkills")
	if skills_node and skills_node.has_method("get_level"):
		strength_level = skills_node.get_level("Strength")

	var effective_strength := strength_level + 8
	var max_hit := int(0.5 + effective_strength * (strength_bonus + 64) / 640.0)
	return max(1, max_hit)
