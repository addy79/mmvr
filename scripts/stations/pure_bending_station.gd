extends Station
## Chapter 4 - Pure bending: a beam segment loaded by equal and opposite couples M. The
## painted grid shows that cross-sections stay plane and rotate; fibers above the neutral
## axis shorten and fibers below stretch. Later steps: plastic bending, eccentric axial
## loading and composite (two-material) sections. Curvature is exaggerated.

const BEND_SHADER: Shader = preload("res://shaders/bend.gdshader")
const SEGMENT: float = 1.6
const CENTER := Vector3(0.0, 1.3, 0.0)
const SECTION_NAMES: PackedStringArray = ["Rectangle", "Circle", "Tube", "I-beam", "Box"]
const MATERIAL_NAMES: PackedStringArray = ["Steel", "Aluminum", "Wood"]
const MAX_DRAWN_ANGLE: float = 1.2  ## largest drawn k*L [rad]
const PLASTIC: int = 5
const ECCENTRIC: int = 6
const COMPOSITE: int = 7

var model: PureBending = PureBending.new()
var eccentric: EccentricAxial = EccentricAxial.new()
var composite: CompositeSection = CompositeSection.new()

var _sections: Array[CrossSection] = SectionPresets.all()
var _materials: Array[LabMaterial] = LabMaterial.presets()
var _mesh: MeshInstance3D = MeshInstance3D.new()
var _shader: ShaderMaterial = ShaderMaterial.new()
var _plate: MeshInstance3D = MeshInstance3D.new()
var _plate_shader: ShaderMaterial = ShaderMaterial.new()
var _couples: Array[MomentArrow3D] = [MomentArrow3D.new(Color(0.95, 0.95, 1.0), 0.25, 0.016),
		MomentArrow3D.new(Color(0.95, 0.95, 1.0), 0.25, 0.016)]
var _axial: Array[Arrow3D] = [Arrow3D.new(Color(0.95, 0.85, 0.5), 0.018), Arrow3D.new(Color(0.95, 0.85, 0.5), 0.018)]
var _top_label: Label3D = Text3D.make(34)
var _bottom_label: Label3D = Text3D.make(34)
var _rho_label: Label3D = Text3D.make(36)
var _shape_key: String = ""


func _init() -> void:
	chapter = 4
	title = "Pure bending"
	_controls = [
		ControlSpec.slider(&"M", "Bending moment M", "kN·m", Units.KN, -60.0, 60.0, 0.5, 10.0e3).only_in([0, 1, 2, 3, 4, COMPOSITE]),
		ControlSpec.choice(&"section", "Cross-section", SECTION_NAMES, 0).only_in([0, 1, 2, 3, 4, PLASTIC, ECCENTRIC]),
		ControlSpec.choice(&"material", "Material", MATERIAL_NAMES, 0).only_in([0, 1, 2, 3, 4, PLASTIC]),
		ControlSpec.slider(&"exaggeration", "Curvature drawn ×", "", 1.0, 1.0, 3000.0, 1.0, 600.0, 0).only_in([0, 1, 2, 3, 4, COMPOSITE]),
		ControlSpec.slider(&"k", "Curvature κ/κ_Y", "", 1.0, 0.0, 8.0, 0.05, 2.0).only_in([PLASTIC]),
		ControlSpec.slider(&"P", "Axial load P", "kN", Units.KN, -400.0, 400.0, 5.0, 100.0e3, 0).only_in([ECCENTRIC]),
		ControlSpec.slider(&"e", "Eccentricity e", "mm", Units.MM, -100.0, 100.0, 1.0, 0.03, 0).only_in([ECCENTRIC]),
		ControlSpec.slider(&"plate", "Steel plate thickness", "mm", Units.MM, 0.0, 30.0, 1.0, 0.01, 0).only_in([COMPOSITE]),
	]
	for m: ShaderMaterial in [_shader, _plate_shader]:
		m.shader = BEND_SHADER
		m.set_shader_parameter("segment_length", SEGMENT)
	_mesh.material_override = _shader
	_plate.material_override = _plate_shader
	for mesh: MeshInstance3D in [_mesh, _plate]:
		mesh.position = CENTER - Vector3(SEGMENT / 2.0, 0.0, 0.0)
		add_child(mesh)
	for node: Node3D in [_couples[0], _couples[1], _axial[0], _axial[1], _top_label, _bottom_label, _rho_label]:
		add_child(node)


