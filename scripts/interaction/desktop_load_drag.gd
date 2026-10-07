class_name DesktopLoadDrag
extends Node
## Desktop stand-in for the VR grab: left-drag the load's knob along the beam, or nudge
## the load with the arrow keys.

const NUDGE_SPEED: float = 0.8  ## [m/s]
const RAY_LENGTH: float = 50.0

var _camera: Camera3D
var _load: LoadHandle
var _dragging: bool = false


func _init(camera: Camera3D, load_handle: LoadHandle) -> void:
	_camera = camera
	_load = load_handle


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed and _knob_under(button.position)
		_load.set_held(_dragging)
		if _dragging:
			get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		_drag_to(motion.position)


func _process(delta: float) -> void:
	var axis: float = Input.get_axis("load_left", "load_right")
	if axis != 0.0:
		_load.move_slider(_load.slider_position + axis * NUDGE_SPEED * delta)


func _knob_under(screen_point: Vector2) -> bool:
	var from: Vector3 = _camera.project_ray_origin(screen_point)
	var to: Vector3 = from + _camera.project_ray_normal(screen_point) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, LoadHandle.HANDLES_LAYER)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _load.handle


## Moves the load to where the mouse ray crosses the beam's vertical plane.
func _drag_to(screen_point: Vector2) -> void:
	var frame: Transform3D = (_load.get_parent() as Node3D).global_transform
	var plane := Plane(frame.basis.z.normalized(), frame.origin)
	var hit: Variant = plane.intersects_ray(
			_camera.project_ray_origin(screen_point), _camera.project_ray_normal(screen_point))
	if hit != null:
		_load.move_slider((frame.affine_inverse() * (hit as Vector3)).x)
