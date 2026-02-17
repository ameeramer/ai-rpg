extends Node
## AiNpcManager — Autoload singleton for AI NPC API key + HTTP calls.
## No class_name — autoloads are accessed by name.

signal api_response(result)
signal chat_response(message)
signal api_key_changed(has_key)

var api_key: String = ""
var _initialized: bool = false
var _http: HTTPRequest = null
var _pending_callback: Callable
var _settings_path = "user://ai_npc_settings.json"


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_http = HTTPRequest.new()
	_http.timeout = 30.0
	_http.use_threads = true
	var tls = TLSOptions.client_unsafe()
	if tls:
		_http.set_tls_options(tls)
		FileLogger.log_msg("AiNpcManager: TLS options set (unsafe)")
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
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


func send_brain_request(system_prompt: String, user_msg: String, callback: Callable) -> void:
	if api_key == "":
		FileLogger.log_msg("AiNpcManager: no API key, skipping request")
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED and _http.get_http_client_status() != HTTPClient.STATUS_CONNECTED:
		FileLogger.log_msg("AiNpcManager: HTTP busy, skipping")
		return
	_pending_callback = callback
	var body = {
		"model": "claude-haiku-4-5-20251001",
		"max_tokens": 300,
		"system": system_prompt,
		"messages": [{"role": "user", "content": user_msg}]
	}
	var json_body = JSON.stringify(body)
	var headers = [
		"Content-Type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01"
	]
	FileLogger.log_msg("AiNpcManager: sending brain request, body_len=%d" % json_body.length())
	var err = _http.request(
		"https://api.anthropic.com/v1/messages",
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)
	if err != OK:
		FileLogger.log_msg("AiNpcManager: request() returned error %d" % err)
	else:
		FileLogger.log_msg("AiNpcManager: request() queued OK")


func send_chat_request(system_prompt: String, messages: Array, callback: Callable) -> void:
	if api_key == "":
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED and _http.get_http_client_status() != HTTPClient.STATUS_CONNECTED:
		return
	_pending_callback = callback
	var body = {
		"model": "claude-haiku-4-5-20251001",
		"max_tokens": 500,
		"system": system_prompt,
		"messages": messages
	}
	var json_body = JSON.stringify(body)
	var headers = [
		"Content-Type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01"
	]
	var err = _http.request(
		"https://api.anthropic.com/v1/messages",
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)
	if err != OK:
		FileLogger.log_msg("AiNpcManager: chat request error %d" % err)


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		FileLogger.log_msg("AiNpcManager: HTTP failed result=%d code=%d" % [result, code])
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
