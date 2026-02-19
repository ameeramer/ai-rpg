extends Node
## GameManager — Global singleton for game state, tick system, and save/load.

## Game tick interval in seconds (OSRS = 0.6s)
const TICK_INTERVAL: float = 0.6

## Emitted every game tick (0.6s)
signal game_tick(tick_count)

## Emitted when game is paused/resumed
signal game_paused(is_paused)

## Emitted when an action message should be logged
signal action_logged(message)

var tick_count: int = 0
var is_paused: bool = false
var ui_scale: String = "large"

var UI_SCALE_MAP = {
	"large": Vector2i(1280, 720),
	"medium": Vector2i(1600, 900),
	"small": Vector2i(1920, 1080),
	"tiny": Vector2i(2560, 1440)
}

var _tick_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_default_scale()
	FileLogger.log_msg("GameManager ready")


func _apply_default_scale() -> void:
	var platform = OS.get_name()
	if platform == "Android" or platform == "iOS":
		ui_scale = "large"
	else:
		ui_scale = "small"
	apply_ui_scale()


func set_ui_scale(key: String) -> void:
	if not UI_SCALE_MAP.has(key):
		return
	ui_scale = key
	apply_ui_scale()


func apply_ui_scale() -> void:
	var size = UI_SCALE_MAP.get(ui_scale, Vector2i(1280, 720))
	get_tree().root.content_scale_size = size
	FileLogger.log_msg("UI scale set to '%s' (%dx%d)" % [ui_scale, size.x, size.y])


func _process(delta: float) -> void:
	if is_paused:
		return

	_tick_timer += delta
	while _tick_timer >= TICK_INTERVAL:
		_tick_timer -= TICK_INTERVAL
		tick_count += 1
		game_tick.emit(tick_count)


func pause_game() -> void:
	is_paused = true
	get_tree().paused = true
	game_paused.emit(true)


func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	game_paused.emit(false)


func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()


func log_action(message: String) -> void:
	action_logged.emit(message)
	FileLogger.log_msg(message)
	print("[Action] ", message)


## Convert real seconds to game ticks
func seconds_to_ticks(seconds: float) -> int:
	return int(ceil(seconds / TICK_INTERVAL))


## Convert game ticks to real seconds
func ticks_to_seconds(ticks: int) -> float:
	return ticks * TICK_INTERVAL


func serialize() -> Dictionary:
	return {"tick_count": tick_count, "ui_scale": ui_scale}


func deserialize(data: Dictionary) -> void:
	var tc = data.get("tick_count")
	if tc != null:
		tick_count = int(tc)
	var saved_scale = data.get("ui_scale")
	if saved_scale != null and UI_SCALE_MAP.has(saved_scale):
		ui_scale = saved_scale
		apply_ui_scale()
	FileLogger.log_msg("GameManager: deserialized, tick_count=%d, ui_scale=%s" % [tick_count, ui_scale])
