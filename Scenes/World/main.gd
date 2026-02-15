extends Node3D
## Main game scene — sets up the world, player, camera, and UI.

@onready var player: Node3D = $Player
@onready var camera_controller: Node3D = $CameraController
@onready var hud: Node = $HUD


func _ready() -> void:
	FileLogger.log_msg("Main._ready() start")

	camera_controller.set("target", player)
	FileLogger.log_msg("Camera target set")

	# Force-initialize the player — _ready() may not fire on Android
	var init_val = player.get("_initialized")
	FileLogger.log_msg("Main: player _initialized = %s" % str(init_val))
	if init_val == false:
		player.call("ensure_initialized")
		FileLogger.log_msg("Main: player initialized via ensure_initialized()")
	elif init_val == null:
		FileLogger.log_msg("Main: WARNING — player script did NOT parse, cannot init")

	# Force-initialize all enemies and interactables
	_force_initialize_objects()

	# HUD setup — passes player ref; HUD handles its own UI children
	hud.call("setup", player)
	FileLogger.log_msg("HUD setup done")

	FileLogger.log_msg("Main._ready() complete")
	GameManager.log_action("Welcome to AI RPG! Tap to move, tap objects to interact.")


func _force_initialize_objects() -> void:
	var enemies_count: int = 0
	var interactables_count: int = 0

	var all_nodes := _get_all_descendants(self)
	FileLogger.log_msg("Main: walking %d descendant nodes" % all_nodes.size())
	for node in all_nodes:
		var layer = node.get("collision_layer")
		if layer == null:
			continue
		# Check if node's script parsed (has _initialized property)
		var init_check = node.get("_initialized")
		if layer == 4:
			if init_check != null:
				node.call("ensure_initialized")
			enemies_count += 1
		elif layer == 8 or layer == 16:
			if init_check != null:
				node.call("ensure_initialized")
			interactables_count += 1

	FileLogger.log_msg("Force-initialized %d enemies, %d objects" % [enemies_count, interactables_count])


func _get_all_descendants(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_descendants(child))
	return result
