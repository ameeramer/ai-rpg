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
	data["systems"]["player_skills"] = PlayerSkills.call("serialize")
	data["systems"]["player_inventory"] = PlayerInventory.call("serialize")
	data["systems"]["player_equipment"] = PlayerEquipment.call("serialize")
	data["systems"]["game_manager"] = GameManager.call("serialize")
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		data["systems"]["player"] = {
			"hitpoints": p.get("hitpoints"),
			"max_hitpoints": p.get("max_hitpoints"),
			"position": [p.global_position.x, p.global_position.y, p.global_position.z]
		}
	return data


func _apply_save_data(data: Dictionary) -> bool:
	var version = data.get("save_version", 0)
	if version < 1:
		FileLogger.log_msg("SaveManager: unsupported save version %d" % version)
		load_completed.emit(false)
		return false
	var systems = data.get("systems", {})
	if systems.has("player_skills"):
		PlayerSkills.call("deserialize", systems["player_skills"])
	if systems.has("player_inventory"):
		PlayerInventory.call("deserialize", systems["player_inventory"])
	if systems.has("player_equipment"):
		PlayerEquipment.call("deserialize", systems["player_equipment"])
	if systems.has("game_manager"):
		GameManager.call("deserialize", systems["game_manager"])
	if systems.has("player"):
		_apply_player_data(systems["player"])
	FileLogger.log_msg("SaveManager: loaded save (version %d)" % version)
	load_completed.emit(true)
	return true


func _apply_player_data(pdata: Dictionary) -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return
	var p = players[0]
	var hp = pdata.get("hitpoints")
	if hp != null:
		p.hitpoints = int(hp)
	var max_hp = pdata.get("max_hitpoints")
	if max_hp != null:
		p.max_hitpoints = int(max_hp)
	var pos = pdata.get("position")
	if pos != null and pos is Array and pos.size() >= 3:
		p.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	var sm = p.get("state_machine")
	if sm:
		sm.call("transition_to", "Idle")


func _get_timestamp() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"]
	]
