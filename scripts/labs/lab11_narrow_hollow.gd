extends LabStation
## Lab 11 - Narrow and hollow rectangular beams (ANSYS): a cantilever H x t x L loaded at its
## free end, the usual way (load along H), as a narrow beam (load along t), and hollow (box
## section, wall d). Drawn 2x real size.

const BENCH := Vector3(-0.5, 1.0, 0.0)
const DRAW: float = 2.0
const CASES: PackedStringArray = ["Usual", "Narrow", "Hollow d₁", "Hollow d₂"]
const HOLLOW: int = 4

var _steel: LabMaterial = LabMaterial.steel()
var _bench: LabBeamBench = LabBeamBench.new(DRAW)


func _init() -> void:
	lab = 11
	title = "Narrow and hollow rectangular beams"
	handout = "Lab Handout N°11 - Narrow and Hollow Rectangular beams.docx"
	_controls = [
		ControlSpec.choice(&"case", "Beam shown", CASES, 0),
		ControlSpec.slider(&"P", "Load at the free end", "kN", Units.KN, 0.1, 10.0, 0.1, 2.0e3, 1),
		ControlSpec.slider(&"H", "Height H", "mm", Units.MM, 10.0, 120.0, 1.0, 0.06, 0).only_in([1, 2, 3, HOLLOW, 5]),
		ControlSpec.slider(&"t", "Thickness t", "mm", Units.MM, 5.0, 80.0, 1.0, 0.03, 0).only_in([1, 2, 3, HOLLOW, 5]),
		ControlSpec.slider(&"L", "Length L", "mm", Units.MM, 100.0, 1000.0, 10.0, 0.5, 0).only_in([1, 2, 3, HOLLOW, 5]),
		ControlSpec.slider(&"d1", "Hollow wall d₁", "mm", Units.MM, 1.0, 20.0, 0.5, 0.003, 1).only_in([HOLLOW, 5]),
		ControlSpec.slider(&"d2", "Hollow wall d₂", "mm", Units.MM, 1.0, 20.0, 0.5, 0.006, 1).only_in([HOLLOW, 5]),
		ControlSpec.slider(&"exaggeration", "Deflection drawn ×", "", 1.0, 1.0, 100.0, 1.0, 20.0, 0),
	]
	_bench.position = BENCH
	add_child(_bench)


## Case 0 usual, 1 narrow, 2/3 hollow box t x H with wall d1/d2 (clamped so a hole remains).
func section(c: int) -> CrossSection:
	var h: float = value(&"H")
	var t: float = value(&"t")
	match c:
		0:
			return RectSection.new(t, h)
		1:
			return RectSection.new(h, t)
	var d: float = value(&"d1") if c == 2 else value(&"d2")
	return BoxSection.new(t, h, minf(d, 0.45 * minf(t, h)))


func beam(c: int) -> CantileverBeam:
	return CantileverBeam.new(value(&"L"), value(&"P"), value(&"L"), section(c), _steel)


## Free-end deflection with shear deformation (ANSYS's solid model includes it).
func tip_deflection(c: int) -> float:
	var b: CantileverBeam = beam(c)
	return b.deflection_at(b.length) + b.shear_deflection_at_tip()


func _case() -> int:
	match step():
		2:
			return 0 if value(&"case") > 1.0 else int(value(&"case"))
	return int(value(&"case"))


func _apply() -> void:
	var c: int = _case()
	var b: CantileverBeam = beam(c)
	var supports: Array[Dictionary] = [{"x": 0.0, "kind": "fixed"}]
	var loads: Array[Dictionary] = [{"x": b.length, "text": "P = " + Units.force(b.load)}]
	_bench.show_beam(b, supports, loads, value(&"exaggeration"), 1.0)
	_bench.set_caption("%s: tip %s, σ max %s\n(drawn ×%d)" % [CASES[c], Units.mm(tip_deflection(c), 3), Units.stress(b.max_bending_stress()), int(value(&"exaggeration"))],
			Vector3(b.length * DRAW / 2.0, 0.5, 0.0))


func _show_step() -> void:
	_apply()


func step_titles() -> PackedStringArray:
	return ["Objective", "The model", "Usual vs narrow", "Shear stress across the section", "Full vs hollow", "Where the material works", "Report questions"]


