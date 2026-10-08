extends LabStation
## Lab 5 - Torsion on circular shafts: the load-angle plot at different lengths.
## Torsion and bending machine: the shaft is clamped at one support, a lever at the free end
## carries the weights, a dial gauge under the lever reads the twist (1 mm -> 1 degree).
## Shaft drawn 2.5x long and 6x thick; the twist is exaggerated.

const TWIST_SHADER: Shader = preload("res://shaders/twist.gdshader")
const ORIGIN := Vector3(-0.9, 1.0, 0.0)
const DRAW_LENGTH: float = 2.5
const DRAW_RADIUS: float = 6.0
const LOADS: Array[float] = [5.0, 10.0, 15.0]
const MATERIALS: PackedStringArray = ["Aluminum", "Steel"]
const PLOTS: int = 3

var shaft: TorsionShaft = TorsionShaft.new()
var _materials: Array[LabMaterial] = [LabMaterial.aluminum(), LabMaterial.steel()]
var _mesh: MeshInstance3D = MeshInstance3D.new()
var _shader: ShaderMaterial = ShaderMaterial.new()
var _lever: Node3D = Node3D.new()
var _hanger: MeshInstance3D = MeshInstance3D.new()
var _string: MeshInstance3D = MeshInstance3D.new()
var _clamp: MeshInstance3D = MeshInstance3D.new()
var _bearing: MeshInstance3D = MeshInstance3D.new()
var _label: Label3D = Text3D.make(30)
var _shape_key: String = ""


func _init() -> void:
	lab = 5
	title = "Torsion: load-angle plot at different lengths"
	handout = "Lab Handout N°5 - Torsion on Circular Shafts – The Load-Angle Plot at Different Lengths.docx"
	_controls = [
		ControlSpec.choice(&"material", "Shaft on the machine", MATERIALS, 0),
		ControlSpec.choice(&"which", "Test length", PackedStringArray(["L₁", "L₂"]), 0),
		ControlSpec.choice(&"load", "Weight on the hook", PackedStringArray(["5 N", "10 N", "15 N"]), 2),
		ControlSpec.slider(&"L1", "Length L₁", "mm", Units.MM, 100.0, 500.0, 10.0, 0.2, 0),
		ControlSpec.slider(&"L2", "Length L₂", "mm", Units.MM, 100.0, 500.0, 10.0, 0.4, 0),
		ControlSpec.slider(&"d", "Shaft diameter d", "mm", Units.MM, 3.0, 12.0, 0.1, 0.006, 1),
		ControlSpec.slider(&"r", "Lever arm (hook to shaft axis)", "mm", Units.MM, 50.0, 200.0, 1.0, 0.1, 0),
		ControlSpec.choice(&"readings", "Simulated readings", READINGS, 1).only_in([2, PLOTS, 4]),
		ControlSpec.slider(&"exaggeration", "Twist drawn ×", "", 1.0, 1.0, 20.0, 1.0, 5.0, 0),
	]
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.3, 0.33, 0.38)
	for z: float in [-0.12, 0.12]:
		var guide := MeshInstance3D.new()
		var g := BoxMesh.new()
		g.size = Vector3(1.6, 0.04, 0.04)
		guide.mesh = g
		guide.material_override = steel
		guide.position = ORIGIN + Vector3(0.75, -0.25, z)
		add_child(guide)
	for support: MeshInstance3D in [_clamp, _bearing]:
		var b := BoxMesh.new()
		b.size = Vector3(0.08, 0.3, 0.3)
		support.mesh = b
		support.material_override = steel
		add_child(support)
	_clamp.position = ORIGIN + Vector3(-0.04, -0.1, 0.0)
	_shader.shader = TWIST_SHADER
	_mesh.material_override = _shader
	_mesh.position = ORIGIN
	add_child(_mesh)
	add_child(_lever)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.45, 0.3)
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.03, 0.03, 0.5)
	arm.mesh = arm_mesh
	arm.material_override = wood
	arm.position = Vector3(0.0, 0.0, 0.25)
	_lever.add_child(arm)
	var weight := CylinderMesh.new()
	weight.top_radius = 0.05
	weight.bottom_radius = 0.05
	weight.height = 0.1
	_hanger.mesh = weight
	_hanger.material_override = steel
	add_child(_hanger)
	var string := BoxMesh.new()
	string.size = Vector3(0.006, 0.2, 0.006)
	_string.mesh = string
	_string.material_override = steel
	add_child(_string)
	_label.position = ORIGIN + Vector3(0.6, 0.45, 0.0)
	add_child(_label)