func _apply() -> void:
	var s: int = step()
	model.moment = value(&"M")
	model.section = _sections[int(value(&"section"))]
	model.material = _materials[int(value(&"material"))]
	eccentric.section = model.section
	eccentric.load = value(&"P")
	eccentric.eccentricity = value(&"e")
	composite.h2 = value(&"plate")
	composite.moment = value(&"M")
	match s:
		PLASTIC:
			_apply_plastic()
		ECCENTRIC:
			_apply_eccentric()
		COMPOSITE:
			_apply_composite()
		_:
			_apply_elastic()


## Rebuilds the segment (and plate) meshes when the drawn shape changes.
func _shape(section: CrossSection, offset: float, plate_height: float, plate_offset: float) -> void:
	var key: String = "%d %.4f %.4f %.4f" % [section.get_instance_id(), offset, plate_height, plate_offset]
	if key == _shape_key:
		return
	_shape_key = key
	_mesh.mesh = BeamMeshBuilder.build(SectionProfile.for_section(section).transformed(Transform2D(), Vector2(0.0, offset)), SEGMENT)
	_plate.visible = plate_height > 0.0
	if plate_height > 0.0:
		var plate := SectionProfile.for_section(RectSection.new(composite.b2, plate_height))
		_plate.mesh = BeamMeshBuilder.build(plate.transformed(Transform2D(), Vector2(0.0, plate_offset)), SEGMENT)


## Pure bending (steps 1-5): stress -M*y/I, full color at the extreme fibers.
func _apply_elastic() -> void:
	var c: float = model.section.y_max()
	_shape(model.section, 0.0, 0.0, 0.0)
	_set_colors(_shader, c, 0.0, -signf(model.moment), 2.0, true)
	_draw_curvature(model.curvature() * value(&"exaggeration"), model.moment, c)
	_rho_label.text = "ρ = %s   (curvature drawn ×%d)" % [Units.length(model.radius_of_curvature()) if is_finite(model.radius_of_curvature()) else "∞", int(value(&"exaggeration"))]


## Plastic bending: curvature as a multiple of first-yield curvature; hatched yielded fibers.
func _apply_plastic() -> void:
	var c: float = model.section.y_max()
	var k: float = value(&"k") * model.yield_curvature()
	model.moment = model.moment_at_curvature(k)
	_shape(model.section, 0.0, 0.0, 0.0)
	var core: float = model.elastic_core(k)
	_set_colors(_shader, c, 0.0, -c / core if core > 0.0 else -50.0, core / c, true)
	_draw_curvature(MAX_DRAWN_ANGLE / SEGMENT * clampf(value(&"k") / 8.0, 0.0, 1.0), model.moment, c)
	_rho_label.text = "κ = %.1f κ_Y,  M = %s,  elastic core ±%s" % [value(&"k"), Units.moment(model.moment), Units.small_length(core)]


## Eccentric axial load: straight member, stress P/A + P*e*y/I.
func _apply_eccentric() -> void:
	var c: float = model.section.y_max()
	_shape(model.section, 0.0, 0.0, 0.0)
	var top: float = eccentric.stress_at(c)
	var bottom: float = eccentric.stress_at(-c)
	var ref: float = maxf(maxf(absf(top), absf(bottom)), 1.0)
	_set_colors(_shader, c, (top + bottom) / 2.0 / ref, (top - bottom) / 2.0 / ref, 2.0, false)
	_draw_curvature(0.0, 0.0, c)
	for i: int in 2:
		var side: float = 1.0 if i == 1 else -1.0
		var tail := CENTER + Vector3(side * (SEGMENT / 2.0 + 0.05), eccentric.eccentricity * 4.0, 0.0)
		var len: float = 0.15 + 0.3 * absf(eccentric.load) / 400.0e3
		if eccentric.load >= 0.0:
			_axial[i].place(tail, Vector3(side * len, 0.0, 0.0))
		else:
			_axial[i].place_onto(tail, Vector3(-side * len, 0.0, 0.0))
		_axial[i].label.text = "P = %s at e = %s" % [Units.signed_force(eccentric.load), Units.small_length(eccentric.eccentricity)]
	_rho_label.text = "load line drawn 4× its eccentricity"


