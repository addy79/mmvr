class_name DiagramView
extends Node3D
## Shear or moment diagram drawn in a vertical plane along the beam (x = 0 at the left end).
## The filled ribbon comes from diagram.gdshader; this script places the axis, labels and
## an optional marker line at the section cut.

enum Kind { SHEAR, MOMENT }

const SHADER: Shader = preload("res://shaders/diagram.gdshader")
const HEIGHT: float = 0.35  ## display height of the largest |value| [m]

var _kind: Kind
var _length: float = 1.0
var _ribbon: MeshInstance3D = MeshInstance3D.new()
var _axis: MeshInstance3D = MeshInstance3D.new()
var _title: Label3D = Text3D.make(34, false)
var _value_labels: Array[Label3D] = []
var _marker: MeshInstance3D = MeshInstance3D.new()
var _marker_label: Label3D = Text3D.make(30)


func _init(kind: Kind, data: BeamDataTexture) -> void:
	_kind = kind
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("beam_data", data.texture)
	material.set_shader_parameter("samples", float(BeamDataTexture.SAMPLES))
	material.set_shader_parameter("channel", int(kind))
	material.set_shader_parameter("height", HEIGHT)
	if kind == Kind.MOMENT:
		material.set_shader_parameter("positive_color", Color(0.55, 0.35, 0.85, 0.75))
		material.set_shader_parameter("negative_color", Color(0.85, 0.35, 0.55, 0.75))
	_ribbon.material_override = material
	_ribbon.extra_cull_margin = HEIGHT
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ribbon)
	_axis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_axis)
	_title.text = "Shear force V(x)" if kind == Kind.SHEAR else "Bending moment M(x)"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.position = Vector3(-0.12, 0.0, 0.0)
	add_child(_title)
	for i: int in 2:
		var label := Text3D.make(32)
		_value_labels.append(label)
		add_child(label)
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.012, HEIGHT * 2.3, 0.012)
	_marker.mesh = marker_mesh
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.3, 0.9, 1.0)
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = marker_material
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	_marker.add_child(_marker_label)
	set_marker(-1.0, 0.0)


func show_beam(beam: BeamModel) -> void:
	if not is_equal_approx(beam.length, _length):
		_length = beam.length
		_ribbon.mesh = _ribbon_mesh(_length)
		var axis_mesh := BoxMesh.new()
		axis_mesh.size = Vector3(_length, 0.006, 0.006)
		_axis.mesh = axis_mesh
		_axis.position.x = _length / 2.0
	if _kind == Kind.SHEAR:
		var v0: float = beam.shear_at(0.0)
		var v1: float = beam.shear_at(_length)
		_place(_value_labels[0], 0.25, v0, beam.max_shear(), Units.signed_force(v0))
		_place(_value_labels[1], _length - 0.25, v1, beam.max_shear(), Units.signed_force(v1))
	else:
		var m: float = beam.max_moment()
		_place(_value_labels[0], clampf(beam.max_moment_position(), 0.3, _length - 0.3), m, absf(m),
				"M_max = " + Units.moment(m))
		_value_labels[1].visible = false


## Vertical marker at x (hidden when x < 0) labelled with the value there.
func set_marker(x: float, value_at_x: float, reference: float = 1.0) -> void:
	_marker.visible = x >= 0.0
	_marker.position.x = x
	_marker_label.text = Units.signed_force(value_at_x) if _kind == Kind.SHEAR else Units.moment(value_at_x)
	_marker_label.position.y = HEIGHT * clampf(value_at_x / reference, -1.0, 1.0) + 0.0


## Puts a label just outside the ribbon at x, on the side of the value's sign.
func _place(label: Label3D, x: float, v: float, reference: float, text: String) -> void:
	var h: float = HEIGHT * v / reference if reference > 0.0 else 0.0
	label.visible = absf(v) > 1e-9
	label.text = text
	label.position = Vector3(x, h + (0.08 if v >= 0.0 else -0.08), 0.01)


## Strip of SAMPLES columns; UV.x = x/L, UV.y = 0 on the axis and 1 on the curve.
static func _ribbon_mesh(length: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var n: int = BeamDataTexture.SAMPLES
	for i: int in n:
		var u: float = float(i) / (n - 1)
		verts.append(Vector3(u * length, 0.0, 0.0))
		verts.append(Vector3(u * length, 0.0, 0.0))
		uvs.append(Vector2(u, 0.0))
		uvs.append(Vector2(u, 1.0))
		if i > 0:
			var a: int = 2 * (i - 1)
			indices.append_array(PackedInt32Array([a, a + 1, a + 3, a, a + 3, a + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
