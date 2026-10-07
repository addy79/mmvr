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


## Looks down at the bench from the front and finds the closest view that shows every point
## inside `free` (window fractions not covered by panels). Becomes the R view.
func fit_view(points: PackedVector3Array, free: Rect2) -> void:
	var window: Vector2 = get_viewport().get_visible_rect().size
	if window.y <= 0.0 or points.is_empty():
		return
	var aspect: float = window.x / window.y
	# Tiling window managers often give a tall window: keep the horizontal field of view then.
	keep_aspect = KEEP_WIDTH if aspect < 1.3 else KEEP_HEIGHT
	if _moved:
		return
	var tan_half: float = tan(deg_to_rad(fov) / 2.0)
	var tan_h: float = tan_half if keep_aspect == KEEP_WIDTH else tan_half * aspect
	var tan_v: float = tan_h / aspect
	# Free region in normalized device coordinates (x right, y up, both -1..1), with a margin.
	var ndc := Rect2(2.0 * free.position.x - 1.0, 1.0 - 2.0 * free.end.y,
			2.0 * free.size.x, 2.0 * free.size.y).grow(-0.05)
	var center := Vector3.ZERO
	for p: Vector3 in points:
		center += p
	center /= points.size()
	var back := FIT_DIRECTION.normalized()
	var look := Basis.looking_at(-back)
	for step: int in 150:
		var distance: float = 1.2 + step * 0.1
		var target: Vector3 = center
		var box := Rect2()
		for iteration: int in 4:
			var view: Transform3D = Transform3D(look, target + back * distance).affine_inverse()
			var depth: float = 0.0
			box = Rect2()
			for i: int in points.size():
				var q: Vector3 = view * points[i]
				var p := Vector2(q.x / (-q.z * tan_h), q.y / (-q.z * tan_v))
				box = Rect2(p, Vector2.ZERO) if i == 0 else box.expand(p)
				depth += -q.z / points.size()
			# Slide the camera so the points' box is centred in the free region.
			var shift: Vector2 = ndc.get_center() - box.get_center()
			target += look.x * (-shift.x * depth * tan_h) + look.y * (-shift.y * depth * tan_v)
		if ndc.encloses(box):
			reset_view(target + back * distance, target)
			_home = global_transform
			return


## Lets the next fit_view move the camera again (e.g. after switching stations).
func release_view() -> void:
	_moved = false


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
