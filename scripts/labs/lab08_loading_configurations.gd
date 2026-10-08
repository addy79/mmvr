extends LabStation
## Lab 8 - Loading configurations of beams (ANSYS): a 500 x 20 x 4 mm steel bar as a
## cantilever, simply supported, and over-hanging, loaded at x = 125 or 250 mm (or at the
## free end). Beam theory gives what the ANSYS "Directional Deformation" should read.
## Drawn 2x real size (sections 8x).

const BENCH := Vector3(-0.5, 1.0, 0.0)
const DRAW: float = 2.0
const LENGTH: float = 0.5
const POSITIONS: Array[float] = [0.125, 0.25]
const LOADS: Array[float] = [5.0, 10.0, 15.0]
const CONFIGS: PackedStringArray = ["Cantilever", "Simply supported", "Over-hanging"]

var beam: BeamModel
var _bench: LabBeamBench = LabBeamBench.new(DRAW)
var _steel: LabMaterial = LabMaterial.steel()


func _init() -> void:
	lab = 8
	title = "Loading configurations of beams (ANSYS)"
	handout = "Lab Handout N°8 - Loading Configurations of Beams.docx"
	_controls = [
		ControlSpec.choice(&"config", "Configuration", CONFIGS, 0).only_in([0, 1, 5, 6]),
		ControlSpec.choice(&"x", "Load position x", PackedStringArray(["125 mm", "250 mm"]), 1).only_in([0, 1, 2, 3, 5, 6]),
		ControlSpec.choice(&"load", "Load F", PackedStringArray(["5 N", "10 N", "15 N"]), 2),
		ControlSpec.slider(&"s", "Over-hang: second support at", "mm", Units.MM, 250.0, 500.0, 5.0, 0.4, 0).only_in([4, 5]),
		ControlSpec.choice(&"turn", "Bar orientation", PackedStringArray(["Flat (4 mm deep)", "On edge (20 mm deep)"]), 0),
		ControlSpec.slider(&"exaggeration", "Deflection drawn ×", "", 1.0, 1.0, 20.0, 1.0, 2.0, 0),
	]
	_bench.position = BENCH
	add_child(_bench)


func _section() -> RectSection:
	return RectSection.new(0.02, 0.004) if value(&"turn") == 0.0 else RectSection.new(0.004, 0.02)


## config 0 cantilever (fixed at x = 0), 1 simply supported, 2 over-hanging (load at the tip).
func _beam(config: int, x: float, load: float) -> BeamModel:
	match config:
		0:
			return CantileverBeam.new(LENGTH, load, x, _section(), _steel)
		1:
			return SimplySupportedBeam.new(LENGTH, load, x, _section(), _steel)
	return OverhangBeam.new(LENGTH, load, LENGTH, _section(), _steel, value(&"s"))


func _max_deflection(config: int, x: float, load: float) -> float:
	return absf(_beam(config, x, load).max_deflection())


func _config() -> int:
	match step():
		2:
			return 0
		3:
			return 1
		4:
			return 2
	return int(value(&"config"))


func _apply() -> void:
	var config: int = _config()
	var x: float = LENGTH if config == 2 else POSITIONS[int(value(&"x"))]
	beam = _beam(config, x, LOADS[int(value(&"load"))])
	var supports: Array[Dictionary] = []
	match config:
		0:
			supports = [{"x": 0.0, "kind": "fixed"}]
		1:
			supports = [{"x": 0.0, "kind": "pin"}, {"x": LENGTH, "kind": "roller"}]
		2:
			supports = [{"x": 0.0, "kind": "pin"}, {"x": value(&"s"), "kind": "roller"}]
	var loads: Array[Dictionary] = [{"x": x, "text": "F = " + Units.newtons(beam.load, 0)}]
	_bench.show_beam(beam, supports, loads, value(&"exaggeration"), 4.0)
	_bench.set_caption("%s, x = %s\nmax deflection %s (drawn ×%d)" % [CONFIGS[config], Units.mm(x, 0),
			Units.mm(absf(beam.max_deflection()), 2), int(value(&"exaggeration"))], Vector3(LENGTH * DRAW / 2.0, 0.5, 0.0))


