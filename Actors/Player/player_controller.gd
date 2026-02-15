class_name PlayerController
extends CharacterBody3D
## Main player controller. Uses a StateMachine for behavior.
## Skills + inventory are embedded directly — set_script() does NOT work on Android.

@export var move_speed: float = 4.0
@export var interaction_range: float = 3.0

@onready var state_machine: Node = $StateMachine
@onready var nav_agent: Node = $NavigationAgent3D
@onready var anim_player: Node = $AnimationPlayer
@onready var model: Node3D = $Model

## Current target for interaction (set by InputManager signals)
var target_object: Node3D = null
var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false

## Player stats
var hitpoints: int = 10
var max_hitpoints: int = 10

# ── Skills data (embedded — set_script() doesn't work on Android) ──

var SKILL_NAMES: Array = [
	"Attack", "Strength", "Defence", "Hitpoints",
	"Ranged", "Prayer", "Magic",
	"Cooking", "Woodcutting", "Fishing", "Mining",
	"Smithing", "Crafting", "Firemaking",
	"Agility", "Thieving"
]

var skill_xp: Dictionary = {}
var skill_levels: Dictionary = {}

signal xp_gained(skill_name, amount, total_xp)
signal level_up(skill_name, new_level)

# ── Inventory data (embedded) ──

var MAX_SLOTS: int = 28

signal item_added(item, quantity, slot)
signal item_removed(item, quantity, slot)
signal inventory_changed()
signal inventory_full()

## Each slot is {"item": ItemData, "quantity": int} or null
var slots: Array = []

var _initialized: bool = false


func _ready() -> void:
	FileLogger.log_msg("PlayerController._ready() start")
	ensure_initialized()
	FileLogger.log_msg("PlayerController._ready() done")


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	FileLogger.log_msg("PlayerController.ensure_initialized() running")

	# Connect to InputManager signals
	if not InputManager.world_clicked.is_connected(_on_world_clicked):
		InputManager.world_clicked.connect(_on_world_clicked)
	if not InputManager.object_clicked.is_connected(_on_object_clicked):
		InputManager.object_clicked.connect(_on_object_clicked)

	# Configure navigation agent
	nav_agent = get_node_or_null("NavigationAgent3D")
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
		nav_agent.max_speed = move_speed

	# Resolve @onready nodes manually (may be null if _ready didn't fire)
	if state_machine == null:
		state_machine = get_node_or_null("StateMachine")
	if model == null:
		model = get_node_or_null("Model")

	# Add to player group for easy lookup
	add_to_group("player")

	# Initialize skills + inventory directly — no child nodes needed
	_init_skills()
	_init_inventory()
	FileLogger.log_msg("PlayerController init done: %d skills, %d slots" % [skill_levels.size(), slots.size()])


# ── Skills ──

func _init_skills() -> void:
	for skill in SKILL_NAMES:
		if skill == "Hitpoints":
			skill_xp[skill] = _xp_for_level(10)
			skill_levels[skill] = 10
		else:
			skill_xp[skill] = 0.0
			skill_levels[skill] = 1


func get_level(skill_name: String) -> int:
	return skill_levels.get(skill_name, 1)


func get_xp(skill_name: String) -> float:
	return skill_xp.get(skill_name, 0.0)


func get_xp_to_next_level(skill_name: String) -> float:
	var current_level := get_level(skill_name)
	if current_level >= 99:
		return 0.0
	return _xp_for_level(current_level + 1) - get_xp(skill_name)


func get_level_progress(skill_name: String) -> float:
	var current_level := get_level(skill_name)
	if current_level >= 99:
		return 1.0
	var current_level_xp := _xp_for_level(current_level)
	var next_level_xp := _xp_for_level(current_level + 1)
	return (get_xp(skill_name) - current_level_xp) / (next_level_xp - current_level_xp)


func add_xp(skill_name: String, amount: float) -> void:
	if not skill_xp.has(skill_name):
		return
	skill_xp[skill_name] += amount
	xp_gained.emit(skill_name, amount, skill_xp[skill_name])
	var new_level := _level_for_xp(skill_xp[skill_name])
	if new_level > skill_levels[skill_name]:
		skill_levels[skill_name] = new_level
		level_up.emit(skill_name, new_level)
		GameManager.log_action("Congratulations! Your %s level is now %d!" % [skill_name, new_level])
		if skill_name == "Hitpoints":
			max_hitpoints = new_level
			hitpoints = max_hitpoints


