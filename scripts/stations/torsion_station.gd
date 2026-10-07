extends Station
## Chapter 3 - Torsion: a circular shaft fixed in a wall and twisted by a torque at its free
## end. Painted lines become helices; color and the end-face arrows show tau ~ rho.
## The shaft is drawn 2x real diameter; the twist is exaggerated.

const TWIST_SHADER: Shader = preload("res://shaders/twist.gdshader")
const DRAW: float = 2.0
const WALL_X: float = -1.4
const HEIGHT: float = 1.25
const FACE_ARROWS: int = 5

var shaft: TorsionShaft = TorsionShaft.new()

var _materials: Array[LabMaterial] = [LabMaterial.steel(), LabMaterial.aluminum()]
var _mesh: MeshInstance3D = MeshInstance3D.new()
var _shader: ShaderMaterial = ShaderMaterial.new()
var _wheel: MeshInstance3D = MeshInstance3D.new()  ## lever arm
var _ghost_lever: MeshInstance3D = MeshInstance3D.new()
var _torque: MomentArrow3D = MomentArrow3D.new(Color(0.95, 0.95, 1.0), 0.3, 0.018)
var _face_arrows: Array[Arrow3D] = []
var _phi_label: Label3D = Text3D.make(36)
var _shape_key: String = ""


func _init() -> void:
	chapter = 3
	title = "Torsion of circular shafts"
	_controls = [
		ControlSpec.slider(&"T", "Torque T", "kN·m", Units.KN, -10.0, 10.0, 0.1, 2.0e3),
		ControlSpec.slider(&"L", "Length L", "m", 1.0, 0.5, 2.8, 0.1, 1.5),
		ControlSpec.slider(&"do", "Outer diameter d_o", "mm", Units.MM, 20.0, 150.0, 1.0, 0.06, 0),
		ControlSpec.slider(&"di", "Inner diameter d_i", "mm", Units.MM, 0.0, 140.0, 1.0, 0.0, 0).only_in([3, 4]),
		ControlSpec.choice(&"material", "Material", PackedStringArray(["Steel", "Aluminum"]), 0),
		ControlSpec.slider(&"f", "Rotation speed f", "Hz", 1.0, 1.0, 60.0, 1.0, 30.0, 0).only_in([4]),
		ControlSpec.slider(&"exaggeration", "Twist drawn ×", "", 1.0, 1.0, 100.0, 1.0, 20.0, 0),
	]
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(0.3, 2.4, 1.2)
	wall.mesh = wall_mesh
	wall.position = Vector3(WALL_X - 0.15, 1.2, 0.0)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.35, 0.37, 0.4)
	wall.material_override = grey
	add_child(wall)
	_shader.shader = TWIST_SHADER
	_mesh.material_override = _shader
	_mesh.position = Vector3(WALL_X, HEIGHT, 0.0)
	add_child(_mesh)
	var lever_material := StandardMaterial3D.new()
	lever_material.albedo_color = Color(0.55, 0.45, 0.3)
	var ghost_material := StandardMaterial3D.new()
	ghost_material.albedo_color = Color(1, 1, 1, 0.25)
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for lever: MeshInstance3D in [_wheel, _ghost_lever]:
		var arm := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.6, 0.04)
		arm.mesh = box
		arm.position.y = 0.3
		arm.material_override = lever_material if lever == _wheel else ghost_material
		lever.add_child(arm)
		add_child(lever)
	_torque.rotation.y = PI / 2.0  # arrow's +Z axis along the shaft (+X)
	add_child(_torque)
	for i: int in FACE_ARROWS:
		var a := Arrow3D.new(Color(1.0, 0.55, 0.2), 0.008)
		a.label.visible = false
		_face_arrows.append(a)
		add_child(a)
	add_child(_phi_label)


