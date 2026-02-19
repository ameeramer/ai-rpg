extends CharacterBody3D
## AI NPC controller — movement, public API, HP. NO class_name.
@export var display_name: String = "Aria"
@export var move_speed: float = 3.5
@export var interaction_range: float = 3.0
@export var max_hitpoints: int = 10
signal request_chat(npc)
signal request_trade(npc)
var hitpoints: int = 10
var _initialized = false
var _nav_agent = null
var is_moving = false
var _target_object = null
var _current_action = "idle"
var _attack_ticks = 0
var _gather_ticks = 0
var _is_dead = false
var _respawn_counter = 0
var _tick_connected = false
var npc_inventory = []
var npc_skills = {}
var _player_ref = null
var _approach_player = false
var _approach_reason = ""
var _suspended = false

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
	for s in ["Attack","Strength","Defence","Hitpoints","Ranged","Prayer","Magic","Cooking","Woodcutting","Fishing","Mining","Smithing","Crafting","Firemaking","Agility","Thieving"]:
		npc_skills[s] = {"level": 10 if s == "Hitpoints" else 1, "xp": 1154.0 if s == "Hitpoints" else 0.0}
	if not _tick_connected:
		var sig = GameManager.get("game_tick")
		if sig:
			GameManager.game_tick.connect(_on_game_tick)
			_tick_connected = true
	var key_sig = AiNpcManager.get("api_key_changed")
	if key_sig:
		AiNpcManager.api_key_changed.connect(_on_api_key_changed)
	if not AiNpcManager.call("has_api_key"):
		_suspend()

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
	if hitpoints <= 0:
		_is_dead = true
		_current_action = "dead"
		_target_object = null
		visible = false
		collision_layer = 0
		_respawn_counter = 50
		GameManager.log_action("%s has been defeated!" % display_name)
		_log_event("I was defeated in combat and had to respawn.")

func _on_game_tick(_tick) -> void:
	if _suspended or _is_dead:
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
	var act = get_node_or_null("Actions")
	if act and _current_action == "combat":
		act.call("combat_tick")
	elif act and _current_action == "gathering":
		act.call("gathering_tick")

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

func gather_from(target: Node3D) -> void:
	if _is_dead or target == null or target.get("_is_depleted"):
		return
	_target_object = target
	_current_action = "gathering"
	_gather_ticks = 0
	if _nav_agent:
		_nav_agent.target_position = target.global_position

func approach_player(reason: String) -> void:
	if _player_ref == null or _is_dead:
		return
	_approach_player = true
	_approach_reason = reason
	_nav_agent.target_position = _player_ref.global_position
	_current_action = "moving"

func _log_event(text: String) -> void:
	var brain = get_node_or_null("Brain")
	if brain:
		brain.call("log_event", text)

func serialize() -> Dictionary:
	var act = get_node_or_null("Actions")
	if act:
		return act.call("serialize")
	return {}

func deserialize(data: Dictionary) -> void:
	var act = get_node_or_null("Actions")
	if act:
		act.call("deserialize", data)
