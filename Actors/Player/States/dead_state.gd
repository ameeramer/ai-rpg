extends State
## Player Dead state — shows death message and respawns after a delay.

@onready var player: PlayerController = owner as PlayerController

var _respawn_ticks: int = 0
const RESPAWN_DELAY_TICKS: int = 5  # ~3 seconds

var _tick_connected: bool = false


func on_enter(_msg: Dictionary = {}) -> void:
	FileLogger.log_msg("State -> Dead")
	player.is_moving = false
	player.velocity = Vector3.ZERO

	# Disable collision so enemies stop targeting
	player.set_collision_layer_value(2, false)

	# Make player semi-transparent
	var mesh := player.model.get_node_or_null("PlayerMesh") as MeshInstance3D
	if mesh and mesh.material_override:
		var mat: StandardMaterial3D = mesh.material_override
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.3

	# Start respawn timer
	_respawn_ticks = RESPAWN_DELAY_TICKS
	GameManager.game_tick.connect(_on_game_tick)
	_tick_connected = true

	GameManager.log_action("You will respawn in a few seconds...")


func on_exit() -> void:
	if _tick_connected and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
		_tick_connected = false

	# Re-enable collision
	player.set_collision_layer_value(2, true)

	# Restore opacity
	var mesh := player.model.get_node_or_null("PlayerMesh") as MeshInstance3D
	if mesh and mesh.material_override:
		var mat: StandardMaterial3D = mesh.material_override
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.albedo_color = Color(0.2, 0.4, 0.85, 1.0)


func on_physics_update(_delta: float) -> void:
	# Dead player does nothing
	pass


func _on_game_tick(_tick: int) -> void:
	_respawn_ticks -= 1
	if _respawn_ticks <= 0:
		_respawn()


func _respawn() -> void:
	player.hitpoints = player.max_hitpoints
	player.global_position = Vector3(2, 1, 2)
	GameManager.log_action("You respawn.")
	state_machine.transition_to("Idle")
