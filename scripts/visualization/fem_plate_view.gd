class_name FemPlateView
extends Node3D
## A PlaneStressFem result drawn like ANSYS's contour plots: the (deformed) plate in the
## x-y plane, colored blue -> red by a nodal field, optional element edges, a color legend,
## the fixed support and the pull arrow. draw_scale drawn meters per real meter.

const LEGEND_BANDS: int = 9
const LEGEND_STEP: float = 0.055  ## drawn height of one legend band [m]

var draw_scale: float = 15.0
var _plate: MeshInstance3D = MeshInstance3D.new()
var _edges: MeshInstance3D = MeshInstance3D.new()
var _support: MeshInstance3D = MeshInstance3D.new()
var _arrow: Arrow3D = Arrow3D.new(Color(0.95, 0.95, 1.0), 0.01)
var _legend: Array[MeshInstance3D] = []
var _legend_labels: Array[Label3D] = []
var _title: Label3D = Text3D.make(30)


func _init() -> void:
	var plate_material := StandardMaterial3D.new()
	plate_material.vertex_color_use_as_albedo = true
	plate_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_plate.material_override = plate_material
	add_child(_plate)
	var edge_material := StandardMaterial3D.new()
	edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_material.albedo_color = Color(0.05, 0.05, 0.08)
	_edges.material_override = edge_material
	add_child(_edges)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.35, 0.37, 0.4)
	_support.material_override = grey
	add_child(_support)
	add_child(_arrow)
	for i: int in LEGEND_BANDS + 1:
		var label := Text3D.make(16, false)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_legend_labels.append(label)
		add_child(label)
	for i: int in LEGEND_BANDS:
		var quad := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, LEGEND_STEP * 0.9, 0.01)
		quad.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = color_at((i + 0.5) / LEGEND_BANDS)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		quad.material_override = m
		_legend.append(quad)
		add_child(quad)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_title)


## ANSYS-like rainbow: blue (t = 0) -> cyan -> green -> yellow -> red (t = 1).
static func color_at(t: float) -> Color:
	var stops: Array[Color] = [Color(0.0, 0.0, 1.0), Color(0.0, 0.7, 1.0), Color(0.0, 1.0, 0.4),
			Color(0.75, 1.0, 0.0), Color(1.0, 0.75, 0.0), Color(1.0, 0.0, 0.0)]
	var x: float = clampf(t, 0.0, 1.0) * (stops.size() - 1)
	var i: int = mini(int(x), stops.size() - 2)
	return stops[i].lerp(stops[i + 1], x - i)


## field: nodal values; lo/hi: legend range; unit_scale, unit: legend labels (e.g. 1e-6, "MPa").
func show_result(fem: PlaneStressFem, field: PackedFloat64Array, lo: float, hi: float, exaggeration: float,
		show_mesh: bool, caption: String, label_format: Callable) -> void:
	var s: float = draw_scale
	var half_t: float = fem.thickness * s / 2.0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	var pos := func(i: int, j: int) -> Vector3:
		var u: Vector2 = fem.displacement(i, j) * exaggeration
		return Vector3(i * fem.element_size + u.x, j * fem.element_height + u.y - fem.height / 2.0, 0.0) * s
	var span: float = maxf(hi - lo, 1e-30)
	for i: int in fem.nx:
		for j: int in fem.ny:
			if not fem.is_active(i, j):
				continue
			var corners: Array[Vector2i] = [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			var p: Array[Vector3] = []
			var c: Array[Color] = []
			for k: Vector2i in corners:
				p.append(pos.call(k.x, k.y))
				c.append(color_at((field[fem.node(k.x, k.y)] - lo) / span))
			for z: float in [half_t, -half_t]:
				for tri: Array in [[0, 1, 2], [0, 2, 3]]:
					for v: int in tri:
						surface.set_color(c[v])
						surface.set_normal(Vector3(0, 0, signf(z)))
						surface.add_vertex(p[v] + Vector3(0, 0, z))
			if show_mesh:
				for e: int in 4:
					lines.add_vertex(p[e] + Vector3(0, 0, half_t + 0.001))
					lines.add_vertex(p[(e + 1) % 4] + Vector3(0, 0, half_t + 0.001))
	_plate.mesh = surface.commit()
	_edges.mesh = lines.commit() if show_mesh else null
	var box := BoxMesh.new()
	box.size = Vector3(0.06, fem.height * s + 0.12, 0.12)
	_support.mesh = box
	_support.position = Vector3(-0.03, 0.0, 0.0)
	var right := Vector3(fem.length * s + fem.displacement(fem.nx, fem.ny / 2).x * exaggeration * s, 0.0, 0.0)
	_arrow.place(right + Vector3(0.02, 0.0, 0.0), Vector3(0.18, 0.0, 0.0))
	_arrow.label.text = "pulled %s" % Units.mm(fem.displacement(fem.nx, fem.ny / 2).x)
	_arrow.label.position = right + Vector3(0.1, -0.08, 0.0)
	var x0: float = fem.length * s + 0.5
	var y0: float = -LEGEND_STEP * LEGEND_BANDS / 2.0
	for i: int in LEGEND_BANDS:
		_legend[i].position = Vector3(x0, y0 + (i + 0.5) * LEGEND_STEP, 0.0)
	for i: int in LEGEND_BANDS + 1:
		_legend_labels[i].position = Vector3(x0 + 0.04, y0 + i * LEGEND_STEP, 0.0)
		_legend_labels[i].text = label_format.call(lo + (hi - lo) * i / LEGEND_BANDS)
	_title.text = caption
	_title.position = Vector3(0.0, fem.height * s / 2.0 + 0.16, 0.0)
