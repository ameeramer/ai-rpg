extends Node
## GameManager — Global singleton for game state, tick system, and save/load.

## Game tick interval in seconds (OSRS = 0.6s)
const TICK_INTERVAL: float = 0.6

## Emitted every game tick (0.6s)
signal game_tick(tick_count: int)

## Emitted when game is paused/resumed
signal game_paused(is_paused: bool)

## Emitted when an action message should be logged
signal action_logged(message: String)

var tick_count: int = 0
var is_paused: bool = false

var _tick_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


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
	print("[Action] ", message)


## Convert real seconds to game ticks
func seconds_to_ticks(seconds: float) -> int:
	return int(ceil(seconds / TICK_INTERVAL))


## Convert game ticks to real seconds
func ticks_to_seconds(ticks: int) -> float:
	return ticks * TICK_INTERVAL
