extends Node
## AiNpcManager — Autoload singleton for AI NPC API key + HTTP calls.
## No class_name — autoloads are accessed by name.

signal api_response(result)
signal chat_response(message)
signal api_key_changed(has_key)

var api_key: String = ""
var _initialized: bool = false
var _pending_callback: Callable
var _settings_path = "user://ai_npc_settings.json"


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_load_api_key()
	FileLogger.log_msg("AiNpcManager initialized, key=%s" % ("set" if api_key != "" else "unset"))


func has_api_key() -> bool:
	return api_key != ""


func set_api_key(key: String) -> void:
	api_key = key.strip_edges()
	_save_api_key()
	FileLogger.log_msg("AiNpcManager: API key updated, has_key=%s" % str(api_key != ""))
	api_key_changed.emit(api_key != "")


func _save_api_key() -> void:
	var data = {"api_key": api_key}
	var json_str = JSON.stringify(data)
	var file = FileAccess.open(_settings_path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.flush()


func _load_api_key() -> void:
	if not FileAccess.file_exists(_settings_path):
		return
	var file = FileAccess.open(_settings_path, FileAccess.READ)
	if file == null:
		return
	var json_str = file.get_as_text()
	file = null
	var parsed = JSON.parse_string(json_str)
	if parsed and parsed.has("api_key"):
		api_key = str(parsed["api_key"])


var _retry_count: int = 0
var _max_retries: int = 2


func _make_http() -> HTTPRequest:
	var http = HTTPRequest.new()
	http.timeout = 30.0
	# CRITICAL: use_threads=false on Android — threaded HTTPS fails instantly
	# with RESULT_CONNECTION_ERROR because the background thread lacks proper
	# JNI/network context for mbedTLS on Android Godot 4.3
	http.use_threads = false
	add_child(http)
	return http


func send_brain_request(system_prompt: String, user_msg: String, callback: Callable) -> void:
	if api_key == "":
		FileLogger.log_msg("AiNpcManager: no API key, skipping request")
		return
	_pending_callback = callback
	_retry_count = 0
	var body = {
		"model": "claude-haiku-4-5-20251001",
		"max_tokens": 300,
		"system": system_prompt,
		"messages": [{"role": "user", "content": user_msg}]
	}
	var json_body = JSON.stringify(body)
	_do_request(json_body)


func _do_request(json_body: String) -> void:
	var headers = [
		"Content-Type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01"
	]
	var http = _make_http()
	http.request_completed.connect(_on_request_done.bind(http, json_body))
	FileLogger.log_msg("AiNpcManager: sending request attempt=%d body_len=%d" % [_retry_count, json_body.length()])
	var err = http.request(
		"https://api.anthropic.com/v1/messages",
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)
	if err != OK:
		FileLogger.log_msg("AiNpcManager: request() returned error %d" % err)
		http.queue_free()
	else:
		FileLogger.log_msg("AiNpcManager: request() queued OK (no threads)")


func send_chat_request(system_prompt: String, messages: Array, callback: Callable) -> void:
	if api_key == "":
		return
	_pending_callback = callback
	_retry_count = 0
	var body = {
		"model": "claude-haiku-4-5-20251001",
		"max_tokens": 500,
		"system": system_prompt,
		"messages": messages
	}
	var json_body = JSON.stringify(body)
	_do_request(json_body)


func _on_request_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, json_body: String) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		FileLogger.log_msg("AiNpcManager: HTTP failed result=%d code=%d attempt=%d" % [result, code, _retry_count])
		# Retry on connection error (could be transient)
		if result == 3 and _retry_count < _max_retries:
			_retry_count += 1
			FileLogger.log_msg("AiNpcManager: retrying in 2s (attempt %d)" % _retry_count)
			var timer = get_tree().create_timer(2.0)
			timer.timeout.connect(_do_request.bind(json_body))
			return
		return
	var json_str = body.get_string_from_utf8()
	var parsed = JSON.parse_string(json_str)
	if parsed == null:
		FileLogger.log_msg("AiNpcManager: JSON parse failed")
		return
	if code != 200:
		FileLogger.log_msg("AiNpcManager: API error %d: %s" % [code, json_str.substr(0, 200)])
		return
	var content_arr = parsed.get("content", [])
	var text = ""
	for block in content_arr:
		if block.get("type") == "text":
			text = block.get("text", "")
			break
	FileLogger.log_msg("AiNpcManager: response len=%d" % text.length())
	if _pending_callback.is_valid():
		_pending_callback.call(text)


func serialize() -> Dictionary:
	return {}


func deserialize(_data: Dictionary) -> void:
	pass
