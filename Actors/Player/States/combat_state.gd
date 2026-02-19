extends State
## Player Combat state — OSRS-style tick-based auto-attack.
## NOTE: has_method() fails on Android Godot 4.3 — use .call() directly.

var player: Node3D = null

var _target: Node3D = null
var _ticks_since_attack: int = 0
var _attack_speed_ticks: int = 4  # Default: 4 ticks (2.4s)
var _tick_connected: bool = false


func _is_target_dead() -> bool:
	# has_method() fails on Android — use .get() to check _is_dead property directly
	var dead = _target.get("_is_dead")
	if dead != null:
		return dead
	return false


func on_enter(msg: Dictionary = {}) -> void:
	if player == null:
		player = owner
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

	var target_name: String = _target.get("display_name") if _target.get("display_name") else _target.name
	GameManager.log_action("You attack the %s." % target_name)
	FileLogger.log_msg("Combat: entered combat with %s" % target_name)


func on_exit() -> void:
	if _tick_connected and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
		_tick_connected = false
	_target = null


func on_physics_update(delta: float) -> void:
	if player == null:
		player = owner
	if _target == null or not is_instance_valid(_target):
		state_machine.transition_to("Idle")
		return

	if _is_target_dead():
		state_machine.transition_to("Idle")
		return

	# Face the target
	var look_pos = _target.global_position
	look_pos.y = player.global_position.y
	if look_pos.distance_to(player.global_position) > 0.01:
		player.look_at(look_pos, Vector3.UP)

	# If target moved out of range, chase them
	if not player.is_in_range_of(_target):
		player.set_nav_target(_target.global_position)
		player.move_toward_target(delta)


func _on_game_tick(_tick) -> void:
	if _target == null or not is_instance_valid(_target):
		FileLogger.log_msg("Combat: tick — target gone, going Idle")
		state_machine.transition_to("Idle")
		return

	if _is_target_dead():
		FileLogger.log_msg("Combat: tick — target dead, going Idle")
		state_machine.transition_to("Idle")
		return

	_ticks_since_attack += 1
	var in_range = player.is_in_range_of(_target)
	FileLogger.log_msg("Combat: tick=%s atk=%d/%d in_range=%s" % [str(_tick), _ticks_since_attack, _attack_speed_ticks, str(in_range)])

	if _ticks_since_attack >= _attack_speed_ticks and in_range:
		_perform_attack()
		_ticks_since_attack = 0


func _perform_attack() -> void:
	FileLogger.log_msg("Combat: _perform_attack() start")
	var max_hit = _calculate_max_hit()
	var damage = randi_range(0, max_hit)
	FileLogger.log_msg("Combat: max_hit=%d damage=%d" % [max_hit, damage])

	# Call take_damage directly — we know layer 4 objects are enemies with this method
	_target.call("take_damage", damage)

	var target_name = _target.get("display_name")
	if target_name == null:
		target_name = _target.name
	if damage > 0:
		GameManager.log_action("You hit the %s for %d damage." % [target_name, damage])
	else:
		GameManager.log_action("You miss the %s." % target_name)
	FileLogger.log_msg("Combat: dealt %d damage to %s" % [damage, target_name])

	# Distribute XP based on current attack style
	CombatStyle.call("distribute_combat_xp", damage)

	# Play tween attack animation
	player.play_attack_animation()

	# Check if target is dead
	if _is_target_dead():
		GameManager.log_action("You defeated the %s!" % target_name)
		state_machine.transition_to("Idle")


func _calculate_max_hit() -> int:
	var strength_level = PlayerSkills.get_level("Strength")
	var strength_bonus = PlayerEquipment.call("get_strength_bonus")
	if strength_bonus == null:
		strength_bonus = 0
	# Apply invisible boost from combat style
	var boosts = CombatStyle.call("get_invisible_boost")
	if boosts == null:
		boosts = {}
	var str_boost = boosts.get("Strength", 0)
	var effective_strength = strength_level + str_boost + 8
	var max_hit = int(0.5 + effective_strength * (strength_bonus + 64) / 640.0)
	return max(1, max_hit)
