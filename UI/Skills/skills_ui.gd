class_name SkillsUI
extends VBoxContainer
## Displays all skills with their levels and XP progress bars.

## Use Node instead of PlayerSkills — `is PlayerSkills` fails on Android
var _skills: Node
var _skill_rows: Dictionary = {}


## Accept Node — typed PlayerSkills param fails on Android (type check crash)
func setup(skills: Node) -> void:
	_skills = skills
	_skills.xp_gained.connect(_on_xp_gained)
	_skills.level_up.connect(_on_level_up)
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

	for skill_name in PlayerSkills.SKILL_NAMES:
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
	if _skills == null:
		return

	for skill_name in PlayerSkills.SKILL_NAMES:
		if not _skill_rows.has(skill_name):
			continue
		var row: HBoxContainer = _skill_rows[skill_name]
		var level_label: Label = row.get_node("LevelLabel")
		var xp_bar: ProgressBar = row.get_node("XPBar")

		level_label.text = str(_skills.get_level(skill_name))
		xp_bar.value = _skills.get_level_progress(skill_name)


func _on_xp_gained(_skill_name: String, _amount: float, _total: float) -> void:
	refresh()


func _on_level_up(_skill_name: String, _new_level: int) -> void:
	refresh()
