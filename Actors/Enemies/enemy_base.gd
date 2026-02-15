extends CharacterBody3D
## Base class for all enemies. Handles HP, combat, drops, and respawn.
## NO class_name — referenced by script path in .tscn files.
## Meshes MUST be defined as sub_resource in .tscn (Android requirement).

@export var display_name: String = "Enemy"
@export var max_hp: int = 10
@export var attack_damage: int = 1
@export var attack_speed_ticks: int = 4
@export var attack_range: float = 2.0
@export var aggro_range: float = 0.0
@export var combat_level: int = 1
@export var xp_reward: float = 40.0
@export var drop_table: Array = []
@export var respawn_ticks: int = 50

signal died(enemy)
signal took_damage(amount, current_hp)

var hp: int = 0
var _target: Node3D = null
var _ticks_since_attack: int = 0
var _is_dead: bool = false
var _respawn_counter: int = 0
var _spawn_position: Vector3
var _model_mesh: MeshInstance3D
var _original_color: Color
var _initialized: bool = false


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	hp = max_hp
	_spawn_position = global_position
	collision_layer = 4
	collision_mask = 3
	_model_mesh = get_node_or_null("EnemyMesh") as MeshInstance3D
	if _model_mesh and _model_mesh.material_override:
		_original_color = _model_mesh.material_override.albedo_color
	if not get_node_or_null("NameLabel"):
		_add_name_label()
	GameManager.game_tick.connect(_on_game_tick)
	FileLogger.log_msg("Enemy.init: %s hp=%d aggro=%.1f" % [display_name, hp, aggro_range])


func _add_name_label() -> void:
	var label := Label3D.new()
	label.name = "NameLabel"
	label.text = "%s (Lv %d)" % [display_name, combat_level]
	label.font_size = 32
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 1, 0)
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0)
	var mesh_top := 2.0
	if _model_mesh:
		mesh_top = _model_mesh.position.y + 1.0
	label.position.y = mesh_top + 0.3
	add_child(label)


func take_damage(amount: int) -> void:
	ensure_initialized()
	if _is_dead:
		return
	hp = max(0, hp - amount)
	took_damage.emit(amount, hp)
	_flash_damage()
	_show_hitsplat(amount)
	if hp <= 0:
		_die()


func _flash_damage() -> void:
	if not _model_mesh or not _model_mesh.material_override:
		return
	var mat = _model_mesh.material_override
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color", Color(1, 0.15, 0.15), 0.05)
	tween.tween_property(mat, "albedo_color", _original_color, 0.2)


func _show_hitsplat(amount: int) -> void:
	var label := Label3D.new()
	label.text = str(amount) if amount > 0 else "Miss"
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0)
	label.modulate = Color(1, 0.15, 0.15) if amount > 0 else Color(0.6, 0.6, 0.6)
	var mesh_top := 2.0
	if _model_mesh:
		mesh_top = _model_mesh.position.y + 0.8
	label.position.y = mesh_top
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", mesh_top + 1.5, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


func is_dead() -> bool:
	return _is_dead


func _on_game_tick(_tick) -> void:
	if _is_dead:
		_handle_respawn()
		return
	if _target == null and aggro_range > 0:
		_check_aggro()
	if _target and is_instance_valid(_target):
		_combat_tick()


func _check_aggro() -> void:
	var players := get_tree().get_nodes_in_group("player")
	for player in players:
		if player.get("hitpoints") != null and player.get("hitpoints") <= 0:
			continue
		if global_position.distance_to(player.global_position) <= aggro_range:
			_target = player
			GameManager.log_action("The %s attacks you!" % display_name)
			break


func _combat_tick() -> void:
	if not is_instance_valid(_target):
		_target = null
		return
	if _target.get("hitpoints") != null and _target.get("hitpoints") <= 0:
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
	if _target:
		var damage := randi_range(0, attack_damage)
		_target.call("take_damage", damage)
		if damage > 0:
			GameManager.log_action("The %s hits you for %d damage." % [display_name, damage])
		else:
			GameManager.log_action("The %s misses." % display_name)


func _die() -> void:
	_is_dead = true
	_target = null
	_drop_loot()
	PlayerSkills.add_combat_xp(xp_reward)
	died.emit(self)
	visible = false
	collision_layer = 0
	_respawn_counter = respawn_ticks


func _drop_loot() -> void:
	for entry in drop_table:
		var drop = entry.call("roll")
		if drop and not drop.is_empty():
			var item = drop["item"]
			var qty = drop["quantity"]
			GameManager.log_action("The %s drops: %s x%d" % [display_name, item.call("get_display_name"), qty])
			var added = PlayerInventory.call("add_item", item, qty)
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
