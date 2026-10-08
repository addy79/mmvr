extends LabStation
## Lab 1 - Determination of the stress withstood by a specimen (pure aluminum and H111).
## The MTTU: turn the wheel, read the dial gauge, get F from the springs, sigma = F/A.

const MACHINE := Vector3(-0.6, 0.0, 0.0)
const MATERIALS: PackedStringArray = ["Pure aluminum", "Aluminum H111"]

var rig: TensileRig = TensileRig.new()
var _view: MttuView = MttuView.new()
var _materials: Array[LabMaterial] = [LabMaterial.pure_aluminum(), LabMaterial.aluminum_h111()]


func _init() -> void:
	lab = 1
	title = "Stress withstood by a specimen"
	handout = "Lab Handout N°1-Determination of the stress withstood by a specimen.docx"
	_controls = [
		ControlSpec.choice(&"material", "Specimen", MATERIALS, 0),
		ControlSpec.slider(&"n", "Readings taken (1/3 turn each)", "", 1.0, 1.0, 40.0, 1.0, 10.0, 0),
		ControlSpec.slider(&"e", "Thickness e at the middle", "mm", Units.MM, 0.5, 5.0, 0.05, 2.0e-3),
		ControlSpec.slider(&"a", "Width a at the middle", "mm", Units.MM, 2.0, 15.0, 0.05, 5.0e-3),
		ControlSpec.slider(&"k", "Spring stiffness k (MTTU sheet)", "N/mm", 1.0e-3, 50.0, 2000.0, 10.0, 200.0e3, 0).only_in([1, 2]),
		ControlSpec.slider(&"rc0", "Dial gauge at rest RC0", "mm", Units.MM, 0.0, 25.0, 0.01, 10.0e-3).only_in([1, 2]),
		ControlSpec.choice(&"readings", "Simulated readings", READINGS, 1).only_in([2, 3]),
	]
	_view.position = MACHINE
	add_child(_view)


func _apply() -> void:
	rig.material = _materials[int(value(&"material"))]
	rig.thickness = value(&"e")
	rig.width = value(&"a")
	rig.spring_stiffness = value(&"k")
	rig.dial_zero = value(&"rc0")
	_view.show_state(rig, rig.state_at(int(value(&"n"))))


func _show_step() -> void:
	_apply()


func step_titles() -> PackedStringArray:
	return ["Objective", "The MTTU", "Readings table", "Aluminum vs H111", "Report questions"]


## Row i (1-based) as the student would record it: RC read on the dial, then dL, F, sigma.
func _row(i: int) -> Dictionary:
	var s: Dictionary = rig.state_at(i)
	var dial: float = reading(s.dial, i + 100 * int(value(&"material")), 0.002, 1.0e-5)
	var d_l: float = rig.dial_zero - dial
	var f: float = rig.spring_stiffness * d_l
	return {"rc": dial, "dl": d_l, "f": f, "sigma": f / rig.area(), "broken": s.broken}


