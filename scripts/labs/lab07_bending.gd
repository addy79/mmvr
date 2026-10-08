extends LabStation
## Lab 7 - Bending of beams and rods: a bar on two supports with a central load, dial gauge at
## midspan. Part 1: three stainless steel bars, measured vs theoretical deflection.
## Part 2: a brass rod, Young's modulus from the slope of a straight-line plot.
## Drawn 3x real size (sections 9x).

const BENCH := Vector3(-0.6, 1.0, 0.0)
const DRAW: float = 3.0
const LOADS_1: Array[float] = [5.0, 10.0, 15.0, 20.0]
const LOADS_2: Array[float] = [5.0, 10.0, 15.0, 20.0, 25.0]
const PART2: int = 4
const BRASS_E: int = 5

var beam: SimplySupportedBeam
var _bench: LabBeamBench = LabBeamBench.new(DRAW)
var _steel: LabMaterial = LabMaterial.stainless_304()
var _brass: LabMaterial = LabMaterial.brass()
var _gauge: MeshInstance3D = MeshInstance3D.new()


func _init() -> void:
	lab = 7
	title = "Bending of beams and rods"
	handout = "Lab Handout N°7 - Bending of Beams and Rods.docx"
	_controls = [
		ControlSpec.choice(&"bar", "On the supports", PackedStringArray(["Bar 1", "Bar 2", "Bar 3", "Brass rod"]), 0),
		ControlSpec.choice(&"load", "Load at the center", PackedStringArray(["5 N", "10 N", "15 N", "20 N", "25 N"]), 3),
		ControlSpec.slider(&"l", "Span between supports l", "mm", Units.MM, 200.0, 800.0, 10.0, 0.4, 0),
		ControlSpec.slider(&"b1", "Bar 1 width b", "mm", Units.MM, 3.0, 40.0, 0.5, 0.02, 1).only_in([1, 2, 3]),
		ControlSpec.slider(&"d1", "Bar 1 depth d", "mm", Units.MM, 2.0, 20.0, 0.5, 0.003, 1).only_in([1, 2, 3]),
		ControlSpec.slider(&"b2", "Bar 2 width b", "mm", Units.MM, 3.0, 40.0, 0.5, 0.02, 1).only_in([1, 2, 3]),
		ControlSpec.slider(&"d2", "Bar 2 depth d", "mm", Units.MM, 2.0, 20.0, 0.5, 0.005, 1).only_in([1, 2, 3]),
		ControlSpec.slider(&"b3", "Bar 3 width b", "mm", Units.MM, 3.0, 40.0, 0.5, 0.01, 1).only_in([1, 2, 3]),
		ControlSpec.slider(&"d3", "Bar 3 depth d", "mm", Units.MM, 2.0, 20.0, 0.5, 0.01, 1).only_in([1, 2, 3]),
		ControlSpec.slider(&"D", "Brass rod diameter D", "mm", Units.MM, 4.0, 16.0, 0.1, 0.008, 1).only_in([PART2, BRASS_E]),
		ControlSpec.choice(&"readings", "Simulated readings", READINGS, 1).only_in([2, 3, PART2, BRASS_E]),
		ControlSpec.slider(&"exaggeration", "Deflection drawn ×", "", 1.0, 1.0, 30.0, 1.0, 5.0, 0),
	]
	_bench.position = BENCH
	add_child(_bench)
	var dial := CylinderMesh.new()
	dial.top_radius = 0.05
	dial.bottom_radius = 0.05
	dial.height = 0.03
	_gauge.mesh = dial
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.92, 0.9)
	_gauge.material_override = white
	add_child(_gauge)


func _section(bar: int) -> CrossSection:
	if bar == 3:
		return CircleSection.new(value(&"D") / 2.0)
	var ids: Array[StringName] = [&"b1", &"b2", &"b3"]
	var dids: Array[StringName] = [&"d1", &"d2", &"d3"]
	return RectSection.new(value(ids[bar]), value(dids[bar]))


