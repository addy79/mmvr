extends Station
## Chapter 8 - Principal stresses under a given loading: a sign-post pipe fixed in a wall and
## loaded at its end by a transverse force P, a torque T and an axial force N. The student
## picks a point on the critical (fixed) section and sees its stress element, principal
## stresses, Mohr's circle and the yield check.

const WALL_X: float = -1.4
const AXIS_Y: float = 1.3
const POINT_NAMES: PackedStringArray = ["Top", "Bottom", "Front", "Back"]
const MATERIAL_NAMES: PackedStringArray = ["Steel", "Aluminum"]
const SECTION_X: float = 0.12   ## the inspected section, just out of the wall [m]

var model: CombinedLoading = CombinedLoading.new()

var _materials: Array[LabMaterial] = [LabMaterial.steel(), LabMaterial.aluminum()]
var _beam: CantileverBeam = CantileverBeam.new(1.2, 5.0e3, 1.2, TubeSection.new(0.05, 0.04), LabMaterial.steel())
var _data: BeamDataTexture = BeamDataTexture.new()
var _pipe: BeamView = BeamView.new(_data)
var _pipe_frame: Node3D = Node3D.new()
var _p_arrow: Arrow3D = Arrow3D.new(Color(0.95, 0.95, 1.0), 0.018)
var _n_arrow: Arrow3D = Arrow3D.new(Color(0.95, 0.85, 0.5), 0.018)
var _torque: MomentArrow3D = MomentArrow3D.new(Color(0.6, 0.9, 1.0), 0.2, 0.016)
var _sign: MeshInstance3D = MeshInstance3D.new()
var _ring: MeshInstance3D = MeshInstance3D.new()
var _point: MeshInstance3D = MeshInstance3D.new()
var _element: StressElementView = StressElementView.new()
var _element_label: Label3D = Text3D.make(34)


func _init() -> void:
	chapter = 8
	title = "Principal stresses under a given loading"
	_controls = [
		ControlSpec.slider(&"P", "Transverse load P", "kN", Units.KN, 0.0, 20.0, 0.1, 5.0e3, 1),
		ControlSpec.slider(&"T", "Torque T", "kN·m", Units.KN, -5.0, 5.0, 0.05, 1.5e3),
		ControlSpec.slider(&"N", "Axial force N", "kN", Units.KN, -150.0, 150.0, 1.0, 0.0, 0),
		ControlSpec.slider(&"L", "Arm length L", "m", 1.0, 0.5, 2.0, 0.05, 1.2),
		ControlSpec.slider(&"do", "Outer diameter", "mm", Units.MM, 60.0, 200.0, 1.0, 0.1, 0),
		ControlSpec.slider(&"wall", "Wall thickness", "mm", Units.MM, 3.0, 30.0, 0.5, 0.01, 1),
		ControlSpec.choice(&"point", "Point on the section", POINT_NAMES, 0).only_in([2, 3, 4]),
		ControlSpec.choice(&"orientation", "Element drawn", PackedStringArray(["x-s axes", "principal"]), 0).only_in([2, 3]),
		ControlSpec.choice(&"material", "Material", MATERIAL_NAMES, 0).only_in([4]),
	]
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(0.3, 2.6, 1.4)
	wall.mesh = wall_mesh
	wall.position = Vector3(WALL_X - 0.15, 1.3, 0.0)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.35, 0.37, 0.4)
	wall.material_override = grey
	add_child(wall)
	add_child(_pipe_frame)
	_pipe_frame.add_child(_pipe)
	for node: Node3D in [_p_arrow, _n_arrow, _torque, _sign, _ring, _point, _element, _element_label]:
		add_child(node)
	_torque.rotation.y = PI / 2.0  # moment about the pipe axis (+X)
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(0.02, 0.45, 0.7)
	_sign.mesh = sign_mesh
	var sign_material := StandardMaterial3D.new()
	sign_material.albedo_color = Color(0.2, 0.55, 0.3)
	_sign.material_override = sign_material
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1.0, 0.85, 0.3, 0.35)
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = ring_material
	var dot := SphereMesh.new()
	dot.radius = 0.03
	dot.height = 0.06
	_point.mesh = dot
	var dot_material := StandardMaterial3D.new()
	dot_material.albedo_color = Color(1.0, 0.3, 0.3)
	dot_material.emission_enabled = true
	dot_material.emission = Color(1.0, 0.3, 0.3)
	_point.material_override = dot_material
	_element.position = Vector3(WALL_X + 0.75, AXIS_Y + 0.95, 0.25)
	_element_label.position = _element.position + Vector3(0.0, -0.45, 0.0)


func point() -> CombinedLoading.Point:
	return int(value(&"point")) as CombinedLoading.Point


