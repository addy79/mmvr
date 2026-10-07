extends Station
## Chapter 5 - Analysis and design of beams for bending: a simply supported beam with a
## movable point load and a uniform load. Steps walk from the free-body diagram through
## internal forces, bending and shear stress, the stress at a point, deflection and design.

const LENGTH: float = 4.0
const ORIGIN := Vector3(-2.0, 0.95, 0.0)   ## bottom fiber at support A
const STRESS_ARROWS: int = 9
const SECTION_NAMES: PackedStringArray = ["Rectangle", "Circle", "Tube", "I-beam", "Box"]
const MATERIAL_NAMES: PackedStringArray = ["Steel", "Aluminum", "Wood"]
const TARGET_FS: float = 2.0

var beam: SimplySupportedBeam

var _sections: Array[CrossSection] = SectionPresets.all()
var _materials: Array[LabMaterial] = LabMaterial.presets()
var _rig: BeamRig = BeamRig.new(LENGTH, ORIGIN.y)
var _shear: DiagramView = DiagramView.new(DiagramView.Kind.SHEAR, _rig.data)
var _moment: DiagramView = DiagramView.new(DiagramView.Kind.MOMENT, _rig.data)
var _cut_knob: AxisKnob = AxisKnob.new(0.02, LENGTH - 0.02, Color(0.3, 0.9, 1.0))
var _cut_plane: MeshInstance3D = MeshInstance3D.new()
var _cut_v: Arrow3D = Arrow3D.new(Color(0.3, 0.9, 1.0), 0.016)
var _cut_m: MomentArrow3D = MomentArrow3D.new(Color(0.3, 0.9, 1.0), 0.2)
var _sigma_arrows: Array[Arrow3D] = []
var _tau_arrows: Array[Arrow3D] = []
var _probe_dot: MeshInstance3D = MeshInstance3D.new()
var _element: StressElementView = StressElementView.new()


func _init() -> void:
	chapter = 5
	title = "Beams: reactions, V and M, stresses"
	beam = SimplySupportedBeam.new(LENGTH, 10.0e3, 1.5, _sections[0], _materials[0])
	_controls = [
		ControlSpec.slider(&"P", "Point load P", "kN", Units.KN, 0.0, 50.0, 0.5, 10.0e3),
		ControlSpec.slider(&"a", "Load position a", "m", 1.0, 0.0, LENGTH, 0.01, 1.5),
		ControlSpec.slider(&"w", "Uniform load w", "kN/m", Units.KN, 0.0, 20.0, 0.5, 0.0),
		ControlSpec.slider(&"cut", "Section cut x", "m", 1.0, 0.02, LENGTH - 0.02, 0.01, 1.0).only_in([1, 2, 3, 4]),
		ControlSpec.slider(&"y", "Point height y/c", "", 1.0, -1.0, 1.0, 0.05, 0.5).only_in([4]),
		ControlSpec.choice(&"section", "Cross-section", SECTION_NAMES, 0),
		ControlSpec.choice(&"material", "Material", MATERIAL_NAMES, 0),
		ControlSpec.slider(&"exaggeration", "Deflection drawn ×", "", 1.0, 1.0, 500.0, 1.0, 50.0, 0),
		ControlSpec.choice(&"colors", "Stress colors: full color at", PackedStringArray(["±σ_max", "±σ_Y"]), 0).only_in([2, 6]),
	]
	_rig.position = ORIGIN
	add_child(_rig)
	_rig.load_moved.connect(func(x: float) -> void: set_control(&"a", x))
	_shear.position = Vector3(0.0, 0.85, -0.7)
	_moment.position = Vector3(0.0, 1.55, -0.7)
	_rig.add_child(_shear)
	_rig.add_child(_moment)

	_rig.add_child(_cut_knob)
	_cut_knob.grip.position = Vector3(0.0, -0.32, 0.3)
	_cut_knob.slider_moved.connect(func(x: float) -> void: set_control(&"cut", x))
	var plane := QuadMesh.new()
	plane.size = Vector2(0.5, 0.6)
	_cut_plane.mesh = plane
	_cut_plane.rotation.y = PI / 2.0
	var plane_material := StandardMaterial3D.new()
	plane_material.albedo_color = Color(0.3, 0.9, 1.0, 0.25)
	plane_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plane_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cut_plane.material_override = plane_material
	_cut_knob.add_child(_cut_plane)
	_cut_knob.add_child(_cut_v)
	_cut_knob.add_child(_cut_m)
	for i: int in STRESS_ARROWS:
		var s := Arrow3D.new(Color(1.0, 0.45, 0.35), 0.008)
		s.label.visible = false
		_sigma_arrows.append(s)
		_cut_knob.add_child(s)
		var t := Arrow3D.new(Color(0.35, 0.85, 1.0), 0.008)
		t.label.visible = false
		_tau_arrows.append(t)
		_cut_knob.add_child(t)
	var dot := SphereMesh.new()
	dot.radius = 0.025
	dot.height = 0.05
	_probe_dot.mesh = dot
	_cut_knob.add_child(_probe_dot)
	_element.position = Vector3(0.0, 1.05, 0.5)
	_element.scale = Vector3.ONE * 1.4
	_cut_knob.add_child(_element)


