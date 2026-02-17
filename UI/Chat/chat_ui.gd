extends PanelContainer
## Chat UI — full conversation with AI NPC using Claude API.

signal chat_closed()

var _npc_ref: Node3D = null
var _npc_name: String = ""
var _messages: Array = []
var _scroll: ScrollContainer
var _msg_container: VBoxContainer
var _input_field: LineEdit
var _send_btn: Button
var _close_btn: Button
var _title_label: Label
var _waiting: bool = false


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	style.set_border_width_all(3)
	style.border_color = Color(0.4, 0.5, 0.7, 1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	# Header
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(header)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	_title_label.add_theme_font_size_override("font_size", 36)
	header.add_child(_title_label)
	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.custom_minimum_size = Vector2(72, 60)
	_close_btn.add_theme_font_size_override("font_size", 36)
	_close_btn.pressed.connect(_on_close)
	header.add_child(_close_btn)
	# Messages scroll
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, 300)
	vbox.add_child(_scroll)
	_msg_container = VBoxContainer.new()
	_msg_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg_container.add_theme_constant_override("separation", 6)
	_scroll.add_child(_msg_container)
	# Input row
	var input_row = HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	vbox.add_child(input_row)
	_input_field = LineEdit.new()
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_field.custom_minimum_size = Vector2(0, 60)
	_input_field.placeholder_text = "Type a message..."
	_input_field.add_theme_font_size_override("font_size", 28)
	_input_field.text_submitted.connect(_on_send_text)
	input_row.add_child(_input_field)
	_send_btn = Button.new()
	_send_btn.text = "Send"
	_send_btn.custom_minimum_size = Vector2(120, 60)
	_send_btn.add_theme_font_size_override("font_size", 28)
	_send_btn.pressed.connect(_on_send)
	input_row.add_child(_send_btn)


func open_chat(npc_name: String, npc: Node3D) -> void:
	# Only reset if different NPC or first open
	var same_npc = (_npc_ref == npc and _messages.size() > 0)
	_npc_name = npc_name
	_npc_ref = npc
	_title_label.text = "Chat with " + npc_name
	_waiting = false
	_send_btn.disabled = false
	if not same_npc:
		_messages.clear()
		_clear_messages()
		_add_msg_bubble(npc_name, "Hello! What would you like to talk about?", false)
	visible = true
	_input_field.grab_focus()
	await get_tree().process_frame
	_scroll.scroll_vertical = 999999


func _on_send() -> void:
	var text = _input_field.text.strip_edges()
	if text == "" or _waiting:
		return
	_input_field.text = ""
	_add_msg_bubble("You", text, true)
	_messages.append({"role": "user", "content": text})
	_waiting = true
	_send_btn.disabled = true
	# Tell the brain what the player said so it can act on it
	if _npc_ref:
		var brain = _npc_ref.get_node_or_null("Brain")
		if brain:
			brain.call("set_player_request", text)
	var sys = _build_chat_system()
	AiNpcManager.call("send_chat_request", sys, _messages, Callable(self, "_on_chat_response"))


func _on_send_text(_text: String) -> void:
	_on_send()


func _build_chat_system() -> String:
	var skills = ""
	if _npc_ref:
		var ns = _npc_ref.get("npc_skills")
		if ns:
			for s in ns:
				skills += "%s:%d " % [s, ns[s]["level"]]
	return "You are %s, an AI companion in an OSRS-style RPG. You are friendly, helpful, and talk like an adventurer. Your skills: %s. Keep responses short (1-3 sentences). You can discuss strategy, offer to trade items, or just chat." % [_npc_name, skills]


func _on_chat_response(text: String) -> void:
	_waiting = false
	_send_btn.disabled = false
	if text == "":
		text = "Hmm, I'm not sure what to say..."
	_messages.append({"role": "assistant", "content": text})
	_add_msg_bubble(_npc_name, text, false)


func _add_msg_bubble(sender: String, text: String, is_player: bool) -> void:
	var panel = PanelContainer.new()
	var ps = StyleBoxFlat.new()
	if is_player:
		ps.bg_color = Color(0.15, 0.2, 0.3, 0.9)
	else:
		ps.bg_color = Color(0.2, 0.15, 0.1, 0.9)
	ps.set_corner_radius_all(8)
	ps.content_margin_left = 12
	ps.content_margin_right = 12
	ps.content_margin_top = 8
	ps.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", ps)
	var vb = VBoxContainer.new()
	panel.add_child(vb)
	var name_lbl = Label.new()
	name_lbl.text = sender
	name_lbl.add_theme_font_size_override("font_size", 22)
	if is_player:
		name_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	else:
		name_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	vb.add_child(name_lbl)
	var msg_lbl = RichTextLabel.new()
	msg_lbl.bbcode_enabled = false
	msg_lbl.text = text
	msg_lbl.fit_content = true
	msg_lbl.scroll_active = false
	msg_lbl.add_theme_font_size_override("normal_font_size", 26)
	msg_lbl.add_theme_color_override("default_color", Color(0.9, 0.85, 0.7))
	vb.add_child(msg_lbl)
	_msg_container.add_child(panel)
	await get_tree().process_frame
	_scroll.scroll_vertical = 999999


func _clear_messages() -> void:
	for child in _msg_container.get_children():
		child.queue_free()


func _on_close() -> void:
	visible = false
	chat_closed.emit()


func setup() -> void:
	pass