func _apply() -> void:
	var r_o: float = value(&"do") / 2.0
	model.load = value(&"P")
	model.torque = value(&"T")
	model.axial_load = value(&"N")
	model.arm = value(&"L")
	model.outer_radius = r_o
	model.inner_radius = maxf(r_o - value(&"wall"), 0.0)
	model.material = _materials[int(value(&"material"))]
	# The pipe drawn as a cantilever beam colored by its bending stress.
	_beam.length = model.arm
	_beam.load = model.load
	_beam.load_position = model.arm
	_beam.section = TubeSection.new(r_o, model.inner_radius) if model.inner_radius > 0.0 else CircleSection.new(r_o)
	_beam.material = model.material
	_data.write(_beam)
	_pipe.set_shape(_beam.section, model.arm)
	_pipe.set_drawn_deflection(minf(absf(_beam.max_deflection()) * 20.0, 0.2))
	_pipe.set_stress_ratio(1.0)
	_pipe_frame.position = Vector3(WALL_X, AXIS_Y - r_o, 0.0)

	var end_x: float = WALL_X + model.arm
	_p_arrow.place_onto(Vector3(end_x, AXIS_Y + r_o, 0.0), Vector3(0.0, -(0.15 + 0.35 * model.load / 20.0e3), 0.0))
	_p_arrow.visible = model.load > 0.0
	_p_arrow.label.text = "P = " + Units.force(model.load)
	_n_arrow.place(Vector3(end_x + 0.05, AXIS_Y, 0.0), Vector3(signf(model.axial_load) * (0.1 + 0.3 * absf(model.axial_load) / 150.0e3), 0.0, 0.0))
	_n_arrow.visible = model.axial_load != 0.0
	_n_arrow.label.text = "N = " + Units.signed_force(model.axial_load)
	_torque.position = Vector3(end_x + 0.12, AXIS_Y, 0.0)
	_torque.set_moment(signf(model.torque))
	_torque.label.text = "T = " + Units.moment(model.torque)
	_sign.position = Vector3(end_x, AXIS_Y + 0.35, 0.0)

	var ring := CylinderMesh.new()
	ring.top_radius = r_o + 0.02
	ring.bottom_radius = r_o + 0.02
	ring.height = 0.005
	_ring.mesh = ring
	_ring.rotation.z = PI / 2.0
	_ring.position = Vector3(WALL_X + SECTION_X, AXIS_Y, 0.0)
	var dirs: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	_point.position = _ring.position + dirs[point()] * (r_o + 0.02)

	var state: PlaneStress = model.stress_state(point())
	var theta: float = state.principal_angle() if value(&"orientation") == 1.0 else 0.0
	var t: Vector3 = state.transformed(theta)
	_element.reference = maxf(absf(state.principal_1()), maxf(absf(state.principal_2()), 1.0))
	_element.show_stresses(t.x, t.y, t.z, theta)
	_element_label.text = "%s point:  x = along the pipe, s = around it" % POINT_NAMES[point()]


func _show_step() -> void:
	var on: bool = step() >= 2
	_element.visible = on
	_element_label.visible = on
	_point.visible = on


func refresh() -> void:
	super()
	_show_step()


func set_step(index: int) -> void:
	super(index)
	_show_step()


func step_titles() -> PackedStringArray:
	return ["Internal forces", "Stress from each load", "Stress at a point", "Principal stresses", "Is it safe?"]