func _apply() -> void:
	beam.load = value(&"P")
	beam.load_position = value(&"a")
	beam.distributed_load = value(&"w")
	beam.section = _sections[int(value(&"section"))]
	beam.material = _materials[int(value(&"material"))]
	_rig.show_beam(beam, value(&"exaggeration"), value(&"colors") == 1.0)
	_shear.show_beam(beam)
	_moment.show_beam(beam)
	_apply_cut()


## Internal forces and stresses at the section cut, drawn on the left segment's cut face.
func _apply_cut() -> void:
	var x: float = value(&"cut")
	var c: float = beam.section.y_max()
	_cut_knob.set_value(x)
	var v: float = beam.shear_at(x)
	var m: float = beam.moment_at(x)
	var mid: float = _rig.axis_at(x)
	_cut_plane.position.y = mid
	_shear.set_marker(x, v, beam.max_shear())
	_moment.set_marker(x, m, absf(beam.max_moment()))
	# Positive V acts downward and positive M counterclockwise on the left segment's face.
	var v_len: float = 0.35 * absf(v) / maxf(beam.max_shear(), 1.0)
	_cut_v.place(Vector3(0.02, mid + signf(v) * v_len / 2.0, 0.32), Vector3(0.0, -signf(v) * v_len, 0.0))
	_cut_v.label.text = "V = " + Units.signed_force(v)
	_cut_m.position = Vector3(0.02, mid, 0.0)
	_cut_m.set_moment(signf(m))
	_cut_m.label.text = "M = " + Units.moment(m)
	# Stress distributions through the depth at the cut.
	var sigma_ref: float = maxf(beam.max_bending_stress(), 1.0)
	var tau_ref: float = maxf(beam.max_shear_stress(), 1.0)
	# Drawn on the cut face; the shader hides the beam beyond the cut so they stay visible.
	for i: int in STRESS_ARROWS:
		var y: float = c * (2.0 * i / (STRESS_ARROWS - 1) - 1.0)
		var sigma: float = beam.bending_stress(x, y)
		var p := Vector3(0.015, mid + y, 0.0)
		var len_s: float = 0.4 * absf(sigma) / sigma_ref
		if sigma >= 0.0:
			_sigma_arrows[i].place(p, Vector3(len_s, 0.0, 0.0))
		else:
			_sigma_arrows[i].place_onto(p, Vector3(-len_s, 0.0, 0.0))
		var tau: float = beam.shear_stress(x, y)
		# On the left part's face, tau acts in the direction of V: downward for positive V.
		var len_t: float = 0.3 * tau / tau_ref
		_tau_arrows[i].place(Vector3(0.015, mid + y + len_t / 2.0, 0.0), Vector3(0.0, -len_t, 0.0))
	# Stress element at the probe point (x along the beam, y up): tau_xy = -tau for positive V.
	var y_probe: float = value(&"y") * c
	_probe_dot.position = Vector3(0.0, mid + y_probe, 0.05)
	var state: PlaneStress = _probe_state()
	_element.reference = maxf(absf(state.sigma_x), absf(state.tau_xy))
	_element.show_stresses(state.sigma_x, state.sigma_y, state.tau_xy, 0.0)


