extends Station
## Chapter 7 - Transformations of stress and strain: a plane-stress element that the
## student rotates, Mohr's circle, yield and fracture criteria, thin-walled pressure
## vessels and strain-gauge rosettes.

const CENTER := Vector3(0.0, 1.45, 0.0)
const DRAW: float = 1.6
const MATERIAL_NAMES: PackedStringArray = ["Steel", "Aluminum", "Cast iron"]
const THREE_D: int = 6
const BRITTLE: int = 7
const VESSEL: int = 8
const ROSETTE: int = 9
const TANK := Vector3(0.0, 1.35, -0.3)
const ROSETTE_PLATE := Vector3(-1.4, 1.45, 0.0)

var state: PlaneStress = PlaneStress.new()
var vessel: PressureVessel = PressureVessel.new()
var rosette: StrainRosette = StrainRosette.new()

var _materials: Array[LabMaterial] = [LabMaterial.steel(), LabMaterial.aluminum(), LabMaterial.cast_iron()]
var _element: StressElementView = StressElementView.new()
var _angle_label: Label3D = Text3D.make(40)
var _tank: Node3D = Node3D.new()
var _tank_element: StressElementView = StressElementView.new()
var _tank_label: Label3D = Text3D.make(36)
var _plate: MeshInstance3D = MeshInstance3D.new()
var _gauges: Array[MeshInstance3D] = []
var _gauge_labels: Array[Label3D] = []
var _tank_key: String = ""


func _init() -> void:
	chapter = 7
	title = "Transformations of stress and strain"
	_controls = [
		ControlSpec.slider(&"sx", "σ_x", "MPa", Units.MPA, -200.0, 200.0, 1.0, 50.0e6, 0).only_in([0, 1, 2, 3, 4, 5, THREE_D, BRITTLE]),
		ControlSpec.slider(&"sy", "σ_y", "MPa", Units.MPA, -200.0, 200.0, 1.0, -10.0e6, 0).only_in([0, 1, 2, 3, 4, 5, THREE_D, BRITTLE]),
		ControlSpec.slider(&"txy", "τ_xy", "MPa", Units.MPA, -150.0, 150.0, 1.0, 40.0e6, 0).only_in([0, 1, 2, 3, 4, 5, THREE_D, BRITTLE]),
		ControlSpec.slider(&"theta", "Element rotation θ", "°", 180.0 / PI, -90.0, 90.0, 0.5, 0.0, 1).only_in([0, 1, 2, 3, 4]),
		ControlSpec.choice(&"snap", "Turn the element to", PackedStringArray(["θ slider", "principal", "max shear"]), 0).only_in([2, 3, 4]),
		ControlSpec.choice(&"material", "Material", MATERIAL_NAMES, 0).only_in([5, BRITTLE, ROSETTE]),
		ControlSpec.slider(&"p", "Pressure p", "MPa", Units.MPA, 0.0, 10.0, 0.1, 2.0e6, 1).only_in([VESSEL]),
		ControlSpec.slider(&"r", "Radius r", "m", 1.0, 0.2, 2.0, 0.05, 0.5).only_in([VESSEL]),
		ControlSpec.slider(&"t", "Wall thickness t", "mm", Units.MM, 2.0, 50.0, 1.0, 0.01, 0).only_in([VESSEL]),
		ControlSpec.choice(&"shape", "Vessel", PackedStringArray(["Cylinder", "Sphere"]), 0).only_in([VESSEL]),
		ControlSpec.slider(&"ea", "Gauge a (0°)", "με", 1.0e6, -1000.0, 1000.0, 5.0, 600.0e-6, 0).only_in([ROSETTE]),
		ControlSpec.slider(&"eb", "Gauge b (45°)", "με", 1.0e6, -1000.0, 1000.0, 5.0, 400.0e-6, 0).only_in([ROSETTE]),
		ControlSpec.slider(&"ec", "Gauge c (90°)", "με", 1.0e6, -1000.0, 1000.0, 5.0, -200.0e-6, 0).only_in([ROSETTE]),
	]
	_element.position = CENTER
	_element.scale = Vector3.ONE * DRAW
	add_child(_element)
	_angle_label.position = CENTER + Vector3(0.0, -0.8, 0.0)
	add_child(_angle_label)
	_tank.position = TANK
	add_child(_tank)
	_tank_element.scale = Vector3.ONE * 0.7
	_tank.add_child(_tank_element)
	_tank.add_child(_tank_label)
	_build_rosette()


