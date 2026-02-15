class_name PlayerController
extends CharacterBody3D
## Main player controller. Uses a StateMachine for behavior.
## Child nodes: StateMachine, NavigationAgent3D, CollisionShape3D, AnimationPlayer

@export var move_speed: float = 4.0
@export var interaction_range: float = 3.0

@onready var state_machine: StateMachine = $StateMachine
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var model: Node3D = $Model

## Current target for interaction (set by InputManager signals)
var target_object: Node3D = null
var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false

## Player stats
var hitpoints: int = 10
var max_hitpoints: int = 10


func _ready() -> void:
	FileLogger.log_msg("PlayerController._ready() start")

	# Connect to InputManager signals
	InputManager.world_clicked.connect(_on_world_clicked)
	InputManager.object_clicked.connect(_on_object_clicked)

	# Configure navigation agent
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	nav_agent.max_speed = move_speed

	# Add to player group for easy lookup
	add_to_group("player")
	FileLogger.log_msg("PlayerController._ready() done")


func _on_world_clicked(world_pos: Vector3, _normal: Vector3) -> void:
	if is_dead_state():
		return
	target_object = null
	target_position = world_pos
	state_machine.transition_to("Moving", {"target": world_pos})


func _on_object_clicked(object: Node3D, _hit_pos: Vector3) -> void:
	if is_dead_state():
		return

	target_object = object
	target_position = object.global_position

	var obj_layer: int = object.get("collision_layer") if object.get("collision_layer") != null else 0
	var dist := global_position.distance_to(object.global_position)

	# Enemy (collision layer 4) -> combat
	if obj_layer == 4:
		var is_dead = object.get("_is_dead")
		if is_dead != null and is_dead:
			return
		if dist <= interaction_range:
			state_machine.transition_to("Combat", {"target": object})
		else:
			state_machine.transition_to("Moving", {
				"target": object.global_position,
				"interact_on_arrive": true,
				"interact_target": object
			})
		return

	# Interactable (collision layer 8)
	if obj_layer == 8:
		# Depleted -> just walk there
		if object.get("_is_depleted"):
			state_machine.transition_to("Moving", {"target": object.global_position})
			return
		# Active -> interact or walk then interact
		if dist <= interaction_range:
			state_machine.transition_to("Interacting", {"target": object})
		else:
			state_machine.transition_to("Moving", {
				"target": object.global_position,
				"interact_on_arrive": true,
				"interact_target": object
			})
		return


func move_toward_target(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		is_moving = false
		return

	var next_pos := nav_agent.get_next_path_position()
	var direction := (next_pos - global_position).normalized()
	direction.y = 0

	if direction.length() > 0.01:
		var look_target := global_position + direction
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


func is_dead_state() -> bool:
	return hitpoints <= 0


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
	var label := Label3D.new()
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
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", 3.5, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


func heal(amount: int) -> void:
	hitpoints = min(max_hitpoints, hitpoints + amount)


func _die() -> void:
	GameManager.log_action("Oh dear, you are dead!")
	state_machine.transition_to("Dead")


func play_attack_animation() -> void:
	if not model:
		return
	var tween := create_tween()
	tween.tween_property(model, "rotation_degrees:y", -30.0, 0.08)
	tween.tween_property(model, "rotation_degrees:y", 15.0, 0.06)
	tween.tween_property(model, "rotation_degrees:y", 0.0, 0.06)


func play_damage_flash() -> void:
	if not model:
		return
	# Collect original colors first
	var parts: Array[Dictionary] = []
	for child in model.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			parts.append({"mat": child.material_override, "color": child.material_override.albedo_color})
	if parts.is_empty():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	for p in parts:
		tween.tween_property(p["mat"], "albedo_color", Color(1, 0.2, 0.2), 0.05)
	tween.set_parallel(false)
	tween.tween_interval(0.05)
	tween.set_parallel(true)
	for p in parts:
		tween.tween_property(p["mat"], "albedo_color", p["color"], 0.15)
