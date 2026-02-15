extends Node3D
## Main game scene — sets up the world, player, camera, and UI.

@onready var player: Node3D = $Player
@onready var camera_controller: Node3D = $CameraController
@onready var hud: Node = $HUD


func _ready() -> void:
	FileLogger.log_msg("Main._ready() start")

	camera_controller.set("target", player)
	FileLogger.log_msg("Camera target set")

	hud.call("setup", player)
	FileLogger.log_msg("HUD setup done")

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

	# Set up inventory UI — now uses PlayerInventory autoload, no player ref needed
	var inventory_panel := hud.get_node_or_null("InventoryOverlay/VBox/InventoryPanel")
	if inventory_panel:
		var inv_ui := InventoryUI.new()
		inv_ui.name = "InventoryGrid"
		inventory_panel.add_child(inv_ui)
		inv_ui.call("setup")
	FileLogger.log_msg("Inventory UI done")

	# Set up skills UI — now uses PlayerSkills autoload, no player ref needed
	var skills_panel := hud.get_node_or_null("SkillsOverlay/VBox/SkillsScroll/SkillsPanel")
	if skills_panel:
		var skills_ui := SkillsUI.new()
		skills_ui.name = "SkillsList"
		skills_panel.add_child(skills_ui)
		skills_ui.call("setup")
	FileLogger.log_msg("Skills UI done")

	FileLogger.log_msg("Main._ready() complete")
	GameManager.log_action("Welcome to AI RPG! Tap to move, tap objects to interact.")


func _force_initialize_objects() -> void:
	var enemies_count: int = 0
	var interactables_count: int = 0

	var all_nodes := _get_all_descendants(self)
	for node in all_nodes:
		var layer = node.get("collision_layer")
		if layer == null:
			continue
		if layer == 4:
			node.call("ensure_initialized")
			enemies_count += 1
		elif layer == 8:
			node.call("ensure_initialized")
			interactables_count += 1

	FileLogger.log_msg("Force-initialized %d enemies, %d interactables" % [enemies_count, interactables_count])


func _get_all_descendants(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_descendants(child))
	return result
