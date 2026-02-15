extends PanelContainer
## Full-screen overlay that displays all FileLogger logs with a copy button.
## NO class_name — instantiated via PackedScene on Android.

var _text_edit: TextEdit
var _copy_btn: Button
var _close_btn: Button
var _status_label: Label


func _ready() -> void:
	# Semi-transparent dark background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Debug Logs"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_status_label)

	_copy_btn = Button.new()
	_copy_btn.text = "Copy All"
	_copy_btn.custom_minimum_size = Vector2(140, 56)
	_copy_btn.pressed.connect(_on_copy_pressed)
	header.add_child(_copy_btn)

	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(120, 56)
	_close_btn.pressed.connect(_on_close_pressed)
	header.add_child(_close_btn)

	# Log text area
	_text_edit = TextEdit.new()
	_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_edit.editable = false
	_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	var font_size = 18
	_text_edit.add_theme_font_size_override("font_size", font_size)
	vbox.add_child(_text_edit)

	_load_logs()


func _load_logs() -> void:
	var log_text := ""

	# Read the log file
	var file := FileAccess.open("user://logs/game.log", FileAccess.READ)
	if file:
		log_text = file.get_as_text()
		file = null
	else:
		log_text = "(Could not open log file at user://logs/game.log)\n"
		log_text += "Error: %s\n" % str(FileAccess.get_open_error())

	# Append current in-memory info
	log_text += "\n--- Live Info ---\n"
	log_text += "OS: %s\n" % OS.get_name()
	log_text += "Model: %s\n" % OS.get_model_name()
	log_text += "GPU: %s\n" % RenderingServer.get_video_adapter_name()
	log_text += "Vendor: %s\n" % RenderingServer.get_video_adapter_vendor()
	log_text += "Renderer: %s\n" % str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))
	log_text += "Godot: %s\n" % Engine.get_version_info().get("string", "unknown")
	log_text += "FPS: %d\n" % Engine.get_frames_per_second()
	log_text += "User dir: %s\n" % OS.get_user_data_dir()

	_text_edit.text = log_text
	# Scroll to bottom
	_text_edit.set_caret_line(_text_edit.get_line_count() - 1)


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_text_edit.text)
	_status_label.text = "Copied!"
	# Clear status after 2 seconds
	get_tree().create_timer(2.0).timeout.connect(func(): _status_label.text = "")


func _on_close_pressed() -> void:
	visible = false