func _probe_state() -> PlaneStress:
	var x: float = value(&"cut")
	var y: float = value(&"y") * beam.section.y_max()
	return PlaneStress.new(beam.bending_stress(x, y), 0.0, -beam.shear_stress(x, y))


func _show_step() -> void:
	var s: int = step()
	_rig.set_reactions_visible(s == 0)
	_cut_knob.visible = s >= 1 and s <= 4
	_cut_v.visible = s == 1
	_cut_m.visible = s == 1
	for arrow: Arrow3D in _sigma_arrows:
		arrow.visible = arrow.visible and s == 2
	for arrow: Arrow3D in _tau_arrows:
		arrow.visible = arrow.visible and s == 3
	_probe_dot.visible = s == 4
	_element.visible = s == 4
	_rig.view.set_cut(value(&"cut") if s >= 1 and s <= 4 else INF)
	_shear.visible = s != 5
	_moment.visible = s != 5


func refresh() -> void:
	super()
	_show_step()


func set_control(id: StringName, new_value: float) -> void:
	super(id, new_value)
	_show_step()


func set_step(index: int) -> void:
	_apply()
	super(index)


func step_titles() -> PackedStringArray:
	return ["Free body & reactions", "Internal forces V, M", "Bending stress", "Shear stress",
			"Stress at a point", "Deflection", "Design check"]


