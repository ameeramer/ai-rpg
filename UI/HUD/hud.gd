extends CanvasLayer
## Main HUD — Mobile-first layout with bottom toolbar and overlay panels.

@onready var hp_bar: ProgressBar = $TopLeft/HPBar
@onready var hp_label: Label = $TopLeft/HPBar/HPLabel
@onready var action_log: RichTextLabel = $ActionLogContainer/ActionLog
@onready var touch_blocker: ColorRect = $TouchBlocker
@onready var inventory_overlay: PanelContainer = $InventoryOverlay
@onready var skills_overlay: PanelContainer = $SkillsOverlay
@onready var inventory_panel: Panel = $InventoryOverlay/VBox/InventoryPanel
@onready var skills_panel: VBoxContainer = $SkillsOverlay/VBox/SkillsScroll/SkillsPanel
@onready var inv_btn: Button = $BottomToolbar/ButtonRow/InventoryBtn
@onready var skills_btn: Button = $BottomToolbar/ButtonRow/SkillsBtn
@onready var debug_btn: Button = $BottomToolbar/ButtonRow/DebugBtn
@onready var inv_close: Button = $InventoryOverlay/VBox/Header/CloseBtn
@onready var skills_close: Button = $SkillsOverlay/VBox/Header/CloseBtn

var _player: Node3D
var _debug_panel: Control
var _current_panel: Control = null


func _ready() -> void:
	FileLogger.log_msg("HUD._ready() start")
	GameManager.action_logged.connect(_on_action_logged)

	inv_btn.pressed.connect(_toggle_inventory)
	skills_btn.pressed.connect(_toggle_skills)
	debug_btn.pressed.connect(_toggle_debug_log)

	inv_close.pressed.connect(_close_panels)
	skills_close.pressed.connect(_close_panels)

	touch_blocker.gui_input.connect(_on_blocker_input)
	FileLogger.log_msg("HUD._ready() done")


func setup(player) -> void:
	FileLogger.log_msg("HUD.setup() start")
	_player = player

	# Connect to autoload signals for XP/level/inventory
	PlayerSkills.xp_gained.connect(_on_xp_gained)
	PlayerSkills.level_up.connect(_on_level_up)
	PlayerInventory.inventory_changed.connect(_on_inventory_changed)
	FileLogger.log_msg("HUD.setup() autoload signals connected")

	# Instantiate inventory UI from PackedScene
	_setup_inventory_ui()

	# Instantiate skills UI from PackedScene
	_setup_skills_ui()

	FileLogger.log_msg("HUD.setup() complete")


func _setup_inventory_ui() -> void:
	FileLogger.log_msg("HUD: loading InventoryUI.tscn")
	var inv_scene = load("res://UI/Inventory/InventoryUI.tscn")
	FileLogger.log_msg("HUD: inv_scene = %s" % str(inv_scene))
	if inv_scene == null:
		FileLogger.log_msg("HUD: FAILED to load InventoryUI.tscn")
		return
	if inventory_panel == null:
		FileLogger.log_msg("HUD: inventory_panel is null")
		return
	var inv_ui = inv_scene.instantiate()
	FileLogger.log_msg("HUD: inv_ui instantiated = %s" % str(inv_ui))
	inventory_panel.add_child(inv_ui)
	FileLogger.log_msg("HUD: inv_ui added to panel")
	inv_ui.call("setup")
	FileLogger.log_msg("HUD: inv_ui.setup() called")


func _setup_skills_ui() -> void:
	FileLogger.log_msg("HUD: loading SkillsUI.tscn")
	var skills_scene = load("res://UI/Skills/SkillsUI.tscn")
	FileLogger.log_msg("HUD: skills_scene = %s" % str(skills_scene))
	if skills_scene == null:
		FileLogger.log_msg("HUD: FAILED to load SkillsUI.tscn")
		return
	if skills_panel == null:
		FileLogger.log_msg("HUD: skills_panel is null")
		return
	var skills_ui = skills_scene.instantiate()
	FileLogger.log_msg("HUD: skills_ui instantiated = %s" % str(skills_ui))
	skills_panel.add_child(skills_ui)
	FileLogger.log_msg("HUD: skills_ui added to panel")
	skills_ui.call("setup")
	FileLogger.log_msg("HUD: skills_ui.setup() called")


func _process(_delta: float) -> void:
	if _player:
		_update_hp_bar()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle_inventory()
	elif event.is_action_pressed("toggle_skills"):
		_toggle_skills()


func _update_hp_bar() -> void:
	if hp_bar and _player:
		var max_hp = _player.get("max_hitpoints")
		var hp = _player.get("hitpoints")
		if max_hp != null and hp != null:
			hp_bar.max_value = max_hp
			hp_bar.value = hp
			if hp_label:
				hp_label.text = "HP: %d / %d" % [hp, max_hp]


func _toggle_inventory() -> void:
	if _current_panel == inventory_overlay:
		_close_panels()
	else:
		_show_panel(inventory_overlay)


func _toggle_skills() -> void:
	if _current_panel == skills_overlay:
		_close_panels()
	else:
		_show_panel(skills_overlay)


func _show_panel(panel: Control) -> void:
	_close_panels()
	touch_blocker.visible = true
	panel.visible = true
	_current_panel = panel


func _close_panels() -> void:
	inventory_overlay.visible = false
	skills_overlay.visible = false
	touch_blocker.visible = false
	_current_panel = null


func _on_blocker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_panels()
	elif event is InputEventScreenTouch and event.pressed:
		_close_panels()


func _on_action_logged(message) -> void:
	if action_log:
		action_log.append_text(str(message) + "\n")
		action_log.scroll_to_line(action_log.get_line_count() - 1)


func _on_xp_gained(skill_name, amount, _total) -> void:
	_on_action_logged("[color=green]+%.0f %s XP[/color]" % [amount, skill_name])


func _on_level_up(skill_name, new_level) -> void:
	_on_action_logged("[color=yellow]*** %s level %d! ***[/color]" % [skill_name, new_level])


func _on_inventory_changed() -> void:
	pass


func _toggle_debug_log() -> void:
	if _debug_panel and is_instance_valid(_debug_panel):
		_debug_panel.visible = not _debug_panel.visible
		if _debug_panel.visible:
			_debug_panel.call("_load_logs")
	else:
		var dbg_scene = load("res://UI/HUD/DebugLogPanel.tscn")
		if dbg_scene:
			_debug_panel = dbg_scene.instantiate()
			add_child(_debug_panel)
		else:
			FileLogger.log_msg("HUD: Failed to load DebugLogPanel.tscn")