func _apply() -> void:
	var r_o: float = value(&"do") / 2.0
	shaft.torque = value(&"T")
	shaft.length = value(&"L")
	shaft.outer_radius = r_o
	shaft.inner_radius = minf(value(&"di") / 2.0, r_o - 0.002)
	shaft.material = _materials[int(value(&"material"))]
	var key: String = "%.4f %.4f %.2f" % [shaft.outer_radius, shaft.inner_radius, shaft.length]
	if key != _shape_key:
		_shape_key = key
		var section: CrossSection = CircleSection.new(r_o * DRAW) if shaft.inner_radius <= 0.0 \
				else TubeSection.new(r_o * DRAW, shaft.inner_radius * DRAW)
		_mesh.mesh = BeamMeshBuilder.build(SectionProfile.for_section(section), shaft.length)
		_shader.set_shader_parameter("shaft_length", shaft.length)
		_shader.set_shader_parameter("outer_radius", r_o * DRAW)
	var drawn_twist: float = clampf(shaft.angle_of_twist() * value(&"exaggeration"), -PI, PI)
	_shader.set_shader_parameter("twist_end", drawn_twist)
	_shader.set_shader_parameter("stress_ratio", 1.0)  # full color at the surface, tau ~ rho inside

	var end_x: float = WALL_X + shaft.length
	# Lever on the free end turns with the end section; the ghost shows where it started.
	for lever: MeshInstance3D in [_wheel, _ghost_lever]:
		lever.position = Vector3(end_x + 0.03, HEIGHT, 0.0)
	_wheel.rotation.x = drawn_twist
	_torque.position = Vector3(end_x + 0.2, HEIGHT, 0.0)
	_torque.set_moment(signf(shaft.torque))
	_torque.label.text = "T = " + Units.moment(shaft.torque).replace("kN·m", "kN·m")
	# Shear stress on the end face along the vertical radius: tangential, length ~ rho.
	for i: int in FACE_ARROWS:
		var rho: float = shaft.outer_radius * (i + 1) / FACE_ARROWS
		var tau: float = shaft.shear_stress_at(rho)
		var at := Vector3(end_x + 0.004, HEIGHT + rho * DRAW, 0.0)
		_face_arrows[i].place(at, Vector3(0.0, 0.0, -0.35 * tau / maxf(shaft.max_shear_stress(), 1.0)))
	_phi_label.text = "φ = %s  (drawn ×%d)" % [Units.angle(shaft.angle_of_twist()), int(value(&"exaggeration"))]
	_phi_label.position = Vector3(end_x, HEIGHT + 0.85, 0.0)
	_torque.label.position = Vector3(0.0, -0.45, 0.0)


func _show_step() -> void:
	for a: Arrow3D in _face_arrows:
		a.visible = a.visible and step() >= 1


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
	return ["Deformation", "Torsion formula", "Angle of twist", "Hollow shafts", "Power & design"]


func lesson_text() -> String:
	var F := LessonFormat
	var J: String = "%.4f×10⁻⁶ m⁴" % (shaft.polar_moment() * 1e6)
	var t: String = ""
	match step():
		0:
			t += "A torque T twists the shaft. Each cross-section stays [b]plane and circular[/b] and simply rotates about the axis by an angle that grows from 0 at the wall to φ at the free end. Straight lines painted along the shaft turn into helices.\n"
			t += "A small square on the surface becomes a rhombus: the material is in [b]shear[/b]. The shear strain grows linearly with the distance ρ from the axis:\n"
			t += F.equation("γ = ρ·φ/L", "at the surface, ρ = c", Units.strain(shaft.shear_strain_at(shaft.outer_radius)))
			t += F.note("The twist is drawn exaggerated; real elastic twists are a few degrees.")
			t += F.try_this("reverse the torque (negative T): the helices lean the other way.")
		1:
			t += "In the elastic range τ = G·γ, so the shear stress is also proportional to ρ: zero on the axis, largest at the surface (colors and the arrows on the end face).\n"
			t += F.equation("τ = T·ρ/J", "torsion formula")
			t += F.equation("J = π·c⁴/2", "polar moment of inertia", J)
			t += F.equation("τ_max = T·c/J", "%s × %s / %s" % [Units.moment(absf(shaft.torque)), Units.small_length(shaft.outer_radius), J], Units.stress(shaft.max_shear_stress()))
			t += "Elements on the surface are in [b]pure shear[/b]; turned 45° they see tension and compression of the same size (chapter 7). That is why chalk (brittle) breaks along a 45° helix while steel (ductile) shears straight across.\n"
			t += F.try_this("double the diameter: J grows 16×, so τ_max drops to 1/8.")
		2:
			t += "Integrating the strain along the length gives the [b]angle of twist[/b]:\n"
			t += F.equation("φ = T·L/(J·G)", "%s × %s / (%s × %s)" % [Units.moment(absf(shaft.torque)), Units.length(shaft.length), J, Units.modulus(shaft.material.shear_modulus())], Units.angle(absf(shaft.angle_of_twist())))
			t += F.equation("G = E/(2(1 + ν))", "", Units.modulus(shaft.material.shear_modulus()))
			t += "φ grows linearly along the shaft from the wall. JG is the [b]torsional rigidity[/b]: the stiffer the shaft, the smaller the twist.\n"
			t += F.try_this("switch to aluminum: G is about one third of steel's, so the twist triples while the stresses stay the same.")
		3:
			var solid := TorsionShaft.new()
			solid.torque = shaft.torque
			solid.material = shaft.material
			solid.outer_radius = sqrt(shaft.outer_radius * shaft.outer_radius - shaft.inner_radius * shaft.inner_radius)
			t += "Material near the axis carries little stress (τ ∝ ρ), so it is wasted. A [b]hollow shaft[/b] removes it:\n"
			t += F.equation("J = π·(c₂⁴ − c₁⁴)/2", "", J)
			t += F.equation("τ_max = T·c₂/J", "", Units.stress(shaft.max_shear_stress()))
			t += F.equation("τ_min = T·c₁/J", "on the bore", Units.stress(absf(shaft.shear_stress_at(shaft.inner_radius))))
			t += "A solid shaft with the same amount of material (same area) would have radius %s and τ_max = %s.\n" % [Units.small_length(solid.outer_radius), F.value(Units.stress(solid.max_shear_stress()))]
			t += F.try_this("increase the inner diameter step by step: τ_max rises only slowly while the weight drops quickly.")
		4:
			var f: float = value(&"f")
			var tau_all: float = shaft.material.yield_strength / 2.0 / 2.0
			t += "Shafts transmit power. A torque turning at frequency f (rev/s) delivers\n"
			t += F.equation("P = 2π·f·T", "2π × %.0f Hz × %s" % [f, Units.moment(absf(shaft.torque))], Units.power(absf(shaft.power_at(f))))
			t += "Design: keep τ_max below an allowable shear stress. With the maximum-shear-stress criterion τ_Y = σ_Y/2 and FS = 2: τ_all = %s.\n" % Units.stress(tau_all)
			t += F.equation("FS = τ_Y/τ_max", "", Units.factor(shaft.factor_of_safety()))
			t += F.equation("c_min = (2T/(π·τ_all))^(1/3)", "solid shaft", Units.small_length(shaft.required_solid_radius(tau_all)))
			t += F.try_this("for a fixed power, a faster shaft needs less torque (T = P/2πf): that is why motors run fast and gearboxes slow down to high torque.")
	return t


