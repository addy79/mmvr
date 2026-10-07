class_name LoadHandle
extends XRToolsInteractableSlider
## The point load P: an arrow sliding along the beam axis (local x = a). In VR, grab the
## yellow knob (an XR Tools handle) with grip; on desktop, DesktopLoadDrag moves it.
## The inherited slider_moved(position) signal reports student moves.

const HANDLES_LAYER: int = 1 << 18  ## XR Tools "handles" physics layer
const ARROW_LENGTH: float = 0.45
const HEAD_LENGTH: float = 0.12
const KNOB_RADIUS: float = 0.06
const IDLE_COLOR := Color(1.0, 0.8, 0.1)
const HELD_COLOR := Color(1.0, 1.0, 0.6)

var handle: XRToolsInteractableHandle = XRToolsInteractableHandle.new()

var _arrow: Node3D = Node3D.new()
var _label: Label3D = Label3D.new()
var _knob_material: StandardMaterial3D = StandardMaterial3D.new()
var _beam: SimplySupportedBeam
var _exaggeration: float = 1.0


func _init(length: float) -> void:
	slider_limit_max = length
	add_child(_arrow)
	var arrow_material := StandardMaterial3D.new()
	arrow_material.albedo_color = Color(0.9, 0.9, 0.95)
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 0.05
	head.height = HEAD_LENGTH
	_add_mesh(_arrow, head, HEAD_LENGTH / 2.0, arrow_material).rotation.x = PI
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.015
	shaft.bottom_radius = 0.015
	shaft.height = ARROW_LENGTH - HEAD_LENGTH
	_add_mesh(_arrow, shaft, HEAD_LENGTH + shaft.height / 2.0, arrow_material)

	var origin := Node3D.new()
	origin.position.y = ARROW_LENGTH + KNOB_RADIUS
	_arrow.add_child(origin)
	_knob_material.albedo_color = IDLE_COLOR
	_knob_material.emission_enabled = true
	_knob_material.emission = IDLE_COLOR * 0.25
	var knob := SphereMesh.new()
	knob.radius = KNOB_RADIUS
	knob.height = KNOB_RADIUS * 2.0
	_add_mesh(origin, knob, 0.0, _knob_material)

	handle.collision_layer = HANDLES_LAYER
	handle.collision_mask = 0
	handle.gravity_scale = 0.0
	handle.picked_up_layer = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = KNOB_RADIUS * 1.6
	shape.shape = sphere
	handle.add_child(shape)
	origin.add_child(handle)

	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 36
	_label.pixel_size = 0.0015
	_label.outline_size = 10
	_label.position.y = ARROW_LENGTH + KNOB_RADIUS * 2.0 + 0.06
	_arrow.add_child(_label)

	grabbed.connect(_on_grab_changed.bind(true))
	released.connect(_on_grab_changed.bind(false))


func show_beam(beam: SimplySupportedBeam) -> void:
	_beam = beam
	slider_position = beam.load_position
	_label.text = "P = " + Units.force(beam.load)
	_update_height()


func set_exaggeration(factor: float) -> void:
	_exaggeration = factor
	_update_height()


## Lights the knob while it is held (VR grip or desktop mouse).
func set_held(held: bool) -> void:
	var color: Color = HELD_COLOR if held else IDLE_COLOR
	_knob_material.albedo_color = color
	_knob_material.emission = color * (0.6 if held else 0.25)


## Arrow tip rests on the top fiber (y = 2c above the bottom-fiber origin) of the
## displayed, exaggerated deflected shape.
func _update_height() -> void:
	if _beam:
		_arrow.position.y = 2.0 * _beam.section.y_max() - _beam.deflection_at(_beam.load_position) * _exaggeration


func _on_grab_changed(_interactable: XRToolsInteractableSlider, held: bool) -> void:
	set_held(held)


static func _add_mesh(parent: Node3D, mesh: Mesh, y: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = y
	instance.material_override = material
	parent.add_child(instance)
	return instance