func _beam(bar: int, load: float) -> SimplySupportedBeam:
	var l: float = value(&"l")
	return SimplySupportedBeam.new(l, load, l / 2.0, _section(bar), _brass if bar == 3 else _steel)


## Midspan deflection the dial would show [m].
func _measured(bar: int, load_index: int) -> float:
	var loads: Array[float] = LOADS_2 if bar == 3 else LOADS_1
	return reading(_beam(bar, loads[load_index]).deflection_at(value(&"l") / 2.0), bar * 10 + load_index, 0.05, 0.01e-3)


func _apply() -> void:
	var bar: int = int(value(&"bar"))
	var loads: Array[float] = LOADS_2
	beam = _beam(bar, loads[int(value(&"load"))])
	var l: float = beam.length
	var supports: Array[Dictionary] = [{"x": 0.0, "kind": "pin"}, {"x": l, "kind": "roller"}]
	var point: Array[Dictionary] = [{"x": l / 2.0, "text": "F = " + Units.newtons(beam.load, 0)}]
	_bench.show_beam(beam, supports, point, value(&"exaggeration"), DRAW)
	_gauge.position = BENCH + Vector3(l / 2.0 * DRAW, -0.12, 0.0)
	_bench.set_caption("%s: δ = %s\n(drawn ×%d)" % ["Brass rod" if bar == 3 else "Bar %d" % (bar + 1),
			Units.mm(beam.deflection_at(l / 2.0), 3), int(value(&"exaggeration"))], Vector3(l / 2.0 * DRAW, 0.45, 0.0))


func _show_step() -> void:
	if step() >= PART2 and value(&"bar") != 3.0:
		control(&"bar").value = 3.0
	elif step() in [1, 2, 3] and value(&"bar") == 3.0:
		control(&"bar").value = 0.0
	_apply()


func step_titles() -> PackedStringArray:
	return ["Objective and theory", "Part 1: the bench", "Part 1: deflections", "Ranking and I", "Part 2: brass readings", "Young's modulus of brass", "Report questions"]


