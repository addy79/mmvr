extends LabStation
## Lab 10 - W beams and S beams (ANSYS): W200x52 and S250x52, 1 m long, fixed at the wall and
## connected to other beams at the far end, with a uniform load on the top flange. Both are
## drawn side by side at true size, deflection exaggerated.

const BENCH := Vector3(-0.6, 1.0, 0.0)
const NAMES: PackedStringArray = ["W200×52", "S250×52"]
## Textbook (Beer & Johnston Appendix C) properties: A [mm^2], I_x [10^6 mm^4], S_x [10^3 mm^3], I_y [10^6 mm^4]
const HANDBOOK: Array[Vector4] = [Vector4(6650.0, 52.7, 511.0, 17.8), Vector4(6650.0, 61.2, 482.0, 3.59)]
const RESULTS: int = 3

var _steel: LabMaterial = LabMaterial.steel()
var _benches: Array[LabBeamBench] = [LabBeamBench.new(1.2), LabBeamBench.new(1.2)]
var _labels: Array[Label3D] = [Text3D.make(24), Text3D.make(24)]


func _init() -> void:
	lab = 10
	title = "W beams and S beams (ANSYS)"
	handout = "Lab Handout N°10 - W beams and S beams.docx"
	_controls = [
		ControlSpec.slider(&"w", "Uniform load on the top flange w", "kN/m", Units.KN, 10.0, 600.0, 10.0, 200.0e3, 0),
		ControlSpec.choice(&"end", "Far end", PackedStringArray(["Connected (pinned)", "Free"]), 0),
		ControlSpec.slider(&"L", "Length", "m", 1.0, 0.5, 3.0, 0.1, 1.0).only_in([2, RESULTS, 4]),
		ControlSpec.slider(&"exaggeration", "Deflection drawn ×", "", 1.0, 1.0, 500.0, 1.0, 200.0, 0),
	]
	for i: int in 2:
		_benches[i].position = BENCH + Vector3(0.0, 0.0, -0.45 + 0.9 * i)
		add_child(_benches[i])
		_labels[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(_labels[i])


## Fillet-free I-sections from the Appendix C dimensions (d, b_f, t_f, t_w).
static func section(i: int) -> ISection:
	if i == 0:
		return ISection.new(0.206, 0.204, 0.0126, 0.0079)
	return ISection.new(0.254, 0.126, 0.0125, 0.0151)


func beam(i: int) -> BeamModel:
	var b: BeamModel
	if value(&"end") == 0.0:
		b = ProppedCantileverBeam.new(value(&"L"), 0.0, value(&"L"), section(i), _steel)
	else:
		b = CantileverBeam.new(value(&"L"), 0.0, value(&"L"), section(i), _steel)
	b.distributed_load = value(&"w")
	return b


func _apply() -> void:
	for i: int in 2:
		var b: BeamModel = beam(i)
		var supports: Array[Dictionary] = [{"x": 0.0, "kind": "fixed"}]
		if value(&"end") == 0.0:
			supports.append({"x": b.length, "kind": "roller"})
		var none: Array[Dictionary] = []
		_labels[i].position = _benches[i].position + Vector3(b.length * 1.2 + 0.15, 0.15, 0.0)
		_labels[i].text = "%s\nv_max %s\nσ_v max %s" % [NAMES[i], Units.mm(absf(b.max_deflection()), 3), Units.stress(b.max_von_mises())]
		_benches[i].show_beam(b, supports, none, value(&"exaggeration"), 1.0, "w = " + Units.distributed(b.distributed_load))


func _show_step() -> void:
	_apply()


func step_titles() -> PackedStringArray:
	return ["Objective", "The two sections", "Model and loads", "Results", "Which is stronger?", "Report questions"]


func lesson_text() -> String:
	var F := LessonFormat
	var t: String = ""
	match step():
		0:
			t += "Beams carry floors and roofs to the columns. Their [b]cross-section shape[/b] decides how well they do it. Here two standard steel shapes of the [b]same weight per meter[/b] (52 kg/m, same area) are loaded identically in ANSYS: a wide-flange W200×52 and an American Standard S250×52.\n"
			t += "Since they use the same amount of steel, any difference in deflection or stress comes only from where that steel is placed in the section.\n"
			t += handout_note()
		1:
			var rows: Array[PackedStringArray] = []
			var labels: PackedStringArray = ["t_f (flange thickness)", "t_w (web thickness)", "b_f (flange width)", "d (depth)"]
			var values: Array[Array] = [[12.6, 12.5], [7.9, 15.1], [204.0, 126.0], [206.0, 254.0]]
			for k: int in 4:
				rows.append(PackedStringArray([labels[k], Units.fixed(values[k][0], 1), Units.fixed(values[k][1], 1)]))
			t += "Dimensions from Appendix C of the textbook (mm):\n"
			t += F.table(["Dimension (mm)", NAMES[0], NAMES[1]], rows)
			var props: Array[PackedStringArray] = []
			for i: int in 2:
				var s: ISection = section(i)
				props.append(PackedStringArray([NAMES[i], "%s (%s)" % [Units.fixed(s.area() * 1e6, 0), Units.fixed(HANDBOOK[i].x, 0)],
						"%s (%s)" % [Units.fixed(s.moment_of_inertia() * 1e6, 1), Units.fixed(HANDBOOK[i].y, 1)],
						"%s (%s)" % [Units.fixed(s.section_modulus() * 1e6 * 1e3, 0), Units.fixed(HANDBOOK[i].z, 0)],
						"%s (%s)" % [Units.fixed(s.moment_of_inertia_vertical() * 1e6, 2), Units.fixed(HANDBOOK[i].w, 2)]]))
			t += "Section properties computed from those dimensions (handbook values in parentheses; the small differences are the fillets and, for the S shape, the sloped flanges, which the model leaves out):\n"
			t += F.table(["Shape", "A (mm²)", "I_x (10⁶ mm⁴)", "S_x (10³ mm³)", "I_y (10⁶ mm⁴)"], props)
			t += "The S shape is deeper (larger I_x: stiffer in bending) but has narrow flanges and a thick web, so its S_x is a little smaller and its I_y is about five times smaller than the W shape's.\n"
		2:
			t += "Each beam is %s long, [b]fixed[/b] to a wall at one end and %s at the other, with a uniform load w = %s on the top flange (keep the same value for both beams).\n" % [Units.length(value(&"L")), "connected to other beams (modeled as a pin/roller: no deflection, free rotation)" if value(&"end") == 0.0 else "free", Units.distributed(value(&"w"))]
			if value(&"end") == 0.0:
				t += "Fixed + pinned is statically indeterminate (chapter 9, propped cantilever):\n"
				t += F.equation("R_B = 3wL/8,  R_A = 5wL/8", "")
				t += F.equation("M_wall = −wL²/8", "", Units.moment(-value(&"w") * pow(value(&"L"), 2) / 8.0))
				t += F.equation("v_max = wL⁴/(185EI)", "at x = 0.579L")
			else:
				t += F.equation("M_wall = −wL²/2,  v_tip = wL⁴/(8EI)", "")
			t += "To monitor the beam in ANSYS insert three results: [b]Total Deformation[/b], [b]Equivalent (von Mises) Stress[/b] and [b]Equivalent Elastic Strain[/b] (or Maximum Shear Stress).\n"
		RESULTS:
			var rows: Array[PackedStringArray] = []
			for i: int in 2:
				var b: BeamModel = beam(i)
				rows.append(PackedStringArray([NAMES[i], Units.mm(absf(b.max_deflection()), 3), Units.stress(b.max_bending_stress()),
						Units.stress(b.max_shear_stress()), Units.stress(b.max_von_mises()), Units.strain(b.max_von_mises() / _steel.youngs_modulus)]))
			t += "Beam-theory values your ANSYS results should be close to:\n"
			t += F.table(["Beam", "Max deformation", "Max σ (flanges)", "Max τ (web)", "Max σ_v", "Max strain"], rows)
			t += "• Deformation ∝ 1/I_x: the deeper S250×52 deflects less.\n"
			t += "• Bending stress = M/S_x: the W200×52 (larger S_x) has slightly lower flange stress.\n"
			t += "• Shear is carried by the web, τ ≈ V/(d·t_w): the S shape's thick web gives it lower shear stress. On a short, heavily loaded beam like this one, the web shear near the wall is what governs the von Mises stress.\n"
			t += F.note("ANSYS's 3D solid model also includes shear deformation (noticeable for a 1 m beam 0.2 m deep, adding several % to the deflection) and the local stresses where the load and supports are applied, so its numbers will differ a little from beam theory.")
		4:
			var b0: BeamModel = beam(0)
			var b1: BeamModel = beam(1)
			t += "'Stronger' depends on the criterion, so compare them on each:\n"
			t += F.equation("stiffness (deflection)", "%s vs %s" % [Units.mm(absf(b0.max_deflection()), 3), Units.mm(absf(b1.max_deflection()), 3)], "S stiffer" if absf(b1.max_deflection()) < absf(b0.max_deflection()) else "W stiffer")
			t += F.equation("largest von Mises stress", "%s vs %s" % [Units.stress(b0.max_von_mises()), Units.stress(b1.max_von_mises())], "W lower" if b0.max_von_mises() < b1.max_von_mises() else "S lower")
			t += F.equation("weak-axis I_y", "%s vs %s" % [Units.inertia(section(0).moment_of_inertia_vertical()), Units.inertia(section(1).moment_of_inertia_vertical())], "W ≈ 5× larger")
			t += "For a vertical load on a short, laterally braced beam the S shape's extra depth makes it stiffer, while the W shape's wider flanges put more steel far from the axis per unit of web, giving a larger S_x for bending. The wide flanges are why W shapes dominate modern construction: much larger I_y and torsional stiffness, so far better resistance to [b]lateral-torsional buckling[/b] (a long beam twisting sideways), stability as columns, and flat flanges that are easy to connect. S shapes (sloped flanges, thick webs) are older and used today mainly for rails, hoists and short members.\n"
			t += F.try_this("make the beam 3 m long: bending takes over from shear, and compare the two again. Then let the far end be free.")
		5:
			t += F.question("Dimensions tf, tw, bf, d of each beam.", "From Appendix C (step 2 table).")
			t += F.question("Which variables to insert to monitor the beam?", "Total deformation, equivalent (von Mises) stress, and equivalent elastic strain (or maximum shear stress) — record their maxima for each beam (step 4).")
			t += F.question("Which type of beam is stronger? Why?", "Argue with the numbers (step 5): for this loading the S shape deflects less (larger I_x), the W shape has the lower bending stress (larger S_x) and is far more stable sideways (I_y five times larger), which is why it is the preferred structural shape. State which criterion you use.")
	return t


func fill_figures(figures: FigureArea) -> void:
	if step() < 2 or step() == 5:
		return
	var p := figures.plot(0)
	p.begin("Deflection along the beam", "x (m)", "v (mm)")
	p.flip_y = true
	var colors: Array[Color] = [Color(0.5, 0.85, 1.0), Color(1.0, 0.65, 0.35)]
	for i: int in 2:
		var b: BeamModel = beam(i)
		var pts := PackedVector2Array()
		for k: int in 101:
			var x: float = b.length * k / 100.0
			pts.append(Vector2(x, b.deflection_at(x) * Units.MM))
		p.line(pts, colors[i], 2.5)
		p.marker(Vector2(b.max_deflection_position(), b.max_deflection() * Units.MM), colors[i], NAMES[i])
	var m := figures.plot(1)
	m.begin("Bending moment (same for both)", "x (m)", "M (kN·m)")
	var b0: BeamModel = beam(0)
	var ms := PackedVector2Array()
	for k: int in 101:
		var x: float = b0.length * k / 100.0
		ms.append(Vector2(x, b0.moment_at(x) * Units.KN))
	m.line(ms, Color(0.95, 0.75, 0.35), 2.5, true)


func frame_points() -> PackedVector3Array:
	var l: float = value(&"L") * 1.2
	return PackedVector3Array([BENCH + Vector3(-0.3, -0.3, 0.7), BENCH + Vector3(l + 0.9, 0.6, -0.7)])


func view_direction() -> Vector3:
	return Vector3(0.5, 0.45, 1.0)
