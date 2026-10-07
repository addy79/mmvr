extends Station
## Chapter 1 - Introduction, concept of stress: a rod pulled through a pin and clevis.
## Normal stress in the rod, average shear in the pin (single/double shear), bearing on
## the eye, stresses on an oblique cut, and design with allowable stresses.
## Parts are drawn 5x real size.

const DRAW: float = 5.0                     ## drawing scale
const CENTER := Vector3(0.0, 1.25, 0.0)
const ROD_LENGTH: float = 1.7               ## drawn
const DESIGN_FS: float = 2.0

var model: RodAndPin = RodAndPin.new()

var _materials: Array[LabMaterial] = [LabMaterial.steel(), LabMaterial.aluminum()]
var _rig: Node3D = Node3D.new()
var _rod: MeshInstance3D = MeshInstance3D.new()
var _eye: MeshInstance3D = MeshInstance3D.new()
var _pin: MeshInstance3D = MeshInstance3D.new()
var _plates: Array[MeshInstance3D] = [MeshInstance3D.new(), MeshInstance3D.new()]
var _shear_planes: Array[MeshInstance3D] = [MeshInstance3D.new(), MeshInstance3D.new()]
var _bearing_patch: MeshInstance3D = MeshInstance3D.new()
var _load_arrow: Arrow3D = Arrow3D.new(Color(0.95, 0.95, 1.0), 0.02)
var _reaction_arrow: Arrow3D = Arrow3D.new(Color(0.4, 0.95, 0.5), 0.02)
var _plane: MeshInstance3D = MeshInstance3D.new()
var _sigma_arrow: Arrow3D = Arrow3D.new(Color(1.0, 0.45, 0.35), 0.016)
var _tau_arrow: Arrow3D = Arrow3D.new(Color(0.35, 0.85, 1.0), 0.016)
var _caption: Label3D = Text3D.make(40)


func _init() -> void:
	chapter = 1
	title = "Concept of stress"
	_controls = [
		ControlSpec.slider(&"P", "Load P", "kN", Units.KN, 0.0, 60.0, 0.5, 20.0e3),
		ControlSpec.slider(&"d", "Rod diameter d", "mm", Units.MM, 10.0, 40.0, 1.0, 0.02, 0),
		ControlSpec.slider(&"dp", "Pin diameter d_p", "mm", Units.MM, 8.0, 30.0, 1.0, 0.016, 0).only_in([1, 2, 4]),
		ControlSpec.slider(&"t", "Eye thickness t", "mm", Units.MM, 8.0, 40.0, 1.0, 0.02, 0).only_in([2, 4]),
		ControlSpec.choice(&"shear", "Pin connection", PackedStringArray(["Single shear", "Double shear"]), 1).only_in([1, 4]),
		ControlSpec.slider(&"theta", "Cut-plane angle θ", "°", 180.0 / PI, 0.0, 80.0, 1.0, 0.0, 0).only_in([3]),
		ControlSpec.choice(&"material", "Material", PackedStringArray(["Steel", "Aluminum"]), 0).only_in([0, 4]),
	]
	_rig.position = CENTER
	add_child(_rig)
	for part: MeshInstance3D in [_rod, _eye, _pin, _plates[0], _plates[1]]:
		part.material_override = _material(Color(0.7, 0.72, 0.75))
		_rig.add_child(part)
	_pin.material_override = _material(Color(0.85, 0.75, 0.4))
	for p: MeshInstance3D in _shear_planes:
		p.material_override = _material(Color(1.0, 0.25, 0.2, 0.75))
		_rig.add_child(p)
	_bearing_patch.material_override = _material(Color(1.0, 0.6, 0.1, 0.8))
	_rig.add_child(_bearing_patch)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.25, 1.4, 0.7)
	base.mesh = base_mesh
	base.position = Vector3(-1.35, -0.55, 0.0)
	base.material_override = _material(Color(0.35, 0.37, 0.4))
	_rig.add_child(base)
	for arrow: Arrow3D in [_load_arrow, _reaction_arrow, _sigma_arrow, _tau_arrow]:
		_rig.add_child(arrow)
	_plane.material_override = _material(Color(0.3, 0.9, 1.0, 0.45))
	_rig.add_child(_plane)
	_caption.position = Vector3(0.0, 0.55, 0.0)
	_rig.add_child(_caption)


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED if color.a < 1.0 else BaseMaterial3D.CULL_BACK
	return m


## Makes a part see-through so what is inside it (shear planes, bearing patch) shows.
static func _ghost(part: MeshInstance3D, on: bool) -> void:
	(part.material_override as StandardMaterial3D).albedo_color.a = 0.25 if on else 1.0


