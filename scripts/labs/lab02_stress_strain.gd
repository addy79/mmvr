extends LabStation
## Lab 2 - The stress-strain curve and Young's modulus, on the MTTU. Strain from the
## travel of the upper anchor minus the springs' extension: delta = L_up - dL.

const MACHINE := Vector3(-0.6, 0.0, 0.0)
const MATERIALS: PackedStringArray = ["Steel", "Aluminum"]
const FIT: int = 3

var rig: TensileRig = TensileRig.new()
var _view: MttuView = MttuView.new()
var _materials: Array[LabMaterial] = [LabMaterial.steel(), LabMaterial.aluminum()]


func _init() -> void:
	lab = 2
	title = "Stress-strain curve and Young's modulus"
	handout = "Lab Handout N°2-The Stress-Strain curve and Young’s Modulus.docx"
	_controls = [
		ControlSpec.choice(&"material", "Specimen", MATERIALS, 0),
		ControlSpec.slider(&"n", "Readings taken", "", 1.0, 2.0, 40.0, 1.0, 12.0, 0),
		ControlSpec.slider(&"every", "Thirds of a turn between readings", "", 1.0, 1.0, 10.0, 1.0, 2.0, 0),
		ControlSpec.slider(&"fit", "Readings used for the line fit", "", 1.0, 2.0, 40.0, 1.0, 12.0, 0).only_in([FIT, 4]),
		ControlSpec.slider(&"L0", "Initial length L0", "mm", Units.MM, 20.0, 100.0, 1.0, 50.0e-3, 0),
		ControlSpec.slider(&"e", "Thickness e", "mm", Units.MM, 0.5, 5.0, 0.05, 2.0e-3),
		ControlSpec.slider(&"a", "Width a", "mm", Units.MM, 2.0, 15.0, 0.05, 5.0e-3),
		ControlSpec.slider(&"k", "Spring stiffness k", "N/mm", 1.0e-3, 50.0, 2000.0, 10.0, 200.0e3, 0).only_in([1, 2, 4]),
		ControlSpec.choice(&"readings", "Simulated readings", READINGS, 1).only_in([2, FIT, 4]),
	]
	_view.position = MACHINE
	add_child(_view)


func _apply() -> void:
	rig.material = _materials[int(value(&"material"))]
	rig.thickness = value(&"e")
	rig.width = value(&"a")
	rig.gauge_length = value(&"L0")
	rig.spring_stiffness = value(&"k")
	_view.show_state(rig, rig.state_at(_last_step()))


func _show_step() -> void:
	_apply()


func _last_step() -> int:
	return int(value(&"n")) * int(value(&"every"))


func step_titles() -> PackedStringArray:
	return ["Objective", "Measuring strain", "Readings table", "σ-ε chart and E", "Why E comes out wrong", "Report questions"]


## Reading number i: L_up from the wheel count, RC on the dial; the student's delta, eps, sigma.
func _row(i: int) -> Dictionary:
	var s: Dictionary = rig.state_at(i * int(value(&"every")))
	var key: int = i + 1000 * int(value(&"material"))
	var d_l: float = rig.dial_zero - reading(s.dial, key, 0.002, 1.0e-5)
	var l_up: float = s.travel
	var f: float = rig.spring_stiffness * d_l
	var delta: float = l_up - d_l
	return {"rc": rig.dial_zero - d_l, "dl": d_l, "lup": l_up, "f": f, "sigma": f / rig.area(),
			"delta": delta, "eps": delta / rig.gauge_length, "broken": s.broken}


## Line through the first `fit` readings of sigma (MPa) vs eps: its slope is E.
func _fit() -> LinearFit:
	var pts := PackedVector2Array()
	for i: int in range(1, mini(int(value(&"fit")), int(value(&"n"))) + 1):
		var r: Dictionary = _row(i)
		if not r.broken:
			pts.append(Vector2(r.eps, r.sigma * Units.MPA))
	return LinearFit.of(pts)


