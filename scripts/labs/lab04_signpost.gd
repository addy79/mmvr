extends LabStation
## Lab 4 - Mechanical analysis of a signpost (ANSYS). Hand calculations that check what the
## ANSYS model should give: internal forces at the base, stresses, deflections, safety.
## Drawn at 1:5; the post is colored by its largest normal stress at each height and drawn
## deflected (exaggerated). Physics z (up) is Godot y, physics y is Godot z.

const BASE := Vector3(0.0, 0.0, 0.0)
const DRAW: float = 0.2      ## 1:5
const SEGMENTS: int = 17
const SAFETY: int = 5

var post: Signpost = Signpost.new()
var _segments: Array[MeshInstance3D] = []
var _segment_materials: Array[StandardMaterial3D] = []
var _sign: MeshInstance3D = MeshInstance3D.new()
var _wind_x: Array[Arrow3D] = []
var _wind_y: Arrow3D = Arrow3D.new(Color(0.5, 0.85, 1.0), 0.012)
var _weight: Arrow3D = Arrow3D.new(Color(0.95, 0.95, 1.0), 0.012)
var _label: Label3D = Text3D.make(30)


func _init() -> void:
	lab = 4
	title = "Mechanical analysis of a signpost (ANSYS)"
	handout = "Lab Handout N°4 - Mechanical Analysis of a Signpost.docx"
	_controls = [
		ControlSpec.slider(&"wind", "Wind loads ×", "", 1.0, 0.5, 40.0, 0.5, 1.0, 1),
		ControlSpec.choice(&"on_sign", "W_x2 acts on", PackedStringArray(["Post only", "Post and sign"]), 1),
		ControlSpec.slider(&"x1", "F_y1 position x1 (from the post)", "m", 1.0, 0.0, 4.0, 0.05, 2.0).only_in([1, 2]),
		ControlSpec.slider(&"z1", "F_y1 height z1 (above the post)", "m", 1.0, 0.0, 2.5, 0.05, 1.25).only_in([1, 2]),
		ControlSpec.slider(&"w", "Post width w (along x)", "m", 1.0, 0.1, 0.8, 0.01, 0.5),
		ControlSpec.slider(&"t", "Thickness t (along y)", "m", 1.0, 0.1, 0.8, 0.01, 0.5),
		ControlSpec.slider(&"exaggeration", "Deflection drawn ×", "", 1.0, 1.0, 500.0, 1.0, 100.0, 0),
	]
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.5, 0.5, 0.48)
	var footing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.06, 0.5)
	footing.mesh = box
	footing.material_override = concrete
	footing.position = BASE + Vector3(0.0, 0.03, 0.0)
	add_child(footing)
	for i: int in SEGMENTS:
		var m := MeshInstance3D.new()
		m.mesh = BoxMesh.new()
		var mat := StandardMaterial3D.new()
		m.material_override = mat
		_segments.append(m)
		_segment_materials.append(mat)
		add_child(m)
	_sign.mesh = BoxMesh.new()
	var sign_material := StandardMaterial3D.new()
	sign_material.albedo_color = Color(0.15, 0.45, 0.25)
	_sign.material_override = sign_material
	add_child(_sign)
	for i: int in 9:
		var a := Arrow3D.new(Color(1.0, 0.75, 0.4), 0.007)
		a.label.visible = i == 8
		_wind_x.append(a)
		add_child(a)
	add_child(_wind_y)
	add_child(_weight)
	_label.position = BASE + Vector3(1.0, 1.0, 0.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_label)


