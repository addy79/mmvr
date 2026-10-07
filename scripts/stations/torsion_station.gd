extends Station
## Chapter 3 - Torsion: a circular shaft fixed in a wall and twisted by a torque at its free
## end. Painted lines become helices; color and the end-face arrows show tau ~ rho.
## The shaft is drawn 2x real diameter; the twist is exaggerated.

const TWIST_SHADER: Shader = preload("res://shaders/twist.gdshader")
const DRAW: float = 2.0
const WALL_X: float = -1.4
const HEIGHT: float = 1.25
const FACE_ARROWS: int = 5

const INDETERMINATE: int = 5
const THIN_WALLED: int = 6

var shaft: TorsionShaft = TorsionShaft.new()
var held: IndeterminateShaft = IndeterminateShaft.new()
var thin: ThinWalledShaft = ThinWalledShaft.new()

var _materials: Array[LabMaterial] = [LabMaterial.steel(), LabMaterial.aluminum()]
var _mesh: MeshInstance3D = MeshInstance3D.new()
var _shader: ShaderMaterial = ShaderMaterial.new()
var _wheel: MeshInstance3D = MeshInstance3D.new()  ## lever arm
var _ghost_lever: MeshInstance3D = MeshInstance3D.new()
var _torque: MomentArrow3D = MomentArrow3D.new(Color(0.95, 0.95, 1.0), 0.3, 0.018)
var _face_arrows: Array[Arrow3D] = []
var _phi_label: Label3D = Text3D.make(36)
var _shape_key: String = ""
var _mesh2: MeshInstance3D = MeshInstance3D.new()
var _shader2: ShaderMaterial = ShaderMaterial.new()
var _far_wall: MeshInstance3D = MeshInstance3D.new()


