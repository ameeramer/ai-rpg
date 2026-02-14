class_name SkillsUI
extends VBoxContainer
## Displays all skills with their levels and XP progress bars.

var _skills: PlayerSkills
var _skill_rows: Dictionary = {}


func setup(skills: PlayerSkills) -> void:
	_skills = skills
	_skills.xp_gained.connect(_on_xp_gained)
	_skills.level_up.connect(_on_level_up)
	_build_ui()
	refresh()


func _build_ui() -> void:
	# Clear existing children
	for child in get_children():
		child.queue_free()

	for skill_name in PlayerSkills.SKILL_NAMES:
		var row := _create_skill_row(skill_name)
		add_child(row)
		_skill_rows[skill_name] = row


func _create_skill_row(skill_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)

	# Skill name label
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = skill_name
	name_label.custom_minimum_size = Vector2(90, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# Level label
	var level_label := Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "1"
	level_label.custom_minimum_size = Vector2(30, 0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(level_label)

	# XP progress bar
	var progress := ProgressBar.new()
	progress.name = "XPBar"
	progress.custom_minimum_size = Vector2(80, 0)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.show_percentage = false
	progress.max_value = 1.0
	progress.value = 0.0
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