func _apply() -> void:
	model.load = value(&"P")
	model.rod_diameter = value(&"d")
	model.pin_diameter = value(&"dp")
	model.eye_thickness = value(&"t")
	model.double_shear = value(&"shear") == 1.0
	model.plane_angle = value(&"theta")
	model.material = _materials[int(value(&"material"))]

	var r: float = model.rod_diameter / 2.0 * DRAW
	var rp: float = model.pin_diameter / 2.0 * DRAW
	var t: float = model.eye_thickness * DRAW
	var pin_x: float = -ROD_LENGTH / 2.0
	_rod.mesh = _cylinder(r, ROD_LENGTH)
	_rod.rotation = Vector3(0.0, 0.0, PI / 2.0)
	var eye := BoxMesh.new()
	eye.size = Vector3(rp * 3.2, rp * 3.2, t)
	_eye.mesh = eye
	_eye.position = Vector3(pin_x, 0.0, 0.0)
	var plate_t: float = t * 0.6
	var pin_len: float = t + 2.0 * (plate_t + 0.01)
	_pin.mesh = _cylinder(rp, pin_len + 0.04)
	_pin.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	_pin.position = Vector3(pin_x, 0.0, 0.0)
	for i: int in 2:
		var plate := BoxMesh.new()
		plate.size = Vector3(0.5, rp * 3.2, plate_t)
		_plates[i].mesh = plate
		_plates[i].position = Vector3(pin_x - 0.17, 0.0, (1.0 if i == 0 else -1.0) * (t / 2.0 + 0.01 + plate_t / 2.0))
		_shear_planes[i].mesh = _cylinder(rp * 1.15, 0.006)
		_shear_planes[i].rotation = Vector3(PI / 2.0, 0.0, 0.0)
		_shear_planes[i].position = Vector3(pin_x, 0.0, (1.0 if i == 0 else -1.0) * (t / 2.0 + 0.005))
	_plates[1].visible = model.double_shear
	var patch := BoxMesh.new()
	patch.size = Vector3(0.006, rp * 2.0, t)
	_bearing_patch.mesh = patch
	_bearing_patch.position = Vector3(pin_x + rp + 0.004, 0.0, 0.0)

	var p_len: float = 0.15 + 0.4 * model.load / 60.0e3
	_load_arrow.place(Vector3(ROD_LENGTH / 2.0, 0.0, 0.0), Vector3(p_len, 0.0, 0.0))
	_load_arrow.label.text = "P = " + Units.force(model.load)
	_reaction_arrow.place(Vector3(-1.25, 0.25, 0.0), Vector3(-p_len, 0.0, 0.0))
	_reaction_arrow.label.text = "support reacts with P"

	# Oblique cut through the rod: an ellipse r x r/cos(theta) whose normal n is at theta to x.
	var theta: float = model.plane_angle
	var n := Vector3(cos(theta), sin(theta), 0.0)
	var along := Vector3(-sin(theta), cos(theta), 0.0)
	_plane.mesh = _cylinder(1.0, 0.004)
	var plane_center := Vector3(0.25, 0.0, 0.0)
	_plane.transform = Transform3D(Basis(along * r * 1.6 / cos(theta), n, Vector3.BACK * r * 1.6), plane_center)
	# Internal force on the left part's face is +P*x: normal part P*cos(theta) along n,
	# shear part P*sin(theta) along -along.
	var ref: float = maxf(model.normal_stress(), 1.0)
	var front := Vector3(0.0, 0.0, r + 0.06)
	_sigma_arrow.place(plane_center + front, n * 0.35 * model.oblique_normal_stress() / ref)
	_sigma_arrow.label.text = "σ_θ = " + Units.stress(model.oblique_normal_stress())
	_tau_arrow.place(plane_center + front, -along * 0.35 * model.oblique_shear_stress() / ref)
	_tau_arrow.label.text = "τ_θ = " + Units.stress(model.oblique_shear_stress())
	_caption.text = "Drawn %d× real size" % int(DRAW)


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 32
	return c


func _show_step() -> void:
	var s: int = step()
	for p: MeshInstance3D in _shear_planes:
		p.visible = s == 1
	_shear_planes[1].visible = s == 1 and model.double_shear
	_bearing_patch.visible = s == 2
	for plate: MeshInstance3D in _plates:
		_ghost(plate, s == 1 or s == 2)
	_ghost(_eye, s == 2)
	_ghost(_rod, s == 3)
	_plane.visible = s == 3
	_sigma_arrow.visible = s == 3
	_tau_arrow.visible = s == 3 and model.plane_angle > 0.001


func refresh() -> void:
	super()
	_show_step()


func set_control(id: StringName, new_value: float) -> void:
	super(id, new_value)
	_show_step()