func _build_rosette() -> void:
	var plate := BoxMesh.new()
	plate.size = Vector3(0.7, 0.7, 0.02)
	_plate.mesh = plate
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.77, 0.8)
	_plate.material_override = m
	_plate.position = ROSETTE_PLATE
	add_child(_plate)
	var foil := StandardMaterial3D.new()
	foil.albedo_color = Color(0.9, 0.6, 0.2)
	for i: int in 3:
		var g := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(0.26, 0.035, 0.01)
		g.mesh = strip
		g.material_override = foil
		var angle: float = PI / 4.0 * i
		g.rotation.z = angle
		g.position = ROSETTE_PLATE + Vector3(cos(angle), sin(angle), 0.0) * 0.17 + Vector3(0, 0, 0.015)
		_gauges.append(g)
		add_child(g)
		var label := Text3D.make(32)
		label.position = ROSETTE_PLATE + Vector3(cos(angle), sin(angle), 0.0) * 0.42 + Vector3(0, 0, 0.02)
		_gauge_labels.append(label)
		add_child(label)


## Element angle: the slider, or snapped to the principal / max-shear orientation.
func theta() -> float:
	if step() > 4:
		return 0.0
	match int(value(&"snap")):
		1:
			return state.principal_angle()
		2:
			return state.max_shear_angle()
	return value(&"theta")


func _material() -> LabMaterial:
	return _materials[int(value(&"material"))]


func _apply() -> void:
	var s: int = step()
	rosette.strain_a = value(&"ea")
	rosette.strain_b = value(&"eb")
	rosette.strain_c = value(&"ec")
	rosette.material = _material()
	vessel.pressure = value(&"p")
	vessel.radius = value(&"r")
	vessel.thickness = value(&"t")
	vessel.spherical = value(&"shape") == 1.0
	if s == ROSETTE:
		state = rosette.stress_state()
	else:
		state = PlaneStress.new(value(&"sx"), value(&"sy"), value(&"txy"))
	var th: float = theta()
	var t: Vector3 = state.transformed(th)
	_element.visible = s != VESSEL
	_element.position = CENTER + (Vector3(0.45, 0.0, 0.0) if s == ROSETTE else Vector3.ZERO)
	_element.reference = maxf(maxf(absf(state.principal_1()), absf(state.principal_2())), 1.0)
	_element.show_stresses(t.x, t.y, t.z, th)
	_angle_label.visible = s != VESSEL
	_angle_label.text = "θ = %s (counterclockwise from x)" % Units.angle(th) if s != ROSETTE else "stresses from the rosette (Hooke's law)"
	_apply_tank(s == VESSEL)
	_plate.visible = s == ROSETTE
	var readings: Array[float] = [rosette.strain_a, rosette.strain_b, rosette.strain_c]
	for i: int in 3:
		_gauges[i].visible = s == ROSETTE
		_gauge_labels[i].visible = s == ROSETTE
		_gauge_labels[i].text = "%s: %.0f με" % [["a", "b", "c"][i], readings[i] * 1e6]


