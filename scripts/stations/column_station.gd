extends Station
## Chapter 10 - Columns: a column under an axial load P with chosen end conditions and an
## optional eccentricity e. Below P_cr it stays straight (or bows per the secant formula);
## at P_cr it buckles into its mode shape. Drawn 2.4 m tall, section 1.5x real size.

const DRAWN_HEIGHT: float = 2.4
const BASE := Vector3(0.0, 0.25, 0.0)
const DRAW: float = 1.5
const BUCKLED_AMPLITUDE: float = 0.35
const MAX_DRAWN: float = 0.45
const END_NAMES: PackedStringArray = ["Pinned-pinned", "Fixed-free", "Fixed-pinned", "Fixed-fixed"]
const SECTION_NAMES: PackedStringArray = ["Rect 50×100", "Round d 80", "Tube 100×8", "W200×46.1"]
const MATERIAL_NAMES: PackedStringArray = ["Steel", "Aluminum", "Wood"]

var column: EulerColumn = EulerColumn.new()

var _sections: Array[CrossSection] = [RectSection.new(0.05, 0.1), CircleSection.new(0.04),
		TubeSection.new(0.05, 0.042), ISection.new(0.203, 0.203, 0.011, 0.00724)]
var _materials: Array[LabMaterial] = LabMaterial.presets()
var _data: BeamDataTexture = BeamDataTexture.new()
var _frame: Node3D = Node3D.new()
var _view: BeamView = BeamView.new(_data)
var _load: Arrow3D = Arrow3D.new(Color(0.95, 0.95, 1.0), 0.02)
var _base_fixed: MeshInstance3D = MeshInstance3D.new()
var _base_pin: MeshInstance3D = MeshInstance3D.new()
var _top_fixed: MeshInstance3D = MeshInstance3D.new()
var _top_pin: MeshInstance3D = MeshInstance3D.new()
var _status: Label3D = Text3D.make(44)
var _info: Label3D = Text3D.make(34)


func _init() -> void:
	chapter = 10
	title = "Columns and buckling"
	_controls = [
		ControlSpec.slider(&"P", "Axial load P", "kN", Units.KN, 0.0, 1000.0, 1.0, 50.0e3, 0),
		ControlSpec.slider(&"L", "Length L", "m", 1.0, 1.0, 8.0, 0.1, 3.0),
		ControlSpec.choice(&"ends", "End conditions", END_NAMES, 0),
		ControlSpec.choice(&"section", "Cross-section", SECTION_NAMES, 0),
		ControlSpec.choice(&"material", "Material", MATERIAL_NAMES, 0),
		ControlSpec.slider(&"e", "Eccentricity e", "mm", Units.MM, 0.0, 50.0, 0.5, 0.0, 1).only_in([0, 4, 5]),
		ControlSpec.slider(&"exaggeration", "Bow drawn ×", "", 1.0, 1.0, 200.0, 1.0, 20.0, 0).only_in([0, 4, 5]),
	]
	# The member's local +X points up; its deflection (local -Y) shows as sideways (+X world).
	_frame.position = BASE
	_frame.rotation.z = PI / 2.0
	add_child(_frame)
	_frame.add_child(_view)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.35, 0.37, 0.4)
	var block := BoxMesh.new()
	block.size = Vector3(0.6, 0.25, 0.6)
	for b: MeshInstance3D in [_base_fixed, _top_fixed]:
		b.mesh = block
		b.material_override = grey
		add_child(b)
	_base_fixed.position = BASE + Vector3(0.0, -0.125, 0.0)
	_top_fixed.position = BASE + Vector3(0.0, DRAWN_HEIGHT + 0.125, 0.0)
	var prism := PrismMesh.new()
	prism.size = Vector3(0.25, 0.22, 0.3)
	_base_pin.mesh = prism
	_base_pin.material_override = grey
	_base_pin.position = BASE + Vector3(0.0, -0.11, 0.0)
	add_child(_base_pin)
	var guide := PrismMesh.new()
	guide.size = Vector3(0.25, 0.22, 0.3)
	_top_pin.mesh = guide
	_top_pin.material_override = grey
	_top_pin.rotation.z = PI
	_top_pin.position = BASE + Vector3(0.0, DRAWN_HEIGHT + 0.11, 0.0)
	add_child(_top_pin)
	add_child(_load)
	_status.position = BASE + Vector3(0.9, DRAWN_HEIGHT + 0.35, 0.0)
	_info.position = BASE + Vector3(0.95, DRAWN_HEIGHT - 0.2, 0.0)
	add_child(_status)
	add_child(_info)


