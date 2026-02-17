extends CharacterBody3D
## AI NPC controller — movement, combat, gathering, HP. NO class_name.
@export var display_name: String = "Aria"
@export var move_speed: float = 3.5
@export var interaction_range: float = 3.0
@export var max_hitpoints: int = 10
signal request_chat(npc)
signal request_trade(npc)
var hitpoints: int = 10
var _initialized: bool = false
var _nav_agent: NavigationAgent3D = null
var is_moving: bool = false
var _target_object: Node3D = null
var _current_action: String = "idle"
var _attack_ticks: int = 0
var _gather_ticks: int = 0
var _is_dead: bool = false
var _respawn_counter: int = 0
var _tick_connected: bool = false
var npc_inventory: Array = []
var npc_skills: Dictionary = {}
var _player_ref: Node3D = null
var _approach_player: bool = false
var _approach_reason: String = ""
var _xp_table: Array = []
var _suspended: bool = false

func _ready() -> void:
	ensure_initialized()

func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	collision_layer = 16
	collision_mask = 1 | 2
	hitpoints = max_hitpoints
	_nav_agent = get_node_or_null("NavigationAgent3D")
	if _nav_agent:
		_nav_agent.path_desired_distance = 0.5
		_nav_agent.target_desired_distance = 0.5
		_nav_agent.max_speed = move_speed
	var t: float = 0.0
	for i in range(1, 100):
		t += floorf(i + 300.0 * pow(2.0, i / 7.0))
		_xp_table.append(floorf(t / 4.0))
	var skills = ["Attack","Strength","Defence","Hitpoints","Ranged","Prayer","Magic","Cooking","Woodcutting","Fishing","Mining","Smithing","Crafting","Firemaking","Agility","Thieving"]
	for s in skills:
		npc_skills[s] = {"level": 10 if s == "Hitpoints" else 1, "xp": 1154.0 if s == "Hitpoints" else 0.0}
	if not _tick_connected:
		var sig = GameManager.get("game_tick")
		if sig:
			GameManager.game_tick.connect(_on_game_tick)
			_tick_connected = true
	var key_sig = AiNpcManager.get("api_key_changed")
	if key_sig:
		AiNpcManager.api_key_changed.connect(_on_api_key_changed)
	_add_name_label()
	# Start suspended if no API key
	var has_key = AiNpcManager.call("has_api_key")
	if not has_key:
		_suspend()

func _add_name_label() -> void:
	if get_node_or_null("NameLabel"):
		return
	var lbl = Label3D.new()
	lbl.name = "NameLabel"
	lbl.text = display_name
	lbl.font_size = 32
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(0.4, 0.7, 1.0)
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0, 0, 0)
	lbl.position.y = 2.3
	add_child(lbl)

func _on_api_key_changed(has_key) -> void:
	if has_key and _suspended:
		_resume()
	elif not has_key and not _suspended:
		_suspend()

func _suspend() -> void:
	_suspended = true
	visible = false
	collision_layer = 0
	_current_action = "idle"
	_target_object = null

func _resume() -> void:
	_suspended = false
	visible = true
	if not _is_dead:
		collision_layer = 16

func set_player_ref(p: Node3D) -> void:
	_player_ref = p

func get_dialogue() -> Array:
	return ["Hello! I'm " + display_name + "."]

func is_merchant() -> bool:
	return false

func is_ai_npc() -> bool:
	return true

func is_in_range_of(target: Node3D) -> bool:
	return global_position.distance_to(target.global_position) <= interaction_range

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	hitpoints = max(0, hitpoints - amount)
	_show_hitsplat(amount)
	if hitpoints <= 0:
		_is_dead = true
		_current_action = "dead"
		_target_object = null
		visible = false
		collision_layer = 0
		_respawn_counter = 50
		GameManager.log_action("%s has been defeated!" % display_name)
		_log_event("I was defeated in combat and had to respawn.")

