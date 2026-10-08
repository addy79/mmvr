extends LabStation
## Lab 9 - Shearing and bending moment diagrams on the shear force / bending moment device:
## a load W at X1, X2 or X3 is balanced at the cut by the shear hanger (W1) and the bending
## moment hanger (W2, arm a). Drawn 2.5x real size.

const BENCH := Vector3(-0.55, 1.0, 0.0)
const DRAW: float = 2.5
const POSITIONS: Array[float] = [0.15, 0.10, 0.05]
const TABLE: int = 3
const DIAGRAMS: int = 4
const COMPARE: int = 5

var rig: ShearMomentRig = ShearMomentRig.new()
var _bench: LabBeamBench = LabBeamBench.new(DRAW)
var _cut: MeshInstance3D = MeshInstance3D.new()
var _w1: Arrow3D = Arrow3D.new(Color(0.5, 0.85, 1.0), 0.008)
var _w2: Arrow3D = Arrow3D.new(Color(0.55, 0.95, 0.55), 0.008)
var _arm: MeshInstance3D = MeshInstance3D.new()


func _init() -> void:
	lab = 9
	title = "Shearing force and bending moment"
	handout = "Lab Handout N°9 - Shearing and Bending Moment Diagrams.docx"
	_controls = [
		ControlSpec.choice(&"pos", "Load hanger at", PackedStringArray(["X1 = 0.15 m", "X2 = 0.10 m", "X3 = 0.05 m"]), 1),
		ControlSpec.choice(&"which", "Applied load", PackedStringArray(["Load 1", "Load 2"]), 0),
		ControlSpec.slider(&"m1", "Load 1", "g", 1000.0, 50.0, 1000.0, 10.0, 0.2, 0),
		ControlSpec.slider(&"m2", "Load 2", "g", 1000.0, 50.0, 1000.0, 10.0, 0.4, 0),
		ControlSpec.slider(&"L", "Span between supports L", "m", 1.0, 0.3, 0.8, 0.01, 0.44).only_in([1, 2]),
		ControlSpec.slider(&"c", "Cut position from the left support", "m", 1.0, 0.16, 0.7, 0.01, 0.30).only_in([1, 2]),
		ControlSpec.slider(&"a", "Bending-moment hanger arm a", "m", 1.0, 0.05, 0.2, 0.001, 0.105, 3).only_in([1]),
		ControlSpec.choice(&"readings", "Simulated readings", READINGS, 1).only_in([TABLE, DIAGRAMS, COMPARE]),
	]
	_bench.position = BENCH
	add_child(_bench)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.9, 0.3, 0.25)
	var cut := BoxMesh.new()
	cut.size = Vector3(0.01, 0.12, 0.08)
	_cut.mesh = cut
	_cut.material_override = red
	add_child(_cut)
	var arm := BoxMesh.new()
	_arm.mesh = arm
	_arm.material_override = red
	add_child(_arm)
	add_child(_w1)
	add_child(_w2)


func _mass(which: int) -> float:
	return value(&"m1") if which == 0 else value(&"m2")


func _rig(which: int, pos: int) -> ShearMomentRig:
	var r := ShearMomentRig.new()
	r.span = value(&"L")
	r.cut = maxf(value(&"c"), 0.16)
	r.moment_arm = value(&"a")
	r.load_mass = _mass(which)
	r.load_position = POSITIONS[pos]
	return r


## Masses the student ends up putting in the two hangers [kg] (to the nearest 5 g with scatter).
func _hanger_masses(which: int, pos: int) -> Vector2:
	var r: ShearMomentRig = _rig(which, pos)
	return Vector2(reading(r.shear_hanger_mass(), which * 10 + pos, 0.06, 0.005),
			reading(r.moment_hanger_mass(), 100 + which * 10 + pos, 0.06, 0.005))


func _apply() -> void:
	rig = _rig(int(value(&"which")), int(value(&"pos")))
	var beam: SimplySupportedBeam = rig.beam()
	var supports: Array[Dictionary] = [{"x": 0.0, "kind": "pin"}, {"x": rig.span, "kind": "roller"}]
	var loads: Array[Dictionary] = [{"x": rig.load_position, "text": "W = %s g" % Units.fixed(rig.load_mass * 1000.0, 0)}]
	_bench.show_beam(beam, supports, loads, 0.0, 3.0)
	var top: Vector3 = _bench.world_top(rig.cut)
	_cut.position = BENCH + Vector3(rig.cut * DRAW, top.y / 2.0, 0.0)
	var masses: Vector2 = _hanger_masses(int(value(&"which")), int(value(&"pos")))
	_w1.place(BENCH + Vector3(rig.cut * DRAW - 0.02, -0.02, 0.0), Vector3(0.0, -0.2, 0.0))
	_w1.label.text = "shear hanger W1 = %s g" % Units.fixed(masses.x * 1000.0, 0)
	_w1.label.position = BENCH + Vector3(rig.cut * DRAW - 0.3, -0.3, 0.0)
	var arm_end: float = (rig.cut + rig.moment_arm) * DRAW
	(_arm.mesh as BoxMesh).size = Vector3(rig.moment_arm * DRAW, 0.012, 0.012)
	_arm.position = BENCH + Vector3((rig.cut * DRAW + arm_end) / 2.0, -0.05, 0.05)
	_w2.place(BENCH + Vector3(arm_end, -0.05, 0.05), Vector3(0.0, -0.2, 0.0))
	_w2.label.text = "moment hanger W2 = %s g (arm a)" % Units.fixed(masses.y * 1000.0, 0)
	_w2.label.position = BENCH + Vector3(arm_end + 0.1, -0.4, 0.05)


