extends Node
## InputManager — Unified input handling for both mouse (PC) and touch (Android).
## Converts all input into world-space actions.

## Emitted when the player taps/clicks a point in the 3D world.
signal world_clicked(position: Vector3, normal: Vector3)

## Emitted when the player taps/clicks on a Node3D (e.g., an enemy, tree, NPC).
signal object_clicked(object: Node3D, position: Vector3)

## Emitted when the player long-presses / right-clicks an object (context menu).
signal object_context(object: Node3D, screen_position: Vector2)

## Emitted on pinch zoom (mobile) or scroll wheel (PC).
signal zoom_changed(delta: float)

## Ray length for raycasting from camera
const RAY_LENGTH: float = 1000.0

## Long press threshold in seconds (for right-click equivalent on mobile)
const LONG_PRESS_THRESHOLD: float = 0.5

var _touch_start_time: float = 0.0
var _touch_start_pos: Vector2 = Vector2.ZERO
var _is_touching: bool = false
var _camera: Camera3D


func set_camera(camera: Camera3D) -> void:
	_camera = camera


func _unhandled_input(event: InputEvent) -> void:
	# Handle mouse click (PC debug)
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)

	# Handle touch input (Android)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)

	# Handle scroll wheel zoom (PC)
	if event.is_action_pressed("camera_zoom_in"):
		zoom_changed.emit(1.0)
	elif event.is_action_pressed("camera_zoom_out"):
		zoom_changed.emit(-1.0)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_do_raycast(event.position, false)
	elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_do_raycast(event.position, true)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_start_time = Time.get_ticks_msec() / 1000.0
		_touch_start_pos = event.position
		_is_touching = true
	elif _is_touching:
		_is_touching = false
		var hold_duration := (Time.get_ticks_msec() / 1000.0) - _touch_start_time
		var drag_distance := event.position.distance_to(_touch_start_pos)

		# Only process as tap if finger didn't move much (not a drag/pan)
		if drag_distance < 20.0:
			var is_long_press := hold_duration >= LONG_PRESS_THRESHOLD
			_do_raycast(event.position, is_long_press)


func _do_raycast(screen_pos: Vector2, is_context: bool) -> void:
	if _camera == null:
		return

	var from := _camera.project_ray_origin(screen_pos)
	var to := from + _camera.project_ray_normal(screen_pos) * RAY_LENGTH

	var space_state := _camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	# Exclude player layer (2) from raycast — only hit world(1), enemies(4), interactables(8)
	query.collision_mask = 1 | 4 | 8

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return

	var hit_position: Vector3 = result["position"]
	var hit_normal: Vector3 = result["normal"]
	var collider: Node3D = result["collider"]

	FileLogger.log_msg("Raycast hit: %s (class: %s, layer: %d, groups: %s) at %s" % [
		collider.name, collider.get_class(),
		collider.get("collision_layer") if collider.get("collision_layer") != null else -1,
		str(collider.get_groups()),
		str(hit_position)])

	# Check if collider or any ancestor is an enemy (using group "enemies")
	var enemy := _find_in_group(collider, "enemies")
	if enemy:
		FileLogger.log_msg("Detected enemy: %s" % enemy.name)
		if is_context:
			object_context.emit(enemy, screen_pos)
		else:
			object_clicked.emit(enemy, hit_position)
		return

	# Check if collider or any ancestor is an interactable (using group "interactables")
	var interactable := _find_in_group(collider, "interactables")
	if interactable:
		FileLogger.log_msg("Detected interactable: %s" % interactable.name)
		if is_context:
			object_context.emit(interactable, screen_pos)
		else:
			object_clicked.emit(interactable, hit_position)
		return

	# Otherwise it's a ground click — move there
	FileLogger.log_msg("Ground click at %s (collider: %s)" % [str(hit_position), collider.name])
	if not is_context:
		world_clicked.emit(hit_position, hit_normal)


## Walk up the node tree from the hit collider to find an ancestor in the given group.
func _find_in_group(node: Node, group_name: String) -> Node3D:
	var current: Node = node
	while current:
		if current.is_in_group(group_name):
			return current as Node3D
		current = current.get_parent()
	return null