func _show_hitsplat(amount: int) -> void:
	var lbl = Label3D.new()
	lbl.text = str(amount) if amount > 0 else "Miss"
	lbl.font_size = 48
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.outline_size = 10
	lbl.modulate = Color(1, 0.15, 0.15) if amount > 0 else Color(0.6, 0.6, 0.6)
	lbl.position.y = 2.2
	add_child(lbl)
	var tw = create_tween()
	tw.tween_property(lbl, "position:y", 3.5, 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)

func _on_game_tick(_tick) -> void:
	if _suspended:
		return
	if _is_dead:
		_respawn_counter -= 1
		if _respawn_counter <= 0:
			_is_dead = false
			hitpoints = max_hitpoints
			visible = true
			collision_layer = 16
			_current_action = "idle"
			_log_event("Respawned after being defeated.")
		return
	if _current_action == "combat":
		_combat_tick()
	elif _current_action == "gathering":
		_gathering_tick()

func move_to(pos: Vector3) -> void:
	if _nav_agent == null or _is_dead:
		return
	_target_object = null
	_gather_ticks = 0
	_nav_agent.target_position = pos
	_current_action = "moving"
	is_moving = true

func _physics_process(_delta: float) -> void:
	if _suspended or _is_dead or _nav_agent == null:
		return
	if (_current_action == "combat" or _current_action == "gathering") and _target_object and is_instance_valid(_target_object):
		if not is_in_range_of(_target_object):
			_nav_agent.target_position = _target_object.global_position
			_do_move()
			return
	if _current_action != "moving" and not _approach_player:
		return
	if _nav_agent.is_navigation_finished():
		is_moving = false
		if _approach_player and _player_ref:
			_approach_player = false
			if _approach_reason == "chat":
				request_chat.emit(self)
			elif _approach_reason == "trade":
				request_trade.emit(self)
			_approach_reason = ""
			_current_action = "idle"
		elif _current_action == "moving":
			_current_action = "idle"
		return
	_do_move()

func _do_move() -> void:
	var np = _nav_agent.get_next_path_position()
	var dir = (np - global_position).normalized()
	dir.y = 0
	if dir.length() > 0.01:
		var lt = global_position + dir
		lt.y = global_position.y
		if lt.distance_to(global_position) > 0.01:
			look_at(lt, Vector3.UP)
	velocity = dir * move_speed
	move_and_slide()
	is_moving = true

func attack_target(target: Node3D) -> void:
	if _is_dead or target == null or target.get("_is_dead"):
		return
	_target_object = target
	_current_action = "combat"
	_attack_ticks = 4
	if _nav_agent and not is_in_range_of(target):
		_nav_agent.target_position = target.global_position

func _combat_tick() -> void:
	if _target_object == null or not is_instance_valid(_target_object):
		_current_action = "idle"
		return
	if _target_object.get("_is_dead"):
		var ename = _target_object.get("display_name")
		if ename == null:
			ename = _target_object.name
		_log_event("Defeated %s in combat." % ename)
		_current_action = "idle"
		_target_object = null
		return
	if not is_in_range_of(_target_object):
		return
	_attack_ticks -= 1
	if _attack_ticks <= 0:
		var sl = npc_skills.get("Strength", {}).get("level", 1)
		var mh = max(1, int(0.5 + (sl + 8) * 64 / 640.0))
		var dmg = randi_range(0, mh)
		_target_object.call("take_damage", dmg)
		_add_xp("Attack", dmg * 4.0)
		_add_xp("Hitpoints", dmg * 1.33)
		_attack_ticks = 4

func gather_from(target: Node3D) -> void:
	if _is_dead or target == null or target.get("_is_depleted"):
		return
	_target_object = target
	_current_action = "gathering"
	_gather_ticks = 0
	if _nav_agent:
		_nav_agent.target_position = target.global_position

