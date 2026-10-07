extends Station
## Chapter 9 - Deflection of beams: a cantilever or a simply supported beam with a point
## load and a uniform load. The figures follow the integration chain M/EI -> slope -> v,
## show the boundary conditions, and split the deflection by superposition.

const LENGTH: float = 4.0
const ORIGIN := Vector3(-2.0, 0.95, 0.0)
const SUPPORT_NAMES: PackedStringArray = ["Simply supported", "Cantilever", "Propped cantilever"]
const INDETERMINATE: int = 5
const SECTION_NAMES: PackedStringArray = ["Rectangle", "Circle", "Tube", "I-beam", "Box"]
const MATERIAL_NAMES: PackedStringArray = ["Steel", "Aluminum", "Wood"]
const LIMIT_RATIO: float = 360.0   ## serviceability limit L/360

var beam: BeamModel

var _sections: Array[CrossSection] = SectionPresets.all()
var _materials: Array[LabMaterial] = LabMaterial.presets()
var _simple: SimplySupportedBeam
var _cantilever: CantileverBeam
var _propped: ProppedCantileverBeam
var _rig: BeamRig = BeamRig.new(LENGTH, ORIGIN.y)
var _max_marker: MeshInstance3D = MeshInstance3D.new()
var _max_label: Label3D = Text3D.make(36)
var _tangent: MeshInstance3D = MeshInstance3D.new()


func _init() -> void:
	chapter = 9
	title = "Deflection of beams"
	_simple = SimplySupportedBeam.new(LENGTH, 10.0e3, 2.0, _sections[0], _materials[0])
	_cantilever = CantileverBeam.new(LENGTH, 10.0e3, 2.0, _sections[0], _materials[0])
	_propped = ProppedCantileverBeam.new(LENGTH, 10.0e3, 2.0, _sections[0], _materials[0])
	_controls = [
		ControlSpec.choice(&"support", "Supports", SUPPORT_NAMES, 0),
		ControlSpec.slider(&"P", "Point load P", "kN", Units.KN, 0.0, 50.0, 0.5, 10.0e3),
		ControlSpec.slider(&"a", "Load position a", "m", 1.0, 0.0, LENGTH, 0.01, 2.0),
		ControlSpec.slider(&"w", "Uniform load w", "kN/m", Units.KN, 0.0, 20.0, 0.5, 2.0e3),
		ControlSpec.choice(&"section", "Cross-section", SECTION_NAMES, 3),
		ControlSpec.choice(&"material", "Material", MATERIAL_NAMES, 0),
		ControlSpec.slider(&"exaggeration", "Deflection drawn ×", "", 1.0, 1.0, 500.0, 1.0, 30.0, 0),
	]
	_rig.position = ORIGIN
	add_child(_rig)
	_rig.load_moved.connect(func(x: float) -> void: set_control(&"a", x))
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	_max_marker.mesh = dot
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1.0, 0.35, 0.3)
	red.emission_enabled = true
	red.emission = Color(1.0, 0.35, 0.3)
	_max_marker.material_override = red
	_rig.add_child(_max_marker)
	_rig.add_child(_max_label)
	var line := BoxMesh.new()
	line.size = Vector3(0.9, 0.01, 0.01)
	_tangent.mesh = line
	var cyan := StandardMaterial3D.new()
	cyan.albedo_color = Color(0.3, 0.9, 1.0)
	cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tangent.material_override = cyan
	_rig.add_child(_tangent)


func _apply() -> void:
	beam = [_simple, _cantilever, _propped][int(value(&"support"))]
	beam.load = value(&"P")
	beam.load_position = value(&"a")
	beam.distributed_load = value(&"w")
	beam.section = _sections[int(value(&"section"))]
	beam.material = _materials[int(value(&"material"))]
	_rig.show_beam(beam, value(&"exaggeration"), false)
	# Red dot at the largest deflection (bottom fiber); cyan tangent showing the end slope.
	var xm: float = beam.max_deflection_position()
	_max_marker.position = Vector3(xm, _rig.axis_at(xm) - beam.section.y_max() - 0.05, 0.12)
	_max_label.text = "v_max = " + Units.small_length(beam.max_deflection())
	_max_label.position = _max_marker.position + Vector3(0.0, -0.18, 0.0)
	var x_slope: float = 0.0 if beam is SimplySupportedBeam else LENGTH  # a free or roller end
	var drawn_slope: float = beam.slope_at(x_slope) * _rig.deflection_scale
	_tangent.position = Vector3(x_slope + (0.4 if x_slope == 0.0 else -0.4), _rig.axis_at(x_slope) - drawn_slope * (0.4 if x_slope == 0.0 else -0.4), 0.15)
	_tangent.rotation.z = -atan(drawn_slope)


