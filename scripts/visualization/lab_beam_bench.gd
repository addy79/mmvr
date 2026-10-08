class_name LabBeamBench
extends Node3D
## A lab-size beam drawn larger than life (draw_scale), on any supports, with its point
## loads: the deflected, stress-colored member of BeamView plus simple supports, walls and
## arrows. The node origin is the drawn bottom fiber at x = 0.

const SUPPORT_SIZE: float = 0.07
const MAX_DRAWN_DEFLECTION: float = 0.18  ## [m, drawn]

var draw_scale: float = 1.0
## Drawn meters per real meter of deflection after the last show_beam.
var deflection_factor: float = 0.0

var data: BeamDataTexture = BeamDataTexture.new()
var view: BeamView = BeamView.new(data)
var _frame: Node3D = Node3D.new()
var _supports: Node3D = Node3D.new()
var _arrows: Array[Arrow3D] = []
var _material: StandardMaterial3D = StandardMaterial3D.new()
var _beam: BeamModel
var _section_scale: float = 1.0
var _label: Label3D = Text3D.make(30)


func _init(p_draw_scale: float) -> void:
	draw_scale = p_draw_scale
	_frame.scale = Vector3.ONE * draw_scale
	add_child(_frame)
	_frame.add_child(view)
	add_child(_supports)
	_material.albedo_color = Color(0.35, 0.37, 0.4)
	add_child(_label)


## supports: {x, kind} with kind "pin", "roller" or "fixed" (x in real meters).
## loads: {x, text} point loads drawn as arrows onto the top fiber; w_text labels a uniform load.
## section_scale draws the section thicker than the length scale (thin lab bars).
func show_beam(beam: BeamModel, supports: Array[Dictionary], loads: Array[Dictionary], exaggeration: float,
		section_scale: float = 1.0, w_text: String = "") -> void:
	_beam = beam
	_section_scale = section_scale
	data.write(beam)
	view.set_shape(beam.section, beam.length, false, section_scale)
	var v_max: float = absf(beam.max_deflection())
	var drawn: float = minf(v_max * exaggeration, MAX_DRAWN_DEFLECTION / draw_scale)
	view.set_drawn_deflection(drawn)
	deflection_factor = drawn / v_max if v_max > 0.0 else 0.0
	var sigma: float = beam.max_bending_stress()
	view.set_stress_ratio(sigma / beam.material.yield_strength if beam.material.yield_strength > 0.0 else 0.0)
	_build_supports(supports)
	var n: int = loads.size() + (11 if not w_text.is_empty() else 0)
	while _arrows.size() < n:
		var a := Arrow3D.new(Color(0.95, 0.95, 1.0), 0.008)
		_arrows.append(a)
		add_child(a)
	for i: int in _arrows.size():
		_arrows[i].visible = i < n
	for i: int in loads.size():
		var x: float = loads[i].x
		_arrows[i].place_onto(world_top(x), Vector3(0.0, -0.22, 0.0))
		_arrows[i].label.visible = true
		_arrows[i].label.text = loads[i].text
	if not w_text.is_empty():
		for k: int in 11:
			var a: Arrow3D = _arrows[loads.size() + k]
			var x: float = beam.length * k / 10.0
			a.place_onto(world_top(x), Vector3(0.0, -0.12, 0.0))
			a.label.visible = k == 5
			a.label.text = w_text


## Drawn position (bench coordinates) of the deflected top fiber at real x.
func world_top(x: float) -> Vector3:
	var top: float = 2.0 * _beam.section.y_max() * _section_scale - _beam.deflection_at(x) * deflection_factor
	return Vector3(x, top, 0.0) * draw_scale


func set_caption(text: String, at: Vector3) -> void:
	_label.text = text
	_label.position = at


func _build_supports(supports: Array[Dictionary]) -> void:
	for child: Node in _supports.get_children():
		child.queue_free()
	var depth: float = 2.0 * _beam.section.y_max() * _section_scale * draw_scale
	for s: Dictionary in supports:
		var x: float = s.x * draw_scale
		match s.kind:
			"pin":
				var prism := PrismMesh.new()
				prism.size = Vector3(SUPPORT_SIZE, SUPPORT_SIZE, 0.12)
				_add(prism, Vector3(x, -SUPPORT_SIZE / 2.0, 0.0))
			"roller":
				var cyl := CylinderMesh.new()
				cyl.top_radius = SUPPORT_SIZE / 2.0
				cyl.bottom_radius = SUPPORT_SIZE / 2.0
				cyl.height = 0.12
				_add(cyl, Vector3(x, -SUPPORT_SIZE / 2.0, 0.0)).rotation.x = PI / 2.0
			"fixed":
				var wall := BoxMesh.new()
				wall.size = Vector3(0.08, depth + 0.3, 0.3)
				_add(wall, Vector3(x - 0.04, depth / 2.0, 0.0))


func _add(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _material
	m.position = at
	_supports.add_child(m)
	return m
