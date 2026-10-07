class_name MomentArrow3D
extends Node3D
## Curved arrow for a couple or torque about the node's local +Z axis (right-hand rule:
## counterclockwise seen from +Z when positive). set_moment(sign) flips or hides it.

const ARC: float = 1.5 * PI
const SEGMENTS: int = 28

var label: Label3D = Text3D.make(32)
var _arc: MeshInstance3D = MeshInstance3D.new()


func _init(color: Color, radius: float = 0.18, tube: float = 0.014) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.35
	_arc.mesh = _build(radius, tube)
	_arc.material_override = material
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arc)
	label.position = Vector3(0.0, radius + 0.1, 0.0)
	add_child(label)


## sign > 0: counterclockwise about +Z; < 0: clockwise; 0: hidden.
func set_moment(sign: float) -> void:
	visible = sign != 0.0
	_arc.scale = Vector3(1.0 if sign >= 0.0 else -1.0, 1.0, 1.0)


static func _build(radius: float, tube: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: int = 8
	var start: float = -PI / 4.0
	for i: int in SEGMENTS:
		var a0: float = start + ARC * i / SEGMENTS
		var a1: float = start + ARC * (i + 1) / SEGMENTS
		for j: int in ring:
			var b0: float = TAU * j / ring
			var b1: float = TAU * (j + 1) / ring
			var p := func(a: float, b: float) -> Vector3:
				var dir := Vector3(cos(a), sin(a), 0.0)
				return dir * (radius + tube * cos(b)) + Vector3(0, 0, tube * sin(b))
			var quad := [p.call(a0, b0), p.call(a1, b0), p.call(a1, b1), p.call(a0, b1)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(quad[k])
	# Arrow head at the counterclockwise end, pointing along the tangent.
	var end_a: float = start + ARC
	var base := Vector3(cos(end_a), sin(end_a), 0.0) * radius
	var tangent := Vector3(-sin(end_a), cos(end_a), 0.0)
	var side := Vector3(cos(end_a), sin(end_a), 0.0)
	var tip: Vector3 = base + tangent * tube * 6.0
	for j: int in ring:
		var b0: float = TAU * j / ring
		var b1: float = TAU * (j + 1) / ring
		var c0: Vector3 = base + (side * cos(b0) + Vector3.BACK * sin(b0)) * tube * 2.6
		var c1: Vector3 = base + (side * cos(b1) + Vector3.BACK * sin(b1)) * tube * 2.6
		for v: Vector3 in [c0, c1, tip, c0, base, c1]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()