func step_titles() -> PackedStringArray:
	return ["Normal stress", "Shear in the pin", "Bearing stress", "Stress on an oblique plane", "Design: allowable load"]


func lesson_text() -> String:
	var F := LessonFormat
	var P: String = Units.force(model.load)
	var t: String = ""
	match step():
		0:
			t += "[b]Stress[/b] is internal force per unit area. Cut the rod anywhere along its length: the part on one side pulls on the other with the force P, spread over the cross-section of area A.\n"
			t += F.equation("A = π·d²/4", "π × (%s)²/4" % Units.small_length(model.rod_diameter), Units.area(model.rod_area()))
			t += F.equation("σ = P/A", "%s / %s" % [P, Units.area(model.rod_area())], Units.stress(model.normal_stress()))
			t += "σ > 0 means [b]tension[/b] (the material is pulled apart), σ < 0 compression. Units: 1 Pa = 1 N/m², 1 MPa = 1 N/mm².\n"
			t += F.note("This is the average stress. It is uniform only away from the ends (Saint-Venant's principle) and when P acts along the centroidal axis.")
			t += F.note("In general the state of stress at a point needs six components on a small cube: σ_x, σ_y, σ_z and τ_xy, τ_yz, τ_zx (moment equilibrium of the cube forces τ_xy = τ_yx, etc.). A bar under axial load is the simplest case: only σ_x ≠ 0.")
			t += "Compared with the yield strength σ_Y = %s, the rod is at %s of its strength.\n" % [Units.stress(model.material.yield_strength), F.value("%.0f %%" % (100.0 * model.normal_stress() / model.material.yield_strength))]
			t += F.try_this("halve the diameter: the area drops to a quarter, so the stress becomes four times larger for the same P.")
		1:
			var n: int = 2 if model.double_shear else 1
			t += "The pin is loaded sideways. It tends to be cut along the red plane(s) between the eye and the clevis plates: that is [b]shear[/b]. The force on each plane acts [i]in[/i] the plane.\n"
			t += F.equation("A_pin = π·d_p²/4", "", Units.area(model.pin_area()))
			t += F.equation("τ_avg = P/(n·A_pin)", "%s / (%d × %s)" % [P, n, Units.area(model.pin_area())], Units.stress(model.pin_shear_stress()))
			t += "In [b]single shear[/b] one plane carries all of P (n = 1). With a [b]double-shear[/b] clevis the load is split between two planes (n = 2), halving the stress in the same pin.\n"
			t += F.note("τ_avg is an average: the real shear stress is not uniform over the pin section.")
			t += F.try_this("switch between single and double shear and watch τ halve or double.")
		2:
			t += "Where the pin presses on the eye of the rod, the contact stress is the [b]bearing stress[/b]. The real pressure is uneven around the hole, so we use the projected area t·d_p (orange patch).\n"
			t += F.equation("σ_b = P/(t·d_p)", "%s / (%s × %s)" % [P, Units.small_length(model.eye_thickness), Units.small_length(model.pin_diameter)], Units.stress(model.bearing_stress()))
			t += "A thin eye or a slender pin gives high bearing stress: the hole elongates or the edge tears.\n"
			t += F.try_this("thin the eye to 8 mm and watch σ_b rise; a thicker eye spreads the same force over more area.")
		3:
			var theta: float = model.plane_angle
			t += "Stress depends on the plane you look at. Cut the rod along a plane whose normal makes an angle θ with the axis (cyan ellipse). The same force P now has a component normal to the plane and one along it, acting on a larger area A/cos θ.\n"
			t += F.derivation("The cut has area A_θ = A/cos θ. The force P splits into F = P·cos θ normal to the cut and V = P·sin θ along it, so σ_θ = F/A_θ = (P/A)cos²θ and τ_θ = V/A_θ = (P/A)sin θ·cos θ.")
			t += F.equation("σ_θ = (P/A)·cos²θ", "%s × cos²(%s)" % [Units.stress(model.normal_stress()), Units.angle(theta)], Units.stress(model.oblique_normal_stress()))
			t += F.equation("τ_θ = (P/A)·sin θ·cos θ", "", Units.stress(model.oblique_shear_stress()))
			t += "The normal stress is largest at θ = 0 (σ_max = P/A); the shear stress is largest at θ = 45°: τ_max = P/(2A) = %s.\n" % Units.stress(model.normal_stress() / 2.0)
			t += F.note("This is why ductile bars in tension often fail along 45° cones: metals yield in shear.")
			t += F.try_this("set θ = 45° and check that σ_θ = τ_θ = P/(2A). Chapter 7 generalizes this to any stress state.")
		4:
			var sy: float = model.material.yield_strength
			var s_all: float = sy / DESIGN_FS
			var t_all: float = 0.5 * sy / DESIGN_FS
			var b_all: float = 1.5 * sy / DESIGN_FS
			var p_rod: float = model.allowable_load_rod(s_all)
			var p_pin: float = model.allowable_load_pin(t_all)
			var p_brg: float = model.allowable_load_bearing(b_all)
			var p_allow: float = minf(p_rod, minf(p_pin, p_brg))
			t += "A design must keep every stress below an [b]allowable stress[/b] = failure stress / factor of safety. With FS = %.1f and typical allowables for %s:\n" % [DESIGN_FS, model.material.display_name]
			t += F.equation("σ_all = σ_Y/FS", "", Units.stress(s_all))
			t += F.equation("τ_all = 0.5·σ_Y/FS", "", Units.stress(t_all))
			t += F.equation("σ_b,all = 1.5·σ_Y/FS", "", Units.stress(b_all))
			t += "Each failure mode gives an allowable load:\n"
			t += F.equation("rod:  σ_all·A", "", Units.force(p_rod))
			t += F.equation("pin:  τ_all·n·A_pin", "", Units.force(p_pin))
			t += F.equation("bearing:  σ_b,all·t·d_p", "", Units.force(p_brg))
			t += F.note("Allowable-stress design (ASD) divides the strength by FS. Load-and-resistance-factor design (LRFD) instead checks γ_D·P_D + γ_L·P_L ≤ φ·P_U, with load factors γ > 1 and a resistance factor φ < 1, so uncertain live loads get a larger margin than well-known dead loads.")
			t += "The connection is only as strong as its weakest mode: P_allow = %s. Applied P = %s → %s\n" % [F.value(Units.force(p_allow)), P, F.ok_or_fail(model.load <= p_allow, "safe" if model.load <= p_allow else "overloaded")]
			t += F.try_this("find the cheapest change that raises P_allow: bigger pin, thicker eye, or thicker rod? The weakest mode decides.")
	return t