func _row(c: int, label: String) -> PackedStringArray:
	var b: CantileverBeam = beam(c)
	return PackedStringArray([label, Units.fixed(b.section.moment_of_inertia() * 1e6, 3), Units.mm_value(tip_deflection(c), 3),
			Units.mpa_value(b.max_bending_stress(), 1), Units.mpa_value(b.max_shear_stress(), 2), Units.mpa_value(b.max_combined_shear(), 1)])


func lesson_text() -> String:
	var F := LessonFormat
	var t: String = ""
	var headers: PackedStringArray = ["Beam", "I (10⁶ mm⁴)", "v_tip (mm)", "σ_max (MPa)", "τ = VQ/It (MPa)", "τ_max (MPa)"]
	match step():
		0:
			t += "Same cantilever, three ways of building or loading it: the [b]usual[/b] way (load along the height H), as a [b]narrow[/b] beam (load along the small thickness t), and [b]hollow[/b] (material removed from the inside). Compare the deformation and the shear stress in ANSYS and explain the differences.\n"
			t += "Everything follows from where the material sits relative to the neutral axis: I = ∫y²dA for bending, and the shear formula τ = VQ/(It) for shear.\n"
			t += handout_note()
		1:
			t += "Beam H × t × L = %s × %s × %s (set these to the dimensions you use in ANSYS and report them in the handout's table), structural steel, fixed at one end. The load P = %s acts on the free end face (t × H).\n" % [Units.mm(value(&"H"), 0), Units.mm(value(&"t"), 0), Units.mm(value(&"L"), 0), Units.force(value(&"P"))]
			t += F.equation("cantilever, end load: v_tip = PL³/(3EI) + PL/(G·A_s)", "bending + shear deformation (A_s = 5A/6 for a rectangle)")
			t += F.equation("σ_max = M·c/I = P·L·c/I", "at the wall, top and bottom fibers")
			t += F.equation("τ_max = V·Q/(I·t) = 1.5·V/A", "rectangle, at the neutral axis")
			t += "ANSYS's 'Maximum Shear Stress' is the largest shear stress on any plane at a point, √((σ/2)² + τ²) (the Tresca measure). At the wall's top fiber it equals σ_max/2, which is usually much larger than the transverse shear τ.\n"
		2:
			var rows: Array[PackedStringArray] = [_row(0, "Usual"), _row(1, "Narrow")]
			t += F.table(headers, rows)
			var ratio: float = pow(value(&"H") / value(&"t"), 2)
			t += "Turning the beam does not change its area, so the transverse shear 1.5V/A is the [b]same[/b]. But the bending properties change a lot:\n"
			t += F.equation("I_usual / I_narrow = (tH³/12)/(Ht³/12) = (H/t)²", "", Units.fixed(ratio, 2))
			t += "So the narrow beam deflects about (H/t)² = %s times more (a bit less once shear deformation counts) and its bending stress is H/t = %s times higher, so its maximum shear stress (σ/2) is higher too. The usual configuration carries much more load for the same steel.\n" % [Units.fixed(ratio, 1), Units.fixed(value(&"H") / value(&"t"), 2)]
			t += "A narrow configuration is better when you [b]want flexibility[/b] (leaf springs, flexures, snap fits, a diving board) or when the load really comes sideways. Also, a deep narrow beam loaded the usual way can twist and buckle sideways (lateral-torsional buckling) if not braced.\n"
		3:
			t += "Transverse shear across the depth at the wall, τ(y) = VQ(y)/(I·t(y)): a parabola, zero at the top and bottom faces and largest at the neutral axis. Both orientations peak at the same 1.5V/A; the narrow one has a shorter, fatter parabola.\n"
			t += "In ANSYS 'Shear Stress' (τ_xy in the load plane) shows this parabola; 'Maximum Shear Stress' instead shows the Tresca value, dominated by the bending stress near the wall.\n"
		HOLLOW:
			var rows: Array[PackedStringArray] = [_row(0, "Full"), _row(2, "Hollow d₁ = %s" % Units.mm(value(&"d1"), 1)), _row(3, "Hollow d₂ = %s" % Units.mm(value(&"d2"), 1))]
			t += "Same outer size t × H, usual loading, walls of thickness d:\n"
			t += F.table(headers, rows)
			var full: CrossSection = section(0)
			var thin: CrossSection = section(2)
			t += F.equation("material kept (d₁)", "", "%s %% of the area, %s %% of I" % [Units.fixed(thin.area() / full.area() * 100.0, 0), Units.fixed(thin.moment_of_inertia() / full.moment_of_inertia() * 100.0, 0)])
			var area_ratio: float = thin.area() / full.area()
			var i_ratio: float = thin.moment_of_inertia() / full.moment_of_inertia()
			t += "The core sits near the neutral axis, where y² is small, so it contributes little to I: removing it loses a smaller share of I (%s %%) than of the material (%s %% removed). Per kilogram of steel, the hollow beam is %s times stiffer. In absolute terms it deflects and bends more, the more so the thinner the wall.\n" % [Units.fixed((1.0 - i_ratio) * 100.0, 0), Units.fixed((1.0 - area_ratio) * 100.0, 0), Units.fixed(i_ratio / area_ratio, 2)]
			t += "The transverse shear rises much more, because the shear must now go through the two thin walls (τ ≈ V/(2·d·H)).\n"
			t += "Thinner walls (smaller d): lighter, a bit more flexible, much higher shear stress, and eventually local buckling of the walls, which this simple theory does not capture.\n"
		5:
			var full: CrossSection = section(0)
			var thin: CrossSection = section(2)
			t += "Bending stress σ(y) = −My/I is largest at the top and bottom, where the hollow section keeps its material; the core of a full beam carries almost no bending stress. That is why the hollow (and I-beams) are efficient.\n"
			t += F.equation("stiffness per weight, I/A: full", "", "%s mm²" % Units.fixed(full.moment_of_inertia() / full.area() * 1e6, 0))
			t += F.equation("stiffness per weight, I/A: hollow d₁", "", "%s mm²" % Units.fixed(thin.moment_of_inertia() / thin.area() * 1e6, 0))
			t += "The figure shows the shear stress across the depth: in the hollow beam it jumps up where the width drops from t to 2d.\n"
		6:
			t += F.question("Usual vs narrow: which sustains more load and why? When is narrow better?", "Usual: I is (H/t)² larger, so less deflection and lower bending stress (step 3). Narrow is better when flexibility is wanted, or for loads that act along t.")
			t += F.question("Full vs hollow: deformation and shear stress? Effect of d?", "Hollow deflects more and has much higher shear stress, but it is stiffer per unit of weight; thinner walls make deflection and shear larger (step 5). Quote your ANSYS values next to these.")
			t += F.question("When is a hollow beam better than a full one?", "When weight or material matter (vehicles, aircraft, cranes, long spans where self-weight dominates), when torsional stiffness is needed (closed sections resist twisting very well), or to run services inside. A full beam is better under very high local or shear loads, and is cheaper to make for small parts.")
	return t