## Composite: wood beam on a steel plate bending about the transformed section's neutral axis.
func _apply_composite() -> void:
	var z_bar: float = composite.neutral_axis()
	var h_total: float = composite.total_height()
	var wood := RectSection.new(composite.b1, composite.h1)
	_shape(wood, composite.h2 + composite.h1 / 2.0 - z_bar, composite.h2, composite.h2 / 2.0 - z_bar)
	var ref: float = maxf(absf(composite.stress_at(0.0)), absf(composite.stress_at(h_total)))
	# Within each material the stress is -M*y/I_t (times n in steel): slope at y = c (top).
	var c_top: float = h_total - z_bar
	var slope: float = -composite.moment * c_top / composite.transformed_inertia() / ref
	_set_colors(_shader, c_top, 0.0, slope, 2.0, true)
	_set_colors(_plate_shader, c_top, 0.0, slope * composite.modular_ratio(), 2.0, true)
	var k: float = composite.moment / (composite.material_1.youngs_modulus * composite.transformed_inertia())
	_draw_curvature(k * value(&"exaggeration"), composite.moment, c_top)
	_rho_label.text = "wood 100 × 200 on a %s steel plate, n = %.1f" % [Units.small_length(composite.h2), composite.modular_ratio()]


static func _set_colors(m: ShaderMaterial, half_depth: float, axial: float, bending: float, core: float, axis: bool) -> void:
	m.set_shader_parameter("half_depth", half_depth)
	m.set_shader_parameter("axial_ratio", axial)
	m.set_shader_parameter("bending_ratio", bending)
	m.set_shader_parameter("yield_fraction", core)
	m.set_shader_parameter("show_axis", axis)


## Bends the drawn segment to curvature k and places the end couples (hidden when M = 0).
func _draw_curvature(k: float, moment: float, c: float) -> void:
	k = clampf(k, -MAX_DRAWN_ANGLE / SEGMENT, MAX_DRAWN_ANGLE / SEGMENT)
	for m: ShaderMaterial in [_shader, _plate_shader]:
		m.set_shader_parameter("curvature", k)
	var half: float = SEGMENT / 2.0
	for i: int in 2:
		var side: float = 1.0 if i == 1 else -1.0
		var phi: float = half * k * side
		var end := Vector3(sin(phi) / k, (1.0 - cos(phi)) / k, 0.0) if absf(k) > 1e-6 else Vector3(half * side, 0.0, 0.0)
		_couples[i].position = CENTER + end + Vector3(0.12 * side, 0.0, 0.0)
		_couples[i].rotation.z = phi
		_couples[i].set_moment(signf(moment) * side)
		_couples[i].label.text = "M = " + Units.moment(moment)
	var sagging: bool = moment >= 0.0
	_top_label.text = "shortens (compression)" if sagging else "stretches (tension)"
	_bottom_label.text = "stretches (tension)" if sagging else "shortens (compression)"
	_top_label.position = CENTER + Vector3(0.0, c + 0.2, 0.0)
	_bottom_label.position = CENTER + Vector3(0.0, -c - 0.2, 0.0)
	_rho_label.position = CENTER + Vector3(0.0, c + 0.45, 0.0)
	var bending_visible: bool = step() != ECCENTRIC
	_top_label.visible = bending_visible and moment != 0.0
	_bottom_label.visible = bending_visible and moment != 0.0
	for a: Arrow3D in _axial:
		a.visible = not bending_visible


func set_step(index: int) -> void:
	_step = clampi(index, 0, step_titles().size() - 1)
	_apply()
	changed.emit()


func step_titles() -> PackedStringArray:
	return ["Deformation", "Normal strain", "Flexure formula", "Curvature", "Section modulus & yield",
			"Plastic bending", "Eccentric axial load", "Composite sections"]


