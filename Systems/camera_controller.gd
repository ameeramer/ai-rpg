class_name CameraController
extends Node3D
## OSRS-style isometric camera that follows the player.
## Supports zoom (scroll/pinch) and rotation.

@export var target: Node3D
@export var follow_speed: float = 8.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 20.0
@export var default_zoom: float = 12.0
@export var zoom_speed: float = 2.0
@export var camera_angle: float = -55.0  # OSRS-like top-down angle
@export var rotation_sensitivity: float = 0.3
@export var min_pitch: float = -80.0
@export var max_pitch: float = -10.0

@onready var camera: Camera3D = $Camera3D

var _current_zoom: float
var _target_zoom: float


func _ready() -> void:
	FileLogger.log_msg("CameraController._ready() start")
	_current_zoom = default_zoom
	_target_zoom = default_zoom

	# Set up the camera angle
	rotation_degrees.x = camera_angle

	# Connect to InputManager signals
	InputManager.zoom_changed.connect(_on_zoom_changed)
	var drag_sig = InputManager.get("camera_drag")
	if drag_sig:
		InputManager.camera_drag.connect(_on_camera_drag)

	# Register this camera with the InputManager
	if camera:
		InputManager.set_camera(camera)
		FileLogger.log_msg("Camera registered with InputManager")
	else:
		FileLogger.log_error("Camera3D child node not found!")
	FileLogger.log_msg("CameraController._ready() done")


func _process(delta: float) -> void:
	# Follow target
	if target:
		var target_pos := target.global_position
		global_position = global_position.lerp(target_pos, follow_speed * delta)

	# Smooth zoom
	_current_zoom = lerp(_current_zoom, _target_zoom, zoom_speed * delta)
	if camera:
		camera.position.z = _current_zoom


func _on_zoom_changed(zoom_delta) -> void:
	_target_zoom = clamp(_target_zoom - zoom_delta, min_zoom, max_zoom)


func _on_camera_drag(delta) -> void:
	rotation_degrees.y -= delta.x * rotation_sensitivity
	var new_pitch = rotation_degrees.x - delta.y * rotation_sensitivity
	rotation_degrees.x = clamp(new_pitch, min_pitch, max_pitch)
