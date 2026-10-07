class_name DesktopCamera
extends Camera3D
## Desktop camera: move with the WASD keys (by physical position, so ZQSD on AZERTY),
## Q/E down/up, Shift faster; drag with the left or right mouse button (or use the arrow
## keys) to look around; scroll / two-finger swipe to move forward and back; R resets.

const MOVE_SPEED: float = 2.5
const SPRINT_MULTIPLIER: float = 3.0
const ACCELERATION: float = 10.0
const DRAG_SENSITIVITY: float = 0.004  ## [rad/pixel]
const KEY_TURN_SPEED: float = 1.5      ## [rad/s]
const SCROLL_STEP: float = 0.35        ## [m per wheel notch]
const FIT_DIRECTION := Vector3(0.0, 0.32, 1.0)  ## from the lab toward the camera

var _yaw: float = 0.0
var _pitch: float = 0.0
var _velocity: Vector3 = Vector3.ZERO
var _dragging: bool = false
var _home := Transform3D.IDENTITY
## True once the student has moved, so window resizes stop re-framing the view.
var _moved: bool = false


## Looks down at the lab from the front and backs off until every point fits inside the top
## free_fraction of the window (the rest is covered by the control strip). Becomes the R view.
func fit_view(points: PackedVector3Array, free_fraction: float) -> void:
	var window: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = window.x / window.y
	# Tiling window managers often give a tall window: keep the horizontal field of view then.
	keep_aspect = KEEP_WIDTH if aspect < 1.3 else KEEP_HEIGHT
	if _moved:
		return
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
				_home = global_transform
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
	_velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		match button.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				_dragging = button.pressed
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				var notches: float = button.factor if button.factor > 0.0 else 1.0
				var sign: float = 1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				global_position += -basis.z * SCROLL_STEP * notches * sign
				_moved = true
		return
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		_turn(-motion.relative.x * DRAG_SENSITIVITY, -motion.relative.y * DRAG_SENSITIVITY)
		return
	var gesture := event as InputEventPanGesture  # two-finger swipe on a touchpad
	if gesture:
		global_position += -basis.z * -gesture.delta.y * SCROLL_STEP
		_moved = true
		return
	if event.is_action_pressed("reset_view") and not event.is_echo():
		global_transform = _home
		reset_view(global_position, global_position - _home.basis.z)
		_moved = false


func _process(delta: float) -> void:
	var turn := Vector2(Input.get_axis("turn_right", "turn_left"), Input.get_axis("look_down", "look_up"))
	if turn != Vector2.ZERO:
		_turn(turn.x * KEY_TURN_SPEED * delta, turn.y * KEY_TURN_SPEED * delta)
	var input := Vector3(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_down", "move_up"),
		Input.get_axis("move_forward", "move_back"))
	var dir: Vector3 = basis * Vector3(input.x, 0.0, input.z) + Vector3.UP * input.y
	var speed: float = MOVE_SPEED * (SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") else 1.0)
	_velocity = _velocity.lerp(dir.limit_length(1.0) * speed, 1.0 - exp(-ACCELERATION * delta))
	if _velocity.length_squared() > 1e-6:
		global_position += _velocity * delta
		_moved = true


func _turn(yaw: float, pitch: float) -> void:
	_yaw += yaw
	_pitch = clampf(_pitch + pitch, -1.5, 1.5)
	rotation = Vector3(_pitch, _yaw, 0.0)
	_moved = true