func step_titles() -> PackedStringArray:
	return ["Curvature", "Integration & BCs", "Support conditions", "Superposition", "Design for stiffness",
			"Statically indeterminate"]


func lesson_text() -> String:
	var F := LessonFormat
	var cant: bool = beam is CantileverBeam
	var ei: float = beam.flexural_rigidity()
	var t: String = ""
	match step():
		0:
			t += "Chapter 4 showed that bending curves a beam: 1/ρ = M/(EI). For small slopes the curvature of the [b]elastic curve[/b] v(x) is its second derivative, so (v measured downward):\n"
			t += F.equation("d²v/dx² = −M(x)/(E·I)", "")
			t += "The curvature follows the moment diagram, scaled by 1/EI (figure). Where M is largest the beam bends most sharply; where M = 0 (a pin, a free end) it is locally straight.\n"
			t += F.equation("E·I", "%s × %s" % [Units.modulus(beam.material.youngs_modulus), Units.inertia(beam.section.moment_of_inertia())], "%.0f kN·m²" % (ei / 1e3))
			t += F.try_this("switch the cross-section: the M/EI curve keeps its shape but its size changes with 1/I.")
		1:
			t += "Integrate twice. Each integration adds a constant, fixed by the [b]boundary conditions[/b]:\n"
			t += F.equation("E·I·θ(x) = −∫M dx + C₁", "θ = dv/dx, the slope")
			t += F.equation("E·I·v(x) = −∬M dx dx + C₁x + C₂", "")
			if cant:
				t += "Cantilever: at the wall v(0) = 0 [b]and[/b] θ(0) = 0 (it cannot move or rotate).\n"
			else:
				t += "Simply supported: v(0) = 0 and v(L) = 0 (the supports do not move; the beam may rotate there).\n"
			t += F.equation("slope at %s" % ("the free end" if cant else "A"), "", Units.angle(beam.slope_at(LENGTH if cant else 0.0)))
			t += F.equation("v_max", "at x = %s" % Units.length(beam.max_deflection_position()), Units.small_length(beam.max_deflection()))
			t += F.note("Where a point load sits, M has a corner; v and θ stay continuous there. With singularity functions (⟨x − a⟩ⁿ) one expression covers the whole beam and these continuity conditions are automatic.")
			var ma: Vector2 = beam.moment_area(0.0, LENGTH)
			t += "[b]Moment-area theorems[/b] read the same results directly from the M/EI diagram:\n"
			t += F.equation("θ_A − θ_B = ∫ M/EI dx", "area of the M/EI diagram from A to B", Units.angle(ma.x))
			t += F.equation("check: θ(0) − θ(L)", "", Units.angle(beam.slope_at(0.0) - beam.slope_at(LENGTH)))
			t += F.equation("t_B/A = ∫ (x_B − x)·M/EI dx", "deviation of B from the tangent at A", Units.small_length(ma.y))
			t += F.try_this("compare the three stacked plots: each is the integral of the one above it.")
		2:
			var p: String = Units.force(beam.load)
			t += "How a beam is supported changes its stiffness enormously. For a point load at the most unfavourable place:\n"
			var end_loaded := CantileverBeam.new(LENGTH, beam.load, LENGTH, beam.section, beam.material)
			var mid_loaded := SimplySupportedBeam.new(LENGTH, beam.load, LENGTH / 2.0, beam.section, beam.material)
			t += F.equation("cantilever, P at the free end: v_max = P·L³/(3EI)", "", Units.small_length(end_loaded.max_deflection()))
			t += F.equation("simply supported, P at midspan: v_max = P·L³/(48EI)", "", Units.small_length(mid_loaded.max_deflection()))
			t += "Same beam, same load P = %s: the cantilever deflects [b]16 times more[/b]. Uniform loads give wL⁴/(8EI) and 5wL⁴/(384EI).\n" % p
			t += F.equation("this beam (%s)" % SUPPORT_NAMES[int(value(&"support"))], "", Units.small_length(beam.max_deflection()))
			t += F.try_this("switch between the two supports with the same loads and compare v_max and where it occurs.")
		3:
			var only_p := _copy(beam.load, 0.0)
			var only_w := _copy(0.0, beam.distributed_load)
			t += "In the elastic range deflections are linear in the loads, so [b]superposition[/b] holds: solve each load alone (tables of standard cases) and add:\n"
			t += F.equation("v(x) = v_P(x) + v_w(x)", "")
			t += F.equation("at x = %s" % Units.length(beam.max_deflection_position()), "%s + %s" % [Units.small_length(only_p.deflection_at(beam.max_deflection_position())), Units.small_length(only_w.deflection_at(beam.max_deflection_position()))], Units.small_length(beam.max_deflection()))
			t += F.note("Superposition adds deflections at the same x. The maxima of v_P and v_w are generally at different places, so v_max ≠ v_P,max + v_w,max.")
			t += F.try_this("move the point load and watch only the v_P curve (figure) change.")
		4:
			var limit: float = LENGTH / LIMIT_RATIO
			var ok: bool = beam.max_deflection() <= limit
			t += "Beams must be stiff as well as strong: floors that sag feel unsafe and crack finishes. A common limit is L/360:\n"
			t += F.equation("v_allow = L/360", "", Units.small_length(limit))
			t += F.equation("v_max", "", Units.small_length(beam.max_deflection()))
			t += "→ %s\n" % F.ok_or_fail(ok, "stiff enough" if ok else "too flexible")
			t += "Because v ∝ 1/I, the moment of inertia needed is\n"
			t += F.equation("I_req = I·v_max/v_allow", "", Units.inertia(beam.required_inertia(limit)))
			t += F.equation("I (current)", SectionText.describe(beam.section), Units.inertia(beam.section.moment_of_inertia()))
			t += F.try_this("find the lightest section that passes. Changing material helps less than you might think: E of steel is only 3× aluminum's.")
		INDETERMINATE:
			var pr := _propped
			pr.load = beam.load
			pr.load_position = beam.load_position
			pr.distributed_load = beam.distributed_load
			pr.section = beam.section
			pr.material = beam.material
			var released := CantileverBeam.new(LENGTH, beam.load, beam.load_position, beam.section, beam.material)
			released.distributed_load = beam.distributed_load
			t += "Add a roller under the free end of a cantilever: four reactions (R_A, M_A, R_B and a horizontal one) but only three equilibrium equations — the [b]propped cantilever[/b] is statically indeterminate to the first degree.\n"
			t += "[b]Method of superposition[/b]: remove the roller (the redundant R_B), compute the end deflection of the released cantilever under the loads, then find the R_B that pushes the end back to zero:\n"
			t += F.equation("v_B (loads, no roller)", "", Units.small_length(released.deflection_at(LENGTH)))
			t += F.equation("compatibility: v_B − R_B·L³/(3EI) = 0", "")
			t += F.equation("R_B = 3EI·v_B/L³", "", Units.force(pr.reaction_b()))
			t += F.equation("R_A = P + wL − R_B", "", Units.force(pr.reaction_a()))
			t += F.equation("M_A", "", Units.moment(pr.fixed_end_moment()))
			t += F.equation("v_max", "at x = %s" % Units.length(pr.max_deflection_position()), Units.small_length(pr.max_deflection()))
			t += F.note("Check (uniform load only): R_B = 3wL/8, M_A = −wL²/8, v_max = wL⁴/(185EI). Indeterminate beams are stiffer and their moments are spread more evenly — but supports that settle change the reactions.")
			t += F.try_this("select 'Propped cantilever' in Supports and compare v_max with the cantilever under the same loads.")
	return t