func fill_figures(figures: FigureArea) -> void:
	match step():
		0:
			var p := figures.plot(0)
			p.begin("Shear strain across the radius", "ρ (mm)", "γ (×10⁻⁶)")
			p.line(_profile(func(rho: float) -> float: return shaft.shear_strain_at(rho) * 1e6), Color(0.95, 0.65, 0.3), 3.0)
		1, 3:
			var p := figures.plot(0)
			p.begin("Shear stress τ(ρ) across the diameter", "ρ (mm)", "τ (MPa)")
			p.line(_profile(func(rho: float) -> float: return signf(rho) * shaft.shear_stress_at(absf(rho)) * Units.MPA), Color(1.0, 0.55, 0.2), 3.0, true)
		2:
			var p := figures.plot(0)
			p.begin("Twist angle along the shaft", "x (m)", "φ (°)")
			p.line(PackedVector2Array([Vector2.ZERO, Vector2(shaft.length, rad_to_deg(shaft.angle_of_twist()))]), Color(0.6, 0.8, 1.0), 3.0)
		4:
			var p := figures.plot(0)
			p.begin("Power transmitted vs speed at this torque", "f (Hz)", "P (kW)")
			p.line(PackedVector2Array([Vector2.ZERO, Vector2(60.0, absf(shaft.power_at(60.0)) / 1e3)]), Color(0.5, 0.9, 0.5), 3.0)
			p.marker(Vector2(value(&"f"), absf(shaft.power_at(value(&"f"))) / 1e3), Color(1, 1, 1), "now")


## Samples f over -c..c (in mm) across the diameter.
func _profile(f: Callable) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c: float = shaft.outer_radius
	for i: int in 121:
		var rho: float = c * (2.0 * i / 120.0 - 1.0)
		pts.append(Vector2(rho * Units.MM, f.call(rho)))
	return pts


func view_direction() -> Vector3:
	return Vector3(0.9, 0.45, 1.0)  # from the free end's side, so the twist shows


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([Vector3(WALL_X - 0.3, 0.0, 0.5), Vector3(WALL_X + 3.0, 0.0, 0.5),
			Vector3(WALL_X - 0.3, 2.2, -0.5), Vector3(WALL_X + 3.0, 2.0, -0.5)])
