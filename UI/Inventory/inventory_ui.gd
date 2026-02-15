extends GridContainer

var SLOT_SIZE = Vector2(110, 110)
var SLOT_COUNT: int = 28
var ICON_RES: int = 128

var _slot_buttons: Array = []
var _icon_cache: Dictionary = {}
var _viewport: SubViewport
var _cam: Camera3D
var _light: DirectionalLight3D
var _render_queue: Array = []
var _current_model: Node3D

func _ready() -> void:
	FileLogger.log_msg("InventoryUI._ready() start")
	columns = 4
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	_setup_render_viewport()
	_create_slots()
	FileLogger.log_msg("InventoryUI._ready() done, %d buttons" % _slot_buttons.size())

func setup() -> void:
	FileLogger.log_msg("InventoryUI.setup() start")
	var sig = PlayerInventory.get("inventory_changed")
	if sig:
		PlayerInventory.inventory_changed.connect(refresh)
		FileLogger.log_msg("InventoryUI: connected to inventory_changed")
	else:
		FileLogger.log_msg("InventoryUI: WARNING — no inventory_changed signal")
	refresh()
	FileLogger.log_msg("InventoryUI.setup() done")

func _setup_render_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(ICON_RES, ICON_RES)
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
	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-45, 30, 0)
	_light.light_energy = 1.5
	_viewport.add_child(_light)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -60, 0)
	fill.light_energy = 0.4
	_viewport.add_child(fill)

func _create_slots() -> void:
	var slot_normal = StyleBoxFlat.new()
	slot_normal.bg_color = Color(0.18, 0.15, 0.12, 0.9)
	slot_normal.border_width_left = 1
	slot_normal.border_width_top = 1
	slot_normal.border_width_right = 1
	slot_normal.border_width_bottom = 1
	slot_normal.border_color = Color(0.35, 0.3, 0.2, 0.8)
	slot_normal.corner_radius_top_left = 3
	slot_normal.corner_radius_top_right = 3
	slot_normal.corner_radius_bottom_right = 3
	slot_normal.corner_radius_bottom_left = 3
	var slot_hover = StyleBoxFlat.new()
	slot_hover.bg_color = Color(0.25, 0.22, 0.16, 0.95)
	slot_hover.border_width_left = 1
	slot_hover.border_width_top = 1
	slot_hover.border_width_right = 1
	slot_hover.border_width_bottom = 1
	slot_hover.border_color = Color(0.6, 0.5, 0.3, 1)
	slot_hover.corner_radius_top_left = 3
	slot_hover.corner_radius_top_right = 3
	slot_hover.corner_radius_bottom_right = 3
	slot_hover.corner_radius_bottom_left = 3
	for i in range(SLOT_COUNT):
		var btn = Button.new()
		btn.custom_minimum_size = SLOT_SIZE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.add_theme_stylebox_override("normal", slot_normal)
		btn.add_theme_stylebox_override("hover", slot_hover)
		btn.add_theme_stylebox_override("pressed", slot_hover)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
		btn.text = ""
		btn.pressed.connect(_on_slot_pressed.bind(i))
		add_child(btn)
		_slot_buttons.append(btn)

func refresh() -> void:
	var inv_slots = PlayerInventory.get("slots")
	if inv_slots == null:
		return
	var paths_to_render: Array = []
	for i in range(SLOT_COUNT):
		var btn = _slot_buttons[i]
		var slot_data = inv_slots[i] if i < inv_slots.size() else null
		if slot_data == null:
			btn.text = ""
			btn.icon = null
			btn.tooltip_text = "Empty"
		else:
			var item = slot_data["item"]
			var qty: int = slot_data["quantity"]
			btn.tooltip_text = item.call("get_display_name")
			var mp = item.get("model_path")
			if mp and mp != "" and _icon_cache.has(mp):
				btn.icon = _icon_cache[mp]
				btn.text = str(qty) if qty > 1 else ""
			elif mp and mp != "":
				btn.text = str(item.item_name).substr(0, 6)
				if qty > 1:
					btn.text += "\nx" + str(qty)
				if not paths_to_render.has(mp):
					paths_to_render.append(mp)
			elif item.get("icon"):
				btn.icon = item.icon
				btn.text = str(qty) if qty > 1 else ""
			else:
				var dt = str(item.item_name).substr(0, 6)
				if qty > 1:
					dt += "\nx" + str(qty)
				btn.text = dt
	if not paths_to_render.is_empty():
		for p in paths_to_render:
			_render_queue.append(p)
		_process_render_queue()

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
		FileLogger.log_msg("InventoryUI: failed to load model: " + mp)
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

func _on_slot_pressed(slot_index: int) -> void:
	var inv_slots = PlayerInventory.get("slots")
	if inv_slots == null:
		return
	if slot_index >= inv_slots.size() or inv_slots[slot_index] == null:
		return
	var item = inv_slots[slot_index]["item"]
	# Show context menu — find the HUD parent and call show_context_menu
	var btn = _slot_buttons[slot_index]
	var pos = btn.global_position + Vector2(btn.size.x, 0)
	var hud = _find_hud()
	if hud:
		hud.call("show_context_menu", item, slot_index, pos)

func _find_hud() -> Node:
	var node = get_parent()
	while node:
		if node.get("show_context_menu") != null:
			return node
		node = node.get_parent()
	return null