func buckled() -> bool:
	return column.load >= column.critical_load()


func _apply() -> void:
	column.load = value(&"P")
	column.length = value(&"L")
	column.ends = int(value(&"ends")) as EulerColumn.Ends
	column.section = _sections[int(value(&"section"))]
	column.material = _materials[int(value(&"material"))]
	column.eccentricity = value(&"e")
	var weak_is_vertical: bool = column.section.moment_of_inertia_vertical() < column.section.moment_of_inertia()
	_view.set_shape(column.section, DRAWN_HEIGHT, weak_is_vertical, DRAW)
	var drawn: float = 0.0
	if buckled():
		var compressed := func(_s: float) -> float: return -1.0
		_data.write_profile(column.mode_shape, compressed, compressed)
		drawn = BUCKLED_AMPLITUDE
	else:
		_data.write_profile(column.lateral_deflection_at, func(s: float) -> float: return column.stress_at(s, -1.0),
				func(s: float) -> float: return column.stress_at(s, 1.0))
		drawn = minf(column.max_deflection() * value(&"exaggeration"), MAX_DRAWN)
	_view.set_drawn_deflection(drawn)
	_view.set_stress_ratio(1.0)
	var fixed_base: bool = column.ends != EulerColumn.Ends.PINNED_PINNED
	_base_fixed.visible = fixed_base
	_base_pin.visible = not fixed_base
	_top_fixed.visible = column.ends == EulerColumn.Ends.FIXED_FIXED
	_top_pin.visible = column.ends == EulerColumn.Ends.PINNED_PINNED or column.ends == EulerColumn.Ends.FIXED_PINNED
	var top_shift: float = drawn * column.mode_shape(1.0) if column.ends == EulerColumn.Ends.FIXED_FREE else 0.0
	var e_drawn: float = column.eccentricity * DRAW * 5.0
	_load.place_onto(BASE + Vector3(top_shift + e_drawn, DRAWN_HEIGHT + (0.27 if _top_fixed.visible or _top_pin.visible else 0.02), 0.0),
			Vector3(0.0, -(0.2 + 0.4 * minf(column.load / 1000.0e3, 1.0)), 0.0))
	_load.label.text = "P = " + Units.force(column.load)
	_status.text = "BUCKLED: P ≥ P_cr" if buckled() else "stable: P < P_cr"
	_status.modulate = Color(1.0, 0.35, 0.3) if buckled() else Color(0.5, 0.95, 0.55)
	_info.text = "P_cr = %s\nL = %s (drawn %.1f m)" % [Units.force(column.critical_load()), Units.length(column.length), DRAWN_HEIGHT]


func step_titles() -> PackedStringArray:
	return ["Stability", "Euler's formula", "End conditions", "Slenderness", "Eccentric load", "Design check",
			"Design formulas (AISC)"]


