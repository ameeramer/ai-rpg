extends StaticBody3D
## Bank booth — click to open bank UI.

@export var display_name: String = "Bank booth"
@export var interaction_verb: String = "Use"

var _is_depleted: bool = false
var is_active: bool = true
var _initialized: bool = false

func _ready() -> void:
	ensure_initialized()

func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

func interact(player) -> bool:
	player.call("open_bank")
	return false

func interaction_tick(player):
	return null

func stop_interaction(player) -> void:
	pass