func fill_figures(figures: FigureArea) -> void:
	var p_max: float = 60.0
	match step():
		0, 1, 2:
			var p := figures.plot(0)
			var probe: RodAndPin = _copy_model()
			probe.load = p_max / Units.KN
			var end_value: float = [probe.normal_stress(), probe.pin_shear_stress(), probe.bearing_stress()][step()]
			var now: float = [model.normal_stress(), model.pin_shear_stress(), model.bearing_stress()][step()]
			var names: PackedStringArray = ["σ = P/A", "τ = P/(n·A_pin)", "σ_b = P/(t·d_p)"]
			p.begin("%s grows linearly with P" % names[step()], "P (kN)", "stress (MPa)")
			p.line(PackedVector2Array([Vector2.ZERO, Vector2(p_max, end_value * Units.MPA)]), Color(1.0, 0.6, 0.4), 3.0)
			p.marker(Vector2(model.load * Units.KN, now * Units.MPA), Color(1, 0.85, 0.4), Units.stress(now))
			if step() == 0:
				p.hline(model.material.yield_strength * Units.MPA, Color(1, 0.4, 0.4), "σ_Y")
		3:
			var p := figures.plot(0)
			p.begin("Stresses on the cut vs. its angle θ", "θ (°)", "stress (MPa)")
			var sig := PackedVector2Array()
			var tau := PackedVector2Array()
			var probe: RodAndPin = _copy_model()
			for i: int in 91:
				probe.plane_angle = deg_to_rad(float(i))
				sig.append(Vector2(i, probe.oblique_normal_stress() * Units.MPA))
				tau.append(Vector2(i, probe.oblique_shear_stress() * Units.MPA))
			var s0: float = model.normal_stress() * Units.MPA
			p.line(sig, Color(1.0, 0.45, 0.35), 3.0)
			p.line(tau, Color(0.35, 0.85, 1.0), 3.0)
			p.vline(rad_to_deg(model.plane_angle), Color(1, 0.85, 0.4), "θ")
			p.marker(Vector2(45.0, s0 / 2.0), Color(0.35, 0.85, 1.0), "τ_max at 45°")


func _copy_model() -> RodAndPin:
	var c := RodAndPin.new()
	c.load = model.load
	c.rod_diameter = model.rod_diameter
	c.pin_diameter = model.pin_diameter
	c.eye_thickness = model.eye_thickness
	c.double_shear = model.double_shear
	c.material = model.material
	return c


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([CENTER + Vector3(-1.5, -0.5, 0.3), CENTER + Vector3(1.4, -0.5, 0.3),
			CENTER + Vector3(-1.5, 0.6, -0.3), CENTER + Vector3(1.4, 0.6, -0.3)])
