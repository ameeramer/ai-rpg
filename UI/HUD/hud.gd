extends CanvasLayer
## Main HUD — Mobile-first layout with bottom toolbar and overlay panels.

@onready var hp_bar: ProgressBar = $TopLeft/HPBar
@onready var hp_label: Label = $TopLeft/HPBar/HPLabel
@onready var action_log: RichTextLabel = $ActionLogContainer/ActionLog
@onready var touch_blocker: ColorRect = $TouchBlocker
@onready var inventory_overlay: PanelContainer = $InventoryOverlay
@onready var skills_overlay: PanelContainer = $SkillsOverlay
@onready var equipment_overlay: PanelContainer = $EquipmentOverlay
@onready var save_menu_overlay: PanelContainer = $SaveMenuOverlay
@onready var inventory_panel: Panel = $InventoryOverlay/VBox/InventoryPanel
@onready var skills_panel: VBoxContainer = $SkillsOverlay/VBox/SkillsScroll/SkillsPanel
@onready var equipment_panel: Panel = $EquipmentOverlay/VBox/EquipmentPanel
@onready var save_menu_panel: VBoxContainer = $SaveMenuOverlay/VBox/SaveMenuScroll/SaveMenuPanel

var _player: Node3D
var _debug_panel: Control
var _dialogue_ui: Control
var _shop_ui: Control
var _context_menu: Control
var _current_panel: Control = null

func _ready() -> void:
	GameManager.action_logged.connect(_on_action_logged)
	$BottomToolbar/ButtonRow/InventoryBtn.pressed.connect(_toggle.bind("inv"))
	$BottomToolbar/ButtonRow/SkillsBtn.pressed.connect(_toggle.bind("skills"))
	$BottomToolbar/ButtonRow/EquipBtn.pressed.connect(_toggle.bind("equip"))
	$BottomToolbar/ButtonRow/MenuBtn.pressed.connect(_toggle.bind("menu"))
	$BottomToolbar/ButtonRow/DebugBtn.pressed.connect(_toggle_debug_log)
	$InventoryOverlay/VBox/Header/CloseBtn.pressed.connect(_close_panels)
	$SkillsOverlay/VBox/Header/CloseBtn.pressed.connect(_close_panels)
	$EquipmentOverlay/VBox/Header/CloseBtn.pressed.connect(_close_panels)
	$SaveMenuOverlay/VBox/Header/CloseBtn.pressed.connect(_close_panels)
	touch_blocker.gui_input.connect(_on_blocker_input)

func setup(player) -> void:
	_player = player
	player.call("set_hud", self)
	var xp_sig = PlayerSkills.get("xp_gained")
	if xp_sig:
		PlayerSkills.xp_gained.connect(_on_xp_gained)
		PlayerSkills.level_up.connect(_on_level_up)
	_load_ui("res://UI/Inventory/InventoryUI.tscn", inventory_panel)
	_load_ui("res://UI/Skills/SkillsUI.tscn", skills_panel)
	_load_ui("res://UI/Equipment/EquipmentUI.tscn", equipment_panel)
	_load_ui("res://UI/SaveMenu/SaveMenuUI.tscn", save_menu_panel)
	var ctx = load("res://UI/Inventory/ItemContextMenu.tscn")
	if ctx:
		_context_menu = ctx.instantiate()
		add_child(_context_menu)
		_context_menu.visible = false
		_context_menu.call("set_player", player)
	var dlg = load("res://UI/Dialogue/DialogueUI.tscn")
	if dlg:
		_dialogue_ui = dlg.instantiate()
		add_child(_dialogue_ui)
		_dialogue_ui.visible = false
		if _dialogue_ui.get("dialogue_closed"):
			_dialogue_ui.dialogue_closed.connect(_on_dialogue_closed)
		if _dialogue_ui.get("trade_requested"):
			_dialogue_ui.trade_requested.connect(_on_trade_requested)

func _load_ui(path: String, parent: Control) -> void:
	var scene = load(path)
	if scene == null or parent == null:
		return
	var ui = scene.instantiate()
	parent.add_child(ui)
	ui.call("setup")

func _process(_delta: float) -> void:
	if _player:
		var max_hp = _player.get("max_hitpoints")
		var hp = _player.get("hitpoints")
		if max_hp != null and hp != null:
			hp_bar.max_value = max_hp
			hp_bar.value = hp
			if hp_label:
				hp_label.text = "HP: %d / %d" % [hp, max_hp]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle("inv")
	elif event.is_action_pressed("toggle_skills"):
		_toggle("skills")
	elif event.is_action_pressed("toggle_equipment"):
		_toggle("equip")

func _get_overlay(key: String) -> Control:
	if key == "inv":
		return inventory_overlay
	elif key == "skills":
		return skills_overlay
	elif key == "equip":
		return equipment_overlay
	elif key == "menu":
		return save_menu_overlay
	return null

func _toggle(key: String) -> void:
	var panel = _get_overlay(key)
	if panel == null:
		return
	if _current_panel == panel:
		_close_panels()
	else:
		_close_panels()
		touch_blocker.visible = true
		panel.visible = true
		_current_panel = panel

func _close_panels() -> void:
	for p in [inventory_overlay, skills_overlay, equipment_overlay, save_menu_overlay, touch_blocker]:
		p.visible = false
	_current_panel = null
	if _context_menu:
		_context_menu.visible = false
	if _shop_ui and is_instance_valid(_shop_ui):
		_shop_ui.visible = false

func _on_blocker_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_close_panels()

func _on_action_logged(message) -> void:
	if action_log:
		action_log.append_text(str(message) + "\n")
		action_log.scroll_to_line(action_log.get_line_count() - 1)

func _on_xp_gained(skill_name, amount, _total) -> void:
	_on_action_logged("[color=green]+%.0f %s XP[/color]" % [amount, skill_name])

func _on_level_up(skill_name, new_level) -> void:
	_on_action_logged("[color=yellow]*** %s level %d! ***[/color]" % [skill_name, new_level])

func show_context_menu(item, slot_idx: int, pos: Vector2) -> void:
	if _context_menu:
		_context_menu.call("show_for_item", item, slot_idx, pos)

func show_dialogue(npc_name: String, lines: Array, merchant: bool = false, npc: Node3D = null) -> void:
	if _dialogue_ui:
		_dialogue_ui.call("show_dialogue", npc_name, lines, merchant, npc)

func _on_dialogue_closed() -> void:
	if _player and _player.get("state_machine"):
		_player.get("state_machine").call("transition_to", "Idle")

func _on_trade_requested(npc) -> void:
	if npc == null:
		return
	var npc_name = npc.get("display_name")
	if npc_name == null:
		npc_name = npc.name
	var stock = npc.call("get_shop_stock")
	if stock:
		show_shop(npc_name, stock)

func show_shop(npc_name: String, stock: Array) -> void:
	if _shop_ui == null or not is_instance_valid(_shop_ui):
		var sc = load("res://UI/Shop/ShopUI.tscn")
		if sc:
			_shop_ui = sc.instantiate()
			add_child(_shop_ui)
	if _shop_ui:
		_shop_ui.call("open_shop", npc_name, stock)
		_shop_ui.visible = true
		touch_blocker.visible = true

func _toggle_debug_log() -> void:
	if _debug_panel and is_instance_valid(_debug_panel):
		_debug_panel.visible = not _debug_panel.visible
		if _debug_panel.visible:
			_debug_panel.call("_load_logs")
	else:
		var sc = load("res://UI/HUD/DebugLogPanel.tscn")
		if sc:
			_debug_panel = sc.instantiate()
			add_child(_debug_panel)
