extends Control
## Boot scene — minimal 2D scene that loads first on Android.
## Gives the GPU driver time to initialize, captures device info, then
## transitions to the 3D game scene.

@onready var status_label: Label = $StatusLabel

var _frame_count: int = 0
var _ready_done: bool = false
var _load_started: bool = false

const MAIN_SCENE: String = "res://Scenes/World/Main.tscn"
## Wait this many frames before attempting to load 3D — gives Vulkan time
const FRAMES_BEFORE_LOAD: int = 30


func _ready() -> void:
	FileLogger.log_msg("Boot._ready() — boot scene loaded successfully")
	FileLogger.log_msg("Boot: renderer = %s" % str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")))
	FileLogger.log_msg("Boot: driver = %s" % OS.get_name())
	status_label.text = "Loading AI RPG..."
	_ready_done = true


func _process(_delta: float) -> void:
	if not _ready_done:
		return

	_frame_count += 1

	if _frame_count == 5:
		FileLogger.log_msg("Boot: rendered 5 frames OK — GPU is alive")
		status_label.text = "Initializing..."

	if _frame_count == FRAMES_BEFORE_LOAD and not _load_started:
		_load_started = true
		FileLogger.log_msg("Boot: starting background load of Main.tscn")
		status_label.text = "Loading game world..."
		# Use background loading so we don't block and cause ANR
		var err := ResourceLoader.load_threaded_request(MAIN_SCENE)
		if err != OK:
			FileLogger.log_error("Boot: load_threaded_request failed: %d" % err)
			status_label.text = "Error: could not start loading (%d)" % err
			_load_started = false

	if _load_started and _frame_count > FRAMES_BEFORE_LOAD:
		var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			FileLogger.log_msg("Boot: Main.tscn loaded successfully, switching scene")
			var scene: PackedScene = ResourceLoader.load_threaded_get(MAIN_SCENE)
			if scene:
				get_tree().change_scene_to_packed(scene)
			else:
				FileLogger.log_error("Boot: loaded resource is null")
				status_label.text = "Error: scene is null"
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			FileLogger.log_error("Boot: background load of Main.tscn FAILED")
			status_label.text = "Error: failed to load game"
			_load_started = false
		elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			FileLogger.log_error("Boot: Main.tscn is not a valid resource")
			status_label.text = "Error: invalid scene"
			_load_started = false