func _apply() -> void:
	post.wind_factor = value(&"wind")
	post.wind_x_on_sign = value(&"on_sign") == 1.0
	post.force_x = value(&"x1")
	post.force_z = value(&"z1")
	post.post_width = value(&"w")
	post.thickness = value(&"t")
	var k: float = value(&"exaggeration") * DRAW
	var h1: float = post.post_height
	var dz: float = h1 / SEGMENTS
	var n: float = post.base_axial_force() / post.area()
	for i: int in SEGMENTS:
		var z: float = (i + 0.5) * dz
		var sigma: float = n + post.moment_x_at(z) * post.post_width / 2.0 / post.inertia_for_x() \
				+ post.moment_y_at(z) * post.thickness / 2.0 / post.inertia_for_y()
		var box := _segments[i].mesh as BoxMesh
		box.size = Vector3(post.post_width, dz, post.thickness) * DRAW
		_segments[i].position = BASE + Vector3(post.post_deflection(z, 0) * k, z * DRAW, post.post_deflection(z, 1) * k)
		_segment_materials[i].albedo_color = Color(0.86, 0.86, 0.84).lerp(Color(0.9, 0.15, 0.1), clampf(sigma / post.material.yield_strength, 0.0, 1.0))
	var sign_box := _sign.mesh as BoxMesh
	sign_box.size = Vector3(post.sign_length, post.sign_height, post.thickness) * DRAW
	# The rigid sign's center moves halfway between the post top and the sign's top edge.
	var center: Vector2 = (Vector2(post.post_deflection(h1, 0), post.post_deflection(h1, 1)) + post.sign_top_displacement()) / 2.0
	_sign.position = BASE + Vector3(post.sign_offset * DRAW + center.x * k, (h1 + post.sign_height / 2.0) * DRAW, center.y * k)
	var lean: Vector2 = Vector2(post.post_slope(h1, 0), post.post_slope(h1, 1)) * value(&"exaggeration")
	_sign.rotation = Vector3(lean.y, -post.twist_angle() * value(&"exaggeration"), -lean.x)
	var z_top: float = h1 + (post.sign_height if post.wind_x_on_sign else 0.0)
	for i: int in _wind_x.size():
		var z: float = z_top * (i + 1) / _wind_x.size()
		var len: float = 0.05 + 0.3 * post.wind_x_at(z) / maxf(post.wind_x_at(z_top), 1.0)
		var x_face: float = (-post.post_width / 2.0 if z <= h1 else 0.0) * DRAW + (post.post_deflection(minf(z, h1), 0) * k)
		_wind_x[i].place_onto(BASE + Vector3(x_face - 0.01, z * DRAW, 0.0), Vector3(len, 0.0, 0.0))
		_wind_x[i].label.text = "W_x2 = %s·z N/m" % Units.fixed(post.wind_x_rate * post.wind_factor, 0)
	var face_z: float = post.thickness / 2.0 * DRAW
	var at := Vector3((post.force_x - post.sign_offset) * DRAW, (post.force_z - post.sign_height / 2.0) * DRAW, face_z)
	_wind_y.place_onto(_sign.position + at, Vector3(0.0, 0.0, -0.3))
	_wind_y.label.text = "F_y1 = " + Units.newtons(post.base_shear_y(), 0)
	_weight.place(_sign.position + Vector3(0.0, post.sign_height / 2.0 * DRAW + 0.3, 0.0), Vector3(0.0, -0.25, 0.0))
	_weight.label.text = "W_z1·L = " + Units.newtons(post.sign_weight_per_length * post.sign_length, 0)
	_label.text = "base: σ_max = %s\nsign top moves %s\n(drawn ×%d, model 1:5)" % [Units.stress(post.max_von_mises()),
			Units.mm(post.sign_corner_displacement().length()), int(value(&"exaggeration"))]


func _show_step() -> void:
	_apply()


func step_titles() -> PackedStringArray:
	return ["Objective", "Model and loads", "Forces at the base", "Stresses at the base", "Deformation",
			"Safe? Elastic?", "Report questions"]