func lesson_text() -> String:
	var F := LessonFormat
	var c: float = model.outer_radius
	var t: String = ""
	match step():
		0:
			t += "Real members carry several loads at once. Here the sign's weight and the wind act on a pipe fixed in a wall. Cut the pipe at the wall (yellow ring): to hold the free part in equilibrium the section must carry\n"
			t += F.equation("axial force N", "", Units.signed_force(model.axial_load))
			t += F.equation("shear force V = P", "", Units.force(model.load))
			t += F.equation("bending moment M = P·L", "%s × %s" % [Units.force(model.load), Units.length(model.arm)], Units.moment(model.bending_moment()))
			t += F.equation("torque T", "", Units.moment(model.torque))
			t += "The section at the wall is [b]critical[/b]: M is largest there (the pipe's colors show the bending stress growing toward the wall).\n"
			t += F.try_this("lengthen the arm L: only M grows, the other internal forces stay the same.")
		1:
			t += "Each internal force produces its own stress, which we already know how to compute:\n"
			t += F.equation("σ_N = N/A", "A = %s" % Units.area(model.area()), Units.stress(model.axial_load / model.area()))
			t += F.equation("σ_M = M·c/I", "I = %s" % Units.inertia(model.moment_of_inertia()), "±" + Units.stress(model.bending_moment() * c / model.moment_of_inertia()))
			t += F.equation("τ_T = T·c/J", "J = 2I", Units.stress(absf(model.torsion_shear())))
			t += F.equation("τ_V = V·Q/(I·t)", "at the neutral axis", Units.stress(model.transverse_shear()))
			t += "They do not act at the same points: bending peaks at the [b]top[/b] (tension) and [b]bottom[/b] (compression), where τ_V = 0; transverse shear peaks on the [b]sides[/b] (neutral axis), where σ_M = 0; torsion acts everywhere on the surface.\n"
			t += F.try_this("set P = 0: only torsion and axial stress remain, the same at all four points.")
		2:
			var st: PlaneStress = model.stress_state(point())
			t += "[b]Superpose[/b] the stresses at the chosen point (red dot). On a surface element with x along the pipe and s around it:\n"
			t += F.equation("σ_x = N/A ± M·c/I", "", Units.stress(st.sigma_x))
			t += F.equation("τ_xs = τ_T ± τ_V", "", Units.stress(st.tau_xy))
			t += F.note("On the front side τ_T and τ_V add; on the back they subtract. On the top and bottom τ_V = 0.")
			t += F.try_this("step through Top, Bottom, Front and Back and watch the element change.")
		3:
			var st: PlaneStress = model.stress_state(point())
			t += "With σ_x, σ_y = 0 and τ_xs known, chapter 7 gives the principal stresses and their planes:\n"
			t += F.equation("σ₁,₂ = σ_x/2 ± √((σ_x/2)² + τ²)", "", "%s, %s" % [Units.stress(st.principal_1()), Units.stress(st.principal_2())])
			t += F.equation("θ_p = ½·atan(2τ/σ_x)", "", Units.angle(st.principal_angle()))
			t += F.equation("τ_max (in plane)", "", Units.stress(st.max_inplane_shear()))
			t += F.try_this("choose 'Element drawn: principal' — the shear arrows vanish on the rotated element.")
		4:
			var sy: float = model.material.yield_strength
			var worst: int = 0
			var worst_vm: float = 0.0
			for p: int in 4:
				var vm: float = model.stress_state(p as CombinedLoading.Point).von_mises()
				if vm > worst_vm:
					worst_vm = vm
					worst = p
			var st: PlaneStress = model.stress_state(point())
			t += "Compare each point with the yield strength σ_Y = %s using the von Mises criterion:\n" % Units.stress(sy)
			t += F.equation("σ_vm = √(σ₁² − σ₁σ₂ + σ₂²)", POINT_NAMES[point()] + " point", Units.stress(st.von_mises()))
			t += F.equation("FS = σ_Y/σ_vm", "", Units.factor(st.von_mises_safety(sy)))
			t += F.equation("Tresca FS = (σ_Y/2)/τ_abs,max", "", Units.factor(st.tresca_safety(sy)))
			var worst_fs: float = model.stress_state(worst as CombinedLoading.Point).von_mises_safety(sy)
			t += "The most critical point is %s with σ_vm = %s → FS = %s.\n" % [F.value(POINT_NAMES[worst]), Units.stress(worst_vm), F.ok_or_fail(worst_fs >= 1.5, Units.factor(worst_fs))]
			t += F.try_this("make the wall thinner until FS < 1.5. Which point fails first, and why?")
	return t


func fill_figures(figures: FigureArea) -> void:
	match step():
		0:
			var p := figures.plot(0)
			p.begin("Bending moment along the arm (largest at the wall)", "x from the wall (m)", "|M| (kN·m)")
			p.line(PackedVector2Array([Vector2.ZERO, Vector2(model.arm, 0.0)]), Color(0.5, 0.5, 0.5), 1.0)
			p.line(PackedVector2Array([Vector2(0.0, model.bending_moment() * Units.KN), Vector2(model.arm, 0.0)]), Color(0.65, 0.45, 0.95), 3.0, true)
		2, 3:
			MohrFigure.fill(figures.plot(0), model.stress_state(point()), model.stress_state(point()).principal_angle() if value(&"orientation") == 1.0 else 0.0)
		4:
			var p := figures.plot(0)
			p.begin("von Mises stress at the four points", "point (1 top, 2 bottom, 3 front, 4 back)", "σ_vm (MPa)")
			for i: int in 4:
				var vm: float = model.stress_state(i as CombinedLoading.Point).von_mises() * Units.MPA
				p.line(PackedVector2Array([Vector2(i + 1.0, 0.0), Vector2(i + 1.0, vm)]), Color(1.0, 0.6, 0.3), 14.0)
				p.marker(Vector2(i + 1.0, vm), Color(1, 1, 1), POINT_NAMES[i])
			p.hline(model.material.yield_strength * Units.MPA, Color(1.0, 0.4, 0.4), "σ_Y")


func view_direction() -> Vector3:
	return Vector3(0.45, 0.4, 1.0)


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([Vector3(WALL_X - 0.3, AXIS_Y - 0.6, 0.6), Vector3(WALL_X + model.arm + 0.5, AXIS_Y - 0.6, 0.4),
			Vector3(WALL_X, AXIS_Y + 1.5, 0.0), Vector3(WALL_X + model.arm + 0.4, AXIS_Y + 0.7, 0.0)])
