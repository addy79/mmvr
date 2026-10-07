extends Station
## Chapter 4 - Pure bending: a beam segment loaded by equal and opposite couples M. The
## painted grid shows that cross-sections stay plane and rotate; fibers above the neutral
## axis shorten and fibers below stretch. Curvature is exaggerated.

const BEND_SHADER: Shader = preload("res://shaders/bend.gdshader")
const SEGMENT: float = 1.6
const CENTER := Vector3(0.0, 1.3, 0.0)
const SECTION_NAMES: PackedStringArray = ["Rectangle", "Circle", "Tube", "I-beam"]
const MATERIAL_NAMES: PackedStringArray = ["Steel", "Aluminum", "Wood"]
const MAX_DRAWN_ANGLE: float = 1.2  ## largest drawn k*L [rad]

var model: PureBending = PureBending.new()

var _sections: Array[CrossSection] = SectionPresets.all()
var _materials: Array[LabMaterial] = LabMaterial.presets()
var _mesh: MeshInstance3D = MeshInstance3D.new()
var _shader: ShaderMaterial = ShaderMaterial.new()
var _couples: Array[MomentArrow3D] = [MomentArrow3D.new(Color(0.95, 0.95, 1.0), 0.25, 0.016),
		MomentArrow3D.new(Color(0.95, 0.95, 1.0), 0.25, 0.016)]
var _top_label: Label3D = Text3D.make(34)
var _bottom_label: Label3D = Text3D.make(34)
var _rho_label: Label3D = Text3D.make(36)
var _section: CrossSection


func _init() -> void:
	chapter = 4
	title = "Pure bending"
	_controls = [
		ControlSpec.slider(&"M", "Bending moment M", "kN·m", Units.KN, -60.0, 60.0, 0.5, 10.0e3),
		ControlSpec.choice(&"section", "Cross-section", SECTION_NAMES, 0),
		ControlSpec.choice(&"material", "Material", MATERIAL_NAMES, 0),
		ControlSpec.slider(&"exaggeration", "Curvature drawn ×", "", 1.0, 1.0, 3000.0, 1.0, 600.0, 0),
	]
	_shader.shader = BEND_SHADER
	_shader.set_shader_parameter("segment_length", SEGMENT)
	_mesh.material_override = _shader
	_mesh.position = CENTER - Vector3(SEGMENT / 2.0, 0.0, 0.0)
	add_child(_mesh)
	for c: MomentArrow3D in _couples:
		add_child(c)
	for l: Label3D in [_top_label, _bottom_label, _rho_label]:
		add_child(l)


func _apply() -> void:
	model.moment = value(&"M")
	model.section = _sections[int(value(&"section"))]
	model.material = _materials[int(value(&"material"))]
	var c: float = model.section.y_max()
	if model.section != _section:
		_section = model.section
		_mesh.mesh = BeamMeshBuilder.build(SectionProfile.for_section(_section), SEGMENT)
		_shader.set_shader_parameter("half_depth", c)
	var k: float = model.curvature() * value(&"exaggeration")
	k = clampf(k, -MAX_DRAWN_ANGLE / SEGMENT, MAX_DRAWN_ANGLE / SEGMENT)
	_shader.set_shader_parameter("curvature", k)
	_shader.set_shader_parameter("moment_sign", signf(model.moment))
	_shader.set_shader_parameter("stress_ratio", 1.0)  # full color at the extreme fibers
	# Couples at the drawn ends: counterclockwise on the right end for M > 0, clockwise on the left.
	var half: float = SEGMENT / 2.0
	for i: int in 2:
		var side: float = 1.0 if i == 1 else -1.0
		var phi: float = half * k * side
		var end := Vector3(sin(phi) / k, (1.0 - cos(phi)) / k, 0.0) if absf(k) > 1e-6 else Vector3(half * side, 0.0, 0.0)
		_couples[i].position = CENTER + end + Vector3(0.12 * side, 0.0, 0.0)
		_couples[i].rotation.z = phi
		_couples[i].set_moment(signf(model.moment) * side)
		_couples[i].label.text = "M = " + Units.moment(model.moment)
	var sagging: bool = model.moment >= 0.0
	_top_label.text = "shortens (compression)" if sagging else "stretches (tension)"
	_bottom_label.text = "stretches (tension)" if sagging else "shortens (compression)"
	_top_label.position = CENTER + Vector3(0.0, c + 0.2, 0.0)
	_bottom_label.position = CENTER + Vector3(0.0, -c - 0.2, 0.0)
	_rho_label.text = "ρ = %s   (curvature drawn ×%d)" % [Units.length(model.radius_of_curvature()) if is_finite(model.radius_of_curvature()) else "∞", int(value(&"exaggeration"))]
	_rho_label.position = CENTER + Vector3(0.0, c + 0.45, 0.0)