func lesson_text() -> String:
	var F := LessonFormat
	var l: float = value(&"l")
	var t: String = ""
	match step():
		0:
			t += "A bar rests on two supports a span l apart and carries a load F at the center. A dial gauge under the center reads the [b]deflection[/b]. Part 1 compares three steel bars of different cross-sections; Part 2 uses the same idea backwards to measure the Young's modulus of brass.\n"
			t += "Elastic beam theory (chapter 9) gives the midspan deflection of a simply supported beam with a central load:\n"
			t += F.derivation("M(x) = Fx/2 for x ≤ l/2. Integrating EI·v'' = −M twice with v(0) = 0 and v'(l/2) = 0 (symmetry) gives v(l/2) = Fl³/(48EI).")
			t += F.equation("δ_max = F·l³/(48·E·I)", "(1)")
			t += F.equation("I = b·d³/12", "rectangle b wide, d deep (d along the load)")
			t += "δ is proportional to F (linear elastic), very sensitive to the span (l³), and inversely proportional to the [b]flexural rigidity EI[/b]: E is the material's stiffness, I the section's.\n"
			t += handout_note()
		1:
			t += "Place a bar on the supports, the dial gauge at the center, the hook at the center, and load it with 5, 10, 15 and 20 N. AISI 304 stainless steel: E = 193 000 N/mm².\n"
			t += F.equation("now: I = b·d³/12", "", "%s mm⁴" % Units.fixed(beam.section.moment_of_inertia() * 1e12, 1))
			t += F.equation("δ = F·l³/(48EI)", "%s × %s³ / (48 × %s × %s mm⁴)" % [Units.newtons(beam.load, 0), Units.mm(l, 0), Units.fixed(beam.material.youngs_modulus * 1e-6, 0), Units.fixed(beam.section.moment_of_inertia() * 1e12, 1)], Units.mm(beam.deflection_at(l / 2.0), 3))
			t += F.equation("bending stress σ = M·c/I, M = F·l/4", "", Units.stress(beam.max_bending_stress()))
			t += "The stress stays far below the yield strength (%s): the bars return to zero, so the test is repeatable.\n" % Units.stress(_steel.yield_strength)
			t += F.note("Set the bar sizes and span to the ones you used (b = width, d = depth in the load direction; the defaults are placeholders).")
			t += F.try_this("turn a bar on its side (swap b and d): with d³ in I, the deflection changes enormously.")
		2:
			for bar: int in 3:
				var s: CrossSection = _section(bar)
				var rows: Array[PackedStringArray] = []
				for i: int in 4:
					var theory: float = _beam(bar, LOADS_1[i]).deflection_at(l / 2.0)
					var meas: float = _measured(bar, i)
					rows.append(PackedStringArray(["%d N" % LOADS_1[i], Units.mm_value(meas, 2), Units.mm_value(theory, 3), Units.fixed(percent_error(meas, theory), 1)]))
				t += F.section("Steel bar %d: d = %s, b = %s, I = %s mm⁴" % [bar + 1, Units.mm(value([&"d1", &"d2", &"d3"][bar]), 1), Units.mm(value([&"b1", &"b2", &"b3"][bar]), 1), Units.fixed(s.moment_of_inertia() * 1e12, 1)])
				t += F.table(["Load", "Measured δ (mm)", "Theoretical δ (mm)", "% error"], rows)
			t += F.equation("% error = |measured − theory| / theory × 100", "")
			t += F.note("Real errors come from the dial's resolution (0.01 mm, large next to small deflections), the bar not sitting flat, support friction, and the actual E and dimensions differing from nominal (d is cubed: a 2 % error in d is 6 % in δ).")
		3:
			var rows: Array[PackedStringArray] = []
			var order: Array[int] = [0, 1, 2]
			order.sort_custom(func(a: int, b: int) -> bool: return _section(a).moment_of_inertia() > _section(b).moment_of_inertia())
			for bar: int in order:
				rows.append(PackedStringArray(["Bar %d" % (bar + 1), "%s mm⁴" % Units.fixed(_section(bar).moment_of_inertia() * 1e12, 1), Units.mm(_beam(bar, 20.0).deflection_at(l / 2.0), 3)]))
			var rod := CircleSection.new(0.004)
			rows.append(PackedStringArray(["Steel rod D = 8 mm", "%s mm⁴" % Units.fixed(rod.moment_of_inertia() * 1e12, 1), Units.mm(SimplySupportedBeam.new(l, 20.0, l / 2.0, rod, _steel).deflection_at(l / 2.0), 3)]))
			t += "Most to least resistant to bending (smallest deflection first, same material and span):\n"
			t += F.table(["Bar", "I", "δ at 20 N"], rows)
			t += "The ranking is exactly the ranking of I: with the same E and l, δ ∝ 1/I.\n"
			t += "The [b]area moment of inertia[/b] I = ∫y²dA measures how far the section's area lies from the neutral axis. Bending stretches and shortens fibers in proportion to their distance y, and their resisting moment grows with y again, hence y². Depth counts as d³, width only as b: the same bar is far stiffer on edge than flat.\n"
			t += F.equation("round rod D = 8 mm: I = π·D⁴/64", "π × 8⁴ / 64", "%s mm⁴" % Units.fixed(rod.moment_of_inertia() * 1e12, 1))
			t += "Compare that value with your bars' I to decide whether the rod is more resistant; it is only if its I is larger.\n"
		PART2:
			var rows: Array[PackedStringArray] = []
			for i: int in 5:
				rows.append(PackedStringArray(["%d N" % LOADS_2[i], Units.mm_value(_measured(3, i), 2)]))
			t += "Same bench, a brass rod of diameter %s (I = π·D⁴/64 = %s mm⁴). Load it with 5 to 25 N and record the deflection:\n" % [Units.mm(value(&"D"), 1), Units.fixed(_section(3).moment_of_inertia() * 1e12, 1)]
			t += F.table(["Load", "Measured δ (mm)"], rows)
		BRASS_E:
			var fit: LinearFit = _brass_fit()
			t += "Rearrange equation (1) so that E is a slope:\n"
			t += F.equation("F·l³/(48·I) = E·δ", "")
			t += "Plot y = F·l³/(48I) (N/mm) against x = δ (mm): the points fall on a line through the origin whose slope is E (N/mm² = MPa).\n"
			t += F.equation("fit: y = E·δ", "E = %s MPa, R² = %s" % [Units.fixed(fit.slope, 0), Units.fixed(fit.r_squared, 4)], "%s GPa" % Units.fixed(fit.slope * 1e-3, 1))
			t += F.equation("handbook (yellow brass)", "", Units.modulus(_brass.youngs_modulus))
			t += F.note("Plotting F against δ would also work (slope = 48EI/l³), but then E needs another step; the choice of variables above makes the slope E directly. Brass E ranges about 100–125 GPa depending on composition and temper.")
		6:
			t += F.question("Rank the three bars from most to least resistant.", "By measured deflection at the same load (step 4). It matches the ranking of I.")
			t += F.question("What do you notice about their area moment of inertia? How can you define it?", "Smaller deflection ↔ larger I. I = ∫y²dA about the neutral axis: the section's resistance to bending from the way its area is distributed (b·d³/12 for a rectangle).")
			t += F.question("Cylindrical steel rod D = 8 mm: I, and more resistant?", "I = πD⁴/64 = 201 mm⁴. Compare with each bar's I (step 4).")
			t += F.question("Which variables to plot so that the slope is E? The value of E in GPa?", "y = F·l³/(48I) against x = δ (step 6), straight line through the origin, slope = E. Convert MPa to GPa (÷1000).")
	return t


