extends VBoxContainer
## SaveMenuUI — Save/Load/Export/Import game state panel.
## Instantiated as PackedScene in SaveMenuOverlay via HUD.

var _status_label: Label
var _export_label: Label
var _import_field: TextEdit
var _import_status: Label
var _api_key_field: LineEdit
var _api_status: Label
var _scale_buttons: Dictionary = {}
var _initialized: bool = false


func _ready() -> void:
	FileLogger.log_msg("SaveMenuUI._ready()")


func setup() -> void:
	if _initialized:
		return
	_initialized = true
	_build_ui()
	_update_status()


func _build_ui() -> void:
	_status_label = _make_label("Checking save...")
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	add_child(_status_label)
	# Save/Load row
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 12)
	add_child(row1)
	var save_btn = _make_button("Save Game")
	save_btn.pressed.connect(_on_save_pressed)
	row1.add_child(save_btn)
	var load_btn = _make_button("Load Game")
	load_btn.pressed.connect(_on_load_pressed)
	row1.add_child(load_btn)
	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 16)
	add_child(sep)
	# Transfer section header
	var transfer_label = _make_label("Transfer Save Data")
	transfer_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	add_child(transfer_label)
	# Export
	var export_btn = _make_button("Export Code")
	export_btn.pressed.connect(_on_export_pressed)
	add_child(export_btn)
	_export_label = _make_label("Tap Export to generate a code.")
	_export_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_export_label.custom_minimum_size.y = 60
	_export_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	_export_label.add_theme_font_size_override("font_size", 27)
	add_child(_export_label)
	# Import section
	var import_hint = _make_label("Paste code below:")
	add_child(import_hint)
	_import_field = TextEdit.new()
	_import_field.custom_minimum_size = Vector2(0, 150)
	_import_field.add_theme_font_size_override("font_size", 27)
	_import_field.placeholder_text = "Paste save code here..."
	var te_style = StyleBoxFlat.new()
	te_style.bg_color = Color(0.08, 0.07, 0.05, 0.95)
	te_style.border_width_left = 1
	te_style.border_width_top = 1
	te_style.border_width_right = 1
	te_style.border_width_bottom = 1
	te_style.border_color = Color(0.4, 0.35, 0.25)
	te_style.corner_radius_top_left = 4
	te_style.corner_radius_top_right = 4
	te_style.corner_radius_bottom_right = 4
	te_style.corner_radius_bottom_left = 4
	_import_field.add_theme_stylebox_override("normal", te_style)
	add_child(_import_field)
	var import_btn = _make_button("Import Code")
	import_btn.pressed.connect(_on_import_pressed)
	add_child(import_btn)
	_import_status = _make_label("")
	_import_status.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	add_child(_import_status)
	# AI NPC API Key section
	var ai_sep = HSeparator.new()
	ai_sep.add_theme_constant_override("separation", 16)
	add_child(ai_sep)
	var ai_header = _make_label("AI NPC Settings")
	ai_header.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	add_child(ai_header)
	var key_hint = _make_label("Anthropic API Key:")
	key_hint.add_theme_font_size_override("font_size", 27)
	add_child(key_hint)
	_api_key_field = LineEdit.new()
	_api_key_field.custom_minimum_size = Vector2(0, 72)
	_api_key_field.add_theme_font_size_override("font_size", 27)
	_api_key_field.placeholder_text = "sk-ant-..."
	_api_key_field.secret = true
	add_child(_api_key_field)
	var api_btn = _make_button("Save API Key")
	api_btn.custom_minimum_size = Vector2(255, 84)
	api_btn.add_theme_font_size_override("font_size", 33)
	api_btn.pressed.connect(_on_api_key_save)
	add_child(api_btn)
	_api_status = _make_label("")
	_api_status.add_theme_font_size_override("font_size", 27)
	_api_status.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	add_child(_api_status)
	_update_api_status()
	# UI Scale section
	var scale_sep = HSeparator.new()
	scale_sep.add_theme_constant_override("separation", 16)
	add_child(scale_sep)
	var scale_header = _make_label("UI Scale")
	scale_header.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	add_child(scale_header)
	var scale_row = HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 8)
	add_child(scale_row)
	var scale_options = ["large", "medium", "small", "tiny"]
	var scale_labels = {"large": "Large", "medium": "Medium", "small": "Small", "tiny": "Tiny"}
	for key in scale_options:
		var btn = Button.new()
		btn.text = scale_labels[key]
		btn.custom_minimum_size = Vector2(180, 84)
		btn.add_theme_font_size_override("font_size", 33)
		btn.pressed.connect(_on_scale_pressed.bind(key))
		scale_row.add_child(btn)
		_scale_buttons[key] = btn
	_refresh_scale_buttons()


