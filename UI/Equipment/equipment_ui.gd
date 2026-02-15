extends VBoxContainer
## Equipment panel UI — shows equipped items in paper-doll layout.

var _slot_buttons: Dictionary = {}
var _stats_label: Label
var _icon_cache: Dictionary = {}
var _viewport: SubViewport
var _cam: Camera3D
var _render_queue: Array = []
var _current_model: Node3D

var SLOT_LAYOUT: Array = [
	["", "Head", ""],
	["Cape", "Amulet", ""],
	["", "Body", ""],
	["Weapon", "Legs", "Shield"],
	["Hands", "Feet", "Ring"]
]


func _ready() -> void:
	FileLogger.log_msg("EquipmentUI._ready() start")
	add_theme_constant_override("separation", 4)
	_setup_render_viewport()
	_build_layout()
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 39)
	_stats_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_stats_label)
	FileLogger.log_msg("EquipmentUI._ready() done")


func setup() -> void:
	var sig = PlayerEquipment.get("equipment_changed")
	if sig:
		PlayerEquipment.equipment_changed.connect(refresh)
	refresh()


func _setup_render_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(96, 96)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.own_world_3d = true
	add_child(_viewport)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 2.0
	_cam.position = Vector3(0, 0.5, 2.5)
	_cam.look_at(Vector3(0, 0.3, 0), Vector3.UP)
	_viewport.add_child(_cam)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.5
	_viewport.add_child(light)


func _build_layout() -> void:
	var slot_style = StyleBoxFlat.new()
	slot_style.bg_color = Color(0.18, 0.15, 0.12, 0.9)
	slot_style.border_width_left = 1
	slot_style.border_width_top = 1
	slot_style.border_width_right = 1
	slot_style.border_width_bottom = 1
	slot_style.border_color = Color(0.45, 0.38, 0.25, 0.8)
	slot_style.corner_radius_top_left = 4
	slot_style.corner_radius_top_right = 4
	slot_style.corner_radius_bottom_right = 4
	slot_style.corner_radius_bottom_left = 4
	for row in SLOT_LAYOUT:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(hbox)
		for slot_name in row:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(150, 150)
			btn.add_theme_stylebox_override("normal", slot_style)
			btn.add_theme_font_size_override("font_size", 24)
			btn.add_theme_color_override("font_color", Color(0.5, 0.45, 0.35))
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = true
			if slot_name == "":
				btn.disabled = true
				btn.modulate = Color(1, 1, 1, 0.0)
			else:
				btn.text = slot_name
				btn.tooltip_text = slot_name
				btn.pressed.connect(_on_slot_pressed.bind(slot_name))
				_slot_buttons[slot_name] = btn
			hbox.add_child(btn)


func refresh() -> void:
	var eq_slots = PlayerEquipment.get("slots")
	if eq_slots == null:
		return
	var to_render: Array = []
	for slot_name in _slot_buttons:
		var btn = _slot_buttons[slot_name]
		var item = eq_slots.get(slot_name)
		if item == null:
			btn.text = slot_name
			btn.icon = null
		else:
			var mp = item.get("model_path")
			if mp and mp != "" and _icon_cache.has(mp):
				btn.icon = _icon_cache[mp]
				btn.text = ""
			elif mp and mp != "":
				btn.text = str(item.item_name).substr(0, 5)
				if not to_render.has(mp):
					to_render.append(mp)
			else:
				btn.text = str(item.item_name).substr(0, 5)
	_update_stats()
	if not to_render.is_empty():
		for p in to_render:
			_render_queue.append(p)
		_process_render_queue()


func _update_stats() -> void:
	var atk = PlayerEquipment.call("get_attack_bonus")
	var str_b = PlayerEquipment.call("get_strength_bonus")
	var def_b = PlayerEquipment.call("get_defence_bonus")
	if atk == null:
		atk = 0
	if str_b == null:
		str_b = 0
	if def_b == null:
		def_b = 0
	_stats_label.text = "Atk: +%d  Str: +%d  Def: +%d" % [atk, str_b, def_b]


func _on_slot_pressed(slot_name: String) -> void:
	PlayerEquipment.call("unequip_slot", slot_name)


func _process_render_queue() -> void:
	if _render_queue.is_empty():
		refresh()
		return
	var mp = _render_queue.pop_front()
	if _icon_cache.has(mp):
		_process_render_queue()
		return
	var scene = load(mp)
	if scene == null:
		_process_render_queue()
		return
	if _current_model:
		_current_model.queue_free()
		_current_model = null
	_current_model = scene.instantiate()
	_viewport.add_child(_current_model)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	var img = _viewport.get_texture().get_image()
	var tex = ImageTexture.create_from_image(img)
	_icon_cache[mp] = tex
	_current_model.queue_free()
	_current_model = null
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_process_render_queue()
