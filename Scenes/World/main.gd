extends Node3D
## Main game scene — sets up the world, player, camera, and UI.

## Use Node3D/Node — typed custom class vars may fail on Android (is check)
@onready var player: Node3D = $Player
@onready var camera_controller: Node3D = $CameraController
@onready var hud: Node = $HUD


func _ready() -> void:
	FileLogger.log_msg("Main._ready() start")

	# Point camera at player — use .set() since camera_controller is typed as Node3D
	camera_controller.set("target", player)
	FileLogger.log_msg("Camera target set")

	# Set up HUD with player reference — use .call() for Android safety
	hud.call("setup", player)
	FileLogger.log_msg("HUD setup done")

	# Explicitly initialize all enemies and interactables — _ready() may not fire on Android
	_force_initialize_objects()

	# Skills + inventory are embedded in PlayerController — no child nodes needed.
	# PlayerController._ready() initializes them before Main._ready() runs.
	var is_init = player.get("_initialized")
	FileLogger.log_msg("Player initialized: %s" % str(is_init))

	# Set up inventory UI inside the overlay panel
	var inventory_panel := hud.get_node_or_null("InventoryOverlay/VBox/InventoryPanel")
	if inventory_panel:
		var inv_ui := InventoryUI.new()
		inv_ui.name = "InventoryGrid"
		inventory_panel.add_child(inv_ui)
		inv_ui.call("setup", player)
	FileLogger.log_msg("Inventory UI done")

	# Set up skills UI inside the scroll container
	var skills_panel := hud.get_node_or_null("SkillsOverlay/VBox/SkillsScroll/SkillsPanel")
	if skills_panel:
		var skills_ui := SkillsUI.new()
		skills_ui.name = "SkillsList"
		skills_panel.add_child(skills_ui)
		skills_ui.call("setup", player)
	FileLogger.log_msg("Skills UI done")

	FileLogger.log_msg("Main._ready() complete")
	GameManager.log_action("Welcome to AI RPG! Tap to move, tap objects to interact.")


## Force-initialize all game objects by collision layer.
## On Android Godot 4.3, _ready() may not fire for scripts on PackedScene instances.
## This walks the full scene tree and calls ensure_initialized() on matching objects.
func _force_initialize_objects() -> void:
	var enemies_count: int = 0
	var interactables_count: int = 0

	var all_nodes := _get_all_descendants(self)
	for node in all_nodes:
		var layer = node.get("collision_layer")
		if layer == null:
			continue

		# Enemy (layer 4)
		if layer == 4:
			node.call("ensure_initialized")
			enemies_count += 1

		# Interactable (layer 8)
		elif layer == 8:
			node.call("ensure_initialized")
			interactables_count += 1

	FileLogger.log_msg("Force-initialized %d enemies, %d interactables" % [enemies_count, interactables_count])


func _get_all_descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_descendants(child))
	return result
