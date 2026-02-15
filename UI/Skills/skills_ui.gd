class_name SkillsUI
extends VBoxContainer
## Displays all skills with their levels and XP progress bars.

## Player node — skills data is embedded directly on PlayerController
var _player: Node3D
var _skill_rows: Dictionary = {}

## Skill names — duplicated here to avoid class_name dependency issues on Android
var SKILL_NAMES = [
	"Attack", "Strength", "Defence", "Hitpoints",
	"Ranged", "Prayer", "Magic",
	"Cooking", "Woodcutting", "Fishing", "Mining",
	"Smithing", "Crafting", "Firemaking",
	"Agility", "Thieving"
]


## Accept Node3D — the player node has skills embedded directly
func setup(player: Node3D) -> void:
	_player = player
	# Connect to signals on the player node
	if _player.has_signal("xp_gained"):
		_player.xp_gained.connect(_on_xp_gained)
	if _player.has_signal("level_up"):
		_player.level_up.connect(_on_level_up)
	_build_ui()
	refresh()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	add_theme_constant_override("separation", 2)

	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.15, 0.12, 0.08, 0.8)
	xp_bg.corner_radius_top_left = 2
	xp_bg.corner_radius_top_right = 2
	xp_bg.corner_radius_bottom_right = 2
	xp_bg.corner_radius_bottom_left = 2

	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.2, 0.65, 0.15, 1)
	xp_fill.corner_radius_top_left = 2
	xp_fill.corner_radius_top_right = 2
	xp_fill.corner_radius_bottom_right = 2
	xp_fill.corner_radius_bottom_left = 2

	for skill_name in SKILL_NAMES:
		var row := _create_skill_row(skill_name, xp_bg, xp_fill)
		add_child(row)
		_skill_rows[skill_name] = row


func _create_skill_row(skill_name: String, xp_bg: StyleBoxFlat, xp_fill: StyleBoxFlat) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 42)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = skill_name
	name_label.custom_minimum_size = Vector2(140, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	row.add_child(name_label)

	var level_label := Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "1"
	level_label.custom_minimum_size = Vector2(48, 0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 22)
	level_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	row.add_child(level_label)

	var progress := ProgressBar.new()
	progress.name = "XPBar"
	progress.custom_minimum_size = Vector2(100, 0)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.show_percentage = false
	progress.max_value = 1.0
	progress.value = 0.0
	progress.add_theme_stylebox_override("background", xp_bg)
	progress.add_theme_stylebox_override("fill", xp_fill)
	row.add_child(progress)

	return row


func refresh() -> void:
	if _player == null:
		return

	var levels_dict = _player.get("skill_levels")
	var xp_dict = _player.get("skill_xp")
	if levels_dict == null or xp_dict == null:
		return

	for skill_name in SKILL_NAMES:
		if not _skill_rows.has(skill_name):
			continue
		var row: HBoxContainer = _skill_rows[skill_name]
		var level_label: Label = row.get_node("LevelLabel")
		var xp_bar: ProgressBar = row.get_node("XPBar")

		var level: int = levels_dict.get(skill_name, 1)
		level_label.text = str(level)

		# Calculate progress to next level
		if level >= 99:
			xp_bar.value = 1.0
		else:
			var current_xp: float = xp_dict.get(skill_name, 0.0)
			var current_level_xp := _xp_for_level(level)
			var next_level_xp := _xp_for_level(level + 1)
			xp_bar.value = (current_xp - current_level_xp) / (next_level_xp - current_level_xp)


func _xp_for_level(level: int) -> float:
	var total: float = 0.0
	for i in range(1, level):
		total += floorf(i + 300.0 * pow(2.0, i / 7.0))
	return floorf(total / 4.0)


func _on_xp_gained(_skill_name: String, _amount: float, _total: float) -> void:
	refresh()


func _on_level_up(_skill_name: String, _new_level: int) -> void:
	refresh()
