extends Node
## SaveManager — Handles save/load/export/import of game state.
## Registered as "SaveManager" in project.godot autoloads.
## No class_name — autoloads are accessed by name, not type.

signal save_completed(success)
signal load_completed(success)

var SAVE_PATH = "user://savegame.json"
var SAVE_VERSION: int = 1
var AUTO_SAVE_INTERVAL: int = 500
var _initialized: bool = false
var _player_ref: Node3D = null


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	var sig = GameManager.get("game_tick")
	if sig:
		GameManager.game_tick.connect(_on_game_tick)
	FileLogger.log_msg("SaveManager initialized")


func set_player(p: Node3D) -> void:
	_player_ref = p
	FileLogger.log_msg("SaveManager: player ref set")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		FileLogger.log_msg("SaveManager: app paused, auto-saving")
		save_game()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		FileLogger.log_msg("SaveManager: closing, auto-saving")
		save_game()


func _on_game_tick(tc) -> void:
	if int(tc) > 0 and int(tc) % AUTO_SAVE_INTERVAL == 0:
		FileLogger.log_msg("SaveManager: periodic auto-save at tick %d" % int(tc))
		save_game()


func save_game() -> bool:
	var save_data = _collect_save_data()
	var json_str = JSON.stringify(save_data, "  ")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		FileLogger.log_msg("SaveManager: cannot open %s for writing" % SAVE_PATH)
		save_completed.emit(false)
		return false
	file.store_string(json_str)
	file.flush()
	file = null
	FileLogger.log_msg("SaveManager: saved (%d bytes)" % json_str.length())
	save_completed.emit(true)
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		FileLogger.log_msg("SaveManager: no save file found")
		load_completed.emit(false)
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		FileLogger.log_msg("SaveManager: cannot open save file")
		load_completed.emit(false)
		return false
	var json_str = file.get_as_text()
	file = null
	var parsed = JSON.parse_string(json_str)
	if parsed == null:
		FileLogger.log_msg("SaveManager: corrupt save file (parse failed)")
		load_completed.emit(false)
		return false
	return _apply_save_data(parsed)


func export_save_string() -> String:
	var save_data = _collect_save_data()
	var json_str = JSON.stringify(save_data)
	var bytes = json_str.to_utf8_buffer()
	return Marshalls.raw_to_base64(bytes)


func import_save_string(b64_str: String) -> bool:
	var trimmed = b64_str.strip_edges()
	var bytes = Marshalls.base64_to_raw(trimmed)
	if bytes.size() == 0:
		FileLogger.log_msg("SaveManager: empty or invalid base64 string")
		return false
	var json_str = bytes.get_string_from_utf8()
	var parsed = JSON.parse_string(json_str)
	if parsed == null:
		FileLogger.log_msg("SaveManager: corrupt import data (parse failed)")
		return false
	var result = _apply_save_data(parsed)
	if result:
		save_game()
	return result


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _collect_save_data() -> Dictionary:
	var data = {
		"save_version": SAVE_VERSION,
		"timestamp": _get_timestamp(),
		"systems": {}
	}
	_save_system(data, "player_skills", PlayerSkills)
	_save_system(data, "player_inventory", PlayerInventory)
	_save_system(data, "player_equipment", PlayerEquipment)
	_save_system(data, "combat_style", CombatStyle)
	_save_system(data, "game_manager", GameManager)
	if _player_ref and is_instance_valid(_player_ref):
		data["systems"]["player"] = {
			"hitpoints": _player_ref.get("hitpoints"),
			"max_hitpoints": _player_ref.get("max_hitpoints"),
			"position": [
				_player_ref.global_position.x,
				_player_ref.global_position.y,
				_player_ref.global_position.z
			]
		}
	return data


func _save_system(data: Dictionary, key: String, system: Node) -> void:
	var result = system.call("serialize")
	if result != null:
		data["systems"][key] = result


func _apply_save_data(data: Dictionary) -> bool:
	var version = data.get("save_version", 0)
	if version < 1:
		FileLogger.log_msg("SaveManager: unsupported save version %d" % version)
		load_completed.emit(false)
		return false
	var systems = data.get("systems", {})
	FileLogger.log_msg("SaveManager: applying keys: %s" % str(systems.keys()))
	if systems.has("player_skills"):
		PlayerSkills.call("deserialize", systems["player_skills"])
	if systems.has("player_inventory"):
		PlayerInventory.call("deserialize", systems["player_inventory"])
	if systems.has("player_equipment"):
		PlayerEquipment.call("deserialize", systems["player_equipment"])
	if systems.has("combat_style"):
		CombatStyle.call("deserialize", systems["combat_style"])
	if systems.has("game_manager"):
		GameManager.call("deserialize", systems["game_manager"])
	if systems.has("player"):
		_apply_player_data(systems["player"])
	FileLogger.log_msg("SaveManager: loaded save (version %d)" % version)
	load_completed.emit(true)
	return true


func _apply_player_data(pdata: Dictionary) -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		FileLogger.log_msg("SaveManager: no player ref for apply_player_data")
		return
	var hp = pdata.get("hitpoints")
	if hp != null:
		_player_ref.hitpoints = int(hp)
	var max_hp = pdata.get("max_hitpoints")
	if max_hp != null:
		_player_ref.max_hitpoints = int(max_hp)
	var pos = pdata.get("position")
	if pos != null and pos is Array and pos.size() >= 3:
		_player_ref.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	var sm = _player_ref.get("state_machine")
	if sm:
		sm.call("transition_to", "Idle")
	FileLogger.log_msg("SaveManager: player data applied")


func _get_timestamp() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"]
	]