func lesson_text() -> String:
	var F := LessonFormat
	var p: Signpost = post
	var t: String = ""
	match step():
		0:
			t += "You are the engineer: a client wants to install its signposts in a particularly windy place. Model the signpost in ANSYS Mechanical, compute the stress, strain and deformation it gets, and decide whether it is safe, and what to change if it is not.\n"
			t += "ANSYS gives colored contours; an engineer always checks them with a [b]hand calculation[/b]. The post is a vertical cantilever fixed in its foundation: every load on it ends up as internal forces at the base, which is where the stresses are largest. This bench does that check with your numbers, so you know what ANSYS should say.\n"
			t += handout_note()
		1:
			t += "Geometry (all structural steel, handout figure 3): post %s × %s × %s high; sign b2 = %s long × %s high × %s thick on top of it, running from the post toward +x (its center is %s from the post's axis).\n" % [
					Units.length(p.post_width), Units.length(p.thickness), Units.length(p.post_height), Units.length(p.sign_length), Units.length(p.sign_height), Units.length(p.thickness), Units.length(p.sign_offset)]
			t += "Loads (z vertical, from the base):\n"
			t += F.equation("W_z1 = 1340 N/m", "weight of the sign per unit length → %s in total" % Units.newtons(p.sign_weight_per_length * p.sign_length, 0))
			t += F.equation("W_x2 = 700·z", "wind along x growing with height, from the base to the top of the sign (taken in N/m at height z)")
			t += F.equation("F_y1 = 3600 N", "wind on the face of the sign, along y, at (x1, z1) = (%s, %s) on the sign" % [Units.length(p.force_x), Units.length(p.force_z)])
			t += F.equation("F_z1 = 11000 N", "weight of the support (post)")
			t += "In ANSYS: fixed support on the bottom face; the weights as forces on the top faces, F_y1 as a force on the sign's face, and W_x2 as a load defined by a function of z on the post's side face.\n"
			t += F.note("The handout gives no values for x1 and z1; the default puts F_y1 at the sign's center (set them to what you use in ANSYS). The wind ×%s control scales both wind loads." % Units.fixed(p.wind_factor, 1))
		2:
			t += "Cut the post just above the foundation and write equilibrium of the part above the cut:\n"
			t += F.equation("N = F_z1 + W_z1·L", "11000 + 1340 × %s" % Units.fixed(p.sign_length, 1), Units.newtons(p.base_axial_force(), 0) + " (compression)")
			var h: float = p.post_height + (p.sign_height if p.wind_x_on_sign else 0.0)
			var m_weight: float = p.sign_weight_per_length * p.sign_length * p.sign_offset
			t += F.equation("V_x = ∫ W_x2 dz = 700·h²/2", "h = %s" % Units.length(h), Units.newtons(p.base_shear_x(), 0))
			t += F.equation("M from W_x2 = ∫ 700·z·z dz = 700·h³/3", "", Units.moment(p.moment_x_at(0.0) - m_weight))
			t += F.equation("M from the sign's weight = W_z1·b2·(b2/2)", "%s × %s" % [Units.newtons(p.sign_weight_per_length * p.sign_length, 0), Units.length(p.sign_offset)], Units.moment(m_weight))
			t += F.equation("M₁ (bending in the x-z plane, total)", "", Units.moment(p.moment_x_at(0.0)))
			t += F.equation("V_y = F_y1", "", Units.newtons(p.base_shear_y(), 0))
			t += F.equation("M₂ from F_y1 = F_y1·(h1 + z1)", "%s × %s" % [Units.newtons(p.base_shear_y(), 0), Units.length(p.post_height + p.force_z)], Units.moment(p.moment_y_at(0.0)))
			t += F.equation("torque T = F_y1·x1", "%s × %s" % [Units.newtons(p.base_shear_y(), 0), Units.length(p.force_x)], Units.moment(p.torque()))
			t += "Because the sign hangs to one side, its weight also [b]bends[/b] the post (in the same direction as the wind), and the wind on the sign [b]twists[/b] it. A triangular load's resultant (700·h²/2) acts at 2h/3 from the base, which is where the h³/3 comes from.\n"
			t += F.try_this("look at the figure: the bending moment from the wind is zero at the top and grows fast toward the base.")
		3:
			t += "Square section %s × %s: A = %s m², I = %s m⁴ for each axis (when w = t).\n" % [Units.length(p.post_width), Units.length(p.thickness), Units.fixed(p.area(), 4), Units.fixed(p.inertia_for_x(), 6)]
			t += "Combined axial load and bending in two planes (chapter 8): the normal stress at a corner is\n"
			t += F.equation("σ = −N/A ± M₁·(w/2)/I₁ ± M₂·(t/2)/I₂", "")
			t += F.equation("most tensile corner", "", Units.stress(p.max_tension_stress()))
			t += F.equation("most compressed corner", "", Units.stress(p.max_compression_stress()))
			t += F.equation("transverse shear, τ = 1.5·V/A", "", Units.stress(p.max_transverse_shear()))
			t += F.equation("torsion, τ = T/(c₁ab²), c₁ ≈ 1/(3 + 1.8b/a)", "", Units.stress(p.torsion_stress()))
			t += F.equation("largest von Mises stress", "", Units.stress(p.max_von_mises()))
			t += F.equation("largest strain ≈ σ_v/E", "", Units.strain(p.max_strain()))
			t += "Shear stresses (transverse and torsion) are tiny next to the bending stresses and vanish at the corners. The maximum is at the [b]base corners[/b] on the windward/leeward faces, where both bending stresses add. That is where ANSYS's red will be (it may show a slightly higher peak right at the fixed face, a local effect of the rigid support).\n"
		4:
			var d: Vector2 = p.sign_corner_displacement()
			t += "The post bends as a cantilever. Integrating the curvature M/EI twice from the fixed base (chapter 9):\n"
			t += F.equation("top of the post, along x", "", Units.mm(p.post_deflection(p.post_height, 0)))
			t += F.equation("top of the post, along y", "", Units.mm(p.post_deflection(p.post_height, 1)))
			t += F.equation("twist of the post φ = T·h1/(G·J)", "", Units.degrees(p.twist_angle(), 4))
			t += F.equation("far top corner of the sign = v(h1) + θ(h1)·h2 + φ·b2", "", "x %s, y %s" % [Units.mm(d.x), Units.mm(d.y)])
			t += F.equation("total deformation max (ANSYS 'Total Deformation')", "", Units.mm(d.length()))
			t += F.note("Checks: wind on the post alone gives v_top = 11·w₀·h⁴/(120EI) with w₀ = 700·h1; a constant moment M gives M·h²/(2EI); F_y1 gives F·h³/(3EI) + F·z1·h²/(2EI). The sign itself is treated as rigid.")
		SAFETY:
			var fs: float = p.factor_of_safety()
			t += "Compare the largest von Mises stress with the yield strength of structural steel (%s):\n" % Units.stress(p.material.yield_strength)
			t += F.equation("factor of safety FS = σ_Y/σ_v,max", "%s / %s" % [Units.stress(p.material.yield_strength), Units.stress(p.max_von_mises())], F.ok_or_fail(fs >= 1.0, Units.factor(fs)))
			t += ("Since σ_v,max < σ_Y everywhere, the steel stays in the [b]elastic region[/b] and springs back when the wind stops.\n" if fs >= 1.0 else "σ_v,max exceeds σ_Y: the base would [b]yield[/b] (plastic region) and the post would keep a permanent lean.\n")
			t += "A safe design also needs: deflection limits (a sign that sways too much is unusable), fatigue (wind loads cycle millions of times, so welds and holes at the base matter), and the foundation's strength. Stress concentrations at the base plate, bolts and welds can be several times the nominal stress.\n"
			t += F.try_this("raise the wind factor until FS drops to 1 (gust, storm, or a bigger sign). Then shrink the post to a hollow-like slender one (w, t) and see how much faster it fails: σ_bending ∝ 1/w³ for a square.")
		6:
			t += F.question("Maximum stress, strain and deformation, and where they are.", "Stress and strain: at the base (fixed support), on the corners where both bending stresses add (step 4). Deformation: at the top of the sign (step 5). Compare your ANSYS values with these hand values; explain any difference (load application, support modeling, mesh).")
			t += F.question("Is the signpost structurally safe? Elastic or plastic?", "Use the factor of safety (step 6). With the handout loads the stress is under 20 MPa against a 250 MPa yield strength: elastic, very safe in strength. Mention what is not checked (fatigue, foundation, connections).")
			t += F.question("Recommendations to increase safety.", "The post is a solid 0.5 m steel bar, extremely heavy. Better: a hollow section (tube or box) with the same outer size (I barely drops, weight drops a lot; chapter 4), larger depth in the direction of the dominant wind, stiffeners at the base, a stronger foundation/anchor, a sign with openings to reduce the wind force, guys/braces in very windy places, periodic inspection of welds and bolts for fatigue.")
	return t