func lesson_text() -> String:
	var F := LessonFormat
	var s: CrossSection = model.section
	var c: float = s.y_max()
	var t: String = ""
	match step():
		0:
			t += "A member loaded only by equal and opposite couples M at its ends is in [b]pure bending[/b]: no shear force, the same M at every section. By symmetry it bends into a [b]circular arc[/b] of radius ρ.\n"
			t += "The painted grid shows the key facts:\n[ul]\n[b]cross-sections stay plane[/b] and pass through the center of the arc (vertical lines stay straight);\nfibers on the concave side [b]shorten[/b], on the convex side they [b]stretch[/b];\none surface keeps its length: the [b]neutral surface[/b] (yellow line on the side faces).\n[/ul]\n"
			t += F.note("Assumptions: prismatic member with a plane of symmetry, couples in that plane, small deformations. Plane sections remaining plane follows from symmetry alone, for any material.")
			t += "Here M = %s → ρ = %s.\n" % [F.value(Units.moment(model.moment)), F.value(Units.length(model.radius_of_curvature()))]
			t += F.try_this("make M negative: the segment hogs, and the top now stretches.")
		1:
			t += "Because sections stay plane, the longitudinal strain varies [b]linearly[/b] with the distance y from the neutral surface:\n"
			t += F.derivation("A fiber at distance y has length (ρ − y)θ after bending; the neutral fiber keeps its length L = ρθ. So ε_x = ((ρ − y)θ − ρθ)/(ρθ) = −y/ρ.")
			t += F.equation("ε_x = −y/ρ", "")
			t += F.equation("ε_m = c/ρ", "%s / %s" % [Units.small_length(c), Units.length(model.radius_of_curvature())], Units.strain(model.max_strain()))
			t += F.equation("ε_top", "", Units.strain(model.strain_at(c)))
			t += F.equation("ε_bottom", "", Units.strain(model.strain_at(-c)))
			t += F.note("This is pure geometry: it holds for any material, elastic or not. The transverse strains ε_y = ε_z = −ν·ε_x give anticlastic curvature of the cross-section.")
			t += F.try_this("switch the cross-section: the strain profile depends only on c and ρ.")
		2:
			t += "With Hooke's law σ = E·ε the stress is linear too. Two equilibrium conditions fix everything:\n"
			t += F.derivation("ΣF_x = 0: ∫σ_x dA = −(E/ρ)∫y dA = 0, so the first moment about the neutral axis vanishes: the neutral axis passes through the [b]centroid[/b]. ΣM = M: −∫y·σ_x dA = (E/ρ)∫y² dA = E·I/ρ = M. Eliminating E/ρ gives the flexure formula.")
			t += F.equation("σ_x = −M·y/I", "flexure formula")
			t += F.equation("σ_m = M·c/I", "%s × %s / %s" % [Units.moment(absf(model.moment)), Units.small_length(c), Units.inertia(s.moment_of_inertia())], Units.stress(model.max_stress()))
			t += F.equation("σ_top", "", Units.stress(model.stress_at(c)))
			t += F.equation("σ_bottom", "", Units.stress(model.stress_at(-c)))
			t += "I = %s for the %s.\n" % [Units.inertia(s.moment_of_inertia()), SectionText.describe(s)]
			t += F.try_this("compare the rectangle and the I-beam at the same M: the I-beam's material sits far from the axis, so I is larger and σ smaller.")
		3:
			t += "The same derivation gives the [b]moment-curvature relation[/b]:\n"
			t += F.equation("1/ρ = M/(E·I)", "%s / (%s × %s)" % [Units.moment(absf(model.moment)), Units.modulus(model.material.youngs_modulus), Units.inertia(s.moment_of_inertia())], "%.4f×10⁻³ 1/m" % (absf(model.curvature()) * 1e3))
			t += "EI is the [b]flexural rigidity[/b]. Chapter 9 integrates this curvature along a beam (where M varies) to find the deflection.\n"
			t += F.try_this("switch steel → aluminum: the stresses stay the same, but E drops to one third, so the curvature triples.")
		4:
			t += "The largest stress depends on the section only through the [b]elastic section modulus[/b]:\n"
			t += F.equation("S = I/c", "", Units.first_moment(model.section_modulus()))
			t += F.equation("σ_m = |M|/S", "", Units.stress(model.max_stress()))
			t += "The section first yields at its extreme fibers when σ_m = σ_Y:\n"
			t += F.equation("M_Y = σ_Y·S", "", Units.moment(model.yield_moment()))
			t += F.equation("FS = M_Y/|M| = σ_Y/σ_m", "", Units.factor(model.factor_of_safety()))
			t += F.try_this("for each section, raise M until FS reaches 1 and compare M_Y. Material far from the neutral axis is what counts.")
		PLASTIC:
			var k: float = value(&"k") * model.yield_curvature()
			t += "For an elastic-perfectly-plastic material (steel), bending beyond M_Y does not break the beam: yielding spreads inward from the extreme fibers (hatched), leaving an [b]elastic core[/b] of half-depth y_Y = ε_Y/κ.\n"
			t += F.equation("κ_Y = σ_Y/(E·c)", "first yield", "%.4f×10⁻³ 1/m" % (model.yield_curvature() * 1e3))
			t += F.equation("M(κ) = −∫σ(y)·y·t(y) dy", "κ = %.2f κ_Y" % value(&"k"), Units.moment(model.moment_at_curvature(k)))
			t += F.equation("elastic core y_Y = ε_Y/κ", "", Units.small_length(model.elastic_core(k)))
			t += "As κ grows the whole section yields, at ±σ_Y above and below the neutral axis: the [b]plastic moment[/b]\n"
			t += F.equation("M_p = σ_Y·Z", "Z = %s" % Units.first_moment(s.plastic_modulus()), Units.moment(model.plastic_moment()))
			t += F.equation("shape factor k = M_p/M_Y = Z/S", "", "%.3f" % model.shape_factor())
			t += F.note("Rectangle k = 1.5, solid circle 1.70, I-beams ≈ 1.1–1.2: I-beams are already efficient elastically. Unloading is elastic and leaves residual stresses.")
			t += F.try_this("compare the shape factors of all five sections, and watch the M-κ curve flatten toward M_p.")
		ECCENTRIC:
			t += "An axial load P applied off the centroid at a distance e is equivalent to a centric load P plus a couple M = P·e. Superpose the two stress distributions:\n"
			t += F.equation("σ(y) = P/A + P·e·y/I", "")
			t += F.equation("σ_top", "", Units.stress(eccentric.stress_at(c)))
			t += F.equation("σ_bottom", "", Units.stress(eccentric.stress_at(-c)))
			var na: float = eccentric.neutral_axis()
			t += F.equation("neutral axis: y₀ = −I/(A·e)", "", Units.small_length(na) + ("  (outside the section)" if absf(na) > c else ""))
			t += "The stress keeps one sign everywhere while e stays inside the [b]kern[/b]:\n"
			t += F.equation("|e| ≤ I/(A·c)", "", Units.small_length(eccentric.kern_limit()))
			t += F.note("Masonry and concrete, which crack in tension, are designed to keep compressive loads within the kern (the middle third of a rectangle).")
			t += F.try_this("set P negative (compression) and increase e until the far face goes into tension.")
		COMPOSITE:
			t += "A beam made of two bonded materials still has plane sections and a linear strain, but the stress jumps at the interface because E differs. The [b]transformed section[/b] replaces the steel plate by wood n times wider:\n"
			t += F.equation("n = E_steel/E_wood", "", "%.2f" % composite.modular_ratio())
			t += F.equation("neutral axis ȳ = ΣA'·z/ΣA'", "from the bottom", Units.small_length(composite.neutral_axis()))
			t += F.equation("I_t = Σ(I + A'·d²)", "", Units.inertia(composite.transformed_inertia()))
			t += F.equation("wood: σ = −M·y/I_t", "top fiber", Units.stress(composite.stress_at(composite.total_height())))
			t += F.equation("steel: σ = −n·M·y/I_t", "bottom fiber", Units.stress(composite.stress_at(0.0)))
			t += F.note("The same idea designs reinforced-concrete beams (concrete cracked in tension, steel bars transformed with n ≈ 8).")
			t += F.try_this("thicken the steel plate: the neutral axis moves down and the wood stresses fall sharply.")
	return t