func lesson_text() -> String:
	var F := LessonFormat
	var t: String = ""
	var n: int = int(value(&"n"))
	var s: Dictionary = rig.state_at(n)
	match step():
		0:
			t += "Goal: find the stress a specimen of known dimensions withstands, by pulling it in the Mechanical Tensile Testing Unit (MTTU): a [b]tensile test[/b].\n"
			t += "Stress is force per unit area. When a force F is spread uniformly over a cross-section of area A, the [b]normal (uniaxial) stress[/b] is\n"
			t += F.equation("σ = F/A", "", "N/mm² = MPa")
			t += "Our specimens are flat bars, so the area of the middle section is the thickness e times the width a, measured with the digital caliper:\n"
			t += F.equation("A = e·a", "%s × %s" % [Units.mm(rig.thickness), Units.mm(rig.width)], "%s mm²" % Units.fixed(rig.area() * 1e6, 2))
			t += "Why stress and not just force? Two bars of the same metal break at very different forces if their areas differ, but at the [b]same stress[/b]: σ is a property of the material, F is not. That is what lets an engineer use a lab result to size a real part.\n"
			t += F.note("Units: 1 N/mm² = 1 MPa = 10⁶ Pa. Keep forces in N and areas in mm² and the stress comes out directly in MPa.")
			t += handout_note()
		1:
			t += "The specimen hangs between two anchors. The [b]upper anchor[/b] is raised by the wheel; the [b]lower anchor[/b] is held down by calibrated springs. Specimen and springs are in [b]series[/b]: the same force F goes through both.\n"
			t += F.equation("F = k·ΔL", "k from the MTTU description sheet")
			t += F.equation("ΔL = RC0 − RC", "dial gauge reading at rest minus reading now")
			t += "So the dial gauge, which only measures how far the lower anchor has risen, is really a [b]force gauge[/b]: the springs turn a displacement into a force.\n"
			t += F.equation("now: ΔL", "%s − %s" % [Units.mm(rig.dial_zero), Units.mm(s.dial)], Units.mm(s.spring))
			t += F.equation("F = k·ΔL", "%s N/mm × %s" % [Units.fixed(rig.spring_stiffness * 1e-3, 0), Units.mm(s.spring)], Units.newtons(s.force))
			t += F.equation("σ = F/A", "%s / %s mm²" % [Units.newtons(s.force), Units.fixed(rig.area() * 1e6, 2)], Units.stress(s.stress))
			t += "Each third of a turn of the wheel raises the upper anchor by 0.5 mm. That travel is shared: most goes into stretching the springs, a little into stretching the specimen (lab 2 uses this to measure strain).\n"
			t += F.try_this("increase the number of readings until the specimen breaks: the force rises, levels off as the aluminum yields and hardens, then drops and the bar snaps.")
		2:
			t += "Procedure: zero the dial (record RC0), then turn the wheel one third of a turn at a time and record RC after each. Compute ΔL, F and σ for each point. Table %d of the handout (%s):\n" % [int(value(&"material")) + 1, MATERIALS[int(value(&"material"))]]
			t += F.equation("RC0", "", Units.mm(rig.dial_zero))
			t += F.equation("A", "", "%s mm²" % Units.fixed(rig.area() * 1e6, 2))
			var rows: Array[PackedStringArray] = []
			for i: int in range(1, n + 1):
				var r: Dictionary = _row(i)
				rows.append(PackedStringArray([str(i), Units.mm_value(r.rc), Units.mm_value(r.dl), Units.fixed(r.f, 1),
						"broken" if r.broken else Units.mpa_value(r.sigma)]))
			t += F.table(["#", "RC (mm)", "ΔL = RC0 − RC (mm)", "F (N)", "σ (N/mm²)"], rows)
			t += "Sample calculation (last row): ΔL = RC0 − RC, F = k·ΔL, σ = F/(e·a). The largest σ in the table is the [b]stress withstood[/b] (the ultimate strength if you went to fracture).\n"
			t += F.note("With realistic scatter the dial readings carry a small error, as yours will. Put the table in Excel with the formulas, as the handout asks.")
		3:
			var steps_pure: int = _fracture_steps(0)
			var steps_h: int = _fracture_steps(1)
			t += "Same rig, same specimen size, two materials. The figure traces σ against the wheel travel for both, up to fracture.\n"
			t += F.equation("Pure aluminum: σ_max", "", "%s  (breaks after %d steps)" % [Units.stress(_materials[0].ultimate_strength), steps_pure])
			t += F.equation("Aluminum H111: σ_max", "", "%s  (breaks after %d steps)" % [Units.stress(_materials[1].ultimate_strength), steps_h])
			t += "Both curves start with the same steep slope: in the elastic range the springs take almost all the travel, so F rises by about k × 0.5 mm per step whatever the specimen. They separate when the softer one [b]yields[/b]: its own elongation then grows quickly and the force can no longer climb.\n"
			t += "Pure aluminum has few obstacles to dislocation motion and yields at about %s. The H111 alloy is strengthened by magnesium atoms in solid solution and by a little strain hardening, so it withstands about %s.\n" % [Units.stress(_materials[0].yield_strength), Units.stress(_materials[1].ultimate_strength)]
			t += F.note("The values used here are typical datasheet values (1050-O and 5754-H111). Your specimens may differ: trust your table.")
		4:
			t += F.question("Draw a force diagram of the specimen under test.",
					"Isolate the specimen. Only two forces act: the upper anchor pulls it up with F, the lower anchor (springs) pulls it down with F. Its weight is negligible next to F. Equal, opposite and collinear: it is a two-force member in equilibrium, and any cut section carries an internal normal force N = F.")
			t += F.question("Why is it called tensile testing?",
					"The loads pull the ends apart, so the material is in [b]tension[/b] (σ > 0, the bar lengthens and narrows). Compare with a compression test, where the load pushes the ends together.")
			t += F.question("What is the composition of H111?",
					"Careful: H111 is not an alloy but a [b]temper designation[/b]. 'H' = strain-hardened, 'H1' = strain-hardened only (no heat treatment), 'H111' = hardened slightly less than H11, typically by straightening after annealing. The composition is given by the four-digit alloy number in front of it (for example 5754 = aluminum with about 2.6–3.6 % Mg; 5083 = about 4–4.9 % Mg with Mn and Cr). Look at the specimen label or datasheet to tell which alloy you tested.")
			t += F.question("Which material is stronger, and why?",
					"Compare the largest σ of your two tables (not the largest F unless the areas are equal). The alloy is stronger: alloying atoms distort the crystal lattice and pin dislocations (solid-solution strengthening), and prior cold work adds more dislocations that block each other (strain hardening).")
			t += F.question("Why measure the stress at the narrowest (middle) section?",
					"F is the same in every section (equilibrium), so σ = F/A is largest where A is smallest: that is where the material yields and breaks first, so it is the stress that matters. The middle is also far from the grips, where by Saint-Venant's principle the stress is uniform and σ = F/A is valid; near the grips the stress is disturbed.")
	return t


