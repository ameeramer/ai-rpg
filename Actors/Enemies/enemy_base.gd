class_name EnemyBase
extends CharacterBody3D
## Base class for all enemies. Handles HP, combat, drops, and respawn.
## Creates visible meshes programmatically based on display_name.

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
var _model_mesh: MeshInstance3D
var _original_color: Color


func _ready() -> void:
	hp = max_hp
	_spawn_position = global_position
	collision_layer = 4  # Layer 3: Enemies
	collision_mask = 3   # Collide with world + player

	# Use existing EnemyMesh if defined in .tscn, otherwise create one
	_model_mesh = get_node_or_null("EnemyMesh") as MeshInstance3D
	if _model_mesh and _model_mesh.material_override:
		_original_color = _model_mesh.material_override.albedo_color
	elif not _model_mesh:
		_create_mesh()

	GameManager.game_tick.connect(_on_game_tick)
	add_to_group("enemies")


func _create_mesh() -> void:
	var capsule := CapsuleMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var name_lower := display_name.to_lower()
	if name_lower.contains("goblin"):
		capsule.radius = 0.4
		capsule.height = 1.4
		mat.albedo_color = Color(0.3, 0.55, 0.2)
	elif name_lower.contains("skeleton"):
		capsule.radius = 0.35
		capsule.height = 1.8
		mat.albedo_color = Color(0.85, 0.82, 0.75)
	else:
		capsule.radius = 0.4
		capsule.height = 1.6
		mat.albedo_color = Color(0.6, 0.2, 0.2)

	_original_color = mat.albedo_color

	_model_mesh = MeshInstance3D.new()
	_model_mesh.name = "EnemyMesh"
	_model_mesh.mesh = capsule
	_model_mesh.material_override = mat
	_model_mesh.position.y = capsule.height / 2.0
	add_child(_model_mesh)

	# Add name label above the enemy
	var label := Label3D.new()
	label.name = "NameLabel"
	label.text = "%s (Lv %d)" % [display_name, combat_level]
	label.font_size = 32
	label.position.y = capsule.height + 0.3
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 1, 0)
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0)
	add_child(label)


func take_damage(amount: int) -> void:
	if _is_dead:
		return
	hp = max(0, hp - amount)
	took_damage.emit(amount, hp)
	_flash_damage()
	if hp <= 0:
		_die()


func _flash_damage() -> void:
	if not _model_mesh or not _model_mesh.material_override:
		return
	var mat: StandardMaterial3D = _model_mesh.material_override
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color", Color(1, 0.15, 0.15), 0.05)
	tween.tween_property(mat, "albedo_color", _original_color, 0.2)


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
		# Don't aggro dead players
		if player is PlayerController and player.hitpoints <= 0:
			continue
		if global_position.distance_to(player.global_position) <= aggro_range:
			_target = player
			GameManager.log_action("The %s attacks you!" % display_name)
			break


func _combat_tick() -> void:
	if not is_instance_valid(_target):
		_target = null
		return

	# Don't attack dead players
	if _target is PlayerController and _target.hitpoints <= 0:
		_target = null
		return

	var distance := global_position.distance_to(_target.global_position)
	if distance > aggro_range * 2 and aggro_range > 0:
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
	collision_layer = 0
	_respawn_counter = respawn_ticks


func _drop_loot() -> void:
	var players := get_tree().get_nodes_in_group("player")
	var player: Node3D = players[0] if players.size() > 0 else null

	for entry in drop_table:
		var drop := entry.roll()
		if not drop.is_empty():
			var item: ItemData = drop["item"]
			var qty: int = drop["quantity"]
			GameManager.log_action("The %s drops: %s x%d" % [display_name, item.get_display_name(), qty])
			if player:
				var inventory := player.get_node_or_null("PlayerInventory")
				if inventory and inventory.has_method("add_item"):
					var added := inventory.add_item(item, qty)
					if not added:
						GameManager.log_action("Your inventory is full!")


func _handle_respawn() -> void:
	_respawn_counter -= 1
	if _respawn_counter <= 0:
		hp = max_hp
		_is_dead = false
		global_position = _spawn_position
		visible = true
		collision_layer = 4
