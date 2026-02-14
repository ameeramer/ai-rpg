class_name EnemyBase
extends CharacterBody3D
## Base class for all enemies. Handles HP, combat, drops, and respawn.

@export var display_name: String = "Enemy"
@export var max_hp: int = 10
@export var attack_damage: int = 1
@export var attack_speed_ticks: int = 4  # Ticks between attacks
@export var attack_range: float = 2.0
@export var aggro_range: float = 0.0  # 0 = passive, >0 = aggressive within range
@export var combat_level: int = 1
@export var xp_reward: float = 40.0  # Total combat XP on kill
@export var drop_table: Array[DropTableEntry] = []
@export var respawn_ticks: int = 50  # ~30 seconds

signal died(enemy: EnemyBase)
signal took_damage(amount: int, current_hp: int)

var hp: int
var _target: Node3D = null
var _ticks_since_attack: int = 0
var _is_dead: bool = false
var _respawn_counter: int = 0
var _spawn_position: Vector3


func _ready() -> void:
	hp = max_hp
	_spawn_position = global_position
	collision_layer = 4  # Layer 3: Enemies
	collision_mask = 3   # Collide with world + player

	GameManager.game_tick.connect(_on_game_tick)
	add_to_group("enemies")


func take_damage(amount: int) -> void:
	if _is_dead:
		return
	hp = max(0, hp - amount)
	took_damage.emit(amount, hp)
	if hp <= 0:
		_die()


func is_dead() -> bool:
	return _is_dead


func _on_game_tick(_tick: int) -> void:
	if _is_dead:
		_handle_respawn()
		return

	# Aggro check
	if _target == null and aggro_range > 0:
		_check_aggro()

	# Attack if in combat
	if _target and is_instance_valid(_target):
		_combat_tick()


func _check_aggro() -> void:
	var players := get_tree().get_nodes_in_group("player")
	for player in players:
		if global_position.distance_to(player.global_position) <= aggro_range:
			_target = player
			GameManager.log_action("The %s attacks you!" % display_name)
			break


func _combat_tick() -> void:
	if not is_instance_valid(_target):
		_target = null
		return

	var distance := global_position.distance_to(_target.global_position)
	if distance > aggro_range * 2 and aggro_range > 0:
		# Target too far, de-aggro
		_target = null
		return

	_ticks_since_attack += 1
	if _ticks_since_attack >= attack_speed_ticks and distance <= attack_range:
		_perform_attack()
		_ticks_since_attack = 0


func _perform_attack() -> void:
	if _target and _target.has_method("take_damage"):
		var damage := randi_range(0, attack_damage)
		_target.take_damage(damage)
		if damage > 0:
			GameManager.log_action("The %s hits you for %d damage." % [display_name, damage])
		else:
			GameManager.log_action("The %s misses." % display_name)


func _die() -> void:
	_is_dead = true
	_target = null

	# Drop items
	_drop_loot()

	# Grant XP to nearby player
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Node3D = players[0]
		var skills := player.get_node_or_null("PlayerSkills")
		if skills and skills.has_method("add_combat_xp"):
			skills.add_combat_xp(xp_reward)

	died.emit(self)

	# Hide and start respawn timer
	visible = false
	set_physics_process(false)
	_respawn_counter = respawn_ticks


func _drop_loot() -> void:
	for entry in drop_table:
		var drop := entry.roll()
		if not drop.is_empty():
			GameManager.log_action("The %s drops: %s x%d" % [
				display_name, drop["item"].get_display_name(), drop["quantity"]
			])
			# TODO: Spawn ground item at position


func _handle_respawn() -> void:
	_respawn_counter -= 1
	if _respawn_counter <= 0:
		hp = max_hp
		_is_dead = false
		global_position = _spawn_position
		visible = true
		set_physics_process(true)
