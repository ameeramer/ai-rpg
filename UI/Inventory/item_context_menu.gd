extends PanelContainer
## Context menu popup for inventory items — shows on long-press/right-click.
## Actions: Eat, Equip, Bury, Drop, Examine, Cook, Use.

signal action_selected(action, slot_idx)

var _slot_idx: int = -1
var _item = null
var _vbox: VBoxContainer


func _ready() -> void:
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.07, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.55, 0.45, 0.28, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)


func show_for_item(item, slot_idx: int, screen_pos: Vector2) -> void:
	_item = item
	_slot_idx = slot_idx
	# Clear old buttons
	for child in _vbox.get_children():
		child.queue_free()
	# Add item name header
	var header = Label.new()
	header.text = item.call("get_display_name")
	header.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	header.add_theme_font_size_override("font_size", 26)
	_vbox.add_child(header)
	# Determine available actions
	var actions = _get_actions_for_item(item)
	for action in actions:
		_add_action_button(action)
	# Position near the tap
	var vp_size = get_viewport().get_visible_rect().size
	var px = screen_pos.x
	var py = screen_pos.y
	if px + 200 > vp_size.x:
		px = vp_size.x - 200
	if py + 300 > vp_size.y:
		py = vp_size.y - 300
	position = Vector2(px, py)
	visible = true


func _get_actions_for_item(item) -> Array:
	var actions: Array = []
	var cat = item.get("category")
	var heal = item.get("heal_amount")
	var equippable = item.get("is_equippable")
	var cooked_id = item.get("cooked_item_id")
	var item_id = item.get("id")
	# Eat — cooked food with healing
	if heal != null and heal > 0:
		actions.append("Eat")
	# Cook — raw food with cooked_item_id
	if cooked_id != null and cooked_id > 0 and (heal == null or heal <= 0):
		actions.append("Cook")
	# Equip — weapons and armor
	if equippable:
		actions.append("Equip")
	# Bury — bones (id 526)
	if item_id == 526:
		actions.append("Bury")
	# Drop and Examine always available
	actions.append("Drop")
	actions.append("Examine")
	return actions


func _add_action_button(action_name: String) -> void:
	var btn = Button.new()
	btn.text = action_name
	btn.custom_minimum_size = Vector2(200, 60)
	btn.add_theme_font_size_override("font_size", 26)
	var style_n = StyleBoxFlat.new()
	style_n.bg_color = Color(0.18, 0.15, 0.1, 0.9)
	style_n.corner_radius_top_left = 4
	style_n.corner_radius_top_right = 4
	style_n.corner_radius_bottom_right = 4
	style_n.corner_radius_bottom_left = 4
	btn.add_theme_stylebox_override("normal", style_n)
	var style_h = StyleBoxFlat.new()
	style_h.bg_color = Color(0.3, 0.25, 0.15, 0.95)
	style_h.corner_radius_top_left = 4
	style_h.corner_radius_top_right = 4
	style_h.corner_radius_bottom_right = 4
	style_h.corner_radius_bottom_left = 4
	btn.add_theme_stylebox_override("hover", style_h)
	btn.add_theme_stylebox_override("pressed", style_h)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	btn.pressed.connect(_on_action.bind(action_name))
	_vbox.add_child(btn)


func _on_action(action_name: String) -> void:
	action_selected.emit(action_name, _slot_idx)
	visible = false