func lesson_text() -> String:
	var F := LessonFormat
	var pcr: String = Units.force(column.critical_load())
	var t: String = ""
	match step():
		0:
			t += "A slender column can fail long before its material yields: it suddenly bows sideways — [b]buckling[/b], a loss of stability. Below a critical load P_cr a small sideways push dies out (stable); above it, it grows (unstable).\n"
			t += F.equation("P_cr", "", pcr)
			t += F.equation("P / P_cr", "", "%.2f" % (column.load / column.critical_load()))
			t += "Status: %s\n" % F.ok_or_fail(not buckled(), "stable" if not buckled() else "buckled")
			t += F.try_this("raise P slowly. At P_cr the column snaps into its buckled shape. Add a small eccentricity e: it bows earlier and gradually instead.")
		1:
			t += "For an ideal straight column pinned at both ends, the deflected shape must satisfy EI·v'' = −P·v. Non-zero solutions exist only for particular loads; the smallest is [b]Euler's formula[/b]:\n"
			t += F.derivation("With v the sideways deflection, the moment is M = P·v, so EI·v'' + P·v = 0, i.e. v'' + k²v = 0 with k² = P/(EI). Solution v = A·sin kx + B·cos kx; v(0) = 0 gives B = 0, v(L) = 0 gives A·sin kL = 0. A bent shape (A ≠ 0) needs kL = nπ: P = n²π²EI/L², smallest for n = 1.")
			t += F.equation("P_cr = π²·E·I/L_e²", "π² × %s × %s / (%s)²" % [Units.modulus(column.material.youngs_modulus), Units.inertia(column.min_inertia()), Units.length(column.effective_length())], pcr)
			t += "I is the [b]smallest[/b] moment of inertia of the section: the column buckles about its weak axis. P_cr does not depend on the strength of the material, only on its stiffness E.\n"
			t += F.try_this("double L: P_cr drops to a quarter. Switch steel → aluminum: P_cr drops to about a third.")
		2:
			t += "End conditions change the buckled shape (figure) and thus P_cr. They are captured by the [b]effective length[/b] L_e = K·L, the distance between inflection points of the mode shape:\n"
			t += F.equation("pinned-pinned: K = 1", "fixed-free: K = 2")
			t += F.equation("fixed-pinned: K = 0.699", "fixed-fixed: K = 0.5")
			t += F.equation("L_e = K·L", "%.3f × %s" % [EulerColumn.K_FACTORS[column.ends], Units.length(column.length)], Units.length(column.effective_length()))
			t += F.equation("P_cr = π²EI/L_e²", "", pcr)
			t += "A fixed-free column (a flagpole) is 4× weaker than a pinned one; fixing both ends makes it 4× stronger.\n"
			t += F.try_this("step through the four end conditions and compare P_cr.")
		3:
			var lr: float = column.slenderness()
			var lr_c: float = column.transition_slenderness()
			t += "Dividing by the area gives the critical stress in terms of the [b]slenderness ratio[/b] L_e/r, where r = √(I/A) is the radius of gyration:\n"
			t += F.equation("r = √(I_min/A)", "", Units.small_length(column.radius_of_gyration()))
			t += F.equation("L_e/r", "", "%.0f" % lr)
			t += F.equation("σ_cr = π²E/(L_e/r)²", "", Units.stress(column.critical_stress()))
			t += "Euler's formula only applies while σ_cr < σ_Y, i.e. for L_e/r > π√(E/σ_Y) = %.0f. Stockier columns yield (crush) before they buckle (figure).\n" % lr_c
			t += "This column: %s\n" % F.value("slender: buckling governs" if lr > lr_c else "short: yielding governs, Euler does not apply")
			t += F.try_this("shorten the column until the white dot crosses into the region where σ_Y caps the curve.")
		4:
			var y_max: float = column.max_deflection()
			t += "Real loads are never perfectly centred. With an eccentricity e the column bends from the start, and the bending grows sharply as P approaches P_cr. The [b]secant formula[/b] gives\n"
			t += F.equation("y_max = e·[sec(½·√(P/(EI))·L_e) − 1]", "", Units.small_length(y_max) if is_finite(y_max) else "∞")
			t += F.equation("σ_max = (P/A)·[1 + (e·c/r²)·sec(½·√(P/(EI))·L_e)]", "", Units.stress(column.max_stress()) if is_finite(column.max_stress()) else "∞")
			t += "Unlike the ideal column, failure now comes from yielding at σ_max = σ_Y, at a load below P_cr.\n"
			t += F.try_this("set e = 10 mm and raise P: the bow (figure) grows slowly at first, then explodes near P_cr.")
		5:
			var fs: float = column.buckling_safety()
			var sy: float = column.material.yield_strength
			var crush_ok: bool = column.max_stress() < sy
			t += "A column design checks both stability and strength:\n"
			t += F.equation("FS_buckling = P_cr/P", "%s / %s" % [pcr, Units.force(column.load)], Units.factor(fs))
			t += F.equation("σ_max ≤ σ_Y", "%s vs %s" % [Units.stress(column.max_stress()) if is_finite(column.max_stress()) else "∞", Units.stress(sy)], F.ok_or_fail(crush_ok, "OK" if crush_ok else "yields"))
			t += "Typical codes ask for FS ≈ 2 against buckling → %s\n" % F.ok_or_fail(fs >= 2.0, "adequate" if fs >= 2.0 else "not enough")
			t += F.try_this("carry 300 kN over 4 m with FS ≥ 2: which section and end conditions do it with the least material?")
		6:
			var lr: float = column.slenderness()
			var limit: float = 4.71 * sqrt(column.material.youngs_modulus / column.material.yield_strength)
			var p_all: float = column.aisc_allowable_load()
			t += "Real columns are never perfectly straight or centrally loaded, and steel sections contain residual stresses from rolling. Design codes therefore use [b]empirical column curves[/b] fitted to tests. The AISC specification (structural steel):\n"
			t += F.equation("σ_e = π²E/(L_e/r)²", "Euler stress", Units.stress(column.critical_stress()))
			t += F.equation("L_e/r ≤ 4.71√(E/σ_Y) = %.0f:  σ_cr = 0.658^(σ_Y/σ_e)·σ_Y" % limit, "inelastic buckling")
			t += F.equation("L_e/r > %.0f:  σ_cr = 0.877·σ_e" % limit, "elastic buckling, reduced for crookedness")
			t += F.equation("this column: L_e/r = %.0f" % lr, "", Units.stress(column.aisc_critical_stress()))
			t += F.equation("P_all = σ_cr·A/1.67", "allowable-stress design", Units.force(p_all))
			t += "Applied P = %s → %s\n" % [Units.force(column.load), F.ok_or_fail(column.load <= p_all, "OK" if column.load <= p_all else "not allowed")]
			t += F.note("The curve (figure) joins the yield strength for short columns to the Euler hyperbola for slender ones. Aluminum and timber have their own design formulas (Aluminum Association, NDS); the AISC formula is for structural steel.")
			t += F.try_this("shorten the column from 6 m to 1 m and watch it move from the elastic to the inelastic branch.")
	return t