func _show_step() -> void:
	_apply()


func step_titles() -> PackedStringArray:
	return ["Objective and theory", "The device", "Load at X2: by hand", "Data collection", "Diagrams", "Experiment vs theory", "Report questions"]


func lesson_text() -> String:
	var F := LessonFormat
	var t: String = ""
	match step():
		0:
			t += "Goal: measure the shear force and bending moment inside a loaded beam at one section, compare with theory, and draw the shear and bending moment diagrams.\n"
			t += "Cut the beam at a section. To keep each part in equilibrium the section must transmit:\n"
			t += "• the [b]shear force[/b] Q: the algebraic sum of the transverse forces on one side of the section;\n"
			t += "• the [b]bending moment[/b] M: the algebraic sum of the moments, about the section, of the forces on one side.\n"
			t += "This device really cuts the beam: the two parts are joined by a mechanism with two hangers. The masses needed to bring the beam back to its equilibrium mark are exactly what the missing material would have carried:\n"
			t += F.equation("Q = W1·g", "W1 = mass in the shear-force hanger")
			t += F.equation("M = W2·g·a", "W2 = mass in the bending-moment hanger, a = %s" % Units.length(rig.moment_arm))
			t += handout_note()
		1:
			t += "Procedure: (1) with no load, adjust the springs until the mark on the screen lines up with the mark on the beam; (2) hang the load at X1 and add masses to hangers 3 (shear) and 4 (moment) until the marks line up again; (3) repeat at X2 and X3; (4) repeat everything with a second, larger load.\n"
			t += F.note("The device's geometry is not in the handout text, so this bench assumes a simply supported beam of span L = %s cut at %s from the left support, with X measured from the left support. Set L, the cut and a to your machine (they are printed on it or in the equipment description)." % [Units.length(rig.span), Units.length(rig.cut)])
			t += F.try_this("move the load hanger between X1, X2, X3 and watch the two balancing masses change.")
		2:
			var r: ShearMomentRig = _rig(int(value(&"which")), 1)
			var w: float = r.load_mass * ShearMomentRig.GRAVITY
			var rb: float = r.beam().reaction_b()
			t += "Free-body diagram with the load W at X2 = 0.10 m. First the reactions (moments about the left support A):\n"
			t += F.equation("W = m·g", "%s kg × 9.81" % Units.fixed(r.load_mass, 3), Units.newtons(w, 3))
			t += F.equation("R_B = W·X2/L", "%s × 0.10 / %s" % [Units.newtons(w, 3), Units.fixed(r.span, 2)], Units.newtons(rb, 3))
			t += F.equation("R_A = W − R_B", "", Units.newtons(r.beam().reaction_a(), 3))
			t += "Then cut at the section and look at the part to the [b]right[/b] of it, which carries only R_B (simpler than the left part, which carries R_A and W):\n"
			t += F.equation("Q = R_B", "", Units.newtons(r.theoretical_shear(), 3))
			t += F.equation("M = R_B·(L − c)", "%s × %s" % [Units.newtons(rb, 3), Units.length(r.span - r.cut)], "%s N·m" % Units.fixed(r.theoretical_moment(), 4))
			t += "Using the left part instead gives the same values (R_A − W = −R_B, and R_A·c − W·(c − X2) = R_B·(L − c)): that is a good check of your work.\n"
		TABLE:
			var rows: Array[PackedStringArray] = []
			for which: int in 2:
				for pos: int in 3:
					var m: Vector2 = _hanger_masses(which, pos)
					var r: ShearMomentRig = _rig(which, pos)
					rows.append(PackedStringArray([Units.fixed(POSITIONS[pos], 2), Units.fixed(_mass(which) * 1000.0, 0), Units.fixed(m.x * 1000.0, 0),
							Units.fixed(ShearMomentRig.shear_from_mass(m.x), 3), Units.fixed(m.y * 1000.0, 0), Units.fixed(r.moment_from_mass(m.y), 4)]))
			t += "Table 1 (Q in N, M in N·m):\n"
			t += F.table(["Point (m)", "Load (g)", "W1 (g)", "Q = W1·g", "W2 (g)", "M = W2·g·a"], rows)
			t += F.note("Convert grams to kilograms before multiplying by g = 9.81 m/s².")
		DIAGRAMS:
			t += "Shear force and bending moment diagrams for the selected load (%s g), one line per load position. The dots are the measured values at the cut.\n" % Units.fixed(_mass(int(value(&"which"))) * 1000.0, 0)
			t += "Between point loads Q is constant and M is linear (dM/dx = Q, chapter 5); Q jumps by W under the load and M has a peak there. At the supports M = 0.\n"
		COMPARE:
			var rows: Array[PackedStringArray] = []
			for which: int in 2:
				for pos: int in [2, 1, 0]:
					var m: Vector2 = _hanger_masses(which, pos)
					var r: ShearMomentRig = _rig(which, pos)
					var q_exp: float = ShearMomentRig.shear_from_mass(m.x)
					var m_exp: float = r.moment_from_mass(m.y)
					rows.append(PackedStringArray(["%s (%s g)" % [Units.fixed(POSITIONS[pos], 2), Units.fixed(_mass(which) * 1000.0, 0)], Units.fixed(q_exp, 3), Units.fixed(r.theoretical_shear(), 3),
							Units.fixed(percent_error(q_exp, r.theoretical_shear()), 1), Units.fixed(m_exp, 4), Units.fixed(r.theoretical_moment(), 4), Units.fixed(percent_error(m_exp, r.theoretical_moment()), 1)]))
			t += "Table 2:\n"
			t += F.table(["Point (m)", "Q exp (N)", "Q theory", "% err", "M exp (N·m)", "M theory", "% err"], rows)
			t += "Typical error sources: friction in the mechanism (the beam balances over a range of masses), the smallest available mass step, the eye judging the marks, and the beam's own weight if the springs were not re-zeroed.\n"
		6:
			t += F.question("Free-body diagram with the load at X2: how to compute Q and M?", "Step 3: reactions from equilibrium, then cut at the section and sum forces and moments on one side.")
			t += F.question("Draw the SFD and BMD for the two loads.", "Step 5 figure, one for each load: Q piecewise constant with a jump W at the load, M piecewise linear with its peak under the load.")
			t += F.question("Compare experimental and theoretical values.", "Table 2 (step 6) with % error = |exp − theory|/theory × 100; comment on the error sources.")
			t += F.question("What affects the shear force? When is it maximum here?", "The size of the load and its position relative to the supports and the cut: for a load left of the cut, Q = W·X/L, so Q at the cut grows as the load moves toward the cut (largest at X1 among the three positions) and grows with W.")
			t += F.question("Where to put the load for the largest bending moment?", "M at the cut = W·X·(L − c)/L for a load left of the cut: it grows with X, and is largest with the load right at the cut, M = W·c·(L − c)/L. For the beam as a whole, the largest moment ever is W·L/4 with the load at midspan.")
	return t


