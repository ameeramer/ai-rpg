extends VBoxContainer
## Combat Styles UI — shows attack style options for current weapon.
## Instantiated as PackedScene inside HUD combat overlay.
## No class_name — instantiated via PackedScene on Android.

var _style_buttons: Array = []
var _weapon_label: Node = null
var _combat_level_label: Node = null

func setup() -> void:
	FileLogger.log_msg("CombatStyleUI.setup() start")
	var eq_sig = PlayerEquipment.get("equipment_changed")
	if eq_sig:
		PlayerEquipment.equipment_changed.connect(_on_equipment_changed)
	var cs_sig = CombatStyle.get("style_changed")
	if cs_sig:
		CombatStyle.style_changed.connect(_on_style_changed)
	var sk_sig = PlayerSkills.get("xp_gained")
	if sk_sig:
		PlayerSkills.xp_gained.connect(_on_xp_changed)
	_build_ui()
	FileLogger.log_msg("CombatStyleUI.setup() done")


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_style_buttons.clear()

	add_theme_constant_override("separation", 12)

	# Combat level label
	_combat_level_label = Label.new()
	_combat_level_label.text = "Combat Level: %d" % PlayerSkills.call("get_combat_level")
	_combat_level_label.add_theme_font_size_override("font_size", 39)
	_combat_level_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_combat_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_combat_level_label)

	# Weapon name label
	_weapon_label = Label.new()
	_weapon_label.add_theme_font_size_override("font_size", 36)
	_weapon_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_weapon_label)

	# Separator
	var sep = HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 6)
	add_child(sep)

	_refresh_styles()


func _refresh_styles() -> void:
	# Remove old style buttons
	for btn in _style_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_style_buttons.clear()

	# Update weapon name
	var weapon = PlayerEquipment.call("get_weapon")
	var weapon_name = "Unarmed"
	if weapon != null:
		var wn = weapon.call("get_display_name")
		if wn != null:
			weapon_name = wn
	if _weapon_label:
		_weapon_label.text = weapon_name

	# Update combat level
	if _combat_level_label:
		_combat_level_label.text = "Combat Level: %d" % PlayerSkills.call("get_combat_level")

	# Get available styles
	var styles = CombatStyle.call("get_styles_for_weapon")
	if styles == null:
		styles = []

	var current = CombatStyle.get("current_style")
	if current == null:
		current = "accurate"

	# Style colors
	var style_colors = {
		"accurate": Color(0.2, 0.5, 0.8),
		"aggressive": Color(0.8, 0.2, 0.2),
		"defensive": Color(0.2, 0.7, 0.3),
		"controlled": Color(0.7, 0.5, 0.2)
	}

	for i in range(styles.size()):
		var s = styles[i]
		var style_key = s.get("style", "accurate")
		var style_name = s.get("name", "Unknown")
		var atk_type = s.get("attack_type", "")

		# Build XP description
		var xp_map = s.get("xp", {})
		var xp_parts = []
		for skill in xp_map:
			if skill != "Hitpoints":
				xp_parts.append(skill)
		var xp_desc = " + ".join(xp_parts)

		# Create button
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 108)
		btn.add_theme_font_size_override("font_size", 36)

		# Style description
		var label_text = "%s (%s)" % [style_name, style_key.capitalize()]
		label_text += "\n%s  |  XP: %s" % [atk_type, xp_desc]
		btn.text = label_text

		# Color coding
		var base_color = style_colors.get(style_key, Color(0.3, 0.3, 0.3))
		var normal_style = StyleBoxFlat.new()
		normal_style.corner_radius_top_left = 8
		normal_style.corner_radius_top_right = 8
		normal_style.corner_radius_bottom_right = 8
		normal_style.corner_radius_bottom_left = 8
		normal_style.border_width_left = 3
		normal_style.border_width_top = 3
		normal_style.border_width_right = 3
		normal_style.border_width_bottom = 3

		if style_key == current:
			normal_style.bg_color = Color(base_color.r * 0.6, base_color.g * 0.6, base_color.b * 0.6, 0.95)
			normal_style.border_color = Color(1, 0.9, 0.4, 1)
		else:
			normal_style.bg_color = Color(base_color.r * 0.25, base_color.g * 0.25, base_color.b * 0.25, 0.9)
			normal_style.border_color = Color(base_color.r * 0.7, base_color.g * 0.7, base_color.b * 0.7, 0.8)

		btn.add_theme_stylebox_override("normal", normal_style)

		# Pressed style
		var pressed_style = normal_style.duplicate()
		pressed_style.bg_color = Color(base_color.r * 0.8, base_color.g * 0.8, base_color.b * 0.8, 1)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		# Hover style
		var hover_style = normal_style.duplicate()
		hover_style.bg_color = Color(base_color.r * 0.4, base_color.g * 0.4, base_color.b * 0.4, 0.95)
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.pressed.connect(_on_style_pressed.bind(style_key))
		add_child(btn)
		_style_buttons.append(btn)


func _on_style_pressed(style_key: String) -> void:
	CombatStyle.call("set_style", style_key)


func _on_equipment_changed() -> void:
	_refresh_styles()


func _on_style_changed() -> void:
	_refresh_styles()


func _on_xp_changed(_skill, _amount, _total) -> void:
	if _combat_level_label:
		_combat_level_label.text = "Combat Level: %d" % PlayerSkills.call("get_combat_level")
