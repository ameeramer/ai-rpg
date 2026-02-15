extends Node3D
## Main game scene — sets up the world, player, camera, and UI.

@onready var player: PlayerController = $Player
@onready var camera_controller: CameraController = $CameraController
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	FileLogger.log_msg("Main._ready() start")

	# Point camera at player
	camera_controller.target = player
	FileLogger.log_msg("Camera target set")

	# Set up HUD with player reference
	hud.setup(player)
	FileLogger.log_msg("HUD setup done")

	# Set up inventory UI inside the overlay panel
	var inventory_panel := hud.get_node_or_null("InventoryOverlay/VBox/InventoryPanel")
	if inventory_panel:
		var inv_ui := InventoryUI.new()
		inv_ui.name = "InventoryGrid"
		inventory_panel.add_child(inv_ui)
		var player_inv := player.get_node_or_null("PlayerInventory") as PlayerInventory
		if player_inv:
			inv_ui.setup(player_inv)
	FileLogger.log_msg("Inventory UI done")

	# Set up skills UI inside the scroll container
	var skills_panel := hud.get_node_or_null("SkillsOverlay/VBox/SkillsScroll/SkillsPanel")
	if skills_panel:
		var skills_ui := SkillsUI.new()
		skills_ui.name = "SkillsList"
		skills_panel.add_child(skills_ui)
		var player_skills := player.get_node_or_null("PlayerSkills") as PlayerSkills
		if player_skills:
			skills_ui.setup(player_skills)
	FileLogger.log_msg("Skills UI done")

	FileLogger.log_msg("Main._ready() complete")
	GameManager.log_action("Welcome to AI RPG! Tap to move, tap objects to interact.")
