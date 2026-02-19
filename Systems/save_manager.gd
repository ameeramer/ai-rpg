extends Node

signal save_completed(success)
signal load_completed(success)

var SAVE_PATH = "user://savegame.json"
var EXPORT_FILENAME = "airpg_save.json"
var SAVE_VERSION = 1
var AUTO_SAVE_INTERVAL = 500
var _initialized = false
var _player_ref = null
var _ai_npc_ref = null

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

func set_player(p) -> void:
	_player_ref = p

func set_ai_npc(npc) -> void:
	_ai_npc_ref = npc

func _notification(what) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func _on_game_tick(tc) -> void:
	if int(tc) > 0 and int(tc) % AUTO_SAVE_INTERVAL == 0:
		save_game()

func save_game() -> bool:
	var json_str = JSON.stringify(_collect_save_data(), "  ")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		save_completed.emit(false)
		return false
	file.store_string(json_str)
	file.flush()
	file = null
	save_completed.emit(true)
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		load_completed.emit(false)
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		load_completed.emit(false)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file = null
	if parsed == null:
		load_completed.emit(false)
		return false
	return _apply_save_data(parsed)

func get_export_path() -> String:
	if OS.get_name() == "Android":
		var dl = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		if dl != "":
			return dl.path_join(EXPORT_FILENAME)
	var docs = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs != "":
		return docs.path_join(EXPORT_FILENAME)
	return ProjectSettings.globalize_path("user://").path_join(EXPORT_FILENAME)

func export_save_file() -> String:
	var json_str = JSON.stringify(_collect_save_data(), "  ")
	var path = get_export_path()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		path = "user://" + EXPORT_FILENAME
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		FileLogger.log_msg("SaveManager: export failed")
		return ""
	file.store_string(json_str)
	file.flush()
	file = null
	FileLogger.log_msg("SaveManager: exported to %s" % path)
	return path

func import_save_file() -> Dictionary:
	var path = get_export_path()
	if not FileAccess.file_exists(path):
		var alt = "user://" + EXPORT_FILENAME
		if FileAccess.file_exists(alt):
			path = alt
		else:
			return {"success": false, "error": "No file found. Place %s in Downloads." % EXPORT_FILENAME}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Cannot read file."}
	var parsed = JSON.parse_string(file.get_as_text())
	file = null
	if parsed == null:
		return {"success": false, "error": "File is corrupt or not a valid save."}
	var ok = _apply_save_data(parsed)
	if ok:
		save_game()
	return {"success": ok, "error": "" if ok else "Failed to apply save.", "path": path}

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func _collect_save_data() -> Dictionary:
	var data = {"save_version": SAVE_VERSION, "timestamp": _get_timestamp(), "systems": {}}
	_save_sys(data, "player_skills", PlayerSkills)
	_save_sys(data, "player_inventory", PlayerInventory)
	_save_sys(data, "player_equipment", PlayerEquipment)
	_save_sys(data, "combat_style", CombatStyle)
	_save_sys(data, "game_manager", GameManager)
	if _player_ref and is_instance_valid(_player_ref):
		data["systems"]["player"] = {
			"hitpoints": _player_ref.get("hitpoints"),
			"max_hitpoints": _player_ref.get("max_hitpoints"),
			"position": [_player_ref.global_position.x, _player_ref.global_position.y, _player_ref.global_position.z]
		}
	if _ai_npc_ref and is_instance_valid(_ai_npc_ref):
		var ai_data = _ai_npc_ref.call("serialize")
		if ai_data:
			data["systems"]["ai_npc"] = ai_data
	return data

func _save_sys(data, key, system) -> void:
	var result = system.call("serialize")
	if result != null:
		data["systems"][key] = result

func _apply_save_data(data) -> bool:
	var version = data.get("save_version", 0)
	if version < 1:
		load_completed.emit(false)
		return false
	var systems = data.get("systems", {})
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
	if systems.has("ai_npc"):
		_apply_ai_npc_data(systems["ai_npc"])
	load_completed.emit(true)
	return true

func _apply_player_data(pdata) -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
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

func _apply_ai_npc_data(data) -> void:
	if _ai_npc_ref == null or not is_instance_valid(_ai_npc_ref):
		return
	_ai_npc_ref.call("deserialize", data)

func _get_timestamp() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02d" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"], dt["second"]]
