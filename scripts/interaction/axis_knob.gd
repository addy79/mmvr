class_name AxisKnob
extends XRToolsInteractableSlider
## A grabbable knob that slides along its parent's local X axis between two limits.
## In VR grab it with grip (XR Tools handle); on desktop DesktopKnobDrag moves it.
## Anything added as a child moves with it. `grip` can be offset to put the knob where
## the hand should take it. Emits the inherited slider_moved(position).

const HANDLES_LAYER: int = 1 << 18  ## XR Tools "handles" physics layer
const RADIUS: float = 0.06

var grip: Node3D = Node3D.new()
var handle: XRToolsInteractableHandle = XRToolsInteractableHandle.new()
var _material: StandardMaterial3D = StandardMaterial3D.new()
var _color: Color


func _init(lo: float, hi: float, color := Color(1.0, 0.8, 0.1)) -> void:
	slider_limit_min = lo
	slider_limit_max = hi
	_color = color
	add_child(grip)
	_material.albedo_color = color
	_material.emission_enabled = true
	_material.emission = color * 0.25
	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	knob.mesh = sphere
	knob.material_override = _material
	grip.add_child(knob)
	handle.collision_layer = HANDLES_LAYER
	handle.collision_mask = 0
	handle.gravity_scale = 0.0
	handle.picked_up_layer = 0
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = RADIUS * 1.6
	shape.shape = ball
	handle.add_child(shape)
	grip.add_child(handle)
	visibility_changed.connect(func() -> void:
		handle.collision_layer = HANDLES_LAYER if is_visible_in_tree() else 0)
	grabbed.connect(func(_s: XRToolsInteractableSlider) -> void: set_held(true))
	released.connect(func(_s: XRToolsInteractableSlider) -> void: set_held(false))


func set_value(v: float) -> void:
	slider_position = v


## Lights the knob while it is held (VR grip or desktop mouse).
func set_held(held: bool) -> void:
	var c: Color = _color.lightened(0.5) if held else _color
	_material.albedo_color = c
	_material.emission = c * (0.6 if held else 0.25)