func lesson_text() -> String:
	var F := LessonFormat
	var m: LabMaterial = rig.material
	var t: String = ""
	match step():
		0:
			t += "Lab 1 measured the stress σ = F/A. Here we also measure the [b]strain[/b], the deformation per unit length, so we can plot the stress-strain curve and read the material's stiffness, [b]Young's modulus E[/b].\n"
			t += F.equation("ε = (L_t − L0)/L0 = δ/L0", "", "dimensionless (mm/mm)")
			t += "ε > 0 in tension (the specimen lengthens), ε < 0 in compression. In the elastic range stress and strain are proportional (Hooke's law):\n"
			t += F.equation("σ = E·ε", "", "E in MPa (or GPa)")
			t += "So on a σ-ε chart the first part of the data is a straight line through the origin whose [b]slope is E[/b]. Beyond it the material yields: strain grows with little extra stress, and part of it is permanent.\n"
			t += handout_note()
		1:
			var s: Dictionary = rig.state_at(_last_step())
			t += "The MTTU has no extensometer, so δ is found by difference. When the wheel turns, the upper anchor rises by L_up; that travel is the specimen's elongation [b]plus[/b] the springs' extension (the lower anchor rises by ΔL, read on the dial):\n"
			t += F.equation("L_up = δ + ΔL", "")
			t += F.equation("δ = L_up − ΔL", "%s − %s" % [Units.mm(s.travel, 1), Units.mm(s.spring, 3)], Units.mm(s.elongation, 3))
			t += F.equation("ε = δ/L0", "%s / %s" % [Units.mm(s.elongation, 3), Units.mm(rig.gauge_length, 0)], Units.strain(s.strain))
			t += F.equation("σ = k·ΔL/A", "", Units.stress(s.stress))
			t += "L_up comes from the graduated scale or from counting: each third of a turn is 0.5 mm.\n"
			t += F.try_this("watch the specimen's length in the 3D view while you add readings: almost nothing happens until it yields, then it stretches visibly.")
		2:
			t += "Table for %s (L0 = %s, A = %s mm², RC0 = %s, a reading every %d thirds of a turn):\n" % [m.display_name,
					Units.mm(rig.gauge_length, 0), Units.fixed(rig.area() * 1e6, 2), Units.mm(rig.dial_zero), int(value(&"every"))]
			var rows: Array[PackedStringArray] = []
			for i: int in range(1, int(value(&"n")) + 1):
				var r: Dictionary = _row(i)
				rows.append(PackedStringArray([Units.mm_value(r.rc), Units.mm_value(r.dl), Units.mm_value(r.lup, 1),
						Units.fixed(r.f, 0), "broken" if r.broken else Units.mpa_value(r.sigma, 1),
						Units.mm_value(r.delta, 3), Units.fixed(r.eps, 5)]))
			t += F.table(["RC (mm)", "ΔL (mm)", "L_up (mm)", "F (N)", "σ (MPa)", "δ (mm)", "ε"], rows)
			t += F.note("Switch the specimen to fill the other table. Keep the same readings plan for both materials so they can be compared.")
		FIT:
			var fit: LinearFit = _fit()
			t += "Plot σ (y) against ε (x) for each material, then fit a straight line to the points of the [b]linear part[/b] only (choose how many readings go into the fit). The slope of the line is the measured Young's modulus:\n"
			t += F.equation("fit: σ = m·ε + b", "m = %s MPa, b = %s MPa, R² = %s" % [Units.fixed(fit.slope, 0), Units.fixed(fit.intercept, 1), Units.fixed(fit.r_squared, 4)])
			t += F.equation("E_measured = m", "", "%s GPa" % Units.fixed(fit.slope * 1e-3, 1))
			t += F.equation("E handbook (%s)" % m.display_name, "", Units.modulus(m.youngs_modulus))
			t += F.equation("difference", "", "%s %%" % Units.fixed(percent_error(fit.slope * 1e6, m.youngs_modulus), 0))
			t += "Points past the yield point bend away from the line; leaving them in the fit lowers the slope and R². A good fit uses only the straight part and should pass close to the origin (b ≈ 0).\n"
			t += F.try_this("set the readings to Ideal: E comes out exactly right. Then back to Realistic scatter and see how far it moves. The next step explains why.")
		4:
			var share: float = rig.elastic_share_of_travel()
			var per_step: float = TensileRig.TRAVEL_PER_STEP * share
			t += "Expect your measured E to be far from the handbook value. This is a property of the setup, not a mistake in your calculations.\n"
			t += "While elastic, the specimen is far stiffer than the springs, so it takes only a tiny share of the travel:\n"
			t += F.equation("specimen stiffness EA/L0", "", "%s N/mm" % Units.fixed(m.youngs_modulus * rig.area() / rig.gauge_length * 1e-3, 0))
			t += F.equation("share of L_up taken by the specimen = k/(k + EA/L0)", "", "%s %%" % Units.fixed(share * 100.0, 2))
			t += F.equation("elastic δ per 1/3 turn", "0.5 mm × share", Units.mm(per_step, 4))
			t += "δ = L_up − ΔL is the small difference of two large numbers. A dial reading error of only ±0.01 mm is %s of that δ, and L_up read on the scale is only good to about ±0.25 mm. Slack and seating in the grips and anchors also add travel that is not specimen strain. All of it lands in δ, so the elastic strain, and therefore E, is very uncertain, while σ (from ΔL alone) stays accurate.\n" % ("%s times" % Units.fixed(0.01e-3 / per_step, 0) if per_step < 0.01e-3 else "%s %%" % Units.fixed(0.01e-3 / per_step * 100.0, 0))
			t += "This is why real tensile tests measure strain directly on the gauge length with an [b]extensometer[/b] or a [b]strain gauge[/b], not from the crosshead travel.\n"
			t += F.try_this("make the springs stiffer (larger k) or the specimen longer and thinner: the specimen's share of the travel grows and E becomes easier to measure.")
		5:
			var other: LabMaterial = _materials[1 - int(value(&"material"))]
			t += F.question("Draw the σ-ε chart of each material.", "Use σ on the vertical axis and ε (dimensionless) on the horizontal one, one chart per material, with the data points as markers (not joined by a smooth curve you cannot justify).")
			t += F.question("What is Young's modulus of each material (MPa)?", "Fit a line to the linear part only and display its equation; E is the slope in MPa. Report the R² and compare with the handbook value (%s for %s, %s for %s); discuss the difference using the previous step." % [Units.modulus(m.youngs_modulus), m.display_name, Units.modulus(other.youngs_modulus), other.display_name])
			t += F.question("Which material has the higher Young's modulus? Why?", "Steel (≈ 200 GPa vs ≈ 70 GPa for aluminum). E measures the stiffness of the interatomic bonds: iron atoms are bonded more stiffly than aluminum atoms (iron also melts at a much higher temperature). E hardly changes with alloying or heat treatment, unlike strength.")
			t += F.question("Which material supports a higher stress before permanent strain? Why?", "That stress is the [b]yield strength[/b] (or the proportional/elastic limit). Read it where your curve leaves the straight line, or use the 0.2 % offset method: draw a line of slope E starting at ε = 0.002 and take its intersection with the curve. Typical values: A36 steel 250 MPa, 6061-T6 aluminum 240 MPa, so the answer depends on the grades of your specimens. Strength depends on how easily dislocations move (alloying, heat treatment, cold work), not on bond stiffness.")
	return t