func _init() -> void:
	chapter = 3
	title = "Torsion of circular shafts"
	_controls = [
		ControlSpec.slider(&"T", "Torque T", "kN·m", Units.KN, -10.0, 10.0, 0.1, 2.0e3),
		ControlSpec.slider(&"L", "Length L", "m", 1.0, 0.5, 2.8, 0.1, 1.5),
		ControlSpec.slider(&"do", "Outer diameter d_o", "mm", Units.MM, 20.0, 150.0, 1.0, 0.06, 0).only_in([0, 1, 2, 3, 4, INDETERMINATE]),
		ControlSpec.slider(&"di", "Inner diameter d_i", "mm", Units.MM, 0.0, 140.0, 1.0, 0.0, 0).only_in([3, 4]),
		ControlSpec.choice(&"material", "Material", PackedStringArray(["Steel", "Aluminum"]), 0),
		ControlSpec.slider(&"f", "Rotation speed f", "Hz", 1.0, 1.0, 60.0, 1.0, 30.0, 0).only_in([4]),
		ControlSpec.slider(&"exaggeration", "Twist drawn ×", "", 1.0, 1.0, 100.0, 1.0, 20.0, 0),
		ControlSpec.slider(&"a", "Torque position L₁/L", "", 1.0, 0.1, 0.9, 0.05, 0.4).only_in([INDETERMINATE]),
		ControlSpec.slider(&"d2", "Diameter of BC", "mm", Units.MM, 20.0, 150.0, 1.0, 0.04, 0).only_in([INDETERMINATE]),
		ControlSpec.slider(&"bw", "Box width b", "mm", Units.MM, 40.0, 200.0, 1.0, 0.1, 0).only_in([THIN_WALLED]),
		ControlSpec.slider(&"bh", "Box depth h", "mm", Units.MM, 30.0, 200.0, 1.0, 0.06, 0).only_in([THIN_WALLED]),
		ControlSpec.slider(&"bt", "Wall thickness t", "mm", Units.MM, 2.0, 15.0, 0.5, 0.005, 1).only_in([THIN_WALLED]),
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
	_shader2.shader = TWIST_SHADER
	_mesh.material_override = _shader
	_mesh2.material_override = _shader2
	_mesh.position = Vector3(WALL_X, HEIGHT, 0.0)
	add_child(_mesh)
	add_child(_mesh2)
	var far := BoxMesh.new()
	far.size = Vector3(0.2, 0.9, 0.7)
	_far_wall.mesh = far
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 0.55, 0.6, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_far_wall.material_override = glass  # see-through so the shaft stays visible
	add_child(_far_wall)
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
	match step():
		INDETERMINATE:
			_apply_held()
		THIN_WALLED:
			_apply_thin()
		_:
			_apply_free()
	_far_wall.visible = step() == INDETERMINATE
	_mesh2.visible = step() == INDETERMINATE
	for a: Arrow3D in _face_arrows:
		a.visible = a.visible and step() >= 1 and step() <= 4


func _build(mesh: MeshInstance3D, shader: ShaderMaterial, section: CrossSection, length: float, at_x: float) -> void:
	mesh.mesh = BeamMeshBuilder.build(SectionProfile.for_section(section), length)
	mesh.position = Vector3(at_x, HEIGHT, 0.0)
	shader.set_shader_parameter("shaft_length", length)
	shader.set_shader_parameter("stress_ratio", 1.0)


## Lever and torque arrow at x, the lever turned by the drawn angle.
func _place_lever(x: float, drawn: float, torque: float) -> void:
	for lever: MeshInstance3D in [_wheel, _ghost_lever]:
		lever.position = Vector3(x + 0.03, HEIGHT, 0.0)
	_wheel.rotation.x = drawn
	_torque.position = Vector3(x + 0.2, HEIGHT, 0.0)
	_torque.set_moment(signf(torque))
	_torque.label.text = "T = " + Units.moment(torque)
	_torque.label.position = Vector3(0.0, -0.45, 0.0)
	_phi_label.position = Vector3(x, HEIGHT + 0.85, 0.0)


## Shaft fixed at both ends, torque at B: two segments twisting up to phi_B and back.
func _apply_held() -> void:
	held.torque = value(&"T")
	held.length_1 = value(&"a") * value(&"L")
	held.length_2 = value(&"L") - held.length_1
	held.radius_1 = value(&"do") / 2.0
	held.radius_2 = value(&"d2") / 2.0
	held.material = _materials[int(value(&"material"))]
	var key: String = "held %.4f %.4f %.3f %.3f" % [held.radius_1, held.radius_2, held.length_1, held.length_2]
	if key != _shape_key:
		_shape_key = key
		_build(_mesh, _shader, CircleSection.new(held.radius_1 * DRAW), held.length_1, WALL_X)
		_build(_mesh2, _shader2, CircleSection.new(held.radius_2 * DRAW), held.length_2, WALL_X + held.length_1)
		var r_max: float = maxf(held.radius_1, held.radius_2) * DRAW
		_shader.set_shader_parameter("outer_radius", r_max)
		_shader2.set_shader_parameter("outer_radius", r_max)
	var drawn: float = clampf(held.rotation_b() * value(&"exaggeration"), -PI, PI)
	_shader.set_shader_parameter("twist_start", 0.0)
	_shader.set_shader_parameter("twist_end", drawn)
	_shader2.set_shader_parameter("twist_start", drawn)
	_shader2.set_shader_parameter("twist_end", 0.0)
	_far_wall.position = Vector3(WALL_X + value(&"L") + 0.1, HEIGHT, 0.0)
	_place_lever(WALL_X + held.length_1, drawn, held.torque)
	_phi_label.text = "φ_B = %s  (drawn ×%d)" % [Units.angle(held.rotation_b()), int(value(&"exaggeration"))]
	for a: Arrow3D in _face_arrows:
		a.visible = false


## Thin-walled box shaft: constant shear flow around the wall.
func _apply_thin() -> void:
	thin.torque = value(&"T")
	thin.length = value(&"L")
	thin.width = value(&"bw")
	thin.depth = value(&"bh")
	thin.thickness = value(&"bt")
	thin.material = _materials[int(value(&"material"))]
	var key: String = "thin %.4f %.4f %.4f %.3f" % [thin.width, thin.depth, thin.thickness, thin.length]
	if key != _shape_key:
		_shape_key = key
		_build(_mesh, _shader, BoxSection.new(thin.width * DRAW, thin.depth * DRAW, thin.thickness * DRAW), thin.length, WALL_X)
		_shader.set_shader_parameter("outer_radius", Vector2(thin.width, thin.depth).length() / 2.0 * DRAW)
	var drawn: float = clampf(thin.angle_of_twist() * value(&"exaggeration"), -PI, PI)
	_shader.set_shader_parameter("twist_start", 0.0)
	_shader.set_shader_parameter("twist_end", drawn)
	_place_lever(WALL_X + thin.length, drawn, thin.torque)
	_phi_label.text = "φ = %s, τ = %s  (drawn ×%d)" % [Units.angle(thin.angle_of_twist()), Units.stress(thin.shear_stress()), int(value(&"exaggeration"))]
	for a: Arrow3D in _face_arrows:
		a.visible = false


## Cantilever shaft (steps 1-5).
func _apply_free() -> void:
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
		_build(_mesh, _shader, section, shaft.length, WALL_X)
		_shader.set_shader_parameter("outer_radius", r_o * DRAW)
	var drawn_twist: float = clampf(shaft.angle_of_twist() * value(&"exaggeration"), -PI, PI)
	_shader.set_shader_parameter("twist_start", 0.0)
	_shader.set_shader_parameter("twist_end", drawn_twist)
	var end_x: float = WALL_X + shaft.length
	# Lever on the free end turns with the end section; the ghost shows where it started.
	_place_lever(end_x, drawn_twist, shaft.torque)
	# Shear stress on the end face along the vertical radius: tangential, length ~ rho.
	for i: int in FACE_ARROWS:
		var rho: float = shaft.outer_radius * (i + 1) / FACE_ARROWS
		var tau: float = shaft.shear_stress_at(rho)
		var at := Vector3(end_x + 0.004, HEIGHT + rho * DRAW, 0.0)
		_face_arrows[i].place(at, Vector3(0.0, 0.0, -0.35 * tau / maxf(shaft.max_shear_stress(), 1.0)))
	_phi_label.text = "φ = %s  (drawn ×%d)" % [Units.angle(shaft.angle_of_twist()), int(value(&"exaggeration"))]


func set_step(index: int) -> void:
	_step = clampi(index, 0, step_titles().size() - 1)
	_apply()
	changed.emit()


func step_titles() -> PackedStringArray:
	return ["Deformation", "Torsion formula", "Angle of twist", "Hollow shafts", "Power & design",
			"Statically indeterminate", "Thin-walled shafts"]


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
			t += F.derivation("Plane sections rotate rigidly, so γ = ρφ/L; elastic: τ = Gγ = (Gφ/L)ρ. Equilibrium: T = ∫ρ·τ dA = (Gφ/L)∫ρ² dA = (Gφ/L)·J. Eliminating Gφ/L gives τ = Tρ/J and φ = TL/(JG).")
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
			var solid: TorsionShaft = shaft.equal_area_solid()
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
		INDETERMINATE:
			t += "Now the shaft is fixed to walls at [b]both ends[/b] and the torque T acts at B. Statics gives T_A + T_C = T: one equation, two unknowns. [b]Compatibility[/b]: the rotation of B computed from either side must be the same, i.e. the two twists cancel:\n"
			t += F.equation("φ_AB + φ_BC = T_A·g₁ − T_C·g₂ = 0", "g_i = L_i/(J_i·G)")
			t += F.equation("T_A = T·g₂/(g₁ + g₂)", "", Units.moment(held.torque_a()))
			t += F.equation("T_C = T·g₁/(g₁ + g₂)", "", Units.moment(held.torque_c()))
			t += F.equation("τ_max,AB = T_A·c₁/J₁", "", Units.stress(held.max_shear_1()))
			t += F.equation("τ_max,BC = T_C·c₂/J₂", "", Units.stress(held.max_shear_2()))
			t += F.equation("φ_B = T_A·g₁", "", Units.angle(held.rotation_b()))
			t += "The stiffer segment (short, thick) carries most of the torque. The twist angle rises from A to B and falls back to zero at C (figure).\n"
			t += F.try_this("move B toward A: the short segment AB becomes very stiff and takes almost all of T.")
		THIN_WALLED:
			t += "For a hollow section of any shape with a thin wall, assume the shear stress is uniform through the thickness and parallel to the wall. Equilibrium of a piece of wall shows that the [b]shear flow[/b] q = τ·t is the same all the way around the closed section:\n"
			t += F.derivation("T = ∮ q·r ds = q·∮ r ds = 2q·𝒜, where 𝒜 is the area enclosed by the wall's centerline (r ds is twice the area of the thin triangle from the center to ds).")
			t += F.equation("𝒜 = (b − t)(h − t)", "", Units.area(thin.enclosed_area()))
			t += F.equation("q = T/(2𝒜)", "", "%.1f kN/m" % (thin.shear_flow() / 1e3))
			t += F.equation("τ = T/(2t·𝒜)", "", Units.stress(thin.shear_stress()))
			t += F.equation("φ = (T·L/(4𝒜²G))·∮ds/t", "∮ds/t = 2(a + b)/t", Units.angle(thin.angle_of_twist()))
			t += F.note("Where the wall is thinner, τ is larger (q constant). Open thin sections (a slit tube, an I-beam) are far weaker in torsion: they cannot carry a circulating shear flow.")
			t += F.try_this("halve the wall thickness: τ doubles and φ doubles; enlarging the enclosed area is much more effective.")
	return t


func fill_figures(figures: FigureArea) -> void:
	match step():
		INDETERMINATE:
			var l1: float = held.length_1
			var l: float = l1 + held.length_2
			var pt := figures.plot(0)
			pt.begin("Internal torque T(x)", "x (m)", "T (kN·m)")
			pt.line(PackedVector2Array([Vector2(0.0, held.torque_a() * Units.KN), Vector2(l1, held.torque_a() * Units.KN),
					Vector2(l1, -held.torque_c() * Units.KN), Vector2(l, -held.torque_c() * Units.KN)]), Color(1.0, 0.6, 0.3), 3.0, true)
			var pp := figures.plot(1)
			pp.begin("Rotation of the sections φ(x)", "x (m)", "φ (°)")
			pp.line(PackedVector2Array([Vector2.ZERO, Vector2(l1, rad_to_deg(held.rotation_b())), Vector2(l, 0.0)]), Color(0.6, 0.8, 1.0), 3.0)
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
