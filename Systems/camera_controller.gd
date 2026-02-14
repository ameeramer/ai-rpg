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

@onready var camera: Camera3D = $Camera3D

var _current_zoom: float
var _target_zoom: float


func _ready() -> void:
	_current_zoom = default_zoom
	_target_zoom = default_zoom

	# Set up the camera angle
	rotation_degrees.x = camera_angle

	# Connect to InputManager zoom signal
	InputManager.zoom_changed.connect(_on_zoom_changed)

	# Register this camera with the InputManager
	if camera:
		InputManager.set_camera(camera)


func _process(delta: float) -> void:
	# Follow target
	if target:
		var target_pos := target.global_position
		global_position = global_position.lerp(target_pos, follow_speed * delta)

	# Smooth zoom
	_current_zoom = lerp(_current_zoom, _target_zoom, zoom_speed * delta)
	if camera:
		camera.position.z = _current_zoom


func _on_zoom_changed(zoom_delta: float) -> void:
	_target_zoom = clamp(_target_zoom - zoom_delta, min_zoom, max_zoom)
