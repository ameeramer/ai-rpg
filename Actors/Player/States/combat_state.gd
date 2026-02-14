extends State
## Player Combat state — OSRS-style tick-based auto-attack.

@onready var player: PlayerController = owner as PlayerController

var _target: Node3D = null
var _ticks_since_attack: int = 0
var _attack_speed_ticks: int = 4  # Default: 4 ticks (2.4s)
var _tick_connection: Callable


func on_enter(msg: Dictionary = {}) -> void:
	_target = msg.get("target", null)
	_ticks_since_attack = _attack_speed_ticks  # Attack immediately on first tick

	if _target == null:
		state_machine.transition_to("Idle")
		return

	# Determine attack speed from equipped weapon
	# TODO: Get from equipment system
	_attack_speed_ticks = 4

	# Connect to game tick
	_tick_connection = _on_game_tick
	GameManager.game_tick.connect(_tick_connection)

	GameManager.log_action("You attack the %s." % _target.name)


func on_exit() -> void:
	if _tick_connection.is_valid() and GameManager.game_tick.is_connected(_tick_connection):
		GameManager.game_tick.disconnect(_tick_connection)
	_target = null


func on_physics_update(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
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
		player.move_toward_target(_delta)


func _on_game_tick(_tick: int) -> void:
	if _target == null or not is_instance_valid(_target):
		state_machine.transition_to("Idle")
		return

	_ticks_since_attack += 1

	if _ticks_since_attack >= _attack_speed_ticks and player.is_in_range_of(_target):
		_perform_attack()
		_ticks_since_attack = 0


func _perform_attack() -> void:
	if _target.has_method("take_damage"):
		# Calculate damage (simplified OSRS formula)
		var max_hit := _calculate_max_hit()
		var damage := randi_range(0, max_hit)
		_target.take_damage(damage)

		if damage > 0:
			GameManager.log_action("You hit the %s for %d damage." % [_target.name, damage])
		else:
			GameManager.log_action("You miss the %s." % _target.name)

		# Play attack animation
		if player.anim_player and player.anim_player.has_animation("attack_slash"):
			player.anim_player.play("attack_slash")

		# Check if target is dead
		if _target.has_method("is_dead") and _target.is_dead():
			GameManager.log_action("You defeated the %s!" % _target.name)
			state_machine.transition_to("Idle")


func _calculate_max_hit() -> int:
	# Simplified OSRS max hit formula
	# TODO: Factor in equipment bonuses and strength level
	var strength_level: int = 1
	var strength_bonus: int = 0

	# Check if player has skills component
	var skills_node := player.get_node_or_null("PlayerSkills")
	if skills_node and skills_node.has_method("get_level"):
		strength_level = skills_node.get_level("Strength")

	var effective_strength := strength_level + 8  # +8 is the stance bonus placeholder
	var max_hit := int(0.5 + effective_strength * (strength_bonus + 64) / 640.0)
	return max(1, max_hit)