func fill_figures(figures: FigureArea) -> void:
	if step() != DIAGRAMS and step() != COMPARE:
		return
	var which: int = int(value(&"which"))
	var colors: Array[Color] = [Color(1.0, 0.65, 0.35), Color(1.0, 0.85, 0.45), Color(0.55, 0.95, 0.6)]
	var q_plot := figures.plot(0)
	var m_plot := figures.plot(1)
	q_plot.begin("Shear force diagram (%s g)" % Units.fixed(_mass(which) * 1000.0, 0), "x (m)", "Q (N)")
	m_plot.begin("Bending moment diagram (%s g)" % Units.fixed(_mass(which) * 1000.0, 0), "x (m)", "M (N·m)")
	for pos: int in 3:
		var r: ShearMomentRig = _rig(which, pos)
		var b: SimplySupportedBeam = r.beam()
		var qs := PackedVector2Array()
		var ms := PackedVector2Array()
		for i: int in 201:
			var x: float = r.span * i / 200.0
			qs.append(Vector2(x, b.shear_at(x)))
			ms.append(Vector2(x, b.moment_at(x)))
		q_plot.line(qs, colors[pos], 2.0)
		m_plot.line(ms, colors[pos], 2.0)
		var m: Vector2 = _hanger_masses(which, pos)
		q_plot.marker(Vector2(r.cut, -ShearMomentRig.shear_from_mass(m.x)), colors[pos], "X%d" % (pos + 1))
		m_plot.marker(Vector2(r.cut, r.moment_from_mass(m.y)), colors[pos], "X%d" % (pos + 1))
	q_plot.vline(_rig(which, 0).cut, Color(0.9, 0.4, 0.35), "cut")
	m_plot.vline(_rig(which, 0).cut, Color(0.9, 0.4, 0.35), "cut")


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([BENCH + Vector3(-0.2, -0.45, 0.2), BENCH + Vector3(value(&"L") * DRAW + 0.3, 0.45, 0.0)])
