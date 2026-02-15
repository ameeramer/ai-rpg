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

## Use Node3D — typed PlayerController param fails on Android (type check crash)
var _player: Node3D
var _debug_panel: DebugLogPanel
var _current_panel: Control = null


func _ready() -> void:
	# Connect to GameManager for action log
	GameManager.action_logged.connect(_on_action_logged)

	# Connect toolbar buttons
	inv_btn.pressed.connect(_toggle_inventory)
	skills_btn.pressed.connect(_toggle_skills)
	debug_btn.pressed.connect(_toggle_debug_log)

	# Connect close buttons
	inv_close.pressed.connect(_close_panels)
	skills_close.pressed.connect(_close_panels)

	# Touch blocker closes panels
	touch_blocker.gui_input.connect(_on_blocker_input)


## Accept Node3D — typed PlayerController param fails on Android (type check crash)
func setup(player: Node3D) -> void:
	_player = player

	# Don't use `as PlayerSkills` / `as PlayerInventory` — type casts fail on Android
	var skills := player.get_node_or_null("PlayerSkills")
	if skills:
		skills.xp_gained.connect(_on_xp_gained)
		skills.level_up.connect(_on_level_up)

	var inventory := player.get_node_or_null("PlayerInventory")
	if inventory:
		inventory.inventory_changed.connect(_on_inventory_changed)


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


func _on_action_logged(message: String) -> void:
	if action_log:
		action_log.append_text(message + "\n")
		action_log.scroll_to_line(action_log.get_line_count() - 1)


func _on_xp_gained(skill_name: String, amount: float, _total: float) -> void:
	_on_action_logged("[color=green]+%.0f %s XP[/color]" % [amount, skill_name])


func _on_level_up(skill_name: String, new_level: int) -> void:
	_on_action_logged("[color=yellow]*** %s level %d! ***[/color]" % [skill_name, new_level])


func _on_inventory_changed() -> void:
	pass


func _toggle_debug_log() -> void:
	if _debug_panel and is_instance_valid(_debug_panel):
		_debug_panel.visible = not _debug_panel.visible
		if _debug_panel.visible:
			_debug_panel._load_logs()
	else:
		_debug_panel = DebugLogPanel.new()
		_debug_panel.name = "DebugLogPanel"
		_debug_panel.anchors_preset = Control.PRESET_FULL_RECT
		_debug_panel.anchor_right = 1.0
		_debug_panel.anchor_bottom = 1.0
		add_child(_debug_panel)
