class_name GatheringNode
extends Interactable
## A resource node that depletes after a random number of successful gathers.
## Used for trees, rocks, fishing spots, etc.

## Min/max successful gathers before depletion
@export var min_gathers: int = 1
@export var max_gathers: int = 5

## Chance of success per tick (0.0 to 1.0). Higher skill = higher chance.
@export var base_success_chance: float = 0.5

## Path to the active 3D model (.glb)
@export_file("*.glb") var active_model_path: String = ""
## Path to the depleted 3D model (.glb)
@export_file("*.glb") var depleted_model_path: String = ""
## Scale applied to loaded models
@export var model_scale: Vector3 = Vector3.ONE

var _gathers_remaining: int = 0
var _active_mesh: Node3D
var _depleted_mesh: Node3D


func _ready() -> void:
	collision_layer = 8  # Layer 4: Interactables
	_gathers_remaining = randi_range(min_gathers, max_gathers)

	# Load 3D models if paths are set
	_load_models()

	# Fall back to looking for existing mesh variants
	if not _active_mesh:
		_active_mesh = get_node_or_null("ActiveMesh")
	if not _depleted_mesh:
		_depleted_mesh = get_node_or_null("DepletedMesh")
	if _depleted_mesh:
		_depleted_mesh.visible = false

	respawned.connect(_on_respawned)


func _load_models() -> void:
	if active_model_path != "":
		var scene: PackedScene = load(active_model_path)
		if scene:
			_active_mesh = Node3D.new()
			_active_mesh.name = "ActiveMesh"
			var instance := scene.instantiate()
			instance.scale = model_scale
			_active_mesh.add_child(instance)
			add_child(_active_mesh)
			# Remove old primitive meshes
			_remove_primitive_meshes()

	if depleted_model_path != "":
		var scene: PackedScene = load(depleted_model_path)
		if scene:
			_depleted_mesh = Node3D.new()
			_depleted_mesh.name = "DepletedMesh"
			var instance := scene.instantiate()
			instance.scale = model_scale
			_depleted_mesh.add_child(instance)
			add_child(_depleted_mesh)
			_depleted_mesh.visible = false


func _remove_primitive_meshes() -> void:
	for child in get_children():
		if child is MeshInstance3D and child != _active_mesh and child != _depleted_mesh:
			child.queue_free()


func _complete_action(player: Node3D) -> Dictionary:
	# Roll for success based on level
	var success_chance := base_success_chance
	if required_skill != "":
		var skills_node := player.get_node_or_null("PlayerSkills")
		if skills_node and skills_node.has_method("get_level"):
			var level: int = skills_node.get_level(required_skill)
			# Higher level = better chance, capped at 95%
			success_chance = min(0.95, base_success_chance + (level - required_level) * 0.02)

	if randf() > success_chance:
		# Failed this tick, try again
		_ticks_remaining = ticks_per_action
		return {"completed": false}

	# Success — give rewards
	var result := super._complete_action(player)

	_gathers_remaining -= 1
	if _gathers_remaining <= 0:
		result["completed"] = true
	return result


func _should_deplete() -> bool:
	return _gathers_remaining <= 0


func _deplete() -> void:
	super._deplete()
	if _active_mesh:
		_active_mesh.visible = false
	if _depleted_mesh:
		_depleted_mesh.visible = true


func _on_respawned() -> void:
	_gathers_remaining = randi_range(min_gathers, max_gathers)
	if _active_mesh:
		_active_mesh.visible = true
	if _depleted_mesh:
		_depleted_mesh.visible = false
