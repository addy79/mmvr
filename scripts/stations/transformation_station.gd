extends Station
## Chapter 7 - Transformations of stress: a plane-stress element that the student rotates.
## The arrows show the stresses on the rotated faces; the figures show the transformation
## curves, Mohr's circle and the yield criteria.

const CENTER := Vector3(0.0, 1.45, 0.0)
const DRAW: float = 1.6
const MATERIAL_NAMES: PackedStringArray = ["Steel", "Aluminum"]

var state: PlaneStress = PlaneStress.new()

var _materials: Array[LabMaterial] = [LabMaterial.steel(), LabMaterial.aluminum()]
var _element: StressElementView = StressElementView.new()
var _angle_label: Label3D = Text3D.make(40)


func _init() -> void:
	chapter = 7
	title = "Transformations of stress"
	_controls = [
		ControlSpec.slider(&"sx", "σ_x", "MPa", Units.MPA, -200.0, 200.0, 1.0, 50.0e6, 0),
		ControlSpec.slider(&"sy", "σ_y", "MPa", Units.MPA, -200.0, 200.0, 1.0, -10.0e6, 0),
		ControlSpec.slider(&"txy", "τ_xy", "MPa", Units.MPA, -150.0, 150.0, 1.0, 40.0e6, 0),
		ControlSpec.slider(&"theta", "Element rotation θ", "°", 180.0 / PI, -90.0, 90.0, 0.5, 0.0, 1),
		ControlSpec.choice(&"snap", "Turn the element to", PackedStringArray(["θ slider", "principal", "max shear"]), 0).only_in([2, 3, 4]),
		ControlSpec.choice(&"material", "Material", MATERIAL_NAMES, 0).only_in([5]),
	]
	_element.position = CENTER
	_element.scale = Vector3.ONE * DRAW
	add_child(_element)
	_angle_label.position = CENTER + Vector3(0.0, -0.8, 0.0)
	add_child(_angle_label)


## Element angle: the slider, or snapped to the principal / max-shear orientation.
func theta() -> float:
	match int(value(&"snap")):
		1:
			return state.principal_angle()
		2:
			return state.max_shear_angle()
	return value(&"theta")


func _apply() -> void:
	state.sigma_x = value(&"sx")
	state.sigma_y = value(&"sy")
	state.tau_xy = value(&"txy")
	var th: float = theta()
	var t: Vector3 = state.transformed(th)
	_element.reference = maxf(maxf(absf(state.principal_1()), absf(state.principal_2())), 1.0)
	_element.show_stresses(t.x, t.y, t.z, th)
	_angle_label.text = "θ = %s (counterclockwise from x)" % Units.angle(th)


func step_titles() -> PackedStringArray:
	return ["Plane stress", "Transformation equations", "Principal stresses", "Maximum shear",
			"Mohr's circle", "Yield criteria"]


