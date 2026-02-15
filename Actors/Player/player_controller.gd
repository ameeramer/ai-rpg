class_name PlayerController
extends CharacterBody3D
## Main player controller. Uses a StateMachine for behavior.
## Child nodes: StateMachine, NavigationAgent3D, CollisionShape3D, AnimationPlayer

@export var move_speed: float = 4.0
@export var interaction_range: float = 2.0

const PLAYER_MODEL_PATH := "res://Assets/Models/Characters/player_character.glb"
const PLAYER_MODEL_SCALE := Vector3(0.5, 0.5, 0.5)

@onready var state_machine: StateMachine = $StateMachine
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var model: Node3D = $Model

## Current target for interaction (set by InputManager signals)
var target_object: Node3D = null
var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false

## Player stats — these get set up by the Skills system
var hitpoints: int = 10
var max_hitpoints: int = 10


func _ready() -> void:
	FileLogger.log_msg("PlayerController._ready() start")

	# Load 3D player model
	_load_player_model()

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


func _load_player_model() -> void:
	var scene: PackedScene = load(PLAYER_MODEL_PATH)
	if not scene:
		FileLogger.log_msg("Failed to load player model: " + PLAYER_MODEL_PATH)
		return
	# Remove the placeholder capsule mesh
	var placeholder := model.get_node_or_null("PlayerMesh")
	if placeholder:
		placeholder.queue_free()
	var instance := scene.instantiate()
	instance.scale = PLAYER_MODEL_SCALE
	instance.name = "PlayerModel"
	model.add_child(instance)
	FileLogger.log_msg("Player 3D model loaded")


func _on_world_clicked(world_pos: Vector3, _normal: Vector3) -> void:
	target_object = null
	target_position = world_pos
	state_machine.transition_to("Moving", {"target": world_pos})


func _on_object_clicked(object: Node3D, _hit_pos: Vector3) -> void:
	target_object = object
	target_position = object.global_position

	# Check if we're already in range
	var distance := global_position.distance_to(object.global_position)
	if distance <= interaction_range:
		state_machine.transition_to("Interacting", {"target": object})
	else:
		# Move to object first, then interact
		state_machine.transition_to("Moving", {
			"target": object.global_position,
			"interact_on_arrive": true,
			"interact_target": object
		})


func move_toward_target(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		is_moving = false
		return

	var next_pos := nav_agent.get_next_path_position()
	var direction := (next_pos - global_position).normalized()
	direction.y = 0  # Keep movement on the horizontal plane

	# Face movement direction
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


func take_damage(amount: int) -> void:
	hitpoints = max(0, hitpoints - amount)
	GameManager.log_action("You take %d damage. HP: %d/%d" % [amount, hitpoints, max_hitpoints])
	if hitpoints <= 0:
		_die()


func heal(amount: int) -> void:
	hitpoints = min(max_hitpoints, hitpoints + amount)


func _die() -> void:
	GameManager.log_action("Oh dear, you are dead!")
	# TODO: Respawn logic
