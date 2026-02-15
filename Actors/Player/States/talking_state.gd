extends State
## Player Talking state — interacting with a friendly NPC.

var player: Node3D = null
var _target: Node3D = null


func on_enter(msg: Dictionary = {}) -> void:
	if player == null:
		player = owner
	_target = msg.get("target", null)
	if _target == null:
		FileLogger.log_msg("Talking: no target, -> Idle")
		state_machine.transition_to("Idle")
		return
	# Stop movement
	player.velocity = Vector3.ZERO
	player.is_moving = false
	# Face the NPC
	var look_pos = _target.global_position
	look_pos.y = player.global_position.y
	if look_pos.distance_to(player.global_position) > 0.01:
		player.look_at(look_pos, Vector3.UP)
	# Tell HUD to open dialogue or shop
	var npc_name = _target.get("display_name")
	if npc_name == null:
		npc_name = _target.name
	FileLogger.log_msg("State -> Talking to %s" % npc_name)
	var is_merchant = _target.call("is_merchant")
	if is_merchant:
		var stock = _target.call("get_shop_stock")
		FileLogger.log_msg("Talking: opening shop for %s (%d items)" % [npc_name, stock.size() if stock else 0])
		player.call("open_shop", npc_name, stock)
	else:
		var lines = _target.call("get_dialogue")
		if lines == null or lines.size() == 0:
			lines = ["..."]
		FileLogger.log_msg("Talking: opening dialogue for %s (%d lines)" % [npc_name, lines.size()])
		player.call("open_dialogue", npc_name, lines)


func on_exit() -> void:
	_target = null


func on_physics_update(_delta: float) -> void:
	pass
