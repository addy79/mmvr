class_name BeamRig
extends Node3D
## A loaded beam on its supports: deflected, stress-colored member, the point load on a
## grabbable knob, the uniform load, and the support reactions. Works for any BeamModel;
## a CantileverBeam gets a wall and a fixed-end moment. The node origin is the bottom
## fiber at x = 0.

signal load_moved(x: float)

const MAX_DRAWN_DEFLECTION: float = 0.6
const UDL_ARROWS: int = 13

var data: BeamDataTexture = BeamDataTexture.new()
var view: BeamView = BeamView.new(data)
## Drawn meters per real meter of deflection after the last show_beam.
var deflection_scale: float = 0.0

var _supports: SupportsView
var _load_knob: AxisKnob
var _load_arrow: Arrow3D = Arrow3D.new(Color(0.95, 0.95, 1.0), 0.016)
var _udl_arrows: Array[Arrow3D] = []
var _udl_label: Label3D = Text3D.make(34)
var _reactions: Array[Arrow3D] = [Arrow3D.new(Color(0.4, 0.95, 0.5), 0.016), Arrow3D.new(Color(0.4, 0.95, 0.5), 0.016)]
var _fixed_moment: MomentArrow3D = MomentArrow3D.new(Color(0.4, 0.95, 0.5), 0.22)
var _beam: BeamModel
var _supports_kind: String = ""


func _init(length: float, height_above_floor: float) -> void:
	_supports = SupportsView.new(height_above_floor)
	add_child(_supports)
	add_child(view)
	_load_knob = AxisKnob.new(0.0, length)
	add_child(_load_knob)
	_load_knob.add_child(_load_arrow)
	_load_knob.slider_moved.connect(load_moved.emit)
	for i: int in UDL_ARROWS:
		var arrow := Arrow3D.new(Color(0.95, 0.75, 0.4), 0.008)
		arrow.label.visible = false
		_udl_arrows.append(arrow)
		add_child(arrow)
	add_child(_udl_label)
	for r: Arrow3D in _reactions:
		add_child(r)
	add_child(_fixed_moment)


func show_beam(beam: BeamModel, exaggeration: float, full_color_at_yield: bool) -> void:
	_beam = beam
	var length: float = beam.length
	var c: float = beam.section.y_max()
	var propped: bool = beam is ProppedCantileverBeam
	var cantilever: bool = beam is CantileverBeam or propped
	var kind: String = "%s %.3f %.2f" % ["propped" if propped else ("fixed" if cantilever else "simple"), c, length]
	if kind != _supports_kind:
		_supports_kind = kind
		if propped:
			_supports.show_propped(length, 2.0 * c)
		elif cantilever:
			_supports.show_fixed(2.0 * c)
		else:
			_supports.show_simple(length)
	data.write(beam)
	view.set_shape(beam.section, length)
	var v_max: float = absf(beam.max_deflection())
	var drawn: float = minf(v_max * exaggeration, MAX_DRAWN_DEFLECTION)
	view.set_drawn_deflection(drawn)
	deflection_scale = drawn / v_max if v_max > 0.0 else 0.0
	var full: float = beam.material.yield_strength if full_color_at_yield else beam.max_bending_stress()
	view.set_stress_ratio(beam.max_bending_stress() / full if full > 0.0 else 0.0)

	var a: float = beam.load_position
	_load_knob.set_value(a)
	var arrow_len: float = 0.15 + 0.35 * minf(beam.load / 50.0e3, 1.0)
	_load_arrow.place_onto(Vector3(0.0, top_at(a), 0.0), Vector3(0.0, -arrow_len, 0.0))
	_load_arrow.visible = beam.load > 0.0
	_load_arrow.label.text = "P = " + Units.force(beam.load)
	_load_knob.grip.position.y = top_at(a) + arrow_len + AxisKnob.RADIUS

	var w_len: float = 0.3 * minf(beam.distributed_load / 20.0e3, 1.0)
	for i: int in _udl_arrows.size():
		var x: float = length * i / (_udl_arrows.size() - 1)
		_udl_arrows[i].place_onto(Vector3(x, top_at(x), 0.0), Vector3(0.0, -w_len, 0.0))
	_udl_label.visible = beam.distributed_load > 0.0
	_udl_label.text = "w = " + Units.distributed(beam.distributed_load)
	_udl_label.position = Vector3(length * 0.75, 2.0 * c + w_len + 0.12, 0.0)

	var values: Array[float] = [beam.reaction_a(), beam.reaction_b()]
	var names: PackedStringArray = ["R_A = ", "R_B = "]
	for i: int in 2:
		var r_len: float = 0.15 + 0.35 * minf(absf(values[i]) / 50.0e3, 1.0)
		var at := Vector3(length * i, -0.02, 0.3)
		if cantilever and i == 0:
			at = Vector3(0.12, -0.02, 0.3)
		_reactions[i].place_onto(at, Vector3(0.0, r_len, 0.0))
		_reactions[i].visible = values[i] > 0.0
		_reactions[i].label.text = names[i] + Units.force(values[i])
		_reactions[i].label.position = at + Vector3(0.0, -r_len - 0.12, 0.0)
	_fixed_moment.visible = cantilever
	if cantilever:
		var m_a: float = beam.moment_at(0.0)
		_fixed_moment.position = Vector3(0.05, c, 0.32)
		_fixed_moment.set_moment(-signf(m_a))  # reaction couple on the beam opposes the hogging moment
		_fixed_moment.label.text = "M_A = " + Units.moment(absf(m_a))


## Height of the drawn (deflected) top fiber at x, in rig coordinates.
func top_at(x: float) -> float:
	return 2.0 * _beam.section.y_max() - _beam.deflection_at(x) * deflection_scale


## Height of the drawn neutral axis at x.
func axis_at(x: float) -> float:
	return _beam.section.y_max() - _beam.deflection_at(x) * deflection_scale


func set_reactions_visible(on: bool) -> void:
	for r: Arrow3D in _reactions:
		r.visible = on and r.visible
	_fixed_moment.visible = on and _fixed_moment.visible