func _make_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(255, 108)
	btn.add_theme_font_size_override("font_size", 39)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.15, 0.1, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.42, 0.28, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	btn.add_theme_stylebox_override("normal", style)
	return btn


func _make_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 33)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	return lbl


func _on_save_pressed() -> void:
	var result = SaveManager.call("save_game")
	if result:
		GameManager.log_action("Game saved!")
		_status_label.text = "Game saved successfully."
	else:
		_status_label.text = "Save failed!"


func _on_load_pressed() -> void:
	var result = SaveManager.call("load_game")
	if result:
		GameManager.log_action("Game loaded!")
		_status_label.text = "Game loaded successfully."
	else:
		_status_label.text = "No save file found."


func _on_export_pressed() -> void:
	var code = SaveManager.call("export_save_string")
	if code and str(code) != "":
		_export_label.text = str(code)
		DisplayServer.clipboard_set(str(code))
		_import_status.text = "Code copied to clipboard!"
		GameManager.log_action("Save code copied to clipboard!")
	else:
		_export_label.text = "Export failed."


func _on_import_pressed() -> void:
	var code = _import_field.text.strip_edges()
	if code == "":
		_import_status.text = "Paste a code first."
		return
	var result = SaveManager.call("import_save_string", code)
	if result:
		_import_status.text = "Import successful!"
		GameManager.log_action("Save imported successfully!")
		_update_status()
	else:
		_import_status.text = "Invalid code. Check and try again."


func _update_status() -> void:
	var has_save = SaveManager.call("has_save_file")
	if has_save:
		_status_label.text = "Save file exists."
	else:
		_status_label.text = "No save file yet."


func _on_api_key_save() -> void:
	var key = _api_key_field.text.strip_edges()
	if key == "":
		_api_status.text = "Please enter an API key."
		return
	AiNpcManager.call("set_api_key", key)
	_api_key_field.text = ""
	_api_status.text = "API key saved!"
	GameManager.log_action("AI NPC API key updated.")


func _update_api_status() -> void:
	var has_key = AiNpcManager.call("has_api_key")
	if has_key:
		_api_status.text = "API key is set. AI NPC is active."
	else:
		_api_status.text = "No API key set. AI NPC uses random behavior."


func _on_scale_pressed(key: String) -> void:
	GameManager.call("set_ui_scale", key)
	_refresh_scale_buttons()


func _refresh_scale_buttons() -> void:
	var current = GameManager.get("ui_scale")
	if current == null:
		current = "large"
	for key in _scale_buttons:
		var btn = _scale_buttons[key]
		var active = (key == current)
		var s = StyleBoxFlat.new()
		s.set_corner_radius_all(8)
		s.set_border_width_all(2)
		if active:
			s.bg_color = Color(0.3, 0.25, 0.4, 0.95)
			s.border_color = Color(0.8, 0.7, 1.0, 1)
		else:
			s.bg_color = Color(0.18, 0.15, 0.1, 0.95)
			s.border_color = Color(0.5, 0.42, 0.28, 1)
		btn.add_theme_stylebox_override("normal", s)
