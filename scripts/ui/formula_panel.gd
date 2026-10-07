class_name FormulaPanel
extends Node3D
## Floating board listing the governing equations with the current values substituted.
## Text only: every number is read from the beam model.

const SIZE := Vector2(1.9, 1.25)  ## board size [m]
const OK_COLOR := Color(0.45, 0.95, 0.5)
const FAIL_COLOR := Color(1.0, 0.35, 0.3)

var _text: Label3D = _make_label(26)
var _safety: Label3D = _make_label(34)
var _relative_to_yield: bool = false
var _beam: SimplySupportedBeam


func _init() -> void:
	var board := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SIZE
	board.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.06, 0.08, 0.11)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	board.material_override = material
	add_child(board)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Noto Sans Mono", "Droid Sans Mono", "monospace"])
	for label: Label3D in [_text, _safety]:
		label.font = mono
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.position = Vector3(-SIZE.x / 2.0 + 0.06, SIZE.y / 2.0 - 0.06, 0.005)
		add_child(label)
	_safety.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_safety.position.y = -SIZE.y / 2.0 + 0.06


func show_beam(beam: SimplySupportedBeam) -> void:
	_beam = beam
	var s: CrossSection = beam.section
	var m: BeamMaterial = beam.material
	var c: float = s.y_max()
	var central: String = "   (= P·L³/48EI, load at midspan)" \
			if is_equal_approx(beam.load_position, beam.length / 2.0) else ""
	var lines: PackedStringArray = [
		"SIMPLY SUPPORTED BEAM, point load P at x = a",
		"L = %s   a = %s   b = L − a = %s   P = %s" % [Units.length(beam.length),
				Units.length(beam.load_position), Units.length(beam.load_offset_from_b()), Units.force(beam.load)],
		"",
		"Reactions   R_A = P·b/L = %s     R_B = P·a/L = %s" % [Units.force(beam.reaction_a()), Units.force(beam.reaction_b())],
		"Shear       V = +R_A (x < a)    V = −R_B (x > a)",
		"Moment      M_max = P·a·b/L = %s   at x = a" % Units.moment(beam.max_moment()),
		"",
		"Section     %s   A = %s   I = %s   c = %s" % [s.display_name, Units.area(s.area()),
				Units.inertia(s.moment_of_inertia()), Units.small_length(c)],
		"Bending     σ = −M·y/I     σ_max = M_max·c/I = %s" % Units.stress(beam.max_bending_stress()),
		"Shear str.  τ = V·Q/(I·t)  τ_max = %s   (Q = %s, t = %s at N.A.)" % [
				Units.stress(beam.max_shear_stress()), Units.first_moment(s.first_moment(0.0)),
				Units.small_length(s.width_at(0.0))],
		"",
		"Deflection  v(x) = P·b·x·(L² − b² − x²)/(6·E·I·L),  x ≤ a  (mirror for x > a)",
		"            v_max = %s at x = %s%s" % [Units.small_length(beam.max_deflection()),
				Units.length(beam.max_deflection_position()), central],
		"",
		"Material    %s   E = %s   σ_Y = %s" % [m.display_name, Units.modulus(m.youngs_modulus),
				Units.stress(m.yield_strength)],
		_color_legend(),
	]
	_text.text = "\n".join(lines)
	var fs: float = beam.factor_of_safety()
	_safety.text = "Factor of safety  FS = σ_Y/σ_max = %s   %s" % [
			"∞" if is_inf(fs) else "%.2f" % fs, "OK" if fs >= 1.0 else "YIELDS!"]
	_safety.modulate = OK_COLOR if fs >= 1.0 else FAIL_COLOR


## All text currently on the board (used by the scene self-test).
func summary() -> String:
	return _text.text + "\n" + _safety.text


func set_color_scale(relative_to_yield: bool) -> void:
	_relative_to_yield = relative_to_yield
	if _beam:
		show_beam(_beam)


func _color_legend() -> String:
	var limit: float = _beam.material.yield_strength if _relative_to_yield else _beam.max_bending_stress()
	return "Colors      red = tension, blue = compression, full color at ±%s" % Units.stress(limit)


static func _make_label(font_size: int) -> Label3D:
	var label := Label3D.new()
	label.font_size = font_size
	label.pixel_size = 0.0011
	label.render_priority = 1
	label.outline_size = 0
	return label
