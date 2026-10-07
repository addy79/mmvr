class_name DesktopKnobDrag
extends Node
## Desktop stand-in for the VR grab: left-drag any AxisKnob along its axis.
## Clicks that miss every knob fall through to the camera (drag to look around).

const RAY_LENGTH: float = 50.0

var _camera: Camera3D
var _knob: AxisKnob


func _init(camera: Camera3D) -> void:
	_camera = camera


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		if _knob:
			_knob.set_held(false)
			_knob = null
		if button.pressed:
			_knob = _knob_under(button.position)
			if _knob:
				_knob.set_held(true)
				get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion and _knob:
		_drag_to(motion.position)
		get_viewport().set_input_as_handled()


func _knob_under(screen_point: Vector2) -> AxisKnob:
	var from: Vector3 = _camera.project_ray_origin(screen_point)
	var to: Vector3 = from + _camera.project_ray_normal(screen_point) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, AxisKnob.HANDLES_LAYER)
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	var node: Node = hit.get("collider")
	while node and not node is AxisKnob:
		node = node.get_parent()
	return node as AxisKnob


## Moves the knob to the point of its axis closest to the mouse ray (on the plane that
## contains the axis and faces the camera best).
func _drag_to(screen_point: Vector2) -> void:
	var frame: Transform3D = (_knob.get_parent() as Node3D).global_transform
	var axis: Vector3 = frame.basis.x.normalized()
	var ray_dir: Vector3 = _camera.project_ray_normal(screen_point)
	var normal: Vector3 = axis.cross(axis.cross(ray_dir))
	if normal.length_squared() < 1e-6:
		return
	var anchor: Vector3 = frame.origin + frame.basis.y * _knob.grip.position.y + frame.basis.z * _knob.grip.position.z
	var plane := Plane(normal.normalized(), anchor)
	var hit: Variant = plane.intersects_ray(_camera.project_ray_origin(screen_point), ray_dir)
	if hit != null:
		_knob.move_slider((hit as Vector3 - frame.origin).dot(axis) / frame.basis.x.length())