func _show_step() -> void:
	_apply()


func step_titles() -> PackedStringArray:
	return ["Objective", "The ANSYS model", "Cantilever", "Simply supported", "Over-hanging", "All configurations", "Report questions"]


func _table(config: int, positions: Array[float]) -> String:
	var rows: Array[PackedStringArray] = []
	for x: float in positions:
		for f: float in LOADS:
			rows.append(PackedStringArray([Units.mm_value(x, 0), Units.fixed(f, 0), Units.fixed(_max_deflection(config, x, f), 6)]))
	return LessonFormat.table(["X (mm)", "Load (N)", "Maximum deflection (m)"], rows)


func lesson_text() -> String:
	var F := LessonFormat
	var s: RectSection = _section()
	var ei: float = _steel.youngs_modulus * s.moment_of_inertia()
	var t: String = ""
	match step():
		0:
			t += "One rectangular bar, three ways of supporting it: [b]cantilever[/b] (one end built in), [b]simply supported[/b] (pin and roller at the ends) and [b]over-hanging[/b] (the load beyond a support). Load it with 5, 10 and 15 N at different places in ANSYS and compare the maximum deflections.\n"
			t += "The support conditions decide how the bending moment builds up along the beam, and the deflection is the double integral of M/EI (chapter 9). This bench gives the beam-theory values your ANSYS results should match.\n"
			t += handout_note()
		1:
			t += "Geometry: 500 mm long, 20 mm wide, 4 mm thick; lines drawn at 125 mm and 250 mm to place the loads. ANSYS default 'Structural Steel': E = 200 GPa, ν = 0.3. Mesh: element size 0.01 m. Result: Deformation → Directional (along the load, negative = down).\n"
			t += F.equation("I = b·h³/12", "%s × %s³ / 12" % [Units.mm(s.b, 0), Units.mm(s.h, 0)], "%s mm⁴" % Units.fixed(s.moment_of_inertia() * 1e12, 2))
			t += F.equation("EI", "", "%s N·m²" % Units.fixed(ei, 3))
			t += "The load is applied across the 4 mm thickness (the bar lies flat), the way it bends most. Turn it on edge to see I grow 25 times.\n"
			t += F.note("With 10 mm elements ANSYS has only one element through the 4 mm thickness. Its default quadratic elements still bend well; if your results come out much stiffer than these, refine the mesh through the thickness.")
		2:
			var a: float = POSITIONS[int(value(&"x"))]
			t += "Fixed at one end (x = 0), free at the other; x is the load's distance from the wall. The tip deflects most:\n"
			t += F.equation("v_tip = F·a²·(3L − a)/(6EI)", "a = x, L = 500 mm")
			t += F.equation("now", "", Units.mm(_max_deflection(0, a, LOADS[int(value(&"load"))]), 3))
			t += "Beyond the load the beam carries no moment, so it stays straight and keeps the slope θ = Fa²/(2EI) it has under the load.\n"
			t += _table(0, POSITIONS)
		3:
			var a: float = POSITIONS[int(value(&"x"))]
			t += "Pin at x = 0, roller at x = 500 mm, load at x. The largest deflection is between the load and the midspan (at midspan when x = 250 mm):\n"
			t += F.equation("x = L/2: v_max = F·L³/(48EI)", "")
			t += F.equation("x ≠ L/2: v_max = F·b·(L² − b²)^(3/2)/(9√3·L·EI)", "b = distance from the load to the far support (the shorter one)")
			t += F.equation("now", "", Units.mm(_max_deflection(1, a, LOADS[int(value(&"load"))]), 4))
			t += _table(1, POSITIONS)
		4:
			var sp: float = value(&"s")
			var c: float = LENGTH - sp
			t += "Pin at x = 0, roller at x = s, the load at the free end x = 500 mm, which hangs over the roller by c = L − s = %s (lab 7's set-up; set s to your bench).\n" % Units.mm(c, 0)
			t += F.equation("R_B = F·L/s,  R_A = F − R_B", "A is pulled down")
			t += F.equation("v_tip = F·c²·(s + c)/(3EI)", "")
			t += F.equation("now", "", Units.mm(_max_deflection(2, LENGTH, LOADS[int(value(&"load"))]), 3))
			t += "The span between the supports bows [b]upward[/b] (hogging moment), while the overhang drops.\n"
			var empty: Array[float] = [LENGTH]
			t += _table(2, empty)
		5:
			t += "Load against maximum deflection, five lines in one plot (handout). Each line is straight through the origin (linear elastic), and its slope 1/k is the flexibility of that configuration:\n"
			var rows: Array[PackedStringArray] = []
			var lines: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0)]
			for ln: Vector2i in lines:
				var x: float = LENGTH if ln.x == 2 else POSITIONS[ln.y]
				rows.append(PackedStringArray([CONFIGS[ln.x], Units.mm(x, 0), Units.fixed(_max_deflection(ln.x, x, 1.0) * 1e3, 4)]))
			t += F.table(["Configuration", "x", "Deflection per N (mm/N)"], rows)
			var ranked: Array[Vector2i] = lines.duplicate()
			ranked.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return _flex(p) < _flex(q))
			t += "Most resistant (least deflection per newton): %s. Least resistant: %s.\n" % [F.value(_line_name(ranked[0])), F.value(_line_name(ranked[-1]))]
			t += "• Holding both ends ([b]simply supported[/b]) gives a short load path and small moments (M_max = Fab/L).\n"
			t += "• A [b]cantilever[/b] carries everything through one support, with a moment F·a at the wall: it is the most flexible when the load is far from the wall.\n"
			t += "• The [b]over-hang[/b] is stiff only while its overhang c is short (v_tip ∝ c²(s + c)); move the second support toward x = 250 mm and it becomes very flexible.\n"
			t += "• Moving the load away from a cantilever's wall, or toward the middle of a simply supported span, increases the deflection.\n"
		6:
			t += F.question("Plot load vs maximum deflection, 5 lines.", "Step 6 figure: label each line (configuration and x). They should be straight lines through the origin.")
			t += F.question("Most and least resistant configuration?", "Compare the slopes (deflection per newton, step 6), which ranks them for you. Explain with the support conditions: more supports and shorter lever arms mean smaller bending moments, and the deflection is the double integral of M/EI.")
			t += F.question("Impact of changing x?", "Cantilever: v_tip = F·a²(3L − a)/(6EI) grows quickly with a (doubling a from 125 to 250 mm multiplies it by about 3.6). Simply supported: the deflection grows as the load moves toward the middle (largest at L/2).")
	return t