## Cylinder or sphere drawn at radius r (capped for display), with a wall element facing the viewer.
func _apply_tank(on: bool) -> void:
	_tank.visible = on
	if not on:
		return
	var r: float = minf(vessel.radius, 0.8)
	var key: String = "%.2f %s" % [r, vessel.spherical]
	if key != _tank_key:
		_tank_key = key
		for child: Node in _tank.get_children():
			if child is MeshInstance3D:
				child.queue_free()
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color(0.6, 0.65, 0.7, 0.55)
		steel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if vessel.spherical:
			var ball := SphereMesh.new()
			ball.radius = r
			ball.height = 2.0 * r
			_add_tank_part(ball, Vector3.ZERO, steel)
		else:
			var body := CylinderMesh.new()
			body.top_radius = r
			body.bottom_radius = r
			body.height = 1.6
			_add_tank_part(body, Vector3.ZERO, steel).rotation.z = PI / 2.0
			for side: float in [-0.8, 0.8]:
				var cap := SphereMesh.new()
				cap.radius = r
				cap.height = 2.0 * r
				_add_tank_part(cap, Vector3(side, 0.0, 0.0), steel)
	var st: PlaneStress = vessel.stress_state()
	_tank_element.position = Vector3(0.0, 0.0, r + 0.03)
	_tank_element.reference = maxf(absf(st.sigma_y), 1.0)
	_tank_element.show_stresses(st.sigma_x, st.sigma_y, 0.0, 0.0)
	_tank_label.text = "x = along the axis, y = around (hoop)"
	_tank_label.position = Vector3(0.0, -r - 0.25, r)


