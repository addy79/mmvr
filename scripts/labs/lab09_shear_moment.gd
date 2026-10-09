extends LabStation
## Lab 9 - Shearing force and bending moment diagrams, on the Edibon MMF unit (handout
## figure 4): the free arm on the left of section x-x carries the load W at X1, X2 or X3
## (measured from the cut); at the cut, the shear hanger W1 and the bending moment hanger W2
## (lever arm a) restore equilibrium. Drawn 3x real size, arm to the left of the cut as in
## the handout.

const CUT := Vector3(0.35, 1.0, 0.0)  ## where section x-x is drawn
const DRAW: float = 3.0
const POSITIONS: Array[float] = [0.15, 0.10, 0.05]
const FBD: int = 2
const TABLE: int = 3
const DIAGRAMS: int = 4
const COMPARE: int = 5

var rig: ShearMomentRig = ShearMomentRig.new()
var _bench: LabBeamBench = LabBeamBench.new(DRAW)
var _post: MeshInstance3D = MeshInstance3D.new()
var _string: MeshInstance3D = MeshInstance3D.new()
var _pulleys: Array[MeshInstance3D] = [MeshInstance3D.new(), MeshInstance3D.new()]
var _w1: Arrow3D = Arrow3D.new(Color(0.5, 0.85, 1.0), 0.008)
var _w2: Arrow3D = Arrow3D.new(Color(0.55, 0.95, 0.55), 0.008)
var _a_label: Label3D = Text3D.make(26)


func _init() -> void:
	lab = 9
	title = "Shearing force and bending moment"
	handout = "Lab Handout N°9 - Shearing and Bending Moment Diagrams.docx"
	_controls = [
		ControlSpec.choice(&"pos", "Load hanger at", PackedStringArray(["X1 = 0.15 m", "X2 = 0.10 m", "X3 = 0.05 m"]), 1),
		ControlSpec.choice(&"which", "Applied load", PackedStringArray(["Load 1", "Load 2"]), 0),
		ControlSpec.slider(&"m1", "Load 1", "g", 1000.0, 50.0, 1000.0, 10.0, 0.2, 0),
		ControlSpec.slider(&"m2", "Load 2", "g", 1000.0, 50.0, 1000.0, 10.0, 0.4, 0),
		ControlSpec.slider(&"a", "Bending-moment lever arm a", "m", 1.0, 0.05, 0.2, 0.001, 0.105, 3).only_in([1]),
		ControlSpec.choice(&"readings", "Simulated readings", READINGS, 1).only_in([TABLE, DIAGRAMS, COMPARE]),
	]
	_bench.position = CUT
	_bench.rotation.y = PI  # the arm runs to the left of the cut, as in the handout's figure
	add_child(_bench)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.3, 0.25)
	_post.mesh = BoxMesh.new()
	_post.material_override = red
	add_child(_post)
	_string.mesh = BoxMesh.new()
	_string.material_override = red
	add_child(_string)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.1, 0.1, 0.12)
	for p: MeshInstance3D in _pulleys:
		var disc := CylinderMesh.new()
		disc.top_radius = 0.05
		disc.bottom_radius = 0.05
		disc.height = 0.02
		p.mesh = disc
		p.material_override = black
		p.rotation.x = PI / 2.0
		add_child(p)
	add_child(_w1)
	add_child(_w2)
	add_child(_a_label)


func _mass(which: int) -> float:
	return value(&"m1") if which == 0 else value(&"m2")


func _rig(which: int, pos: int) -> ShearMomentRig:
	var r := ShearMomentRig.new()
	r.moment_arm = value(&"a")
	r.load_mass = _mass(which)
	r.load_position = POSITIONS[pos]
	return r


## Masses the student ends up putting in the two hangers [kg] (to the nearest 5 g, with scatter).
func _hanger_masses(which: int, pos: int) -> Vector2:
	var r: ShearMomentRig = _rig(which, pos)
	return Vector2(reading(r.shear_hanger_mass(), which * 10 + pos, 0.04, 0.005),
			reading(r.moment_hanger_mass(), 100 + which * 10 + pos, 0.04, 0.005))


