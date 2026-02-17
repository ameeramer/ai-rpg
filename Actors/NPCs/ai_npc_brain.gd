extends Node
## AI NPC Brain — Reads game state, calls Claude API, executes decisions.
## Attached as child of AiNpc. NO class_name. Under 200 lines.

var _npc: Node3D = null
var _player: Node3D = null
var _initialized: bool = false
var _decision_cooldown: int = 0
var _decision_interval: int = 15
var _last_action: String = "idle"
var _world_objects: Array = []


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_npc = get_parent()
	var sig = GameManager.get("game_tick")
	if sig:
		GameManager.game_tick.connect(_on_game_tick)
	FileLogger.log_msg("AiNpcBrain initialized")


func set_player(p: Node3D) -> void:
	_player = p


func set_world_objects(objects: Array) -> void:
	_world_objects = objects


func _on_game_tick(_tick) -> void:
	if _npc == null or _npc.get("_is_dead"):
		return
	# Don't interrupt ongoing actions — let NPC finish what it's doing
	var action = _npc.get("_current_action")
	if action == "combat" or action == "gathering":
		return
	var mgr_key = AiNpcManager.call("has_api_key")
	if not mgr_key:
		_do_fallback_action()
		return
	_decision_cooldown -= 1
	if _decision_cooldown <= 0:
		_decision_cooldown = _decision_interval
		_request_decision()


func _request_decision() -> void:
	var state = _build_game_state()
	var system = _build_system_prompt()
	AiNpcManager.call("send_brain_request", system, state, Callable(self, "_on_decision"))


func _build_system_prompt() -> String:
	return "You are an AI NPC named %s in an OSRS-style RPG. You decide what action to take next to level up your skills and become stronger. Respond with ONLY a JSON object (no markdown) with keys: \"action\" (one of: \"gather_trees\", \"gather_rocks\", \"gather_fish\", \"attack_goblins\", \"attack_skeletons\", \"idle\", \"approach_player_chat\", \"approach_player_trade\"), and \"reason\" (short explanation). Consider your current skill levels, HP, and what would be most efficient to train." % _npc.get("display_name")


func _build_game_state() -> String:
	var skills = _npc.get("npc_skills")
	var hp = _npc.get("hitpoints")
	var max_hp = _npc.get("max_hitpoints")
	var pos = _npc.global_position
	var action = _npc.get("_current_action")
	var inv_count = 0
	var inv = _npc.get("npc_inventory")
	if inv:
		inv_count = inv.size()
	var player_dist = -1.0
	if _player and is_instance_valid(_player):
		player_dist = pos.distance_to(_player.global_position)
	var skill_text = ""
	if skills:
		for s in skills:
			skill_text += "%s: Lv%d " % [s, skills[s]["level"]]
	var state = "My position: (%.0f, %.0f). " % [pos.x, pos.z]
	state += "HP: %d/%d. " % [hp, max_hp]
	state += "Current action: %s. " % str(action)
	state += "Inventory items: %d/28. " % inv_count
	state += "Last action: %s. " % _last_action
	if player_dist >= 0:
		state += "Player distance: %.0f units. " % player_dist
	state += "Skills: %s. " % skill_text
	return state


func _on_decision(response: String) -> void:
	var parsed = JSON.parse_string(response)
	if parsed == null:
		FileLogger.log_msg("AiNpcBrain: failed to parse response")
		return
	var action = parsed.get("action", "idle")
	var reason = parsed.get("reason", "")
	FileLogger.log_msg("AiNpcBrain: action=%s reason=%s" % [action, reason])
	_execute_action(action)
	_last_action = action


func _execute_action(action: String) -> void:
	if action == "gather_trees" or action == "move_to_trees":
		_find_and_gather(8)
	elif action == "gather_rocks" or action == "move_to_rocks":
		_find_and_gather(8)
	elif action == "gather_fish" or action == "move_to_fish":
		_find_and_gather(8)
	elif action == "attack_goblins" or action == "attack_skeletons":
		_find_and_attack()
	elif action == "approach_player_chat":
		_npc.call("approach_player", "chat")
	elif action == "approach_player_trade":
		_npc.call("approach_player", "trade")
	else:
		var wander = _npc.global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		_npc.call("move_to", wander)


func _find_and_gather(layer: int) -> void:
	var best = null
	var best_dist = 999.0
	for obj in _world_objects:
		if not is_instance_valid(obj):
			continue
		var ol = obj.get("collision_layer")
		if ol != layer:
			continue
		if obj.get("_is_depleted"):
			continue
		var dist = _npc.global_position.distance_to(obj.global_position)
		if dist < best_dist:
			best_dist = dist
			best = obj
	if best:
		_npc.call("gather_from", best)


func _find_and_attack() -> void:
	var best = null
	var best_dist = 999.0
	for obj in _world_objects:
		if not is_instance_valid(obj):
			continue
		var ol = obj.get("collision_layer")
		if ol != 4:
			continue
		if obj.get("_is_dead"):
			continue
		var dist = _npc.global_position.distance_to(obj.global_position)
		if dist < best_dist:
			best_dist = dist
			best = obj
	if best:
		_npc.call("attack_target", best)


func _do_fallback_action() -> void:
	_decision_cooldown -= 1
	if _decision_cooldown <= 0:
		_decision_cooldown = 20
		var actions = ["gather_trees", "gather_rocks", "attack_goblins", "idle"]
		var pick = actions[randi() % actions.size()]
		_execute_action(pick)
		_last_action = pick