func lesson_text() -> String:
	var F := LessonFormat
	var L: float = LENGTH
	var a: float = beam.load_position
	var b: float = beam.load_offset_from_b()
	var P: String = Units.force(beam.load)
	var w: String = Units.distributed(beam.distributed_load)
	var x: float = value(&"cut")
	var s: CrossSection = beam.section
	var t: String = ""
	match step():
		0:
			t += "A beam is in [b]equilibrium[/b]: the supports push back exactly enough to balance the loads. "
			t += "Draw the [b]free-body diagram[/b]: replace the pin at A and the roller at B by the forces they exert (green arrows), then write the equilibrium equations.\n\n"
			t += F.equation("ΣM_A = 0:  R_B·L − P·a − w·L·(L/2) = 0")
			t += F.equation("R_B = (P·a + w·L²/2)/L", "(%s × %.2f m + %s × %.0f m²/2)/%.0f m" % [P, a, w, L * L, L], Units.force(beam.reaction_b()))
			t += F.equation("ΣF_y = 0:  R_A = P + w·L − R_B", "%s + %s − %s" % [P, Units.force(beam.distributed_load * L), Units.force(beam.reaction_b())], Units.force(beam.reaction_a()))
			t += "\nThe support nearer the load carries more of it: with a = %.2f m and b = %.2f m, R_A/R_B = b/a for the point load alone.\n" % [a, b]
			t += F.try_this("drag the yellow knob toward A and watch R_A grow while R_B shrinks. Their sum always equals P + wL = %s." % Units.force(beam.load + beam.distributed_load * L))
		1:
			t += "Cut the beam at x (cyan knob) and keep the left part. To stay in equilibrium the cut face must carry an internal [b]shear force V[/b] and [b]bending moment M[/b].\n"
			t += F.note("Sign convention (Beer & Johnston): on the left part's face, positive V acts downward and positive M is counterclockwise; positive M makes the beam sag.")
			t += "With [b]singularity functions[/b] ⟨x − a⟩ⁿ (equal to (x − a)ⁿ for x > a and 0 otherwise) one expression covers the whole beam:\n"
			t += F.equation("V(x) = R_A − w·x − P·⟨x − a⟩⁰", "", Units.signed_force(beam.shear_at(x)))
			t += F.equation("M(x) = R_A·x − w·x²/2 − P·⟨x − a⟩¹", "", Units.moment(beam.moment_at(x)))
			t += "\nThe diagrams behind the beam plot V and M everywhere. Read them with the two key relations:\n"
			t += F.derivation("Equilibrium of a slice dx: ΣF_y gives V − (V + dV) − w·dx = 0, so dV/dx = −w; ΣM gives (M + dM) − M − V·dx + w·dx²/2 = 0, so dM/dx = V.")
			t += F.equation("dV/dx = −w", "slope of the V diagram is the load intensity")
			t += F.equation("dM/dx = V", "M peaks where V crosses zero")
			t += F.equation("M(x) − M(0) = ∫₀ˣ V dx", "area under V from 0 to the cut", Units.moment(beam.shear_area(0.0, x)))
			t += "A point load makes V [b]jump[/b] by P; M then has a corner. Here |M| is largest at x = %s: %s.\n" % [Units.length(beam.max_moment_position()), F.value(Units.moment(beam.max_moment()))]
			t += F.try_this("set w > 0 and slide the cut: V now changes linearly, M becomes a parabola, and the area under V between two cuts equals the change in M.")
		2:
			var sigma_top: float = beam.bending_stress(x, s.y_max())
			var sigma_bot: float = beam.bending_stress(x, -s.y_max())
			t += "Bending makes the fibers on one side of the [b]neutral axis[/b] (through the centroid) shorten and the other side stretch. Stress grows linearly with the distance y from that axis (red arrows on the cut).\n"
			t += F.equation("σ_x = −M·y/I", "flexure formula")
			t += "At the cut: M = %s, I = %s, c = %s\n" % [Units.moment(beam.moment_at(x)), Units.inertia(s.moment_of_inertia()), Units.small_length(s.y_max())]
			t += F.equation("σ_top = −M·c/I", "", Units.stress(sigma_top))
			t += F.equation("σ_bottom = +M·c/I", "", Units.stress(sigma_bot))
			t += F.equation("σ_max = |M|max·c/I = |M|max/S", "%s / %s" % [Units.moment(absf(beam.max_moment())), Units.first_moment(s.section_modulus())], Units.stress(beam.max_bending_stress()))
			t += "\nS = I/c is the [b]section modulus[/b]: for the same area, deep sections (and I-beams) put material far from the axis, so I and S are large.\n"
			t += F.try_this("switch the cross-section and compare σ_max. The I-beam has S = %s; the circle has %s." % [Units.first_moment(_sections[3].section_modulus()), Units.first_moment(_sections[1].section_modulus())])
		3:
			var v: float = beam.shear_at(x)
			t += "The shear force V is not spread evenly: horizontal layers try to slide on each other, and the stress needed to stop them is largest at the neutral axis and zero at the top and bottom (blue arrows).\n"
			t += F.equation("τ = V·Q/(I·t)", "shear formula")
			t += "Q is the first moment, about the neutral axis, of the area above the level considered; t is the section width there.\n"
			t += "At the cut, neutral axis: V = %s, Q = %s, t = %s\n" % [Units.signed_force(v), Units.first_moment(s.first_moment(0.0)), Units.small_length(s.width_at(0.0))]
			t += F.equation("τ_NA = V·Q/(I·t)", "", Units.stress(absf(beam.shear_stress(x, 0.0))))
			t += F.equation("τ_avg = V/A", "", Units.stress(absf(v) / s.area()))
			t += F.note("For a rectangle τ_max = 1.5·V/A; for an I-beam the thin web carries almost all the shear.")
			t += F.try_this("pick the I-beam: τ jumps where the web meets the flange because t changes from b_f to t_w.")
		4:
			var state: PlaneStress = _probe_state()
			var y_mm: float = value(&"y") * s.y_max()
			t += "A tiny element at the white dot (x = %s, y = %s) feels both stresses at once: σ_x from bending and τ_xy from shear. Move it with the 'Point height' slider.\n" % [Units.length(x), Units.small_length(y_mm)]
			t += F.equation("σ_x = −M·y/I", "", Units.stress(state.sigma_x))
			t += F.equation("τ_xy = −V·Q/(I·t)", "", Units.stress(state.tau_xy))
			t += F.note("τ_xy is negative here when V is positive: with y up, positive V pushes the right face of the element downward.")
			t += "Turning the element changes these numbers (chapter 7). The extreme normal stresses act on the [b]principal planes[/b]:\n"
			t += F.equation("σ₁,₂ = σ_x/2 ± √((σ_x/2)² + τ_xy²)", "", "%s, %s" % [Units.stress(state.principal_1()), Units.stress(state.principal_2())])
			t += F.equation("θ_p = ½·atan(2τ_xy/σ_x)", "", Units.angle(state.principal_angle()))
			t += F.try_this("put the point on the neutral axis (y/c = 0): σ_x vanishes and the element is in pure shear, with principal stresses ±τ at 45°.")
		5:
			t += "The beam bends into the [b]elastic curve[/b] v(x). It satisfies EI·v'' = −M (v downward positive), integrated twice with v = 0 at both supports.\n"
			t += F.equation("v(x) = P·b·x·(L² − b² − x²)/(6EIL) + w·x·(L³ − 2Lx² + x³)/(24EI)", "for x ≤ a")
			t += "EI = %s × %s = %s\n" % [Units.modulus(beam.material.youngs_modulus), Units.inertia(s.moment_of_inertia()), "%.0f kN·m²" % (beam.flexural_rigidity() / 1e3)]
			t += F.equation("v_max", "at x = %s" % Units.length(beam.max_deflection_position()), Units.small_length(beam.max_deflection()))
			if is_equal_approx(a, L / 2.0) and beam.distributed_load == 0.0:
				t += F.note("Load at midspan: this is P·L³/(48EI).")
			var limit: float = L / 360.0
			t += "Serviceability: a common limit is L/360 = %s → %s\n" % [Units.small_length(limit), F.ok_or_fail(beam.max_deflection() <= limit, "OK" if beam.max_deflection() <= limit else "too flexible")]
			t += F.try_this("switch steel → aluminum: E drops to about one third, so v_max triples while the stresses do not change at all.")
		6:
			var fs: float = beam.factor_of_safety()
			var allowable: float = beam.material.yield_strength / TARGET_FS
			var s_min: float = beam.required_section_modulus(allowable)
			var s_have: float = s.section_modulus()
			t += "Design asks: is the beam strong enough, with a margin? Compare the largest stress with the material strength.\n"
			t += F.equation("FS = σ_Y/σ_max", "%s / %s" % [Units.stress(beam.material.yield_strength), Units.stress(beam.max_bending_stress())], Units.factor(fs))
			t += "With a target FS = %.1f the allowable stress is σ_all = σ_Y/FS = %s, so the section needs\n" % [TARGET_FS, Units.stress(allowable)]
			t += F.equation("S_min = |M|max/σ_all", "%s / %s" % [Units.moment(absf(beam.max_moment())), Units.stress(allowable)], Units.first_moment(s_min))
			t += "Chosen section: %s, S = %s → %s\n" % [SectionText.describe(s), Units.first_moment(s_have), F.ok_or_fail(s_have >= s_min, "adequate" if s_have >= s_min else "too small")]
			t += F.equation("Shear check: τ_max = V·Q/(I·t)", "", Units.stress(beam.max_shear_stress()))
			t += "\n[b]Selecting a section[/b]: among the sections that are adequate (S ≥ S_min), choose the lightest — the smallest area:\n"
			t += "[table=4][cell][b]Section[/b]  [/cell][cell][b]S (10³ mm³)[/b]  [/cell][cell][b]A (mm²)[/b]  [/cell][cell][b]Adequate?[/b][/cell]"
			var lightest: int = -1
			for i: int in _sections.size():
				var sec: CrossSection = _sections[i]
				var ok: bool = sec.section_modulus() >= s_min
				if ok and (lightest < 0 or sec.area() < _sections[lightest].area()):
					lightest = i
				t += "[cell]%s  [/cell][cell]%.1f  [/cell][cell]%.0f  [/cell][cell]%s[/cell]" % [SECTION_NAMES[i], sec.section_modulus() * 1e6, sec.area() * 1e6, F.ok_or_fail(ok, "yes" if ok else "no")]
			t += "[/table]\n"
			t += "Lightest adequate section: %s\n" % F.value(SECTION_NAMES[lightest] if lightest >= 0 else "none — reduce the load")
			t += F.try_this("raise P and w until FS drops below 1 (colors set to ±σ_Y turn fully red/blue). Which section survives the most load for its area?")
	return t