func _material() -> LabMaterial:
	return _materials[int(value(&"material"))]


func _length(which: int) -> float:
	return value(&"L1") if which == 0 else value(&"L2")


## A shaft of the chosen diameter, material and length carrying weight F at the lever.
func _shaft(material: LabMaterial, length: float, force: float) -> TorsionShaft:
	var s := TorsionShaft.new()
	s.material = material
	s.length = length
	s.outer_radius = value(&"d") / 2.0
	s.torque = force * value(&"r")
	return s


## Dial reading of the twist [rad] (1 mm on the dial = 1 degree), as recorded.
func _reading(material_index: int, which: int, load_index: int) -> float:
	var phi: float = _shaft(_materials[material_index], _length(which), LOADS[load_index]).angle_of_twist()
	return deg_to_rad(reading(rad_to_deg(phi), material_index * 100 + which * 10 + load_index, 0.04, 0.01))


func _fit(material_index: int, which: int) -> LinearFit:
	var pts := PackedVector2Array()
	for i: int in 3:
		pts.append(Vector2(rad_to_deg(_reading(material_index, which, i)), LOADS[i]))
	return LinearFit.of(pts, true)


func _apply() -> void:
	var which: int = int(value(&"which"))
	shaft = _shaft(_material(), _length(which), LOADS[int(value(&"load"))])
	var drawn_length: float = shaft.length * DRAW_LENGTH
	var drawn_radius: float = shaft.outer_radius * DRAW_RADIUS
	var key: String = "%.4f %.4f" % [drawn_length, drawn_radius]
	if key != _shape_key:
		_shape_key = key
		_mesh.mesh = BeamMeshBuilder.build(SectionProfile.for_section(CircleSection.new(drawn_radius)), drawn_length)
	var phi: float = shaft.angle_of_twist() * value(&"exaggeration")
	_shader.set_shader_parameter("shaft_length", drawn_length)
	_shader.set_shader_parameter("outer_radius", drawn_radius)
	_shader.set_shader_parameter("twist_start", 0.0)
	_shader.set_shader_parameter("twist_end", phi)  # same sense as the lever: the weight pulls its tip down
	_shader.set_shader_parameter("stress_ratio", shaft.max_shear_stress() / (shaft.material.yield_strength / 2.0))
	_bearing.position = ORIGIN + Vector3(drawn_length - 0.06, -0.1, 0.0)
	_lever.position = ORIGIN + Vector3(drawn_length + 0.02, 0.0, 0.0)
	_lever.rotation.x = phi
	var tip: Vector3 = _lever.position + Vector3(0.0, -sin(phi) * 0.48, cos(phi) * 0.48)
	_hanger.position = tip + Vector3(0.0, -0.25, 0.0)
	_string.position = tip + Vector3(0.0, -0.1, 0.0)
	_label.text = "%s, L = %s, F = %s\nT = F·r = %s N·m\ntwist φ = %s (drawn ×%d)" % [shaft.material.display_name, Units.mm(shaft.length, 0),
			Units.newtons(LOADS[int(value(&"load"))], 0), Units.fixed(shaft.torque, 2), Units.degrees(shaft.angle_of_twist()), int(value(&"exaggeration"))]


func _show_step() -> void:
	_apply()


