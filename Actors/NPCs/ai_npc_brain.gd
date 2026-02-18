extends Node
## AI NPC Brain — builds world map, sends to Claude, resolves target clicks.
## Attached as child of AiNpc. NO class_name. Under 200 lines.

var _npc = null
var _player = null
var _initialized = false
var _decision_cooldown = 0
var _decision_interval = 15
var _last_action = "idle"
var _world_objects = {}
var _chat_history = []
var _event_log = []
var _events_synced = 0
var MAX_EVENTS = 20

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
	FileLogger.log_msg("AiNpcBrain initialized (click-based)")

func set_player(p: Node3D) -> void:
	_player = p

func set_world_objects(objects: Array) -> void:
	_world_objects = {}
	for obj in objects:
		if is_instance_valid(obj):
			_world_objects[obj.name] = obj

func set_chat_history(messages: Array) -> void:
	_chat_history = messages
	_events_synced = _event_log.size()
	_decision_cooldown = min(_decision_cooldown, 2)

func log_event(text: String) -> void:
	_event_log.append(text)
	if _event_log.size() > MAX_EVENTS:
		_event_log.pop_front()
		_events_synced = max(0, _events_synced - 1)

func get_new_events() -> Array:
	var new_evts = _event_log.slice(_events_synced)
	_events_synced = _event_log.size()
	return new_evts

func _on_game_tick(_tick) -> void:
	if _npc == null or _npc.get("_is_dead"):
		return
	var action = _npc.get("_current_action")
	if action == "combat" or action == "gathering":
		return
	var mgr_key = AiNpcManager.call("has_api_key")
	if not mgr_key:
		return
	_decision_cooldown -= 1
	if _decision_cooldown <= 0:
		_decision_cooldown = _decision_interval
		_request_decision()

func _request_decision() -> void:
	var system = _build_system_prompt()
	AiNpcManager.call("send_brain_request", system, _build_game_state(), Callable(self, "_on_decision"))

func _build_system_prompt() -> String:
	var name = _npc.get("display_name")
	return "You are %s, an AI companion in an OSRS-style RPG. You see the world map and choose what to interact with, just like a player clicking on objects. Respond with ONLY a JSON object:\n- Click an object: {\"target\": \"ObjectName\", \"reason\": \"...\"}\n- Walk somewhere: {\"target\": \"walk\", \"x\": 5, \"z\": -3, \"reason\": \"...\"}\n- Talk/trade with player: {\"target\": \"player\", \"intent\": \"chat\" or \"trade\", \"reason\": \"...\"}\n- Idle/wander: {\"target\": \"idle\", \"reason\": \"...\"}\nPick objects by their exact ID from the world map. Consider distance, skill requirements, your HP, and training efficiency." % name

func _build_game_state() -> String:
	var skills = _npc.get("npc_skills")
	var hp = _npc.get("hitpoints")
	var max_hp = _npc.get("max_hitpoints")
	var pos = _npc.global_position
	var action = _npc.get("_current_action")
	var skill_text = ""
	if skills:
		for s in skills:
			skill_text += "%s:%d " % [s, skills[s]["level"]]
	var state = "Position: (%.0f,%.0f) HP: %d/%d Action: %s\n" % [pos.x, pos.z, hp, max_hp, action]
	state += "Skills: %s\n" % skill_text
	state += "Last: %s\n" % _last_action
	state += _build_world_map()
	if _event_log.size() > 0:
		state += "\nRecent events:\n"
		var start = max(0, _event_log.size() - 6)
		for i in range(start, _event_log.size()):
			state += "- %s\n" % _event_log[i]
	if _chat_history.size() > 0:
		state += "\nRecent chat with player:\n"
		var start = max(0, _chat_history.size() - 6)
		for i in range(start, _chat_history.size()):
			var msg = _chat_history[i]
			var who = "Player" if msg["role"] == "user" else "You"
			state += "%s: %s\n" % [who, msg["content"]]
	return state

func _build_world_map() -> String:
	var lines = ["\nWorld map:"]
	for obj_name in _world_objects:
		var obj = _world_objects[obj_name]
		if not is_instance_valid(obj):
			continue
		var layer = obj.get("collision_layer")
		var p = obj.global_position
		var dname = obj.get("display_name")
		if dname == null:
			dname = obj.name
		if layer == 8:
			var sk = obj.get("required_skill")
			var lv = obj.get("required_level")
			var dep = obj.get("_is_depleted")
			var st = "depleted" if dep else "available"
			var req = ""
			if sk and sk != "":
				req = " %s:%s" % [sk, str(lv) if lv else "1"]
			lines.append("[gather] %s \"%s\" at (%.0f,%.0f)%s - %s" % [obj_name, dname, p.x, p.z, req, st])
		elif layer == 4:
			if obj.get("_is_dead"):
				continue
			var ehp = obj.get("hp")
			var emhp = obj.get("max_hp")
			var clvl = obj.get("combat_level")
			lines.append("[enemy] %s \"%s\" Lv%s at (%.0f,%.0f) HP:%s/%s" % [obj_name, dname, str(clvl) if clvl else "1", p.x, p.z, str(ehp) if ehp else "?", str(emhp) if emhp else "?"])
		elif layer == 16:
			var merchant = obj.call("is_merchant")
			var tag = " merchant" if merchant else ""
			lines.append("[npc] %s \"%s\" at (%.0f,%.0f)%s" % [obj_name, dname, p.x, p.z, tag])
	if _player and is_instance_valid(_player):
		var pp = _player.global_position
		var php = _player.get("hitpoints")
		var pmhp = _player.get("max_hitpoints")
		lines.append("[player] Player at (%.0f,%.0f) HP:%s/%s" % [pp.x, pp.z, str(php) if php else "?", str(pmhp) if pmhp else "?"])
	return "\n".join(lines)

func _on_decision(response: String) -> void:
	var json_str = _extract_json(response)
	var parsed = JSON.parse_string(json_str)
	if parsed == null:
		FileLogger.log_msg("Brain: parse fail: %s" % response.substr(0, 120))
		return
	var target_id = parsed.get("target", "idle")
	var reason = parsed.get("reason", "")
	FileLogger.log_msg("Brain: target=%s reason=%s" % [target_id, reason])
	if reason != "":
		log_event("Chose to click %s: %s" % [target_id, reason])
	_resolve_and_click(target_id, parsed)
	_last_action = target_id

func _extract_json(text: String) -> String:
	if JSON.parse_string(text) != null:
		return text
	var start = text.find("{")
	var end = text.rfind("}")
	if start >= 0 and end > start:
		return text.substr(start, end - start + 1)
	return text

func _resolve_and_click(target_id: String, parsed: Dictionary) -> void:
	if target_id == "idle":
		var wander = _npc.global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		_npc.call("move_to", wander)
		return
	if target_id == "walk":
		var x = float(parsed.get("x", 0))
		var z = float(parsed.get("z", 0))
		_npc.call("move_to", Vector3(x, 0, z))
		return
	if target_id == "player":
		var intent = parsed.get("intent", "chat")
		_npc.call("approach_player", intent)
		return
	var obj = _world_objects.get(target_id)
	if obj == null or not is_instance_valid(obj):
		FileLogger.log_msg("Brain: target not found: %s" % target_id)
		return
	var layer = obj.get("collision_layer")
	if layer == 4:
		if obj.get("_is_dead"):
			return
		_npc.call("attack_target", obj)
	elif layer == 8:
		if obj.get("_is_depleted"):
			return
		_npc.call("gather_from", obj)
	elif layer == 16:
		_npc.call("approach_player", "chat")