func step_titles() -> PackedStringArray:
	return ["Deformation", "Normal strain", "Flexure formula", "Curvature", "Section modulus & yield"]


func lesson_text() -> String:
	var F := LessonFormat
	var s: CrossSection = model.section
	var c: float = s.y_max()
	var t: String = ""
	match step():
		0:
			t += "A member loaded only by equal and opposite couples M at its ends is in [b]pure bending[/b]: no shear force, the same M at every section. By symmetry it bends into a [b]circular arc[/b] of radius ρ.\n"
			t += "The painted grid shows the key facts:\n[ul]\n[b]cross-sections stay plane[/b] and pass through the center of the arc (vertical lines stay straight);\nfibers on the concave side [b]shorten[/b], on the convex side they [b]stretch[/b];\none surface keeps its length: the [b]neutral surface[/b] (yellow line on the side faces).\n[/ul]\n"
			t += "Here M = %s → ρ = %s.\n" % [F.value(Units.moment(model.moment)), F.value(Units.length(model.radius_of_curvature()))]
			t += F.try_this("make M negative: the segment hogs, and the top now stretches.")
		1:
			t += "Because sections stay plane, the longitudinal strain varies [b]linearly[/b] with the distance y from the neutral surface:\n"
			t += F.equation("ε_x = −y/ρ", "")
			t += F.equation("ε_m = c/ρ", "%s / %s" % [Units.small_length(c), Units.length(model.radius_of_curvature())], Units.strain(model.max_strain()))
			t += F.equation("ε_top", "", Units.strain(model.strain_at(c)))
			t += F.equation("ε_bottom", "", Units.strain(model.strain_at(-c)))
			t += F.note("This is pure geometry: it holds for any material, elastic or not.")
			t += F.try_this("switch the cross-section: the strain profile depends only on c and ρ.")
		2:
			t += "With Hooke's law σ = E·ε the stress is linear too. Equilibrium (no net axial force) puts the neutral axis through the [b]centroid[/b], and the moment of the stresses must equal M. Together:\n"
			t += F.equation("σ_x = −M·y/I", "flexure formula")
			t += F.equation("σ_m = M·c/I", "%s × %s / %s" % [Units.moment(absf(model.moment)), Units.small_length(c), Units.inertia(s.moment_of_inertia())], Units.stress(model.max_stress()))
			t += F.equation("σ_top", "", Units.stress(model.stress_at(c)))
			t += F.equation("σ_bottom", "", Units.stress(model.stress_at(-c)))
			t += "I = %s for the %s.\n" % [Units.inertia(s.moment_of_inertia()), SectionText.describe(s)]
			t += F.try_this("compare the rectangle and the I-beam at the same M: the I-beam's material sits far from the axis, so I is larger and σ smaller.")
		3:
			t += "Putting σ = Eε and σ = −My/I together gives the [b]moment-curvature relation[/b]:\n"
			t += F.equation("1/ρ = M/(E·I)", "%s / (%s × %s)" % [Units.moment(absf(model.moment)), Units.modulus(model.material.youngs_modulus), Units.inertia(s.moment_of_inertia())], "%.4f×10⁻³ 1/m" % (absf(model.curvature()) * 1e3))
			t += "EI is the [b]flexural rigidity[/b]. Chapter 9 integrates this curvature along a beam to find its deflection.\n"
			t += F.try_this("switch steel → aluminum: the stresses stay the same, but E drops to one third, so the curvature triples.")
		4:
			var yield_m: float = model.yield_moment()
			t += "The largest stress depends on the section only through the [b]elastic section modulus[/b]:\n"
			t += F.equation("S = I/c", "", Units.first_moment(model.section_modulus()))
			t += F.equation("σ_m = |M|/S", "", Units.stress(model.max_stress()))
			t += "The section first yields at its extreme fibers when σ_m = σ_Y:\n"
			t += F.equation("M_Y = σ_Y·S", "", Units.moment(yield_m))
			t += F.equation("FS = M_Y/|M| = σ_Y/σ_m", "", Units.factor(model.factor_of_safety()))
			t += F.note("Beyond M_Y yielding spreads inward (plastic bending, beyond this lab).")
			t += F.try_this("for each section, raise M until FS reaches 1 and compare M_Y. Material far from the neutral axis is what counts.")
	return t