## Same support and section as the current beam, with other loads (for superposition).
func _copy(p: float, w: float) -> BeamModel:
	var b: BeamModel
	if beam is ProppedCantileverBeam:
		b = ProppedCantileverBeam.new(LENGTH, p, beam.load_position, beam.section, beam.material)
	elif beam is CantileverBeam:
		b = CantileverBeam.new(LENGTH, p, beam.load_position, beam.section, beam.material)
	else:
		b = SimplySupportedBeam.new(LENGTH, p, beam.load_position, beam.section, beam.material)
	b.distributed_load = w
	return b


func fill_figures(figures: FigureArea) -> void:
	match step():
		0:
			var p := figures.plot(0)
			p.begin("Curvature M/EI along the beam", "x (m)", "M/EI (10⁻³/m)")
			p.line(_sample(func(x: float) -> float: return beam.curvature_at(x) * 1e3), Color(0.65, 0.45, 0.95), 3.0, true)
		1:
			var p0 := figures.plot(0)
			p0.begin("M/EI", "x (m)", "10⁻³/m")
			p0.line(_sample(func(x: float) -> float: return beam.curvature_at(x) * 1e3), Color(0.65, 0.45, 0.95), 2.5, true)
			var p1 := figures.plot(1)
			p1.begin("slope θ = dv/dx", "x (m)", "θ (10⁻³ rad)")
			p1.line(_sample(func(x: float) -> float: return beam.slope_at(x) * 1e3), Color(0.3, 0.9, 1.0), 2.5)
			var p2 := figures.plot(2)
			p2.begin("deflection v (downward)", "x (m)", "v (mm)")
			p2.flip_y = true
			p2.line(_sample(func(x: float) -> float: return beam.deflection_at(x) * Units.MM), Color(0.95, 0.8, 0.4), 2.5)
			if beam is CantileverBeam:
				p1.marker(Vector2.ZERO, Color(1, 0.4, 0.4), "θ(0) = 0")
				p2.marker(Vector2.ZERO, Color(1, 0.4, 0.4), "v(0) = 0")
			else:
				p2.marker(Vector2.ZERO, Color(1, 0.4, 0.4), "v(0) = 0")
				p2.marker(Vector2(LENGTH, 0.0), Color(1, 0.4, 0.4), "v(L) = 0")
		2, 4:
			var p := figures.plot(0)
			p.begin("Elastic curve v(x)", "x (m)", "v (mm)")
			p.flip_y = true
			p.line(_sample(func(x: float) -> float: return beam.deflection_at(x) * Units.MM), Color(0.95, 0.8, 0.4), 3.0)
			p.marker(Vector2(beam.max_deflection_position(), beam.max_deflection() * Units.MM), Color(1, 0.4, 0.4), "v_max")
			if step() == 4:
				p.hline(LENGTH / LIMIT_RATIO * Units.MM, Color(1.0, 0.4, 0.4), "L/360")
		3:
			var only_p := _copy(beam.load, 0.0)
			var only_w := _copy(0.0, beam.distributed_load)
			var p := figures.plot(0)
			p.begin("Superposition: v = v_P + v_w", "x (m)", "v (mm)")
			p.flip_y = true
			p.line(_sample(func(x: float) -> float: return only_p.deflection_at(x) * Units.MM), Color(0.95, 0.95, 1.0), 2.0)
			p.line(_sample(func(x: float) -> float: return only_w.deflection_at(x) * Units.MM), Color(0.95, 0.65, 0.3), 2.0)
			p.line(_sample(func(x: float) -> float: return beam.deflection_at(x) * Units.MM), Color(1.0, 0.85, 0.35), 3.5)
			p.marker(Vector2(1.0, only_p.deflection_at(1.0) * Units.MM), Color(0.95, 0.95, 1.0), "v_P")
			p.marker(Vector2(LENGTH - 1.0, only_w.deflection_at(LENGTH - 1.0) * Units.MM), Color(0.95, 0.65, 0.3), "v_w")


func _sample(f: Callable) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 161:
		var x: float = LENGTH * i / 160.0
		pts.append(Vector2(x, f.call(x)))
	return pts


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([ORIGIN + Vector3(-0.4, -0.4, 0.4), ORIGIN + Vector3(LENGTH + 0.3, -0.7, 0.4),
			ORIGIN + Vector3(-0.4, 0.9, 0.0), ORIGIN + Vector3(LENGTH + 0.3, 0.9, 0.0)])
