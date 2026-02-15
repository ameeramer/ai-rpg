extends Node
## InputManager — Unified input handling for both mouse (PC) and touch (Android).
## Converts all input into world-space actions.

## Emitted when the player taps/clicks a point in the 3D world.
signal world_clicked(position, normal)

## Emitted when the player taps/clicks on a Node3D (e.g., an enemy, tree, NPC).
signal object_clicked(object, position)

## Emitted when the player long-presses / right-clicks an object (context menu).
signal object_context(object, screen_position)

## Emitted on pinch zoom (mobile) or scroll wheel (PC).
signal zoom_changed(delta)

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

	# Detect by collision_layer value — proven reliable on Android
	# Layer values: 1=world, 2=player, 4=enemies, 8=interactables
	var layer: int = collider.get("collision_layer") if collider.get("collision_layer") != null else 0

	if layer == 4:
		# Enemy — collision layer 4
		FileLogger.log_msg("Detected enemy: %s (layer %d)" % [collider.name, layer])
		if is_context:
			object_context.emit(collider, screen_pos)
		else:
			object_clicked.emit(collider, hit_position)
		return

	if layer == 8:
		# Interactable — collision layer 8
		FileLogger.log_msg("Detected interactable: %s (layer %d)" % [collider.name, layer])
		if is_context:
			object_context.emit(collider, screen_pos)
		else:
			object_clicked.emit(collider, hit_position)
		return

	# Otherwise it's a ground click — move there
	FileLogger.log_msg("Ground click at %s (collider: %s, layer: %d)" % [str(hit_position), collider.name, layer])
	if not is_context:
		world_clicked.emit(hit_position, hit_normal)