func _apply() -> void:
	rig = _rig(int(value(&"which")), int(value(&"pos")))
	var arm: CantileverBeam = rig.arm()
	var supports: Array[Dictionary] = [{"x": 0.0, "kind": "fixed"}]
	var loads: Array[Dictionary] = [{"x": rig.load_position, "text": "W = %s g" % Units.fixed(rig.load_mass * 1000.0, 0)}]
	_bench.show_beam(arm, supports, loads, 0.0, 2.0)
	var masses: Vector2 = _hanger_masses(int(value(&"which")), int(value(&"pos")))
	var top: float = CUT.y + 2.0 * arm.section.y_max() * 2.0 * DRAW
	var a: float = rig.moment_arm * DRAW
	(_post.mesh as BoxMesh).size = Vector3(0.025, a, 0.025)
	_post.position = Vector3(CUT.x + 0.03, top + a / 2.0, 0.0)
	_pulleys[0].position = Vector3(CUT.x + 0.2, top + 0.05, 0.0)
	_pulleys[1].position = Vector3(CUT.x + 0.5, top + a, 0.0)
	(_string.mesh as BoxMesh).size = Vector3(0.47, 0.006, 0.006)
	_string.position = Vector3(CUT.x + 0.03 + 0.235, top + a, 0.0)
	_w1.place(_pulleys[0].position + Vector3(0.05, 0.0, 0.0), Vector3(0.0, -0.45, 0.0))
	_w1.label.text = "3 · shear hanger W1 = %s g" % Units.fixed(masses.x * 1000.0, 0)
	_w1.label.position = _pulleys[0].position + Vector3(0.05, -0.55, 0.0)
	_w2.place(_pulleys[1].position + Vector3(0.05, 0.0, 0.0), Vector3(0.0, -0.75, 0.0))
	_w2.label.text = "4 · moment hanger W2 = %s g" % Units.fixed(masses.y * 1000.0, 0)
	_w2.label.position = _pulleys[1].position + Vector3(0.0, 0.12, 0.0)
	_a_label.text = "a = %s" % Units.mm(rig.moment_arm, 0)
	_a_label.position = _post.position + Vector3(-0.12, 0.0, 0.0)


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
			t += "This device really cuts the beam at section x-x. Everything to the left of the cut is a free arm carrying only the load W, so the two sums are simply:\n"
			t += F.equation("Q_x = −W", "")
			t += F.equation("M_x = −W·x", "x = distance from the load to the cut")
			t += "A mechanism at the cut lets two hangers supply them: the [b]shear hanger[/b] (3) with W1 and the [b]bending-moment hanger[/b] (4) with W2 on a lever arm a. When the beam is back on its equilibrium mark:\n"
			t += F.equation("Q_x = −W = W1", "")
			t += F.equation("M_x = −W·x = W2·a", "")
			t += handout_note()
		1:
			t += "Procedure: (1) with no load, adjust the tension springs until the mark on the transparent screen lines up with the straight mark on the beam; (2) hang the load (hanger 2) at X1 and add masses to hangers 3 and 4 until the marks line up again; (3) repeat at X2 and X3; (4) repeat everything with a higher load.\n"
			t += F.equation("X1, X2, X3", "", "0.15 m, 0.10 m, 0.05 m from the cut")
			t += F.equation("bending-moment lever arm a", "", Units.mm(rig.moment_arm, 0))
			t += "Expect W1 to stay the same at the three positions (equal to the load), while W2 grows in proportion to x.\n"
			t += F.try_this("move the load hanger between X1, X2, X3 and watch the two balancing masses: only W2 changes.")
		FBD:
			var r: ShearMomentRig = _rig(int(value(&"which")), 1)
			t += "Free-body diagram with the load W at X2 = 0.10 m: cut at x-x and keep the free arm (left part). Its only external force is W; the cut face carries Q and M from the right part.\n"
			t += F.equation("W = m·g", "%s kg × 9.81" % Units.fixed(r.load_mass, 3), Units.newtons(r.load_weight(), 3))
			t += F.equation("ΣF = 0:  Q = W", "", Units.newtons(r.theoretical_shear(), 3))
			t += F.equation("ΣM about the cut = 0:  M = W·X2", "%s × 0.10 m" % Units.newtons(r.load_weight(), 3), "%s N·m" % Units.fixed(r.theoretical_moment(), 4))
			t += F.equation("so W1 = m", "", "%s g" % Units.fixed(r.shear_hanger_mass() * 1000.0, 0))
			t += F.equation("and W2 = M/(g·a) = m·X2/a", "", "%s g" % Units.fixed(r.moment_hanger_mass() * 1000.0, 0))
			t += "The minus signs in the handout (Q_x = −W, M_x = −W·x) come from its sign convention: the arm is pushed down on the left of the cut and bends hogging (concave down).\n"
		TABLE:
			var rows: Array[PackedStringArray] = []
			for which: int in 2:
				for pos: int in 3:
					var m: Vector2 = _hanger_masses(which, pos)
					var r: ShearMomentRig = _rig(which, pos)
					rows.append(PackedStringArray([Units.fixed(POSITIONS[pos], 2), Units.fixed(_mass(which) * 1000.0, 0), Units.fixed(m.x * 1000.0, 0),
							Units.fixed(ShearMomentRig.shear_from_mass(m.x), 3), Units.fixed(m.y * 1000.0, 0), Units.fixed(r.moment_from_mass(m.y), 4)]))
			t += "Table 1 (Q in N, M in N·m; a = %s):\n" % Units.mm(value(&"a"), 0)
			t += F.table(["Point (m)", "Load (g)", "W1 (g)", "Q = W1·g", "W2 (g)", "M = W2·g·a"], rows)
			t += F.note("Convert grams to kilograms before multiplying by g = 9.81 m/s².")
		DIAGRAMS:
			t += "Shear force and bending moment along the free arm for the selected load (%s g), one line per load position, s measured from the cut. The dots are the values measured at the cut.\n" % Units.fixed(_mass(int(value(&"which"))) * 1000.0, 0)
			t += "Between the cut and the load Q is constant (= W) and M is linear, falling from W·x at the cut to zero under the load (dM/ds = −Q: the slope of the moment diagram is the shear). Beyond the load the arm carries nothing.\n"
			t += "The largest bending moment is always at the cut (the arm's 'built-in' end), and it is largest when the load is farthest away.\n"
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
			t += "Table 2 (theory: Q = W, M = W·x):\n"
			t += F.table(["Point (m)", "Q exp (N)", "Q theory", "% err", "M exp (N·m)", "M theory", "% err"], rows)
			t += "Typical error sources: friction in the mechanism (the beam balances over a range of masses), the smallest available mass step, judging the marks by eye, the hanger's own mass, and springs not re-zeroed.\n"
		6:
			t += F.question("Free-body diagram with the load at X2: how to compute Q and M?", "Step 3: cut at x-x, keep the free arm. ΣF = 0 gives Q = W; ΣM about the cut gives M = W·X2 (−W and −W·X2 with the handout's signs).")
			t += F.question("Draw the SFD and BMD for the two loads.", "Step 5: Q constant = W from the cut to the load, then zero; M linear from W·x at the cut to zero at the load. Two plots per load.")
			t += F.question("Compare experimental and theoretical values.", "Table 2 (step 6) with % error = |exp − theory|/theory × 100; comment on the error sources.")
			t += F.question("What affects the shear force? When is it maximum here?", "Only the load W: Q = W does not depend on where the load hangs on the arm (W1 is the same at X1, X2, X3). It is largest with the heavier load.")
			t += F.question("Where to put the load to get the largest bending moment?", "M = W·x grows with the distance from the cut: at the farthest position, X1 = 0.15 m (and with the heavier load).")
	return t