func lesson_text() -> String:
	var F := LessonFormat
	var th: float = theta()
	var tr: Vector3 = state.transformed(th)
	var t: String = ""
	match step():
		0:
			t += "The state of stress at a point is described by the stresses on a tiny element. In [b]plane stress[/b] (thin plates, free surfaces) only three components act in the x-y plane:\n"
			t += F.equation("σ_x", "", Units.stress(state.sigma_x))
			t += F.equation("σ_y", "", Units.stress(state.sigma_y))
			t += F.equation("τ_xy", "", Units.stress(state.tau_xy))
			t += "Signs: normal stress positive in [b]tension[/b] (arrow pointing out of the face); τ_xy positive when it acts in +y on the face whose outward normal is +x (and, for equilibrium of moments, in +x on the +y face).\n"
			t += "The same physical state looks different on an element turned by θ: that is what this chapter is about.\n"
			t += F.try_this("set τ_xy = 0 and σ_x = σ_y: rotate the element — nothing changes. That is a hydrostatic (isotropic) state.")
		1:
			t += "Equilibrium of a wedge cut at angle θ gives the [b]transformation equations[/b]:\n"
			t += F.equation("σ_x' = (σ_x+σ_y)/2 + (σ_x−σ_y)/2·cos2θ + τ_xy·sin2θ", "", Units.stress(tr.x))
			t += F.equation("σ_y' = (σ_x+σ_y)/2 − (σ_x−σ_y)/2·cos2θ − τ_xy·sin2θ", "", Units.stress(tr.y))
			t += F.equation("τ_x'y' = −(σ_x−σ_y)/2·sin2θ + τ_xy·cos2θ", "", Units.stress(tr.z))
			t += "Note the [b]2θ[/b]: the stresses repeat every 180° of rotation. The sum σ_x' + σ_y' = %s never changes (an invariant).\n" % F.value(Units.stress(tr.x + tr.y))
			t += F.try_this("drag θ slowly and follow the white marker along the curves in the figure.")
		2:
			t += "As θ turns, σ_x' passes through a maximum and a minimum. These extremes are the [b]principal stresses[/b]; on those planes the shear stress is [b]zero[/b].\n"
			t += F.equation("tan 2θ_p = 2τ_xy/(σ_x − σ_y)", "", Units.angle(state.principal_angle()))
			t += F.equation("σ_max,min = (σ_x+σ_y)/2 ± √(((σ_x−σ_y)/2)² + τ_xy²)", "", "%s, %s" % [Units.stress(state.principal_1()), Units.stress(state.principal_2())])
			t += "The two principal planes are 90° apart.\n"
			t += F.try_this("choose 'Turn the element to: principal': the shear arrows vanish and the normal arrows show σ_max and σ_min.")
		3:
			t += "The largest shear stress in the plane acts on planes at [b]45°[/b] to the principal planes, and there both normal stresses equal the average:\n"
			t += F.equation("τ_max = √(((σ_x−σ_y)/2)² + τ_xy²) = (σ_max − σ_min)/2", "", Units.stress(state.max_inplane_shear()))
			t += F.equation("θ_s = θ_p − 45°", "", Units.angle(state.max_shear_angle()))
			t += F.equation("σ' = σ_avg = (σ_x+σ_y)/2", "", Units.stress(state.average()))
			t += F.note("In 3D, the out-of-plane principal stress σ_z = 0 also counts: if σ_max and σ_min have the same sign, the absolute maximum shear is σ_max/2.")
			t += F.equation("τ_abs,max", "", Units.stress(state.absolute_max_shear()))
			t += F.try_this("make σ_x = 100, σ_y = 40, τ_xy = 0: the in-plane τ_max is 30 MPa, but τ_abs,max = 50 MPa.")
		4:
			t += "All the transformation equations are captured by one picture, [b]Mohr's circle[/b]:\n[ul]\nplot X = (σ_x, −τ_xy) and Y = (σ_y, +τ_xy);\nXY is a diameter: centre C = σ_avg, radius R = τ_max;\nrotating the element by θ turns the diameter by [b]2θ[/b] in the same sense, giving X' and Y'.\n[/ul]\n"
			t += F.equation("C = (σ_x+σ_y)/2", "", Units.stress(state.average()))
			t += F.equation("R", "", Units.stress(state.radius()))
			t += "The ends of the horizontal diameter are σ_max and σ_min; the top and bottom are ±τ_max.\n"
			t += F.try_this("rotate the element by 45° and check that X' moves a quarter of the way around the circle (90°).")
		5:
			var sy: float = _materials[int(value(&"material"))].yield_strength
			t += "Does a ductile material yield under this combined stress? A tension test only gives σ_Y; [b]yield criteria[/b] translate the principal stresses into one comparable number:\n"
			t += F.equation("Tresca (max shear): τ_abs,max = σ_Y/2", "FS = (σ_Y/2)/τ_abs,max", Units.factor(state.tresca_safety(sy)))
			t += F.equation("von Mises: σ_vm = √(σ_a² − σ_a·σ_b + σ_b²)", "", Units.stress(state.von_mises()))
			t += F.equation("FS = σ_Y/σ_vm", "", Units.factor(state.von_mises_safety(sy)))
			t += "In the σ_a-σ_b plane (figure) the safe region is a hexagon (Tresca) inside an ellipse (von Mises); the white dot is this state.\n"
			t += F.try_this("pure shear (σ_x = σ_y = 0): Tresca predicts yield at τ = 0.5 σ_Y, von Mises at τ = 0.577 σ_Y.")
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
			var sy: float = _materials[int(value(&"material"))].yield_strength * Units.MPA
			var p := figures.plot(0)
			p.begin("Yield surfaces in the σ_a-σ_b plane", "σ_a (MPa)", "σ_b (MPa)")
			p.equal_aspect = true
			var ellipse := PackedVector2Array()
			for i: int in 121:
				ellipse.append(PlaneStress.von_mises_boundary(TAU * i / 120.0, sy))
			p.line(ellipse, Color(0.5, 0.8, 1.0), 2.5)
			p.line(PlaneStress.tresca_boundary(sy), Color(1.0, 0.7, 0.3), 2.5)
			p.marker(Vector2(state.principal_1(), state.principal_2()) * Units.MPA, Color(1, 1, 1), "now")


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([CENTER + Vector3(-1.2, -1.0, 0.0), CENTER + Vector3(1.9, 1.2, 0.0)])
