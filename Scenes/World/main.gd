extends Node3D
## Main game scene — sets up the world, player, camera, and UI.

@onready var player: Node3D = $Player
@onready var camera_controller: Node3D = $CameraController
@onready var hud: Node = $HUD
@onready var ai_npc: Node3D = $AiNpc


func _ready() -> void:
	FileLogger.log_msg("Main._ready() start")

	camera_controller.set("target", player)
	FileLogger.log_msg("Camera target set")

	# Force-initialize the player — _ready() may not fire on Android
	var init_val = player.get("_initialized")
	FileLogger.log_msg("Main: player _initialized = %s" % str(init_val))
	if init_val == false:
		player.call("ensure_initialized")
		FileLogger.log_msg("Main: player initialized via ensure_initialized()")
	elif init_val == null:
		FileLogger.log_msg("Main: WARNING — player script did NOT parse, cannot init")

	# Force-initialize all enemies and interactables
	_force_initialize_objects()

	# Auto-ground model containers using mesh AABB data
	_ground_all_models()

	# HUD setup — passes player ref; HUD handles its own UI children
	hud.call("setup", player)
	FileLogger.log_msg("HUD setup done")

	# Give SaveManager a direct player ref (avoids group lookup on Android)
	SaveManager.call("set_player", player)

	# Initialize AI NPC with player ref and world objects
	_setup_ai_npc()

	# Give SaveManager a direct AI NPC ref for save/load
	if ai_npc:
		SaveManager.call("set_ai_npc", ai_npc)

	# Auto-load save if one exists
	var has_save = SaveManager.call("has_save_file")
	if has_save:
		FileLogger.log_msg("Main: save file found, loading...")
		SaveManager.call("load_game")
		FileLogger.log_msg("Main: save loaded")
	else:
		FileLogger.log_msg("Main: no save file, starting fresh")

	FileLogger.log_msg("Main._ready() complete")
	GameManager.log_action("Welcome to AI RPG! Tap to move, tap objects to interact.")


func _setup_ai_npc() -> void:
	if ai_npc == null:
		FileLogger.log_msg("Main: AI NPC not found")
		return
	var ai_init = ai_npc.get("_initialized")
	if ai_init == false:
		ai_npc.call("ensure_initialized")
	elif ai_init == null:
		FileLogger.log_msg("Main: WARNING — AI NPC script did NOT parse")
		return
	ai_npc.call("set_player_ref", player)
	# Connect AI NPC approach signals to HUD
	var chat_sig = ai_npc.get("request_chat")
	if chat_sig:
		ai_npc.request_chat.connect(_on_ai_npc_chat)
	var trade_sig = ai_npc.get("request_trade")
	if trade_sig:
		ai_npc.request_trade.connect(_on_ai_npc_trade)
	# Force-init Actions child
	var actions = ai_npc.get_node_or_null("Actions")
	if actions:
		var act_init = actions.get("_initialized")
		if act_init == false:
			actions.call("ensure_initialized")
	# Pass world objects to brain
	var brain = ai_npc.get_node_or_null("Brain")
	if brain:
		var brain_init = brain.get("_initialized")
		if brain_init == false:
			brain.call("ensure_initialized")
		brain.call("set_player", player)
		var world_objects = _collect_world_objects()
		brain.call("set_world_objects", world_objects)
	FileLogger.log_msg("Main: AI NPC setup done")


func _on_ai_npc_chat(npc) -> void:
	hud.call("show_ai_chat", npc)


func _on_ai_npc_trade(npc) -> void:
	hud.call("show_ai_trade", npc)


func _collect_world_objects() -> Array:
	var objects: Array = []
	var all_nodes = _get_all_descendants(self)
	for node in all_nodes:
		var layer = node.get("collision_layer")
		if layer == null:
			continue
		if layer == 4 or layer == 8 or layer == 16:
			if node == ai_npc:
				continue
			objects.append(node)
	return objects


func _force_initialize_objects() -> void:
	var enemies_count: int = 0
	var interactables_count: int = 0

	var all_nodes = _get_all_descendants(self)
	FileLogger.log_msg("Main: walking %d descendant nodes" % all_nodes.size())
	for node in all_nodes:
		var layer = node.get("collision_layer")
		if layer == null:
			continue
		# Check if node's script parsed (has _initialized property)
		var init_check = node.get("_initialized")
		if layer == 4:
			if init_check != null:
				node.call("ensure_initialized")
			enemies_count += 1
		elif layer == 8 or layer == 16:
			if init_check != null:
				node.call("ensure_initialized")
			interactables_count += 1

	FileLogger.log_msg("Force-initialized %d enemies, %d objects" % [enemies_count, interactables_count])


func _get_all_descendants(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_descendants(child))
	return result


func _ground_all_models() -> void:
	var names = ["Model", "EnemyMesh", "NPCMesh", "ActiveMesh", "DepletedMesh"]
	for node in _get_all_descendants(self):
		if not (node is Node3D) or not names.has(node.name):
			continue
		var target = 0.0
		var par = node.get_parent()
		if par:
			var key = "model_height"
			if node.name == "DepletedMesh":
				key = "depleted_model_height"
			var mh = par.get(key)
			if mh != null and mh > 0:
				target = mh
		_ground_model(node, target)


func _ground_model(container: Node3D, target_h: float) -> void:
	var min_y = INF
	var max_y = -INF
	var inv = container.global_transform.affine_inverse()
	for mi in _find_mesh_instances(container):
		var aabb = mi.get_aabb()
		if aabb.size == Vector3.ZERO:
			continue
		var t = inv * mi.global_transform
		var p = aabb.position
		var e = aabb.position + aabb.size
		for corner in [t * Vector3(p.x, p.y, p.z), t * Vector3(e.x, p.y, p.z),
			t * Vector3(p.x, e.y, p.z), t * Vector3(e.x, e.y, p.z),
			t * Vector3(p.x, p.y, e.z), t * Vector3(e.x, p.y, e.z),
			t * Vector3(p.x, e.y, e.z), t * Vector3(e.x, e.y, e.z)]:
			if corner.y < min_y:
				min_y = corner.y
			if corner.y > max_y:
				max_y = corner.y
	if min_y >= INF:
		return
	var sf = 1.0
	if target_h > 0.0 and (max_y - min_y) > 0.001:
		sf = target_h / (max_y - min_y)
		container.scale = Vector3(sf, sf, sf)
	if abs(min_y * sf) > 0.001:
		container.position.y = -min_y * sf


func _find_mesh_instances(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
		result.append_array(_find_mesh_instances(child))
	return result
