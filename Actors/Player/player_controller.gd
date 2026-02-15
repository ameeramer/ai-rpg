extends CharacterBody3D

@export var move_speed: float = 4.0
@export var interaction_range: float = 3.0

@onready var state_machine: Node = $StateMachine
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var model: Node3D = $Model

var target_object: Node3D = null
var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false
var hitpoints: int = 10
var max_hitpoints: int = 10
var _initialized: bool = false
var _cached_mats: Array = []

func _ready() -> void:
	FileLogger.log_msg("PlayerController._ready() start")
	ensure_initialized()
	FileLogger.log_msg("PlayerController._ready() done")

func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	FileLogger.log_msg("PlayerController.ensure_initialized() running")
	InputManager.world_clicked.connect(_on_world_clicked)
	InputManager.object_clicked.connect(_on_object_clicked)
	if nav_agent == null:
		nav_agent = get_node_or_null("NavigationAgent3D")
	if state_machine == null:
		state_machine = get_node_or_null("StateMachine")
	if model == null:
		model = get_node_or_null("Model")
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
		nav_agent.max_speed = move_speed
	add_to_group("player")
	if model:
		_gather_mats(model)
	FileLogger.log_msg("PlayerController init done")

func _gather_mats(node: Node) -> void:
	if node is MeshInstance3D:
		var mi = node
		var mat = mi.get("material_override")
		if mat and mat is StandardMaterial3D:
			_cached_mats.append({"mat": mat, "color": mat.albedo_color})
		elif mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var smat = mi.get_surface_override_material(i)
				if smat == null:
					smat = mi.mesh.surface_get_material(i)
				if smat and smat is StandardMaterial3D:
					if not smat.resource_local_to_scene:
						var dup = smat.duplicate()
						mi.set_surface_override_material(i, dup)
						_cached_mats.append({"mat": dup, "color": dup.albedo_color})
					else:
						_cached_mats.append({"mat": smat, "color": smat.albedo_color})
	for child in node.get_children():
		_gather_mats(child)

func _on_world_clicked(world_pos: Vector3, _normal: Vector3) -> void:
	if hitpoints <= 0:
		return
	target_object = null
	target_position = world_pos
	state_machine.call("transition_to", "Moving", {"target": world_pos})

func _on_object_clicked(object: Node3D, _hit_pos: Vector3) -> void:
	if hitpoints <= 0:
		return
	target_object = object
	target_position = object.global_position
	var obj_layer: int = object.get("collision_layer") if object.get("collision_layer") != null else 0
	var dist = global_position.distance_to(object.global_position)
	if obj_layer == 4:
		var is_dead = object.get("_is_dead")
		if is_dead != null and is_dead:
			return
		if dist <= interaction_range:
			state_machine.call("transition_to", "Combat", {"target": object})
		else:
			state_machine.call("transition_to", "Moving", {
				"target": object.global_position,
				"interact_on_arrive": true,
				"interact_target": object
			})
		return
	if obj_layer == 8:
		if object.get("_is_depleted"):
			state_machine.call("transition_to", "Moving", {"target": object.global_position})
			return
		if dist <= interaction_range:
			state_machine.call("transition_to", "Interacting", {"target": object})
		else:
			state_machine.call("transition_to", "Moving", {
				"target": object.global_position,
				"interact_on_arrive": true,
				"interact_target": object
			})
		return

func move_toward_target(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		is_moving = false
		return
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	direction.y = 0
	if direction.length() > 0.01:
		var look_target = global_position + direction
		look_target.y = global_position.y
		if look_target.distance_to(global_position) > 0.01:
			look_at(look_target, Vector3.UP)
	velocity = direction * move_speed
	move_and_slide()
	is_moving = true

func set_nav_target(pos: Vector3) -> void:
	nav_agent.target_position = pos

func is_at_target() -> bool:
	return nav_agent.is_navigation_finished()

func is_in_range_of(target: Node3D) -> bool:
	return global_position.distance_to(target.global_position) <= interaction_range

func take_damage(amount: int) -> void:
	if hitpoints <= 0:
		return
	hitpoints = max(0, hitpoints - amount)
	play_damage_flash()
	_show_hitsplat(amount)
	GameManager.log_action("You take %d damage. HP: %d/%d" % [amount, hitpoints, max_hitpoints])
	if hitpoints <= 0:
		_die()

func _show_hitsplat(amount: int) -> void:
	var label = Label3D.new()
	label.text = str(amount) if amount > 0 else "Miss"
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0)
	if amount > 0:
		label.modulate = Color(1, 0.15, 0.15)
	else:
		label.modulate = Color(0.6, 0.6, 0.6)
	label.position.y = 2.2
	add_child(label)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", 3.5, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func heal(amount: int) -> void:
	hitpoints = min(max_hitpoints, hitpoints + amount)

func _die() -> void:
	GameManager.log_action("Oh dear, you are dead!")
	state_machine.call("transition_to", "Dead")

func play_attack_animation() -> void:
	if not model:
		return
	var tween = create_tween()
	tween.tween_property(model, "rotation_degrees:y", -30.0, 0.08)
	tween.tween_property(model, "rotation_degrees:y", 15.0, 0.06)
	tween.tween_property(model, "rotation_degrees:y", 0.0, 0.06)

func play_damage_flash() -> void:
	if _cached_mats.is_empty():
		return
	var tween = create_tween()
	tween.set_parallel(true)
	for p in _cached_mats:
		tween.tween_property(p["mat"], "albedo_color", Color(1, 0.2, 0.2), 0.05)
	tween.set_parallel(false)
	tween.tween_interval(0.05)
	tween.set_parallel(true)
	for p in _cached_mats:
		tween.tween_property(p["mat"], "albedo_color", p["color"], 0.15)