func fill_figures(figures: FigureArea) -> void:
	var c: float = model.section.y_max()
	match step():
		1, 2:
			var p := figures.plot(0)
			var pts := PackedVector2Array()
			for i: int in 3:
				var y: float = c * (i - 1.0)
				pts.append(Vector2(model.strain_at(y) * 1e6 if step() == 1 else model.stress_at(y) * Units.MPA, y * Units.MM))
			if step() == 1:
				p.begin("Strain across the depth: linear", "ε (×10⁻⁶)", "y (mm)")
			else:
				p.begin("Stress across the depth: linear", "σ (MPa)", "y (mm)")
			p.line(pts, Color(1.0, 0.55, 0.4), 3.0, true)
			p.hline(0.0, Color(1.0, 0.9, 0.3), "neutral axis")
		3:
			var p := figures.plot(0)
			p.begin("Moment-curvature: slope 1/EI", "M (kN·m)", "1/ρ (10⁻³/m)")
			p.line(_sweep(func(m: PureBending) -> float: return m.curvature() * 1e3, -60.0e3), Color(0.6, 0.8, 1.0), 3.0)
			p.marker(Vector2(model.moment * Units.KN, model.curvature() * 1e3), Color(1, 1, 1), "now")
		4:
			var p := figures.plot(0)
			p.begin("Maximum stress vs M for this section", "|M| (kN·m)", "σ_m (MPa)")
			p.line(_sweep(func(m: PureBending) -> float: return m.max_stress() * Units.MPA, 0.0), Color(1.0, 0.6, 0.4), 3.0)
			p.hline(model.material.yield_strength * Units.MPA, Color(1.0, 0.4, 0.4), "σ_Y")
			p.marker(Vector2(absf(model.moment) * Units.KN, model.max_stress() * Units.MPA), Color(1, 1, 1), "now")
		PLASTIC:
			var p := figures.plot(0)
			p.begin("Moment-curvature, elastic-perfectly-plastic", "κ/κ_Y", "M/M_Y")
			var pts := PackedVector2Array()
			var k_y: float = model.yield_curvature()
			for i: int in 81:
				var r: float = 8.0 * i / 80.0
				pts.append(Vector2(r, model.moment_at_curvature(r * k_y) / model.yield_moment()))
			p.line(pts, Color(1.0, 0.75, 0.35), 3.0)
			p.hline(model.shape_factor(), Color(1.0, 0.4, 0.4), "M_p/M_Y = k")
			p.marker(Vector2(value(&"k"), model.moment_at_curvature(value(&"k") * k_y) / model.yield_moment()), Color(1, 1, 1), "now")
			var p2 := figures.plot(1)
			p2.begin("Stress across the depth", "σ (MPa)", "y (mm)")
			var prof := PackedVector2Array()
			var k: float = value(&"k") * k_y
			for i: int in 101:
				var y: float = c * (2.0 * i / 100.0 - 1.0)
				prof.append(Vector2(model.stress_at_curvature(k, y) * Units.MPA, y * Units.MM))
			p2.line(prof, Color(1.0, 0.55, 0.4), 3.0, true)
		ECCENTRIC:
			var p := figures.plot(0)
			p.begin("Superposition: P/A + P·e·y/I", "σ (MPa)", "y (mm)")
			p.line(PackedVector2Array([Vector2(eccentric.stress_at(-c) * Units.MPA, -c * Units.MM),
					Vector2(eccentric.stress_at(c) * Units.MPA, c * Units.MM)]), Color(1.0, 0.6, 0.4), 3.0, true)
			p.vline(eccentric.load / model.section.area() * Units.MPA, Color(0.6, 0.8, 1.0), "P/A")
		COMPOSITE:
			var p := figures.plot(0)
			p.begin("Stress through the composite section", "σ (MPa)", "z from bottom (mm)")
			var z_top: float = composite.total_height()
			var pts := PackedVector2Array()
			for i: int in 201:
				var z: float = z_top * i / 200.0
				pts.append(Vector2(composite.stress_at(z) * Units.MPA, z * Units.MM))
			p.line(pts, Color(1.0, 0.6, 0.4), 3.0)
			p.hline(composite.neutral_axis() * Units.MM, Color(1.0, 0.9, 0.3), "neutral axis")
			p.hline(composite.h2 * Units.MM, Color(0.6, 0.8, 1.0), "interface")


## Evaluates f on copies of the model with M from m_from to 60 kN*m; x in kN*m.
func _sweep(f: Callable, m_from: float) -> PackedVector2Array:
	var probe := PureBending.new()
	probe.section = model.section
	probe.material = model.material
	var pts := PackedVector2Array()
	for i: int in 41:
		probe.moment = m_from + (60.0e3 - m_from) * i / 40.0
		pts.append(Vector2(probe.moment * Units.KN, f.call(probe)))
	return pts


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([CENTER + Vector3(-1.2, -0.6, 0.3), CENTER + Vector3(1.2, -0.6, 0.3),
			CENTER + Vector3(-1.2, 0.8, -0.2), CENTER + Vector3(1.2, 0.8, -0.2)])
