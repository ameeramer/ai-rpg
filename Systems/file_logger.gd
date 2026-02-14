extends Node
## FileLogger — Writes all print output and game logs to a file on disk.
## On Android the log file is at: Android/data/com.airpg.game/files/logs/game.log
## Access via file manager or adb: adb pull /sdcard/Android/data/com.airpg.game/files/logs/game.log

const MAX_LOG_SIZE: int = 1048576  # 1 MB max before rotating
const LOG_DIR: String = "user://logs"
const LOG_FILE: String = "user://logs/game.log"
const OLD_LOG_FILE: String = "user://logs/game.old.log"

var _file: FileAccess
var _start_time_ms: int


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_time_ms = Time.get_ticks_msec()

	# Ensure log directory exists
	DirAccess.make_dir_recursive_absolute(LOG_DIR)

	# Rotate old log if it's too large
	if FileAccess.file_exists(LOG_FILE):
		var size := FileAccess.get_file_as_bytes(LOG_FILE).size()
		if size > MAX_LOG_SIZE:
			DirAccess.rename_absolute(LOG_FILE, OLD_LOG_FILE)

	# Open log file for appending
	_file = FileAccess.open(LOG_FILE, FileAccess.READ_WRITE)
	if _file == null:
		_file = FileAccess.open(LOG_FILE, FileAccess.WRITE)
	else:
		_file.seek_end()

	if _file == null:
		push_error("FileLogger: Could not open log file: %s" % LOG_FILE)
		return

	# Write session header
	var datetime := Time.get_datetime_dict_from_system()
	var header := "\n=== Session Start: %04d-%02d-%02d %02d:%02d:%02d ===" % [
		datetime["year"], datetime["month"], datetime["day"],
		datetime["hour"], datetime["minute"], datetime["second"]
	]
	_write_line(header)
	_write_line("OS: %s" % OS.get_name())
	_write_line("Model: %s" % OS.get_model_name())
	_write_line("Renderer: %s" % RenderingServer.get_video_adapter_name())
	_write_line("Godot: %s" % Engine.get_version_info().get("string", "unknown"))
	_write_line("Log path: %s" % ProjectSettings.globalize_path(LOG_FILE))
	_write_line("")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _file:
			_write_line("=== Session End ===\n")
			_file.flush()
			_file = null


func log_msg(message: String) -> void:
	_write_line("[LOG] %s" % message)


func log_error(message: String) -> void:
	_write_line("[ERROR] %s" % message)
	push_error(message)


func log_warning(message: String) -> void:
	_write_line("[WARN] %s" % message)
	push_warning(message)


func _write_line(text: String) -> void:
	if _file == null:
		return
	var elapsed_s := (Time.get_ticks_msec() - _start_time_ms) / 1000.0
	var line := "[%8.2f] %s" % [elapsed_s, text]
	_file.store_line(line)
	_file.flush()
