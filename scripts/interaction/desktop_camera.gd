class_name DesktopCamera
extends Camera3D
## Desktop free-fly camera: WASD move, Q/E down/up, Shift faster, hold right mouse to look.

const MOVE_SPEED: float = 2.5
const SPRINT_MULTIPLIER: float = 3.0
const ACCELERATION: float = 10.0
const MOUSE_SENSITIVITY: float = 0.0025
const FIT_DIRECTION := Vector3(0.0, 0.32, 1.0)  ## from the lab toward the camera

var _yaw: float = 0.0
var _pitch: float = 0.0
var _velocity: Vector3 = Vector3.ZERO


## Looks down at the lab from the front and backs off until every point fits inside the top
## free_fraction of the window (the rest is covered by the control strip).
func fit_view(points: PackedVector3Array, free_fraction: float) -> void:
	var window: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = window.x / window.y
	# Tiling window managers often give a tall window: keep the horizontal field of view then.
	keep_aspect = KEEP_WIDTH if aspect < 1.3 else KEEP_HEIGHT
	var tan_half: float = tan(deg_to_rad(fov) / 2.0)
	var tan_h: float = tan_half if keep_aspect == KEEP_WIDTH else tan_half * aspect
	var tan_v: float = tan_h / aspect
	var bounds := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		bounds = bounds.expand(p)
	var back := FIT_DIRECTION.normalized()
	var look := Basis.looking_at(-back)
	var ndc_bottom: float = 1.0 - 2.0 * free_fraction + 0.04
	for step: int in 120:
		var distance: float = 2.0 + step * 0.1
		for k: int in 50:
			var target := Vector3(bounds.get_center().x, bounds.position.y - 1.0 + k * 0.06, bounds.get_center().z)
			var view: Transform3D = Transform3D(look, target + back * distance).affine_inverse()
			if _all_inside(view, points, tan_h, tan_v, ndc_bottom):
				reset_view(target + back * distance, target)
				return


static func _all_inside(view: Transform3D, points: PackedVector3Array, tan_h: float, tan_v: float,
		ndc_bottom: float) -> bool:
	for p: Vector3 in points:
		var q: Vector3 = view * p
		if q.z > -0.1:
			return false
		var x: float = q.x / (-q.z * tan_h)
		var y: float = q.y / (-q.z * tan_v)
		if absf(x) > 0.96 or y > 0.96 or y < ndc_bottom:
			return false
	return true


## Places the camera at pos looking at target. Call once the camera is in the tree.
func reset_view(pos: Vector3, target: Vector3) -> void:
	global_position = pos
	look_at(target)
	_pitch = rotation.x
	_yaw = rotation.y


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if button.pressed else Input.MOUSE_MODE_VISIBLE
		return
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= motion.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - motion.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
		rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	var input := Vector3(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_down", "move_up"),
		Input.get_axis("move_forward", "move_back"))
	var dir: Vector3 = basis * Vector3(input.x, 0.0, input.z) + Vector3.UP * input.y
	var speed: float = MOVE_SPEED * (SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") else 1.0)
	_velocity = _velocity.lerp(dir.limit_length(1.0) * speed, 1.0 - exp(-ACCELERATION * delta))
	global_position += _velocity * delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