func add_combat_xp(total_xp: float) -> void:
	add_xp("Attack", total_xp * 0.75)
	add_xp("Hitpoints", total_xp * 0.25)


func get_combat_level() -> int:
	var base := 0.25 * (get_level("Defence") + get_level("Hitpoints") + floorf(get_level("Prayer") / 2.0))
	var melee := 0.325 * (get_level("Attack") + get_level("Strength"))
	var ranged := 0.325 * (floorf(get_level("Ranged") / 2.0) + get_level("Ranged"))
	var magic := 0.325 * (floorf(get_level("Magic") / 2.0) + get_level("Magic"))
	return int(base + max(melee, max(ranged, magic)))


func _xp_for_level(level: int) -> float:
	var total: float = 0.0
	for i in range(1, level):
		total += floorf(i + 300.0 * pow(2.0, i / 7.0))
	return floorf(total / 4.0)


func _level_for_xp(xp: float) -> int:
	for level in range(99, 0, -1):
		if xp >= _xp_for_level(level):
			return level
	return 1


# ── Inventory ──

func _init_inventory() -> void:
	slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		slots[i] = null


func add_item(item, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false
	if item.is_stackable:
		for i in range(MAX_SLOTS):
			if slots[i] != null and slots[i]["item"].id == item.id:
				slots[i]["quantity"] += quantity
				item_added.emit(item, quantity, i)
				inventory_changed.emit()
				return true
	if item.is_stackable:
		var slot := _find_empty_slot()
		if slot == -1:
			inventory_full.emit()
			return false
		slots[slot] = {"item": item, "quantity": quantity}
		item_added.emit(item, quantity, slot)
		inventory_changed.emit()
		return true
	else:
		var added_count := 0
		for _q in range(quantity):
			var slot := _find_empty_slot()
			if slot == -1:
				if added_count == 0:
					inventory_full.emit()
					return false
				inventory_changed.emit()
				return true
			slots[slot] = {"item": item, "quantity": 1}
			item_added.emit(item, 1, slot)
			added_count += 1
		inventory_changed.emit()
		return true


func remove_item_at(slot: int, quantity: int = 1) -> Dictionary:
	if slot < 0 or slot >= MAX_SLOTS or slots[slot] == null:
		return {}
	var slot_data: Dictionary = slots[slot]
	var removed_qty := min(quantity, slot_data["quantity"])
	slot_data["quantity"] -= removed_qty
	if slot_data["quantity"] <= 0:
		slots[slot] = null
	item_removed.emit(slot_data["item"], removed_qty, slot)
	inventory_changed.emit()
	return {"item": slot_data["item"], "quantity": removed_qty}


func remove_item_by_id(item_id: int, quantity: int = 1) -> bool:
	var remaining := quantity
	for i in range(MAX_SLOTS):
		if remaining <= 0:
			break
		if slots[i] != null and slots[i]["item"].id == item_id:
			var can_remove := min(remaining, slots[i]["quantity"])
			slots[i]["quantity"] -= can_remove
			remaining -= can_remove
			if slots[i]["quantity"] <= 0:
				slots[i] = null
	if remaining < quantity:
		inventory_changed.emit()
		return remaining == 0
	return false


func get_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= MAX_SLOTS or slots[slot] == null:
		return {}
	return slots[slot]


func has_item(item_id: int, quantity: int = 1) -> bool:
	var total := 0
	for slot in slots:
		if slot != null and slot["item"].id == item_id:
			total += slot["quantity"]
			if total >= quantity:
				return true
	return false


func count_item(item_id: int) -> int:
	var total := 0
	for slot in slots:
		if slot != null and slot["item"].id == item_id:
			total += slot["quantity"]
	return total


func swap_slots(from: int, to: int) -> void:
	if from < 0 or from >= MAX_SLOTS or to < 0 or to >= MAX_SLOTS:
		return
	var temp = slots[from]
	slots[from] = slots[to]
	slots[to] = temp
	inventory_changed.emit()


func get_used_slots() -> int:
	var count := 0
	for slot in slots:
		if slot != null:
			count += 1
	return count


func is_full() -> bool:
	return get_used_slots() >= MAX_SLOTS


func _find_empty_slot() -> int:
	for i in range(MAX_SLOTS):
		if slots[i] == null:
			return i
	return -1


# ── Movement & combat ──

func _on_world_clicked(world_pos: Vector3, _normal: Vector3) -> void:
	if is_dead_state():
		return
	target_object = null
	target_position = world_pos
	state_machine.transition_to("Moving", {"target": world_pos})


func _on_object_clicked(object: Node3D, _hit_pos: Vector3) -> void:
	if is_dead_state():
		return

	target_object = object
	target_position = object.global_position

	var obj_layer: int = object.get("collision_layer") if object.get("collision_layer") != null else 0
	var dist := global_position.distance_to(object.global_position)

	if obj_layer == 4:
		var is_dead = object.get("_is_dead")
		if is_dead != null and is_dead:
			return
		if dist <= interaction_range:
			state_machine.transition_to("Combat", {"target": object})
		else:
			state_machine.transition_to("Moving", {
				"target": object.global_position,
				"interact_on_arrive": true,
				"interact_target": object
			})
		return

	if obj_layer == 8:
		if object.get("_is_depleted"):
			state_machine.transition_to("Moving", {"target": object.global_position})
			return
		if dist <= interaction_range:
			state_machine.transition_to("Interacting", {"target": object})
		else:
			state_machine.transition_to("Moving", {
				"target": object.global_position,
				"interact_on_arrive": true,
				"interact_target": object
			})
		return


func move_toward_target(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		is_moving = false
		return
	var next_pos := nav_agent.get_next_path_position()
	var direction := (next_pos - global_position).normalized()
	direction.y = 0
	if direction.length() > 0.01:
		var look_target := global_position + direction
		look_target.y = global_position.y
		if look_target.distance_to(global_position) > 0.01:
			look_at(look_target, Vector3.UP)
	velocity = direction * move_speed
	move_and_slide()
	is_moving = true


func set_nav_target(pos: Vector3) -> void:
	nav_agent.target_position = pos


func is_at_target() -> bool:
	return nav_agent.is_navigation_finished()


func is_in_range_of(target: Node3D) -> bool:
	return global_position.distance_to(target.global_position) <= interaction_range


func is_dead_state() -> bool:
	return hitpoints <= 0


func take_damage(amount: int) -> void:
	if hitpoints <= 0:
		return
	hitpoints = max(0, hitpoints - amount)
	play_damage_flash()
	_show_hitsplat(amount)
	GameManager.log_action("You take %d damage. HP: %d/%d" % [amount, hitpoints, max_hitpoints])
	if hitpoints <= 0:
		_die()


func _show_hitsplat(amount: int) -> void:
	var label := Label3D.new()
	label.text = str(amount) if amount > 0 else "Miss"
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0)
	if amount > 0:
		label.modulate = Color(1, 0.15, 0.15)
	else:
		label.modulate = Color(0.6, 0.6, 0.6)
	label.position.y = 2.2
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", 3.5, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


func heal(amount: int) -> void:
	hitpoints = min(max_hitpoints, hitpoints + amount)


func _die() -> void:
	GameManager.log_action("Oh dear, you are dead!")
	state_machine.transition_to("Dead")


func play_attack_animation() -> void:
	if not model:
		return
	var tween := create_tween()
	tween.tween_property(model, "rotation_degrees:y", -30.0, 0.08)
	tween.tween_property(model, "rotation_degrees:y", 15.0, 0.06)
	tween.tween_property(model, "rotation_degrees:y", 0.0, 0.06)


func play_damage_flash() -> void:
	if not model:
		return
	var parts: Array = []
	for child in model.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			parts.append({"mat": child.material_override, "color": child.material_override.albedo_color})
	if parts.is_empty():
		return
	var tween := create_tween()
	tween.set_parallel(true)
	for p in parts:
		tween.tween_property(p["mat"], "albedo_color", Color(1, 0.2, 0.2), 0.05)
	tween.set_parallel(false)
	tween.tween_interval(0.05)
	tween.set_parallel(true)
	for p in parts:
		tween.tween_property(p["mat"], "albedo_color", p["color"], 0.15)