func fill_figures(figures: FigureArea) -> void:
	var x_cut: float = value(&"cut")
	match step():
		1:
			var pv := figures.plot(0)
			pv.begin("Shear force V(x)", "x (m)", "V (kN)")
			pv.line(_sample(func(x: float) -> float: return beam.shear_at(x) * Units.KN), Color(0.3, 0.8, 0.45), 2.5, true)
			pv.vline(x_cut, Color(0.3, 0.9, 1.0), "cut")
			var pm := figures.plot(1)
			pm.begin("Bending moment M(x)", "x (m)", "M (kN·m)")
			pm.line(_sample(func(x: float) -> float: return beam.moment_at(x) * Units.KN), Color(0.65, 0.45, 0.95), 2.5, true)
			pm.vline(x_cut, Color(0.3, 0.9, 1.0), "cut")
			pm.marker(Vector2(beam.max_moment_position(), beam.max_moment() * Units.KN), Color(1, 0.85, 0.4), "M_max")
		2, 3:
			var p := figures.plot(0)
			var c: float = beam.section.y_max()
			var pts := PackedVector2Array()
			for i: int in 61:
				var y: float = c * (2.0 * i / 60.0 - 1.0)
				var v: float = beam.bending_stress(x_cut, y) if step() == 2 else beam.shear_stress(x_cut, y)
				pts.append(Vector2(v * Units.MPA, y * Units.MM))
			if step() == 2:
				p.begin("σ_x across the depth at the cut", "σ (MPa)", "y (mm)")
				p.line(pts, Color(1.0, 0.5, 0.4), 3.0)
			else:
				p.begin("τ across the depth at the cut", "τ (MPa)", "y (mm)")
				p.line(pts, Color(0.4, 0.85, 1.0), 3.0)
			p.hline(0.0, Color(0.8, 0.8, 0.8), "neutral axis")
		4:
			MohrFigure.fill(figures.plot(0), _probe_state(), 0.0)
		5:
			var p := figures.plot(0)
			p.begin("Elastic curve v(x) (downward)", "x (m)", "v (mm)")
			p.flip_y = true
			p.line(_sample(func(x: float) -> float: return beam.deflection_at(x) * Units.MM), Color(0.95, 0.8, 0.4), 3.0)
			p.marker(Vector2(beam.max_deflection_position(), beam.max_deflection() * Units.MM), Color(1, 0.5, 0.4), "v_max")
			p.hline(LENGTH / 360.0 * Units.MM, Color(1.0, 0.4, 0.4), "L/360")


func _sample(f: Callable) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 201:
		var x: float = LENGTH * i / 200.0
		pts.append(Vector2(x, f.call(x)))
	return pts


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([ORIGIN + Vector3(-0.3, -0.3, 0.3), ORIGIN + Vector3(LENGTH + 0.3, -0.3, 0.3),
			ORIGIN + Vector3(-0.6, 2.0, -0.7), ORIGIN + Vector3(LENGTH, 2.0, -0.7)])