func _fracture_steps(material_index: int) -> int:
	var probe := TensileRig.new()
	probe.material = _materials[material_index]
	probe.thickness = rig.thickness
	probe.width = rig.width
	probe.spring_stiffness = rig.spring_stiffness
	return probe.steps_to_fracture()


func fill_figures(figures: FigureArea) -> void:
	match step():
		1, 2:
			var p := figures.plot(0)
			p.begin("Stress vs wheel travel (%s)" % MATERIALS[int(value(&"material"))], "L_up (mm)", "σ (MPa)")
			p.line(_curve(int(value(&"material"))), Color(0.95, 0.75, 0.35), 2.5)
			var pts := PackedVector2Array()
			for i: int in range(1, int(value(&"n")) + 1):
				pts.append(Vector2(i * TensileRig.TRAVEL_PER_STEP * Units.MM, _row(i).sigma * Units.MPA))
			for q: Vector2 in pts:
				p.marker(q, Color(1, 1, 1))
		3:
			var p := figures.plot(0)
			p.begin("Pure aluminum vs H111 (same specimen size)", "L_up (mm)", "σ (MPa)")
			p.line(_curve(0), Color(0.5, 0.8, 1.0), 2.5)
			p.line(_curve(1), Color(1.0, 0.6, 0.35), 2.5)
			p.hline(_materials[0].ultimate_strength * Units.MPA, Color(0.5, 0.8, 1.0), "pure Al σ_max")
			p.hline(_materials[1].ultimate_strength * Units.MPA, Color(1.0, 0.6, 0.35), "H111 σ_max")


## sigma vs wheel travel from 0 to fracture for one material, same specimen and springs.
func _curve(material_index: int) -> PackedVector2Array:
	var probe := TensileRig.new()
	probe.material = _materials[material_index]
	probe.thickness = rig.thickness
	probe.width = rig.width
	probe.spring_stiffness = rig.spring_stiffness
	var pts := PackedVector2Array()
	var steps: int = probe.steps_to_fracture()
	for i: int in steps * 4 + 1:
		var travel: float = i * TensileRig.TRAVEL_PER_STEP / 4.0
		var st: Dictionary = probe.state_at_travel(travel)
		pts.append(Vector2(travel * Units.MM, st.stress * Units.MPA))
	return pts


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([MACHINE + Vector3(-0.5, 0.0, 0.3), MACHINE + Vector3(-0.5, 2.2, 0.0),
			MACHINE + Vector3(1.1, 0.0, 0.3), MACHINE + Vector3(1.1, 2.2, 0.0)])
