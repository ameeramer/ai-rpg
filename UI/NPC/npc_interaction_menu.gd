extends PanelContainer
## NPC interaction menu — shows Chat / Trade options when clicking an AI NPC.

signal option_selected(option, npc)

var _npc = null
var _vbox: VBoxContainer


func _ready() -> void:
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 8)
	add_child(_vbox)
	# Style the panel (OSRS dark style matching ItemContextMenu)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.07, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.55, 0.45, 0.28, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	visible = false


func show_for_npc(npc) -> void:
	_npc = npc
	# Clear old children
	for child in _vbox.get_children():
		child.queue_free()
	# NPC name header
	var npc_name = npc.get("display_name")
	if npc_name == null:
		npc_name = npc.name
	var header = Label.new()
	header.text = str(npc_name)
	header.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	header.add_theme_font_size_override("font_size", 39)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(header)
	# Chat button
	_add_option_button("Chat")
	# Trade button
	_add_option_button("Trade")
	# Center on screen
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -180
	offset_top = -150
	offset_right = 180
	offset_bottom = 150
	visible = true


func _add_option_button(label: String) -> void:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(300, 90)
	btn.add_theme_font_size_override("font_size", 39)
	var style_n = StyleBoxFlat.new()
	style_n.bg_color = Color(0.18, 0.15, 0.1, 0.9)
	style_n.corner_radius_top_left = 4
	style_n.corner_radius_top_right = 4
	style_n.corner_radius_bottom_right = 4
	style_n.corner_radius_bottom_left = 4
	btn.add_theme_stylebox_override("normal", style_n)
	var style_h = StyleBoxFlat.new()
	style_h.bg_color = Color(0.3, 0.25, 0.15, 0.95)
	style_h.corner_radius_top_left = 4
	style_h.corner_radius_top_right = 4
	style_h.corner_radius_bottom_right = 4
	style_h.corner_radius_bottom_left = 4
	btn.add_theme_stylebox_override("hover", style_h)
	btn.add_theme_stylebox_override("pressed", style_h)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	btn.pressed.connect(_on_option.bind(label))
	_vbox.add_child(btn)


func _on_option(option: String) -> void:
	visible = false
	option_selected.emit(option, _npc)
