class_name DiagramView
extends Node3D
## Shear or moment diagram drawn in a vertical plane along the beam (x = 0 at support A).
## The filled ribbon comes from diagram.gdshader; this script places the axis and labels.

enum Kind { SHEAR, MOMENT }

const SHADER: Shader = preload("res://shaders/diagram.gdshader")
const HEIGHT: float = 0.35  ## display height of the largest |value| [m]

var _kind: Kind
var _length: float
var _value_labels: Array[Label3D] = []


func _init(kind: Kind, length: float, data: BeamDataTexture) -> void:
	_kind = kind
	_length = length
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("beam_data", data.texture)
	material.set_shader_parameter("samples", float(BeamDataTexture.SAMPLES))
	material.set_shader_parameter("channel", int(kind))
	material.set_shader_parameter("height", HEIGHT)
	if kind == Kind.MOMENT:
		material.set_shader_parameter("positive_color", Color(0.55, 0.35, 0.85, 0.75))
		material.set_shader_parameter("negative_color", Color(0.85, 0.35, 0.55, 0.75))
	var ribbon := MeshInstance3D.new()
	ribbon.mesh = _ribbon_mesh(length)
	ribbon.material_override = material
	ribbon.extra_cull_margin = HEIGHT
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ribbon)

	var axis := MeshInstance3D.new()
	var axis_mesh := BoxMesh.new()
	axis_mesh.size = Vector3(length, 0.006, 0.006)
	axis.mesh = axis_mesh
	axis.position.x = length / 2.0
	axis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(axis)

	var title := _label(30)
	title.text = "Shear  V(x)" if kind == Kind.SHEAR else "Bending moment  M(x)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.position = Vector3(-0.1, 0.0, 0.0)
	for i: int in 2:
		_value_labels.append(_label(28))


func show_beam(beam: SimplySupportedBeam) -> void:
	if _kind == Kind.SHEAR:
		# V = +R_A on [0, a], V = -R_B on (a, L]
		_place(_value_labels[0], 0.25, beam.reaction_a(), beam.max_shear(), "+" + Units.force(beam.reaction_a()))
		_place(_value_labels[1], _length - 0.25, -beam.reaction_b(), beam.max_shear(), "−" + Units.force(beam.reaction_b()))
		_value_labels[1].visible = beam.reaction_b() > 0.0
		_value_labels[0].visible = beam.reaction_a() > 0.0
	else:
		_place(_value_labels[0], beam.load_position, beam.max_moment(), absf(beam.max_moment()),
				"M_max = " + Units.moment(beam.max_moment()))
		_value_labels[1].visible = false


## Puts a label just outside the ribbon at x, on the side of the value's sign.
func _place(label: Label3D, x: float, value: float, reference: float, text: String) -> void:
	var h: float = HEIGHT * value / reference if reference > 0.0 else 0.0
	label.text = text
	label.position = Vector3(x, h + (0.08 if value >= 0.0 else -0.08), 0.01)


func _label(font_size: int) -> Label3D:
	var label := Label3D.new()
	label.font_size = font_size
	label.pixel_size = 0.0025
	label.outline_size = 8
	label.modulate = Color(0.95, 0.95, 0.95)
	add_child(label)
	return label


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