func fill_figures(figures: FigureArea) -> void:
	match step():
		2, 3:
			var p := figures.plot(0)
			p.begin("Bending moment in the post", "z (m)", "M (kN·m)")
			var mx := PackedVector2Array()
			var my := PackedVector2Array()
			for i: int in 61:
				var z: float = post.post_height * i / 60.0
				mx.append(Vector2(z, post.moment_x_at(z) * Units.KN))
				my.append(Vector2(z, post.moment_y_at(z) * Units.KN))
			p.line(mx, Color(1.0, 0.75, 0.4), 2.5)
			p.line(my, Color(0.5, 0.85, 1.0), 2.5)
			p.marker(mx[0], Color(1.0, 0.75, 0.4), "from W_x2")
			p.marker(my[0], Color(0.5, 0.85, 1.0), "from F_y1")
		4:
			var p := figures.plot(0)
			p.begin("Deflection of the post", "z (m)", "v (mm)")
			var vx := PackedVector2Array()
			var vy := PackedVector2Array()
			for i: int in 41:
				var z: float = post.post_height * i / 40.0
				vx.append(Vector2(z, post.post_deflection(z, 0) * Units.MM))
				vy.append(Vector2(z, post.post_deflection(z, 1) * Units.MM))
			p.line(vx, Color(1.0, 0.75, 0.4), 2.5)
			p.line(vy, Color(0.5, 0.85, 1.0), 2.5)
			p.marker(vx[-1], Color(1.0, 0.75, 0.4), "x")
			p.marker(vy[-1], Color(0.5, 0.85, 1.0), "y")


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([BASE + Vector3(-0.6, 0.0, 0.3), BASE + Vector3(-0.6, 2.3, 0.0), BASE + Vector3(1.9, 2.3, 0.0), BASE + Vector3(1.9, 0.0, 0.3)])


func view_direction() -> Vector3:
	return Vector3(0.35, 0.25, 1.0)
