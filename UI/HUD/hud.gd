extends CanvasLayer
## Main HUD — Contains all UI panels and manages their visibility.

@onready var hp_bar: ProgressBar = $MainContainer/TopBar/HPBar
@onready var hp_label: Label = $MainContainer/TopBar/HPBar/HPLabel
@onready var prayer_bar: ProgressBar = $MainContainer/TopBar/PrayerBar
@onready var prayer_label: Label = $MainContainer/TopBar/PrayerBar/PrayerLabel
@onready var inventory_panel: Control = $MainContainer/SidePanel/InventoryPanel
@onready var skills_panel: Control = $MainContainer/SidePanel/SkillsPanel
@onready var action_log: RichTextLabel = $MainContainer/BottomBar/ActionLog
@onready var minimap: Control = $MainContainer/TopBar/Minimap

var _player: PlayerController


func _ready() -> void:
	# Start with inventory visible, skills hidden
	if skills_panel:
		skills_panel.visible = false

	# Connect to GameManager for action log
	GameManager.action_logged.connect(_on_action_logged)


func setup(player: PlayerController) -> void:
	_player = player

	# Connect to player's skills for level ups
	var skills := player.get_node_or_null("PlayerSkills") as PlayerSkills
	if skills:
		skills.xp_gained.connect(_on_xp_gained)
		skills.level_up.connect(_on_level_up)

	# Connect to inventory
	var inventory := player.get_node_or_null("PlayerInventory") as PlayerInventory
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
		hp_bar.max_value = _player.max_hitpoints
		hp_bar.value = _player.hitpoints
	if hp_label and _player:
		hp_label.text = "%d / %d" % [_player.hitpoints, _player.max_hitpoints]


func _toggle_inventory() -> void:
	if inventory_panel:
		inventory_panel.visible = true
	if skills_panel:
		skills_panel.visible = false


func _toggle_skills() -> void:
	if skills_panel:
		skills_panel.visible = true
	if inventory_panel:
		inventory_panel.visible = false


func _on_action_logged(message: String) -> void:
	if action_log:
		action_log.append_text(message + "\n")
		# Auto-scroll to bottom
		action_log.scroll_to_line(action_log.get_line_count() - 1)


func _on_xp_gained(skill_name: String, amount: float, _total: float) -> void:
	_on_action_logged("[color=green]+%.0f %s XP[/color]" % [amount, skill_name])


func _on_level_up(skill_name: String, new_level: int) -> void:
	_on_action_logged("[color=yellow]*** %s level %d! ***[/color]" % [skill_name, new_level])


func _on_inventory_changed() -> void:
	# Inventory UI will handle its own refresh via signals
	pass