func _brass_fit() -> LinearFit:
	var l: float = value(&"l")
	var i_mm: float = _section(3).moment_of_inertia() * 1e12
	var pts := PackedVector2Array()
	for k: int in 5:
		pts.append(Vector2(_measured(3, k) * Units.MM, LOADS_2[k] * pow(l * Units.MM, 3) / (48.0 * i_mm)))
	return LinearFit.of(pts, true)


func fill_figures(figures: FigureArea) -> void:
	var l: float = value(&"l")
	match step():
		2, 3:
			var p := figures.plot(0)
			p.begin("Measured (dots) and theoretical (lines) deflection", "load (N)", "δ (mm)")
			var colors: Array[Color] = [Color(0.5, 0.85, 1.0), Color(1.0, 0.65, 0.35), Color(0.55, 0.95, 0.55)]
			for bar: int in 3:
				p.line(PackedVector2Array([Vector2.ZERO, Vector2(20.0, _beam(bar, 20.0).deflection_at(l / 2.0) * Units.MM)]), colors[bar], 2.0)
				for i: int in 4:
					p.marker(Vector2(LOADS_1[i], _measured(bar, i) * Units.MM), colors[bar], "bar %d" % (bar + 1) if i == 3 else "")
		BRASS_E:
			var p := figures.plot(0)
			var fit: LinearFit = _brass_fit()
			p.begin("F·l³/(48I) vs δ: slope = E", "δ (mm)", "F·l³/(48I) (N/mm)")
			var x_end: float = 0.0
			for k: int in 5:
				var pt := Vector2(_measured(3, k) * Units.MM, LOADS_2[k] * pow(l * Units.MM, 3) / (48.0 * _section(3).moment_of_inertia() * 1e12))
				p.marker(pt, Color(1, 1, 1))
				x_end = maxf(x_end, pt.x)
			p.line(PackedVector2Array([Vector2.ZERO, Vector2(x_end, fit.slope * x_end)]), Color(0.4, 0.9, 0.5), 2.5)


func frame_points() -> PackedVector3Array:
	var l: float = value(&"l") * DRAW
	return PackedVector3Array([BENCH + Vector3(-0.2, -0.3, 0.2), BENCH + Vector3(l + 0.2, 0.5, 0.0)])
