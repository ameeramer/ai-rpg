extends Node
## AI NPC Actions — combat ticks, gathering ticks, XP, serialization.
## Child of AiNpc. NO class_name. Under 130 lines.

var _npc = null
var _initialized = false
var _xp_table = []

func _ready() -> void:
	ensure_initialized()

func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_npc = get_parent()
	var t = 0.0
	for i in range(1, 100):
		t += floorf(i + 300.0 * pow(2.0, i / 7.0))
		_xp_table.append(floorf(t / 4.0))

func combat_tick() -> void:
	var target = _npc.get("_target_object")
	if target == null or not is_instance_valid(target):
		_npc.set("_current_action", "idle")
		return
	if target.get("_is_dead"):
		var ename = target.get("display_name")
		if ename == null:
			ename = target.name
		_log_event("Defeated %s in combat." % ename)
		_npc.set("_current_action", "idle")
		_npc.set("_target_object", null)
		return
	if not _npc.call("is_in_range_of", target):
		return
	var atk = _npc.get("_attack_ticks")
	atk -= 1
	_npc.set("_attack_ticks", atk)
	if atk <= 0:
		var skills = _npc.get("npc_skills")
		var sl = skills.get("Strength", {}).get("level", 1)
		var mh = max(1, int(0.5 + (sl + 8) * 64 / 640.0))
		var dmg = randi_range(0, mh)
		target.call("take_damage", dmg)
		add_xp("Attack", dmg * 4.0)
		add_xp("Hitpoints", dmg * 1.33)
		_npc.set("_attack_ticks", 4)

func gathering_tick() -> void:
	var target = _npc.get("_target_object")
	if target == null or not is_instance_valid(target):
		_npc.set("_current_action", "idle")
		return
	if target.get("_is_depleted"):
		_npc.set("_current_action", "idle")
		_npc.set("_target_object", null)
		return
	if not _npc.call("is_in_range_of", target):
		return
	var tpa = target.get("ticks_per_action")
	if tpa == null:
		tpa = 4
	var gt = _npc.get("_gather_ticks")
	gt += 1
	_npc.set("_gather_ticks", gt)
	if gt < tpa:
		return
	_npc.set("_gather_ticks", 0)
	var sk = target.get("required_skill")
	var req_lv = target.get("required_level")
	var skills = _npc.get("npc_skills")
	var my_lv = 1
	if sk:
		my_lv = skills.get(str(sk), {}).get("level", 1)
	if req_lv and my_lv < int(req_lv):
		_npc.set("_current_action", "idle")
		_npc.set("_target_object", null)
		return
	var chance = target.get("base_success_chance")
	if chance == null:
		chance = 0.5
	if sk and req_lv:
		chance = min(0.95, float(chance) + (my_lv - int(req_lv)) * 0.02)
	if randf() > chance:
		return
	var xp = target.get("xp_reward")
	if sk and xp:
		add_xp(str(sk), float(xp))
	var gr = target.get("_gathers_remaining")
	if gr != null:
		gr -= 1
		target.set("_gathers_remaining", gr)
		if gr <= 0:
			var obj_name = target.get("display_name")
			if obj_name == null:
				obj_name = target.name
			_log_event("Finished gathering from %s." % obj_name)
			target.call("_deplete")
			_npc.set("_current_action", "idle")
			_npc.set("_target_object", null)

func add_xp(skill: String, amount: float) -> void:
	var skills = _npc.get("npc_skills")
	if skills == null or not skills.has(skill):
		return
	skills[skill]["xp"] += amount
	var xp = skills[skill]["xp"]
	var nl = 1
	for i in range(_xp_table.size()):
		if xp >= _xp_table[i]:
			nl = i + 2
	if nl > 99:
		nl = 99
	if nl > skills[skill]["level"]:
		var old_lv = skills[skill]["level"]
		skills[skill]["level"] = nl
		var dname = _npc.get("display_name")
		GameManager.log_action("%s: %s level %d!" % [dname, skill, nl])
		_log_event("%s leveled up from %d to %d!" % [skill, old_lv, nl])
		if skill == "Hitpoints":
			_npc.set("max_hitpoints", nl)
			_npc.set("hitpoints", nl)

func _log_event(text: String) -> void:
	var brain = _npc.get_node_or_null("Brain")
	if brain:
		brain.call("log_event", text)

func serialize() -> Dictionary:
	var data = {
		"skills": _npc.get("npc_skills"),
		"hp": _npc.get("hitpoints"),
		"max_hp": _npc.get("max_hitpoints"),
		"dead": _npc.get("_is_dead"),
		"pos": [_npc.global_position.x, _npc.global_position.y, _npc.global_position.z]
	}
	var brain = _npc.get_node_or_null("Brain")
	if brain:
		var ch = brain.get("_chat_history")
		if ch and ch.size() > 0:
			data["chat"] = ch
		var ev = brain.get("_event_log")
		if ev and ev.size() > 0:
			data["events"] = ev
			data["events_synced"] = brain.get("_events_synced")
	return data

func deserialize(data: Dictionary) -> void:
	var sk = data.get("skills")
	if sk:
		_npc.set("npc_skills", sk)
	var hp = data.get("hp")
	if hp != null:
		_npc.set("hitpoints", int(hp))
	var mhp = data.get("max_hp")
	if mhp != null:
		_npc.set("max_hitpoints", int(mhp))
	var dead = data.get("dead")
	if dead:
		_npc.set("_is_dead", true)
		_npc.visible = false
		_npc.collision_layer = 0
		_npc.set("_current_action", "dead")
		_npc.set("_respawn_counter", 50)
	var pos = data.get("pos")
	if pos != null and pos is Array and pos.size() >= 3:
		_npc.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	var brain = _npc.get_node_or_null("Brain")
	if brain:
		var chat = data.get("chat")
		if chat:
			brain.call("set_chat_history", chat)
		var events = data.get("events")
		if events:
			brain.set("_event_log", events)
			var es = data.get("events_synced")
			if es != null:
				brain.set("_events_synced", int(es))
