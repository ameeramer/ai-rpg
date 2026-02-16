extends State
## Player Dead state — shows death message and respawns after a delay.

var player: Node3D = null

var _respawn_ticks: int = 0
var RESPAWN_DELAY_TICKS: int = 5  # ~3 seconds

var _tick_connected: bool = false
var _original_colors: Array = []


func on_enter(_msg: Dictionary = {}) -> void:
	# 1. Ensure we have the player reference
	if player == null:
		player = owner as Node3D
	
	# 2. Safety Break: If player is still null or invalid, stop to prevent "Nil" crash
	if not is_instance_valid(player):
		push_error("Dead State Error: 'player' is null or invalid. Check Scene Tree hierarchy.")
		return

	FileLogger.log_msg("State -> Dead")
	
	# Safely access player properties
	player.is_moving = false
	if "velocity" in player:
		player.velocity = Vector3.ZERO

	# Disable collision so enemies stop targeting
	# Note: Ensure layer 2 is actually your 'Player' collision layer
	player.set_collision_layer_value(2, false)

	# Make player semi-transparent — handle multi-mesh model
	_original_colors.clear()
	
	# Ensure player.model exists before looping
	if "model" in player and player.model:
		for child in player.model.get_children():
			if child is MeshInstance3D and child.material_override is StandardMaterial3D:
				var mat = child.material_override
				_original_colors.append({"mat": mat, "color": mat.albedo_color})
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.3

	# Start respawn timer
	_respawn_ticks = RESPAWN_DELAY_TICKS
	
	# Check if GameManager exists and isn't already connected
	if GameManager.has_signal("game_tick") and not _tick_connected:
		GameManager.game_tick.connect(_on_game_tick)
		_tick_connected = true

	GameManager.log_action("You will respawn in a few seconds...")


func on_exit() -> void:
	# Disconnect signal safely
	if _tick_connected and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
		_tick_connected = false

	# Return if player was deleted during death (unlikely but safe)
	if not is_instance_valid(player):
		return

	# Re-enable collision
	player.set_collision_layer_value(2, true)

	# Restore opacity and original colors
	for entry in _original_colors:
		var mat = entry["mat"]
		if is_instance_valid(mat):
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color = entry["color"]
	_original_colors.clear()


func on_physics_update(_delta: float) -> void:
	# Dead player does nothing
	pass


func _on_game_tick(_tick) -> void:
	_respawn_ticks -= 1
	if _respawn_ticks <= 0:
		_respawn()


func _respawn() -> void:
	if is_instance_valid(player):
		player.hitpoints = player.max_hitpoints
		player.global_position = Vector3(2, 0, 2)
		GameManager.log_action("You respawn.")
	
	if state_machine:
		state_machine.transition_to("Idle")
