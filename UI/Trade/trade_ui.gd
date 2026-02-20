extends PanelContainer
## Trade UI — Two-player-style AI NPC trading.
signal trade_closed()
var _npc_ref = null
var _npc_name = ""
var _player_offer = []
var _npc_offer = []
var _state = "offer"
var _pgrid = null
var _ngrid = null
var _title = null
var _offer_btn = null
var _accept_btn = null
var _decline_btn = null
var _status = null

func _ready() -> void:
	var b = load("res://UI/Trade/trade_ui_builder.gd").new()
	b.call("build", self)

func open_trade(npc_name: String, npc) -> void:
	_npc_name = npc_name
	_npc_ref = npc
	_title.text = "Trade with " + npc_name
	_player_offer.clear()
	_npc_offer.clear()
	_state = "offer"
	_upd_btns()
	_status.text = "Tap your items to offer them for trade"
	visible = true
	_refresh()

func _refresh() -> void:
	for g in [_pgrid, _ngrid]:
		for c in g.get_children():
			c.queue_free()
	var slots = PlayerInventory.get("slots")
	if slots:
		for i in range(slots.size()):
			if slots[i] == null:
				continue
			var item = slots[i].get("item")
			var qty = slots[i].get("quantity")
			if item == null:
				continue
			var hl = _has_slot(_player_offer, i)
			var b = _ibtn(item, qty, hl, Color(0.2, 0.4, 0.2, 0.9))
			if _state == "offer":
				b.pressed.connect(_toggle.bind(i, item, qty))
			_pgrid.add_child(b)
	var ni = _npc_ref.get("npc_inventory") if _npc_ref else []
	if ni:
		for e in ni:
			if e == null or e.get("item") == null:
				continue
			var hl = _has_id(_npc_offer, e["item"].id)
			_ngrid.add_child(_ibtn(e["item"], e["quantity"], hl, Color(0.15, 0.3, 0.5, 0.9)))

func _ibtn(item, qty: int, hl: bool, col: Color) -> Button:
	var b = Button.new()
	var n = item.call("get_display_name")
	b.text = "%s\nx%d" % [n if n else "Item", qty]
	b.custom_minimum_size = Vector2(100, 80)
	b.add_theme_font_size_override("font_size", 18)
	if hl:
		var s = StyleBoxFlat.new()
		s.bg_color = col
		s.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", s)
	return b

func _toggle(si: int, item, qty: int) -> void:
	if _state != "offer":
		return
	var f = -1
	for i in range(_player_offer.size()):
		if _player_offer[i]["slot"] == si:
			f = i
			break
	if f >= 0:
		_player_offer.remove_at(f)
	else:
		_player_offer.append({"slot": si, "item": item, "quantity": qty})
	_status.text = "Offering %d item(s)" % _player_offer.size() if _player_offer.size() > 0 else "Tap items to offer"
	_refresh()

func _has_slot(arr: Array, idx: int) -> bool:
	for e in arr:
		if e.get("slot") == idx:
			return true
	return false

func _has_id(arr: Array, id: int) -> bool:
	for e in arr:
		if int(e.get("item_id", -1)) == id:
			return true
	return false

func _on_offer() -> void:
	_state = "waiting"
	_upd_btns()
	_status.text = "Waiting for %s..." % _npc_name
	var sys = "You are %s, evaluating a trade in an OSRS RPG. Respond ONLY with JSON: {\"accept\": true/false, \"npc_offer\": [{\"item_id\": 995, \"quantity\": 50}], \"message\": \"reason\"}. If declining, npc_offer=[]. The player may offer nothing — they might just want to see what you'll give. Be fair but shrewd — consider item gold values." % _npc_name
	var msg = "Player offers:\n"
	if _player_offer.is_empty():
		msg += "- (nothing)\n"
	else:
		for e in _player_offer:
			msg += "- %s x%d (value: %d gp)\n" % [e["item"].call("get_display_name"), e["quantity"], e["item"].value]
	msg += "\nYour inventory:\n"
	var ni = _npc_ref.get("npc_inventory") if _npc_ref else []
	if ni and ni.size() > 0:
		for e in ni:
			msg += "- %s x%d (id:%d, value:%d gp)\n" % [e["item"].call("get_display_name"), e["quantity"], e["item"].id, e["item"].value]
	else:
		msg += "- (empty)\n"
	# Include recent chat history for context
	var brain = _npc_ref.get_node_or_null("Brain") if _npc_ref else null
	var ch = brain.get("_chat_history") if brain else null
	if ch and ch.size() > 0:
		msg += "\nRecent chat with player:\n"
		var start = max(0, ch.size() - 6)
		for i in range(start, ch.size()):
			var who = "Player" if ch[i]["role"] == "user" else "You"
			msg += "%s: %s\n" % [who, ch[i]["content"]]
	AiNpcManager.call("send_trade_request", sys, msg, Callable(self, "_on_trade_response"))

func _on_trade_response(response: String) -> void:
	if not visible:
		return
	var js = response
	var s = response.find("{")
	var e = response.rfind("}")
	if s >= 0 and e > s:
		js = response.substr(s, e - s + 1)
	var p = JSON.parse_string(js)
	if p == null:
		_state = "offer"
		_upd_btns()
		_status.text = "%s didn't understand. Try again." % _npc_name
		return
	_npc_offer = p.get("npc_offer", [])
	_state = "review" if p.get("accept", false) else "offer"
	_status.text = "%s: \"%s\"" % [_npc_name, p.get("message", "")]
	_upd_btns()
	_refresh()

func _on_accept() -> void:
	var given = []
	var got = []
	for en in _player_offer:
		PlayerInventory.call("remove_item_at", en["slot"], en["quantity"])
		_npc_ref.call("add_to_inventory", en["item"], en["quantity"])
		given.append("%s x%d" % [en["item"].call("get_display_name"), en["quantity"]])
	for en in _npc_offer:
		var iid = int(en.get("item_id", 0))
		var qty = int(en.get("quantity", 1))
		var item = ItemRegistry.call("get_item_by_id", iid)
		if item:
			PlayerInventory.call("add_item", item, qty)
			_npc_ref.call("remove_from_inventory", iid, qty)
			got.append("%s x%d" % [item.call("get_display_name"), qty])
	GameManager.log_action("Traded with %s: gave [%s], got [%s]" % [_npc_name, ", ".join(given), ", ".join(got)])
	# Log trade event to NPC brain so it remembers the trade happened
	var brain = _npc_ref.get_node_or_null("Brain") if _npc_ref else null
	if brain:
		var event_msg = "Completed trade with player. Gave: %s. Received: %s." % [", ".join(got) if got.size() > 0 else "nothing", ", ".join(given) if given.size() > 0 else "nothing"]
		brain.call("log_event", event_msg)
	_state = "complete"
	_status.text = "Trade complete!"
	_upd_btns()
	_player_offer.clear()
	_npc_offer.clear()
	_refresh()

func _on_decline() -> void:
	_npc_offer.clear()
	_state = "offer"
	_upd_btns()
	_status.text = "Trade declined. Modify your offer."
	_refresh()

func _upd_btns() -> void:
	_offer_btn.visible = _state == "offer"
	_accept_btn.visible = _state == "review"
	_decline_btn.visible = _state == "review"

func _on_close() -> void:
	visible = false
	_state = "offer"
	trade_closed.emit()

func setup() -> void:
	pass
