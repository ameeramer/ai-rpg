class_name GatheringNode
extends Interactable
## A resource node that depletes after a random number of successful gathers.
## Uses programmatic primitive meshes (trees, rocks, fishing spots).

## Min/max successful gathers before depletion
@export var min_gathers: int = 1
@export var max_gathers: int = 5

## Chance of success per tick (0.0 to 1.0). Higher skill = higher chance.
@export var base_success_chance: float = 0.5

var _gathers_remaining: int = 0
var _active_mesh: Node3D
var _depleted_mesh: Node3D


func _ready() -> void:
	collision_layer = 8  # Layer 4: Interactables
	_gathers_remaining = randi_range(min_gathers, max_gathers)

	# Look for existing mesh variants first
	_active_mesh = get_node_or_null("ActiveMesh")
	_depleted_mesh = get_node_or_null("DepletedMesh")

	# Create default meshes if none exist
	if not _active_mesh:
		_create_default_meshes()

	if _depleted_mesh:
		_depleted_mesh.visible = false

	respawned.connect(_on_respawned)


func _create_default_meshes() -> void:
	var verb := interaction_verb.to_lower()
	if verb == "chop":
		_create_tree_meshes()
	elif verb == "mine":
		_create_rock_meshes()
	elif verb == "fish":
		_create_fishing_meshes()
	else:
		_create_generic_meshes()


func _create_tree_meshes() -> void:
	var is_oak := display_name.to_lower().contains("oak")

	# Active mesh: trunk + canopy
	_active_mesh = Node3D.new()
	_active_mesh.name = "ActiveMesh"
	add_child(_active_mesh)

	# Trunk
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.25 if not is_oak else 0.35
	trunk_mesh.bottom_radius = 0.35 if not is_oak else 0.45
	trunk_mesh.height = 2.5 if not is_oak else 3.5

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.45, 0.3, 0.15)
	trunk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = trunk_mesh.height / 2.0
	_active_mesh.add_child(trunk)

	# Canopy
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.5 if not is_oak else 2.2
	canopy_mesh.height = 3.0 if not is_oak else 4.0

	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.18, 0.5, 0.12) if not is_oak else Color(0.12, 0.42, 0.08)
	canopy_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var canopy := MeshInstance3D.new()
	canopy.name = "Canopy"
	canopy.mesh = canopy_mesh
	canopy.material_override = canopy_mat
	canopy.position.y = trunk_mesh.height + canopy_mesh.radius * 0.6
	_active_mesh.add_child(canopy)

	# Depleted mesh: stump
	_depleted_mesh = Node3D.new()
	_depleted_mesh.name = "DepletedMesh"
	add_child(_depleted_mesh)

	var stump_mesh := CylinderMesh.new()
	stump_mesh.top_radius = 0.4
	stump_mesh.bottom_radius = 0.45
	stump_mesh.height = 0.5

	var stump_mat := StandardMaterial3D.new()
	stump_mat.albedo_color = Color(0.4, 0.28, 0.12)
	stump_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var stump := MeshInstance3D.new()
	stump.name = "Stump"
	stump.mesh = stump_mesh
	stump.material_override = stump_mat
	stump.position.y = 0.25
	_depleted_mesh.add_child(stump)


func _create_rock_meshes() -> void:
	# Active mesh: colored rock
	_active_mesh = Node3D.new()
	_active_mesh.name = "ActiveMesh"
	add_child(_active_mesh)

	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(1.3, 1.0, 1.3)

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.65, 0.42, 0.18)
	rock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var rock := MeshInstance3D.new()
	rock.name = "Rock"
	rock.mesh = rock_mesh
	rock.material_override = rock_mat
	rock.position.y = 0.5
	_active_mesh.add_child(rock)

	# Add copper vein detail (smaller box)
	var vein_mesh := BoxMesh.new()
	vein_mesh.size = Vector3(0.5, 0.4, 0.15)

	var vein_mat := StandardMaterial3D.new()
	vein_mat.albedo_color = Color(0.8, 0.5, 0.15)
	vein_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var vein := MeshInstance3D.new()
	vein.name = "Vein"
	vein.mesh = vein_mesh
	vein.material_override = vein_mat
	vein.position = Vector3(0.0, 0.6, 0.6)
	_active_mesh.add_child(vein)

	# Depleted mesh: gray rock
	_depleted_mesh = Node3D.new()
	_depleted_mesh.name = "DepletedMesh"
	add_child(_depleted_mesh)

	var depleted_mesh := BoxMesh.new()
	depleted_mesh.size = Vector3(1.1, 0.6, 1.1)

	var depleted_mat := StandardMaterial3D.new()
	depleted_mat.albedo_color = Color(0.35, 0.33, 0.3)
	depleted_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var depleted := MeshInstance3D.new()
	depleted.name = "DepletedRock"
	depleted.mesh = depleted_mesh
	depleted.material_override = depleted_mat
	depleted.position.y = 0.3
	_depleted_mesh.add_child(depleted)


func _create_fishing_meshes() -> void:
	# Active: look for existing WaterMesh child
	var water := get_node_or_null("WaterMesh")
	if water:
		_active_mesh = Node3D.new()
		_active_mesh.name = "ActiveMesh"
		# Reparent WaterMesh under ActiveMesh
		water.reparent(_active_mesh)
		add_child(_active_mesh)
	else:
		_active_mesh = Node3D.new()
		_active_mesh.name = "ActiveMesh"
		add_child(_active_mesh)

		var water_mesh := CylinderMesh.new()
		water_mesh.top_radius = 2.0
		water_mesh.bottom_radius = 2.0
		water_mesh.height = 0.1

		var water_mat := StandardMaterial3D.new()
		water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water_mat.albedo_color = Color(0.15, 0.4, 0.75, 0.5)
		water_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "WaterMesh"
		mesh_inst.mesh = water_mesh
		mesh_inst.material_override = water_mat
		mesh_inst.position.y = 0.05
		_active_mesh.add_child(mesh_inst)

	# Add ripple indicator (small white torus-like ring)
	var ripple_mesh := TorusMesh.new()
	ripple_mesh.inner_radius = 0.3
	ripple_mesh.outer_radius = 0.5

	var ripple_mat := StandardMaterial3D.new()
	ripple_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ripple_mat.albedo_color = Color(0.8, 0.9, 1.0, 0.4)
	ripple_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var ripple := MeshInstance3D.new()
	ripple.name = "Ripple"
	ripple.mesh = ripple_mesh
	ripple.material_override = ripple_mat
	ripple.position.y = 0.12
	_active_mesh.add_child(ripple)

	# No depleted mesh for fishing spots - they just deactivate


func _create_generic_meshes() -> void:
	_active_mesh = Node3D.new()
	_active_mesh.name = "ActiveMesh"
	add_child(_active_mesh)

	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.7, 0.2)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position.y = 0.5
	_active_mesh.add_child(inst)


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