## Deflection per newton of line (config, position index).
func _flex(ln: Vector2i) -> float:
	return _max_deflection(ln.x, LENGTH if ln.x == 2 else POSITIONS[ln.y], 1.0)


func _line_name(ln: Vector2i) -> String:
	return "%s, x = %s" % [CONFIGS[ln.x], Units.mm(LENGTH if ln.x == 2 else POSITIONS[ln.y], 0)]


func fill_figures(figures: FigureArea) -> void:
	if step() < 2 or step() == 6:
		return
	var p := figures.plot(0)
	p.begin("Load vs maximum deflection", "load (N)", "max deflection (mm)")
	var colors: Array[Color] = [Color(1.0, 0.6, 0.35), Color(1.0, 0.85, 0.45), Color(0.5, 0.85, 1.0), Color(0.55, 0.95, 0.6), Color(0.85, 0.6, 1.0)]
	var lines: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0)]
	for k: int in lines.size():
		var ln: Vector2i = lines[k]
		if step() != 5 and ln.x != _config():
			continue
		var x: float = LENGTH if ln.x == 2 else POSITIONS[ln.y]
		var pts := PackedVector2Array([Vector2.ZERO])
		for f: float in LOADS:
			pts.append(Vector2(f, _max_deflection(ln.x, x, f) * Units.MM))
		p.line(pts, colors[k], 2.5)
		p.marker(pts[-1], colors[k], "%s %s" % [["cantilever", "simple", "overhang"][ln.x], Units.mm(x, 0)])


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([BENCH + Vector3(-0.2, -0.3, 0.2), BENCH + Vector3(LENGTH * DRAW + 0.2, 0.6, 0.0)])