func _gathering_tick() -> void:
	if _target_object == null or not is_instance_valid(_target_object):
		_current_action = "idle"
		return
	if _target_object.get("_is_depleted"):
		_current_action = "idle"
		_target_object = null
		return
	if not is_in_range_of(_target_object):
		return
	var tpa = _target_object.get("ticks_per_action")
	if tpa == null:
		tpa = 4
	_gather_ticks += 1
	if _gather_ticks < tpa:
		return
	_gather_ticks = 0
	var sk = _target_object.get("required_skill")
	var req_lv = _target_object.get("required_level")
	var my_lv = 1
	if sk:
		my_lv = npc_skills.get(str(sk), {}).get("level", 1)
	if req_lv and my_lv < int(req_lv):
		_current_action = "idle"
		_target_object = null
		return
	var chance = _target_object.get("base_success_chance")
	if chance == null:
		chance = 0.5
	if sk and req_lv:
		chance = min(0.95, float(chance) + (my_lv - int(req_lv)) * 0.02)
	if randf() > chance:
		return
	var xp = _target_object.get("xp_reward")
	if sk and xp:
		_add_xp(str(sk), float(xp))
	var gr = _target_object.get("_gathers_remaining")
	if gr != null:
		gr -= 1
		_target_object.set("_gathers_remaining", gr)
		if gr <= 0:
			var obj_name = _target_object.get("display_name")
			if obj_name == null:
				obj_name = _target_object.name
			_log_event("Finished gathering from %s." % obj_name)
			_target_object.call("_deplete")
			_current_action = "idle"
			_target_object = null

func _add_xp(skill: String, amount: float) -> void:
	if not npc_skills.has(skill):
		return
	npc_skills[skill]["xp"] += amount
	var xp = npc_skills[skill]["xp"]
	var nl = 1
	for i in range(_xp_table.size()):
		if xp >= _xp_table[i]:
			nl = i + 2
	if nl > 99:
		nl = 99
	if nl > npc_skills[skill]["level"]:
		var old_lv = npc_skills[skill]["level"]
		npc_skills[skill]["level"] = nl
		GameManager.log_action("%s: %s level %d!" % [display_name, skill, nl])
		_log_event("%s leveled up from %d to %d!" % [skill, old_lv, nl])
		if skill == "Hitpoints":
			max_hitpoints = nl
			hitpoints = nl

func _log_event(text: String) -> void:
	var brain = get_node_or_null("Brain")
	if brain:
		brain.call("log_event", text)

func approach_player(reason: String) -> void:
	if _player_ref == null or _is_dead:
		return
	_approach_player = true
	_approach_reason = reason
	_nav_agent.target_position = _player_ref.global_position
	_current_action = "moving"


func serialize() -> Dictionary:
	var data = {
		"skills": npc_skills,
		"hp": hitpoints,
		"max_hp": max_hitpoints,
		"dead": _is_dead,
		"pos": [global_position.x, global_position.y, global_position.z]
	}
	var brain = get_node_or_null("Brain")
	if brain:
		var ch = brain.get("_chat_history")
		if ch and ch.size() > 0:
			data["chat"] = ch
		var ev = brain.get("_event_log")
		if ev and ev.size() > 0:
			data["events"] = ev
	return data


func deserialize(data: Dictionary) -> void:
	var sk = data.get("skills")
	if sk:
		npc_skills = sk
	var hp = data.get("hp")
	if hp != null:
		hitpoints = int(hp)
	var mhp = data.get("max_hp")
	if mhp != null:
		max_hitpoints = int(mhp)
	var dead = data.get("dead")
	if dead:
		_is_dead = true
		visible = false
		collision_layer = 0
		_current_action = "dead"
		_respawn_counter = 50
	var pos = data.get("pos")
	if pos != null and pos is Array and pos.size() >= 3:
		global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	var brain = get_node_or_null("Brain")
	if brain:
		var chat = data.get("chat")
		if chat:
			brain.call("set_chat_history", chat)
		var events = data.get("events")
		if events:
			brain.set("_event_log", events)
