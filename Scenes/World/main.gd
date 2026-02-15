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

	# Set up inventory UI
	var inventory_panel := hud.get_node_or_null("MainContainer/SidePanel/InventoryPanel")
	if inventory_panel:
		var inv_ui := InventoryUI.new()
		inv_ui.name = "InventoryGrid"
		inventory_panel.add_child(inv_ui)
		var player_inv := player.get_node_or_null("PlayerInventory") as PlayerInventory
		if player_inv:
			inv_ui.setup(player_inv)
	FileLogger.log_msg("Inventory UI done")

	# Set up skills UI
	var skills_panel := hud.get_node_or_null("MainContainer/SidePanel/SkillsPanel")
	if skills_panel:
		var skills_ui := SkillsUI.new()
		skills_ui.name = "SkillsList"
		skills_panel.add_child(skills_ui)
		var player_skills := player.get_node_or_null("PlayerSkills") as PlayerSkills
		if player_skills:
			skills_ui.setup(player_skills)
	FileLogger.log_msg("Skills UI done")

	# Connect tab buttons
	var inv_tab := hud.get_node_or_null("MainContainer/SidePanel/TabButtons/InventoryTab")
	var skills_tab := hud.get_node_or_null("MainContainer/SidePanel/TabButtons/SkillsTab")
	if inv_tab:
		inv_tab.pressed.connect(func(): hud._toggle_inventory())
	if skills_tab:
		skills_tab.pressed.connect(func(): hud._toggle_skills())

	FileLogger.log_msg("Main._ready() complete")
	GameManager.log_action("Welcome to AI RPG! Click to move, click objects to interact.")