func fill_figures(figures: FigureArea) -> void:
	if step() != DIAGRAMS and step() != COMPARE:
		return
	var which: int = int(value(&"which"))
	var colors: Array[Color] = [Color(1.0, 0.65, 0.35), Color(1.0, 0.85, 0.45), Color(0.55, 0.95, 0.6)]
	var q_plot := figures.plot(0)
	var m_plot := figures.plot(1)
	q_plot.begin("Shear force on the arm (%s g)" % Units.fixed(_mass(which) * 1000.0, 0), "s from the cut (m)", "Q (N)")
	m_plot.begin("Bending moment on the arm (%s g)" % Units.fixed(_mass(which) * 1000.0, 0), "s from the cut (m)", "|M| (N·m)")
	for pos: int in 3:
		var r: ShearMomentRig = _rig(which, pos)
		var arm: CantileverBeam = r.arm()
		var qs := PackedVector2Array()
		var ms := PackedVector2Array()
		for i: int in 181:
			var s: float = ShearMomentRig.ARM_LENGTH * i / 180.0
			qs.append(Vector2(s, arm.shear_at(s)))
			ms.append(Vector2(s, absf(arm.moment_at(s))))
		q_plot.line(qs, colors[pos], 2.0)
		m_plot.line(ms, colors[pos], 2.0)
		var m: Vector2 = _hanger_masses(which, pos)
		q_plot.marker(Vector2(0.0, ShearMomentRig.shear_from_mass(m.x)), colors[pos], "")
		m_plot.marker(Vector2(0.0, r.moment_from_mass(m.y)), colors[pos], "X%d" % (pos + 1))


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([CUT + Vector3(-ShearMomentRig.ARM_LENGTH * DRAW - 0.2, -0.3, 0.2), CUT + Vector3(1.0, 0.7, 0.0), CUT + Vector3(1.0, -1.0, 0.0)])