func fill_figures(figures: FigureArea) -> void:
	var c: float = model.section.y_max()
	match step():
		1, 2:
			var p := figures.plot(0)
			var pts := PackedVector2Array()
			for i: int in 3:
				var y: float = c * (i - 1.0)
				pts.append(Vector2(model.strain_at(y) * 1e6 if step() == 1 else model.stress_at(y) * Units.MPA, y * Units.MM))
			if step() == 1:
				p.begin("Strain across the depth: linear", "ε (×10⁻⁶)", "y (mm)")
			else:
				p.begin("Stress across the depth: linear", "σ (MPa)", "y (mm)")
			p.line(pts, Color(1.0, 0.55, 0.4), 3.0, true)
			p.hline(0.0, Color(1.0, 0.9, 0.3), "neutral axis")
		3:
			var p := figures.plot(0)
			p.begin("Moment-curvature: slope 1/EI", "M (kN·m)", "1/ρ (10⁻³/m)")
			p.line(_sweep(func(m: PureBending) -> float: return m.curvature() * 1e3, -60.0e3), Color(0.6, 0.8, 1.0), 3.0)
			p.marker(Vector2(model.moment * Units.KN, model.curvature() * 1e3), Color(1, 1, 1), "now")
		4:
			var p := figures.plot(0)
			p.begin("Maximum stress vs M for this section", "|M| (kN·m)", "σ_m (MPa)")
			p.line(_sweep(func(m: PureBending) -> float: return m.max_stress() * Units.MPA, 0.0), Color(1.0, 0.6, 0.4), 3.0)
			p.hline(model.material.yield_strength * Units.MPA, Color(1.0, 0.4, 0.4), "σ_Y")
			p.marker(Vector2(absf(model.moment) * Units.KN, model.max_stress() * Units.MPA), Color(1, 1, 1), "now")


## Evaluates f on copies of the model with M from m_from to 60 kN*m; x in kN*m.
func _sweep(f: Callable, m_from: float) -> PackedVector2Array:
	var probe := PureBending.new()
	probe.section = model.section
	probe.material = model.material
	var pts := PackedVector2Array()
	for i: int in 41:
		probe.moment = m_from + (60.0e3 - m_from) * i / 40.0
		pts.append(Vector2(probe.moment * Units.KN, f.call(probe)))
	return pts


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([CENTER + Vector3(-1.2, -0.6, 0.3), CENTER + Vector3(1.2, -0.6, 0.3),
			CENTER + Vector3(-1.2, 0.8, -0.2), CENTER + Vector3(1.2, 0.8, -0.2)])
