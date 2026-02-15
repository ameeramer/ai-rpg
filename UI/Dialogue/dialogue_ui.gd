extends PanelContainer
## Dialogue UI — shows NPC dialogue lines with Next/Close/Trade buttons.

signal dialogue_closed()
signal trade_requested(npc)

var _lines: Array = []
var _current_line: int = 0
var _npc_name: String = ""
var _is_merchant: bool = false
var _npc_ref: Node3D = null
var _name_label: Label
var _text_label: RichTextLabel
var _next_btn: Button
var _close_btn: Button
var _trade_btn: Button


func _ready() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	style.set_border_width_all(3)
	style.border_color = Color(0.55, 0.45, 0.28, 1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_top = 16
	style.content_margin_right = 20
	style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(960, 0)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_name_label.add_theme_font_size_override("font_size", 45)
	vbox.add_child(_name_label)
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.custom_minimum_size = Vector2(870, 135)
	_text_label.add_theme_font_size_override("normal_font_size", 42)
	_text_label.add_theme_color_override("default_color", Color(0.9, 0.85, 0.7))
	_text_label.fit_content = true
	_text_label.scroll_active = false
	vbox.add_child(_text_label)
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)
	var bs = _btn_style()
	_next_btn = _make_btn("Next", bs, btn_row)
	_next_btn.pressed.connect(_on_next)
	_trade_btn = _make_btn("Trade", bs, btn_row)
	_trade_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_trade_btn.pressed.connect(_on_trade)
	_trade_btn.visible = false
	_close_btn = _make_btn("Close", bs, btn_row)
	_close_btn.pressed.connect(_on_close)

func _btn_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.15, 0.1, 0.95)
	s.set_border_width_all(2)
	s.border_color = Color(0.5, 0.42, 0.28, 1)
	s.set_corner_radius_all(6)
	return s

func _make_btn(label: String, style: StyleBoxFlat, parent: Node) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(210, 84)
	btn.add_theme_font_size_override("font_size", 39)
	btn.add_theme_stylebox_override("normal", style)
	parent.add_child(btn)
	return btn

func show_dialogue(npc_name: String, lines: Array, merchant: bool = false, npc: Node3D = null) -> void:
	_npc_name = npc_name
	_lines = lines
	_current_line = 0
	_is_merchant = merchant
	_npc_ref = npc
	_name_label.text = npc_name
	_update_display()
	visible = true

func _update_display() -> void:
	if _current_line < _lines.size():
		_text_label.text = str(_lines[_current_line])
	var has_more = _current_line < _lines.size() - 1
	_next_btn.visible = has_more
	_trade_btn.visible = _is_merchant and not has_more

func _on_next() -> void:
	_current_line += 1
	_update_display()

func _on_trade() -> void:
	visible = false
	trade_requested.emit(_npc_ref)

func _on_close() -> void:
	visible = false
	dialogue_closed.emit()