func step_titles() -> PackedStringArray:
	return ["Objective and theory", "The machine", "Readings tables", "Load-angle plots", "What the slope means", "Report questions"]


func lesson_text() -> String:
	var F := LessonFormat
	var t: String = ""
	match step():
		0:
			t += "Goal: twist circular shafts of aluminum and steel by hanging weights on a lever, show that the [b]twist angle is proportional to the load[/b], and find how the shaft's length changes it.\n"
			t += "A torque T twists each cross-section about the axis; the material is in [b]shear[/b], with τ growing linearly from the center (τ = Tρ/J, chapter 3). In the elastic range, Hooke's law in shear (τ = Gγ) gives the angle of twist:\n"
			t += F.derivation("A line on the surface tilts by γ_max = cφ/L. With τ_max = Gγ_max and τ_max = Tc/J: Tc/J = Gcφ/L, so φ = TL/(JG).")
			t += F.equation("φ = T·L/(J·G)", "J = πd⁴/32 (solid shaft), G = shear modulus")
			t += F.equation("T = F·r", "weight F at lever arm r")
			t += "So φ = (r·L/(J·G))·F: for a given shaft and length, φ is a straight line through the origin in F.\n"
			t += F.note("Default sizes here (d = 6 mm, r = 100 mm, L = 200 and 400 mm) are placeholders: set the sliders to your shafts and machine.")
			t += handout_note()
		1:
			t += "Procedure, as in the handout: slide the bar through support 2 to 3 and tighten the bolts of 6; set the lever 5 at 90° to the guides 4; move supports 2 and 3 to the test length and record it; place the dial gauge on the lever's central notch at 25 mm; hang the hook 11 in the lever's end notch and add 5, 10, 15 N.\n"
			t += "The dial gauge follows the lever, which turns with the shaft's free end, so its displacement measures the twist. On this machine 1 mm on the dial corresponds to 1°.\n"
			t += F.equation("now: T = F·r", "%s × %s" % [Units.newtons(LOADS[int(value(&"load"))], 0), Units.mm(value(&"r"), 0)], "%s N·m" % Units.fixed(shaft.torque, 3))
			t += F.equation("J = πd⁴/32", "", "%s mm⁴" % Units.fixed(shaft.polar_moment() * 1e12, 1))
			t += F.equation("φ = TL/(JG)", "", Units.degrees(shaft.angle_of_twist()))
			t += F.equation("τ_max = T·c/J", "", Units.stress(shaft.max_shear_stress()))
			t += "τ_max stays well below the shear yield stress, so the test is elastic and the shaft returns to zero when unloaded: check that the dial comes back to 25 mm.\n"
			t += F.try_this("change the test length and the weight and watch the lever turn (exaggerated). Twice as long: twice the twist.")
		2:
			for mi: int in 2:
				t += F.section("%s (d = %s)" % [_materials[mi].display_name, Units.mm(value(&"d"), 1)])
				var rows: Array[PackedStringArray] = []
				for li: int in 3:
					rows.append(PackedStringArray([Units.fixed(LOADS[li], 0), Units.fixed(rad_to_deg(_reading(mi, 0, li)), 2),
							Units.fixed(LOADS[li], 0), Units.fixed(rad_to_deg(_reading(mi, 1, li)), 2)]))
				t += F.table(["Load (N), L = %s" % Units.mm(_length(0), 0), "Twist (°)", "Load (N), L = %s" % Units.mm(_length(1), 0), "Twist (°)"], rows)
			t += F.note("Use the same two lengths for both materials so the comparisons are fair.")
		PLOTS:
			t += "Plot the load (y) against the twist angle (x) for each material and length, and fit a line through the origin:\n"
			for mi: int in 2:
				for li: int in 2:
					var fit: LinearFit = _fit(mi, li)
					t += F.equation("%s, L = %s" % [_materials[mi].display_name, Units.mm(_length(li), 0)], "F = %s·φ" % Units.fixed(fit.slope, 3), "R² = %s" % Units.fixed(fit.r_squared, 4))
			t += "The points lie on straight lines through the origin: the twist is proportional to the load, as φ = TL/(JG) predicts.\n"
		4:
			t += "Rewrite φ = F·r·L/(J·G) as F = (J·G/(r·L))·φ. The slope of the load-angle line is the shaft's [b]torsional stiffness seen at the hook[/b]:\n"
			t += F.equation("slope = J·G/(r·L)", "N per radian (× π/180 for N per degree)")
			t += "So from a measured slope you can get the material's shear modulus:\n"
			t += F.equation("G = slope·r·L/J", "")
			var rows: Array[PackedStringArray] = []
			for mi: int in 2:
				for li: int in 2:
					var s: TorsionShaft = _shaft(_materials[mi], _length(li), 0.0)
					var slope_rad: float = _fit(mi, li).slope * 180.0 / PI
					rows.append(PackedStringArray([_materials[mi].display_name, Units.mm(_length(li), 0), Units.fixed(_fit(mi, li).slope, 3),
							Units.modulus(s.modulus_from_slope(slope_rad, value(&"r"))), Units.modulus(_materials[mi].shear_modulus())]))
			t += F.table(["Material", "L", "Slope (N/°)", "G measured", "G handbook"], rows)
			t += "• [b]Material[/b]: steel's slope is about 3 times aluminum's because G_steel ≈ 77 GPa vs G_Al ≈ 26 GPa: steel resists twisting more.\n"
			t += "• [b]Length[/b]: the slope is proportional to 1/L. Doubling the length halves the stiffness and doubles the twist for the same load. Each unit length of shaft twists by the same amount (φ/L = T/(JG)); a longer shaft just adds them up.\n"
			t += "• Diameter matters most: J ∝ d⁴, so a 20 % thicker shaft is about twice as stiff.\n"
		5:
			t += F.question("Plot the load-angle graphs and fit lines.", "Four plots (2 aluminum, 2 steel), load vs angle, with the fitted equation displayed (step 4). A line through the origin is the physically expected model.")
			t += F.question("From theory, the link between twist angle and load? What does the slope represent?", "φ = F·r·L/(J·G): linear in F. The slope of F vs φ is J·G/(r·L), the torsional stiffness at the hook; with r, L and J known it gives G (step 5).")
			t += F.question("Which material is more resistant to twisting?", "The one with the steeper load-angle line for the same length and diameter: steel, because its shear modulus is about three times larger.")
			t += F.question("Effect of changing the length?", "Longer shaft, larger twist for the same load (φ ∝ L), so a smaller slope (∝ 1/L). The maximum shear stress τ = Tc/J does not depend on L: a longer shaft twists more but is not more stressed.")
	return t


func fill_figures(figures: FigureArea) -> void:
	if step() < PLOTS or step() == 5:
		return
	var colors: Array[Color] = [Color(0.5, 0.85, 1.0), Color(1.0, 0.65, 0.35)]
	for mi: int in 2:
		var p := figures.plot(mi)
		p.begin("Load-angle, %s" % _materials[mi].display_name, "twist angle (°)", "load (N)")
		for li: int in 2:
			var fit: LinearFit = _fit(mi, li)
			var x_end: float = rad_to_deg(_reading(mi, li, 2)) * 1.1
			p.line(PackedVector2Array([Vector2.ZERO, Vector2(x_end, fit.slope * x_end)]), colors[li], 2.0)
			for i: int in 3:
				p.marker(Vector2(rad_to_deg(_reading(mi, li, i)), LOADS[i]), colors[li], ("L = %s" % Units.mm(_length(li), 0)) if i == 2 else "")


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([ORIGIN + Vector3(-0.2, -0.6, 0.6), ORIGIN + Vector3(1.4, 0.6, 0.0)])


func view_direction() -> Vector3:
	return Vector3(0.45, 0.35, 1.0)