func fill_figures(figures: FigureArea) -> void:
	if step() != 3 and step() != 5:
		return
	var p := figures.plot(0)
	p.begin("Transverse shear at the wall across the depth", "τ (MPa)", "y (mm)")
	var cases: Array[int] = [0, 1]
	if step() == 5:
		cases = [0, 2, 3]
	var short: PackedStringArray = ["Usual", "Narrow", "Hollow d₁", "Hollow d₂"]
	var colors: Array[Color] = [Color(0.5, 0.85, 1.0), Color(1.0, 0.65, 0.35), Color(0.55, 0.95, 0.6), Color(0.85, 0.6, 1.0)]
	for c: int in cases:
		var b: CantileverBeam = beam(c)
		var cmax: float = b.section.y_max()
		var pts := PackedVector2Array()
		for k: int in 201:
			var y: float = -cmax + 2.0 * cmax * k / 200.0
			pts.append(Vector2(b.shear_stress(0.0, y) * Units.MPA, y * Units.MM))
		p.line(pts, colors[c], 2.5)
		p.marker(pts[100], colors[c], short[c])
	if step() == 5:
		var s := figures.plot(1)
		s.begin("Bending stress at the wall across the depth, σ = −My/I", "σ (MPa)", "y (mm)")
		for c: int in [0, 2]:
			var b: CantileverBeam = beam(c)
			var cmax: float = b.section.y_max()
			s.line(PackedVector2Array([Vector2(b.bending_stress(0.0, -cmax) * Units.MPA, -cmax * Units.MM), Vector2(b.bending_stress(0.0, cmax) * Units.MPA, cmax * Units.MM)]), colors[c], 2.5)


func frame_points() -> PackedVector3Array:
	var l: float = value(&"L") * DRAW
	return PackedVector3Array([BENCH + Vector3(-0.3, -0.3, 0.2), BENCH + Vector3(l + 0.2, 0.6, 0.0)])
