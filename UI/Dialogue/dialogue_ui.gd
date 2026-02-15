extends PanelContainer
## Dialogue UI — shows NPC dialogue lines with Next/Close buttons.

signal dialogue_closed()

var _lines: Array = []
var _current_line: int = 0
var _npc_name: String = ""
var _name_label: Label
var _text_label: RichTextLabel
var _next_btn: Button
var _close_btn: Button


func _ready() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.55, 0.45, 0.28, 1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	# NPC name
	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_name_label)
	# Dialogue text
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.custom_minimum_size = Vector2(500, 80)
	_text_label.add_theme_font_size_override("normal_font_size", 22)
	_text_label.add_theme_color_override("default_color", Color(0.9, 0.85, 0.7))
	_text_label.fit_content = true
	_text_label.scroll_active = false
	vbox.add_child(_text_label)
	# Buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.15, 0.1, 0.95)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.5, 0.42, 0.28, 1)
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_right = 6
	btn_style.corner_radius_bottom_left = 6
	_next_btn = Button.new()
	_next_btn.text = "Next"
	_next_btn.custom_minimum_size = Vector2(120, 48)
	_next_btn.add_theme_font_size_override("font_size", 22)
	_next_btn.add_theme_stylebox_override("normal", btn_style)
	_next_btn.pressed.connect(_on_next)
	btn_row.add_child(_next_btn)
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(120, 48)
	_close_btn.add_theme_font_size_override("font_size", 22)
	_close_btn.add_theme_stylebox_override("normal", btn_style)
	_close_btn.pressed.connect(_on_close)
	btn_row.add_child(_close_btn)


func show_dialogue(npc_name: String, lines: Array) -> void:
	_npc_name = npc_name
	_lines = lines
	_current_line = 0
	_name_label.text = npc_name
	_update_display()
	visible = true


func _update_display() -> void:
	if _current_line < _lines.size():
		_text_label.text = str(_lines[_current_line])
	_next_btn.visible = _current_line < _lines.size() - 1


func _on_next() -> void:
	_current_line += 1
	_update_display()


func _on_close() -> void:
	visible = false
	dialogue_closed.emit()