func _add_tank_part(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.material_override = material
	_tank.add_child(part)
	return part


func set_step(index: int) -> void:
	_step = clampi(index, 0, step_titles().size() - 1)
	_apply()
	changed.emit()


func step_titles() -> PackedStringArray:
	return ["Plane stress", "Transformation equations", "Principal stresses", "Maximum shear",
			"Mohr's circle", "Yield criteria", "Three-dimensional stress", "Brittle materials",
			"Pressure vessels", "Strain rosettes"]


func lesson_text() -> String:
	var F := LessonFormat
	var th: float = theta()
	var tr: Vector3 = state.transformed(th)
	var t: String = ""
	match step():
		0:
			t += "The state of stress at a point is described by the stresses on a tiny element. In [b]plane stress[/b] (thin plates, free surfaces) only three components act in the x-y plane, and σ_z = τ_zx = τ_zy = 0:\n"
			t += F.equation("σ_x", "", Units.stress(state.sigma_x))
			t += F.equation("σ_y", "", Units.stress(state.sigma_y))
			t += F.equation("τ_xy", "", Units.stress(state.tau_xy))
			t += "Signs: normal stress positive in [b]tension[/b] (arrow pointing out of the face); τ_xy positive when it acts in +y on the face whose outward normal is +x (and, for equilibrium of moments, in +x on the +y face).\n"
			t += "The same physical state looks different on an element turned by θ: that is what this chapter is about.\n"
			t += F.try_this("set τ_xy = 0 and σ_x = σ_y: rotate the element — nothing changes. That is a hydrostatic (isotropic) state.")
		1:
			t += "Equilibrium of a wedge cut at angle θ gives the [b]transformation equations[/b]:\n"
			t += F.derivation("A wedge with an inclined face of area ΔA has faces ΔA·cosθ (normal x) and ΔA·sinθ (normal y). Summing forces along the inclined face's normal and tangent and using double-angle identities gives the three equations below.")
			t += F.equation("σ_x' = (σ_x+σ_y)/2 + (σ_x−σ_y)/2·cos2θ + τ_xy·sin2θ", "", Units.stress(tr.x))
			t += F.equation("σ_y' = (σ_x+σ_y)/2 − (σ_x−σ_y)/2·cos2θ − τ_xy·sin2θ", "", Units.stress(tr.y))
			t += F.equation("τ_x'y' = −(σ_x−σ_y)/2·sin2θ + τ_xy·cos2θ", "", Units.stress(tr.z))
			t += "Note the [b]2θ[/b]: the stresses repeat every 180° of rotation. The sum σ_x' + σ_y' = %s never changes (an invariant).\n" % F.value(Units.stress(tr.x + tr.y))
			t += F.try_this("drag θ slowly and follow the white marker along the curves in the figure.")
		2:
			t += "As θ turns, σ_x' passes through a maximum and a minimum. These extremes are the [b]principal stresses[/b]; on those planes the shear stress is [b]zero[/b] (setting dσ_x'/dθ = 0 is the same as setting τ_x'y' = 0).\n"
			t += F.equation("tan 2θ_p = 2τ_xy/(σ_x − σ_y)", "", Units.angle(state.principal_angle()))
			t += F.equation("σ_max,min = (σ_x+σ_y)/2 ± √(((σ_x−σ_y)/2)² + τ_xy²)", "", "%s, %s" % [Units.stress(state.principal_1()), Units.stress(state.principal_2())])
			t += "The two principal planes are 90° apart.\n"
			t += F.try_this("choose 'Turn the element to: principal': the shear arrows vanish and the normal arrows show σ_max and σ_min.")
		3:
			t += "The largest shear stress in the plane acts on planes at [b]45°[/b] to the principal planes, and there both normal stresses equal the average:\n"
			t += F.equation("τ_max = √(((σ_x−σ_y)/2)² + τ_xy²) = (σ_max − σ_min)/2", "", Units.stress(state.max_inplane_shear()))
			t += F.equation("θ_s = θ_p − 45°", "", Units.angle(state.max_shear_angle()))
			t += F.equation("σ' = σ_avg = (σ_x+σ_y)/2", "", Units.stress(state.average()))
			t += F.try_this("make σ_x = 100, σ_y = 40, τ_xy = 0: the in-plane τ_max is 30 MPa — but step 7 shows the true maximum is 50 MPa.")
		4:
			t += "All the transformation equations are captured by one picture, [b]Mohr's circle[/b]:\n[ul]\nplot X = (σ_x, −τ_xy) and Y = (σ_y, +τ_xy);\nXY is a diameter: centre C = σ_avg, radius R = τ_max;\nrotating the element by θ turns the diameter by [b]2θ[/b] in the same sense, giving X' and Y'.\n[/ul]\n"
			t += F.derivation("Eliminating 2θ from the transformation equations: (σ_x' − σ_avg)² + τ_x'y'² = R², a circle in the σ-τ plane.")
			t += F.equation("C = (σ_x+σ_y)/2", "", Units.stress(state.average()))
			t += F.equation("R", "", Units.stress(state.radius()))
			t += "The ends of the horizontal diameter are σ_max and σ_min; the top and bottom are ±τ_max.\n"
			t += F.try_this("rotate the element by 45° and check that X' moves a quarter of the way around the circle (90°).")
		5:
			var sy: float = _material().yield_strength
			t += "Does a [b]ductile[/b] material yield under this combined stress? A tension test only gives σ_Y; [b]yield criteria[/b] translate the principal stresses σ_a, σ_b into one comparable number:\n"
			t += F.equation("Tresca (max shear): τ_abs,max = σ_Y/2", "FS = (σ_Y/2)/τ_abs,max", Units.factor(state.tresca_safety(sy)))
			t += F.equation("von Mises: σ_vm = √(σ_a² − σ_a·σ_b + σ_b²)", "", Units.stress(state.von_mises()))
			t += F.equation("FS = σ_Y/σ_vm", "", Units.factor(state.von_mises_safety(sy)))
			t += F.note("von Mises (maximum distortion energy) fits experiments on ductile metals best; Tresca is slightly conservative (up to 15 %) and simpler.")
			t += F.try_this("pure shear (σ_x = σ_y = 0): Tresca predicts yield at τ = 0.5 σ_Y, von Mises at τ = 0.577 σ_Y.")
		THREE_D:
			t += "Plane stress is really three-dimensional: the face normal to z is free of shear, so z is a [b]principal direction[/b] with σ_c = 0. Rotating the element about the other two axes gives two more Mohr circles (figure):\n"
			t += F.equation("principal stresses σ_a, σ_b, σ_c", "", "%s, %s, 0" % [Units.stress(state.principal_1()), Units.stress(state.principal_2())])
			t += F.equation("τ_abs,max = (σ_max − σ_min)/2 over all three", "", Units.stress(state.absolute_max_shear()))
			t += F.equation("in-plane τ_max", "", Units.stress(state.max_inplane_shear()))
			t += "When σ_a and σ_b have the [b]same sign[/b], the largest circle passes through σ_c = 0 and the absolute maximum shear acts on planes at 45° [i]out of[/i] the x-y plane.\n"
			t += F.try_this("set σ_x = 100, σ_y = 40, τ_xy = 0: the in-plane circle has radius 30, the outer one 50 MPa.")
		BRITTLE:
			var m: LabMaterial = _material()
			var ut: float = m.ultimate_strength
			var uc: float = m.ultimate_compressive_strength
			t += "[b]Brittle[/b] materials (cast iron, concrete, glass) fail by fracture without yielding, and they are much stronger in compression than in tension. Ductile criteria do not apply; instead:\n"
			t += F.equation("max-normal-stress (Rankine): |σ| ≤ σ_U", "FS", Units.factor(state.max_normal_safety(ut, uc)))
			t += F.equation("Mohr's criterion: σ_a/σ_UT − σ_b/σ_UC = 1/FS", "(σ_a > 0 > σ_b)", Units.factor(state.mohr_safety(ut, uc)))
			t += "For %s: σ_UT = %s, σ_UC = %s (figure: the safe region; Mohr's criterion cuts the corners where one principal stress is tensile and the other compressive).\n" % [m.display_name, Units.stress(ut), Units.stress(uc)]
			t += F.try_this("choose cast iron and pure shear (τ_xy only): the element fails at τ ≈ σ_UT/(1 + σ_UT/σ_UC), on 45° planes — like chalk twisted to breaking.")
		VESSEL:
			var st: PlaneStress = vessel.stress_state()
			t += "A thin-walled vessel (t ≤ r/10) under internal pressure p carries the pressure by membrane stresses, nearly uniform through the wall. Free-body diagrams of half the vessel give them:\n"
			t += F.derivation("Cut a cylinder of length Δx along a diameter: p·(2r·Δx) = 2·σ₁·t·Δx gives σ₁ = pr/t. Cut it across: p·πr² = σ₂·2πr·t gives σ₂ = pr/(2t). A sphere is cut the same way in every direction.")
			if vessel.spherical:
				t += F.equation("sphere: σ = p·r/(2t)", "", Units.stress(vessel.hoop_stress()))
			else:
				t += F.equation("hoop: σ₁ = p·r/t", "%s × %s / %s" % [Units.stress(vessel.pressure), Units.length(vessel.radius), Units.small_length(vessel.thickness)], Units.stress(vessel.hoop_stress()))
				t += F.equation("longitudinal: σ₂ = p·r/(2t)", "", Units.stress(vessel.axial_stress()))
			t += "On the outer surface σ₃ = 0, so the third Mohr circle governs the shear:\n"
			t += F.equation("τ_abs,max = σ₁/2", "", Units.stress(vessel.absolute_max_shear()))
			t += F.equation("von Mises FS (steel)", "", Units.factor(st.von_mises_safety(LabMaterial.steel().yield_strength)))
			t += F.note("The hoop stress is twice the longitudinal one: cylinders split along their length (think of a frozen water pipe). A sphere needs only half the wall thickness of a cylinder of the same radius.")
			t += F.try_this("switch to a sphere and compare the stresses at the same p, r and t.")
		ROSETTE:
			var e: Vector2 = rosette.principal_strains()
			t += "Stresses cannot be measured directly — strains can. A [b]strain rosette[/b] glues three gauges at 0°, 45° and 90° on a free surface. Strain transforms exactly like stress, with γ/2 in place of τ:\n"
			t += F.equation("ε(θ) = (ε_x+ε_y)/2 + (ε_x−ε_y)/2·cos2θ + (γ_xy/2)·sin2θ", "")
			t += F.equation("ε_x = ε_a,  ε_y = ε_c,  γ_xy = 2ε_b − (ε_a + ε_c)", "", Units.strain(rosette.shear_strain()))
			t += F.equation("ε_max,min", "", "%s, %s" % [Units.strain(e.x), Units.strain(e.y)])
			t += "Hooke's law for plane stress then gives the stresses on the element (right):\n"
			t += F.equation("σ_x = E/(1−ν²)·(ε_x + ν·ε_y)", "", Units.stress(state.sigma_x))
			t += F.equation("σ_y = E/(1−ν²)·(ε_y + ν·ε_x)", "", Units.stress(state.sigma_y))
			t += F.equation("τ_xy = G·γ_xy", "", Units.stress(state.tau_xy))
			t += F.note("The surface is in plane stress, but not in plane strain: ε_z = −ν(σ_x + σ_y)/E ≠ 0.")
			t += F.try_this("set ε_b = (ε_a + ε_c)/2: then γ_xy = 0 and the gauge directions a and c are principal.")
	return t


func fill_figures(figures: FigureArea) -> void:
	var th: float = theta()
	match step():
		1, 2, 3:
			var p := figures.plot(0)
			p.begin("Stresses on the rotated element vs θ", "θ (°)", "stress (MPa)")
			var sx := PackedVector2Array()
			var txy := PackedVector2Array()
			for i: int in 181:
				var angle: float = deg_to_rad(i - 90.0)
				var tr: Vector3 = state.transformed(angle)
				sx.append(Vector2(i - 90.0, tr.x * Units.MPA))
				txy.append(Vector2(i - 90.0, tr.z * Units.MPA))
			p.line(sx, Color(1.0, 0.45, 0.35), 3.0)
			p.line(txy, Color(0.35, 0.85, 1.0), 3.0)
			var now: Vector3 = state.transformed(th)
			p.vline(rad_to_deg(th), Color(1, 1, 1), "θ")
			p.marker(Vector2(rad_to_deg(th), now.x * Units.MPA), Color(1.0, 0.45, 0.35), "σ_x'")
			p.marker(Vector2(rad_to_deg(th), now.z * Units.MPA), Color(0.35, 0.85, 1.0), "τ_x'y'")
		4:
			MohrFigure.fill(figures.plot(0), state, th)
		5:
			var sy: float = _material().yield_strength * Units.MPA
			var p := figures.plot(0)
			p.begin("Yield surfaces in the σ_a-σ_b plane", "σ_a (MPa)", "σ_b (MPa)")
			p.equal_aspect = true
			var ellipse := PackedVector2Array()
			for i: int in 121:
				ellipse.append(PlaneStress.von_mises_boundary(TAU * i / 120.0, sy))
			p.line(ellipse, Color(0.5, 0.8, 1.0), 2.5)
			p.line(PlaneStress.tresca_boundary(sy), Color(1.0, 0.7, 0.3), 2.5)
			p.marker(Vector2(state.principal_1(), state.principal_2()) * Units.MPA, Color(1, 1, 1), "now")
		THREE_D:
			MohrFigure.fill_3d(figures.plot(0), state)
		BRITTLE:
			var m: LabMaterial = _material()
			var p := figures.plot(0)
			p.begin("Fracture criteria (MPa)", "σ_a", "σ_b")
			p.equal_aspect = true
			p.line(PlaneStress.max_normal_boundary(m.ultimate_strength * Units.MPA, m.ultimate_compressive_strength * Units.MPA), Color(1.0, 0.7, 0.3), 2.0)
			p.line(PlaneStress.mohr_boundary(m.ultimate_strength * Units.MPA, m.ultimate_compressive_strength * Units.MPA), Color(0.5, 0.8, 1.0), 2.5)
			p.marker(Vector2(state.principal_1(), state.principal_2()) * Units.MPA, Color(1, 1, 1), "now")
		VESSEL:
			MohrFigure.fill_3d(figures.plot(0), vessel.stress_state())
		ROSETTE:
			var p := figures.plot(0)
			p.begin("Normal strain vs gauge direction", "θ (°)", "ε (με)")
			var pts := PackedVector2Array()
			for i: int in 181:
				pts.append(Vector2(i, rosette.strain_at(deg_to_rad(float(i))) * 1e6))
			p.line(pts, Color(0.95, 0.75, 0.35), 3.0)
			var readings: Array[float] = [rosette.strain_a, rosette.strain_b, rosette.strain_c]
			for i: int in 3:
				p.marker(Vector2(45.0 * i, readings[i] * 1e6), Color(1, 1, 1), ["a", "b", "c"][i])
			MohrFigure.fill(figures.plot(1), state, 0.0)


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([CENTER + Vector3(-1.9, -1.0, 0.0), CENTER + Vector3(1.9, 1.2, 0.0)])
