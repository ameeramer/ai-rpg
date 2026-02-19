extends VBoxContainer

var _status_label = null
var _transfer_status = null
var _api_key_field = null
var _api_status = null
var _scale_buttons = {}
var _initialized = false

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
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 12)
	add_child(row1)
	var save_btn = _make_button("Save Game")
	save_btn.pressed.connect(_on_save_pressed)
	row1.add_child(save_btn)
	var load_btn = _make_button("Load Game")
	load_btn.pressed.connect(_on_load_pressed)
	row1.add_child(load_btn)
	add_child(HSeparator.new())
	var tl = _make_label("Transfer Save Between Devices")
	tl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	add_child(tl)
	var th = _make_label("Exports to Downloads folder as airpg_save.json")
	th.add_theme_font_size_override("font_size", 27)
	th.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	add_child(th)
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	add_child(row2)
	var export_btn = _make_button("Export to File")
	export_btn.pressed.connect(_on_export_pressed)
	row2.add_child(export_btn)
	var import_btn = _make_button("Import from File")
	import_btn.pressed.connect(_on_import_pressed)
	row2.add_child(import_btn)
	_transfer_status = _make_label("")
	_transfer_status.add_theme_font_size_override("font_size", 27)
	_transfer_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_transfer_status)
	add_child(HSeparator.new())
	var ai_header = _make_label("AI NPC Settings")
	ai_header.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	add_child(ai_header)
	add_child(_make_label("Anthropic API Key:"))
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
	add_child(HSeparator.new())
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

func _make_button(text) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(255, 108)
	btn.add_theme_font_size_override("font_size", 39)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.15, 0.1, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.5, 0.42, 0.28, 1)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	return btn

func _make_label(text) -> Label:
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
	var path = SaveManager.call("export_save_file")
	if path and str(path) != "":
		_transfer_status.text = "Saved to: " + str(path)
		_transfer_status.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
		GameManager.log_action("Save exported to file!")
	else:
		_transfer_status.text = "Export failed. Check storage permissions."
		_transfer_status.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))

func _on_import_pressed() -> void:
	var result = SaveManager.call("import_save_file")
	if result == null:
		_transfer_status.text = "Import failed."
		_transfer_status.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		return
	var success = result.get("success", false)
	if success:
		_transfer_status.text = "Import successful from: " + str(result.get("path", ""))
		_transfer_status.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
		GameManager.log_action("Save imported from file!")
		_update_status()
	else:
		var err = result.get("error", "Unknown error.")
		_transfer_status.text = str(err)
		_transfer_status.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))

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

func _on_scale_pressed(key) -> void:
	GameManager.call("set_ui_scale", key)
	_refresh_scale_buttons()

func _refresh_scale_buttons() -> void:
	var current = GameManager.get("ui_scale")
	if current == null:
		current = "large"
	for key in _scale_buttons:
		var btn = _scale_buttons[key]
		var s = StyleBoxFlat.new()
		s.set_corner_radius_all(8)
		s.set_border_width_all(2)
		if key == current:
			s.bg_color = Color(0.3, 0.25, 0.4, 0.95)
			s.border_color = Color(0.8, 0.7, 1.0, 1)
		else:
			s.bg_color = Color(0.18, 0.15, 0.1, 0.95)
			s.border_color = Color(0.5, 0.42, 0.28, 1)
		btn.add_theme_stylebox_override("normal", s)
