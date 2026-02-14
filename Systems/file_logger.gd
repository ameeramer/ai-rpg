extends Node
## FileLogger — Writes all print output and game logs to a file on disk.
## On Android the log file is at the app's internal storage.
## Access via: adb shell run-as com.airpg.game cat files/logs/game.log
## Or connect via USB and use a file manager to browse app data.

const MAX_LOG_SIZE: int = 1048576  # 1 MB max before rotating
const LOG_DIR: String = "user://logs"
const LOG_FILE: String = "user://logs/game.log"
const OLD_LOG_FILE: String = "user://logs/game.old.log"

var _file: FileAccess
var _start_time_ms: int


func _init() -> void:
	# Write log as early as possible — _init runs before _ready
	_start_time_ms = Time.get_ticks_msec()
	_open_log_file()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_write_line("[LOG] FileLogger._ready() — autoload initialized")


func _open_log_file() -> void:
	# Ensure log directory exists
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("logs"):
		dir.make_dir("logs")

	# Rotate old log if it's too large
	if FileAccess.file_exists(LOG_FILE):
		var existing := FileAccess.open(LOG_FILE, FileAccess.READ)
		if existing:
			var size := existing.get_length()
			existing = null  # close
			if size > MAX_LOG_SIZE:
				if FileAccess.file_exists(OLD_LOG_FILE):
					DirAccess.remove_absolute(OLD_LOG_FILE)
				DirAccess.rename_absolute(LOG_FILE, OLD_LOG_FILE)

	# Open log file for appending
	if FileAccess.file_exists(LOG_FILE):
		_file = FileAccess.open(LOG_FILE, FileAccess.READ_WRITE)
		if _file:
			_file.seek_end()
	else:
		_file = FileAccess.open(LOG_FILE, FileAccess.WRITE)

	if _file == null:
		push_error("FileLogger: Could not open log file at %s (error: %s)" % [LOG_FILE, str(FileAccess.get_open_error())])
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
	_write_line("Locale: %s" % OS.get_locale())
	_write_line("Processors: %s" % str(OS.get_processor_count()))
	_write_line("Video adapter: %s" % RenderingServer.get_video_adapter_name())
	_write_line("Video vendor: %s" % RenderingServer.get_video_adapter_vendor())
	_write_line("Rendering method: %s" % str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")))
	_write_line("Godot version: %s" % Engine.get_version_info().get("string", "unknown"))
	_write_line("User data dir: %s" % OS.get_user_data_dir())
	_write_line("Log path: %s" % ProjectSettings.globalize_path(LOG_FILE))
	_write_line("Main scene: %s" % str(ProjectSettings.get_setting("application/run/main_scene", "none")))
	_write_line("")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_write_line("[LOG] App shutting down (notification: %d)" % what)
		if _file:
			_write_line("=== Session End ===\n")
			_file.flush()
			_file = null
	elif what == NOTIFICATION_CRASH:
		_write_line("[CRASH] Engine crash detected!")
		if _file:
			_file.flush()
			_file = null
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_write_line("[LOG] App paused (went to background)")
		if _file:
			_file.flush()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_write_line("[LOG] App resumed (came to foreground)")
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_write_line("[LOG] App lost focus")
		if _file:
			_file.flush()


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