func fill_figures(figures: FigureArea) -> void:
	if step() < 2 or step() == 5:
		var p := figures.plot(0)
		var curve := StressStrainCurve.new(rig.material)
		p.begin("σ-ε curve of %s (theory)" % rig.material.display_name, "ε", "σ (MPa)")
		var pts := PackedVector2Array()
		for i: int in 301:
			var e: float = rig.material.fracture_strain * i / 300.0
			pts.append(Vector2(e, curve.stress_at(e) * Units.MPA))
		p.line(pts, Color(0.95, 0.75, 0.35), 2.5)
		return
	var p := figures.plot(0)
	p.begin("Measured σ-ε (%s)" % rig.material.display_name, "ε", "σ (MPa)")
	var fit: LinearFit = _fit()
	var max_eps: float = 0.0
	for i: int in range(1, int(value(&"n")) + 1):
		var r: Dictionary = _row(i)
		if r.broken:
			continue
		p.marker(Vector2(r.eps, r.sigma * Units.MPA), Color(1, 1, 1) if i <= int(value(&"fit")) else Color(0.6, 0.6, 0.65))
		max_eps = maxf(max_eps, r.eps)
	if step() >= FIT and fit.count >= 2:
		var x1: float = 0.0
		for i: int in range(1, mini(int(value(&"fit")), int(value(&"n"))) + 1):
			x1 = maxf(x1, _row(i).eps)
		p.line(PackedVector2Array([Vector2(0.0, fit.intercept), Vector2(x1, fit.at(x1))]), Color(0.4, 0.9, 0.5), 2.5)
		var e_hand: float = rig.material.youngs_modulus * Units.MPA
		var y_end: float = minf(e_hand * x1, rig.material.yield_strength * Units.MPA)
		p.line(PackedVector2Array([Vector2.ZERO, Vector2(y_end / e_hand, y_end)]), Color(0.5, 0.75, 1.0), 1.5)


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([MACHINE + Vector3(-0.5, 0.0, 0.3), MACHINE + Vector3(-0.5, 2.2, 0.0),
			MACHINE + Vector3(1.1, 0.0, 0.3), MACHINE + Vector3(1.1, 2.2, 0.0)])