func fill_figures(figures: FigureArea) -> void:
	match step():
		0, 4:
			var p := figures.plot(0)
			var e: float = maxf(column.eccentricity, 0.001)
			p.begin("Lateral deflection vs load (e = %s)" % Units.small_length(e), "y_max (mm)", "P (kN)")
			var probe := _probe()
			probe.eccentricity = e
			var pts := PackedVector2Array()
			for i: int in 120:
				probe.load = column.critical_load() * i / 120.0
				var y: float = probe.max_deflection()
				if y * Units.MM > 200.0:
					break
				pts.append(Vector2(y * Units.MM, probe.load * Units.KN))
			p.line(pts, Color(0.95, 0.75, 0.35), 3.0)
			p.hline(column.critical_load() * Units.KN, Color(1.0, 0.4, 0.4), "P_cr")
			if not buckled() and is_finite(column.max_deflection()):
				p.marker(Vector2(column.max_deflection() * Units.MM, column.load * Units.KN), Color(1, 1, 1), "now")
		1:
			var p := figures.plot(0)
			p.begin("Euler load vs length", "L (m)", "P_cr (kN)")
			var probe := _probe()
			var pts := PackedVector2Array()
			for i: int in 71:
				probe.length = 1.0 + 7.0 * i / 70.0
				pts.append(Vector2(probe.length, minf(probe.critical_load() * Units.KN, 3000.0)))
			p.line(pts, Color(0.6, 0.8, 1.0), 3.0)
			p.marker(Vector2(column.length, column.critical_load() * Units.KN), Color(1, 1, 1), "now")
		2:
			var p := figures.plot(0)
			p.begin("Buckling mode shapes (height vs bow)", "relative bow", "x/L")
			var colors: Array[Color] = [Color(0.6, 0.8, 1.0), Color(1.0, 0.6, 0.4), Color(0.6, 1.0, 0.6), Color(1.0, 0.85, 0.4)]
			var probe := _probe()
			for ends: int in 4:
				probe.ends = ends as EulerColumn.Ends
				var pts := PackedVector2Array()
				for i: int in 61:
					var s: float = i / 60.0
					pts.append(Vector2(probe.mode_shape(s) + ends * 1.3, s))
				p.line(pts, colors[ends], 3.0 if ends == column.ends else 1.5)
				p.marker(Vector2(ends * 1.3, 1.05), colors[ends], END_NAMES[ends].replace("-", "–"))
		3:
			var p := figures.plot(0)
			var sy: float = column.material.yield_strength * Units.MPA
			p.begin("Critical stress vs slenderness", "L_e/r", "σ_cr (MPa)")
			var pts := PackedVector2Array()
			var probe := _probe()
			for i: int in 101:
				# Choose the length that gives the wanted slenderness, then ask the model.
				var lr: float = 20.0 + 280.0 * i / 100.0
				probe.length = lr * probe.radius_of_gyration() / EulerColumn.K_FACTORS[probe.ends]
				pts.append(Vector2(probe.slenderness(), minf(probe.critical_stress() * Units.MPA, sy * 1.6)))
			p.line(pts, Color(0.6, 0.8, 1.0), 3.0)
			p.hline(sy, Color(1.0, 0.4, 0.4), "σ_Y")
			p.marker(Vector2(column.slenderness(), minf(column.critical_stress() * Units.MPA, sy * 1.6)), Color(1, 1, 1), "this column")
		6:
			var p := figures.plot(0)
			var sy: float = column.material.yield_strength * Units.MPA
			p.begin("AISC column curve vs Euler", "L_e/r", "σ (MPa)")
			var probe := _probe()
			var euler := PackedVector2Array()
			var aisc := PackedVector2Array()
			for i: int in 101:
				var lr: float = 10.0 + 290.0 * i / 100.0
				probe.length = lr * probe.radius_of_gyration() / EulerColumn.K_FACTORS[probe.ends]
				euler.append(Vector2(probe.slenderness(), minf(probe.critical_stress() * Units.MPA, sy * 1.5)))
				aisc.append(Vector2(probe.slenderness(), probe.aisc_critical_stress() * Units.MPA))
			p.line(euler, Color(0.6, 0.8, 1.0), 2.0)
			p.line(aisc, Color(1.0, 0.7, 0.3), 3.0)
			p.hline(sy, Color(1.0, 0.4, 0.4), "σ_Y")
			p.marker(Vector2(column.slenderness(), column.aisc_critical_stress() * Units.MPA), Color(1, 1, 1), "this column")
		5:
			var p := figures.plot(0)
			p.begin("Load vs the two limits", "", "P (kN)")
			p.line(PackedVector2Array([Vector2(1, 0), Vector2(1, column.load * Units.KN)]), Color(0.95, 0.95, 1.0), 16.0)
			p.line(PackedVector2Array([Vector2(2, 0), Vector2(2, column.critical_load() * Units.KN)]), Color(0.6, 0.8, 1.0), 16.0)
			p.line(PackedVector2Array([Vector2(3, 0), Vector2(3, column.squash_load() * Units.KN)]), Color(1.0, 0.5, 0.4), 16.0)
			p.marker(Vector2(1, column.load * Units.KN), Color(1, 1, 1), "P")
			p.marker(Vector2(2, column.critical_load() * Units.KN), Color(0.6, 0.8, 1.0), "P_cr")
			p.marker(Vector2(3, column.squash_load() * Units.KN), Color(1.0, 0.5, 0.4), "σ_Y·A")


## A column like the current one, for sweeping one parameter in a figure.
func _probe() -> EulerColumn:
	var c := EulerColumn.new()
	c.length = column.length
	c.ends = column.ends
	c.section = column.section
	c.material = column.material
	c.load = column.load
	c.eccentricity = column.eccentricity
	return c


func view_direction() -> Vector3:
	return Vector3(0.2, 0.15, 1.0)


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([BASE + Vector3(-1.2, -0.3, 0.3), BASE + Vector3(2.2, -0.3, 0.3),
			BASE + Vector3(2.2, DRAWN_HEIGHT + 0.6, 0.0), BASE + Vector3(-1.2, DRAWN_HEIGHT + 0.8, 0.0)])
