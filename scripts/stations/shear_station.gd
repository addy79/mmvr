extends Station
## Chapter 6 - Shearing stresses in beams: a beam segment seen end-on, drawn 3x real size,
## colored by tau(y) with the area beyond the cut hatched; and a stack of planks that slide
## unless glued, to show why horizontal shear exists.

const SECTION_SHADER: Shader = preload("res://shaders/shear_section.gdshader")
const BEND_SHADER: Shader = preload("res://shaders/bend.gdshader")
const DRAW: float = 3.0
const SEGMENT_LENGTH: float = 0.5
const FACE := Vector3(-0.7, 1.35, 0.0)    ## centre of the front cross-section face
const PLANKS := Vector3(0.9, 1.0, 0.0)
const PLANK_LENGTH: float = 1.3
const PLANK_DEPTH: float = 0.11
const SAMPLES: int = 33
const ARROWS: int = 11
const SECTION_NAMES: PackedStringArray = ["Rectangle", "Circle", "Tube", "I-beam", "Box"]

var model: SectionShear = SectionShear.new()

var _sections: Array[CrossSection] = SectionPresets.all()
var _segment: MeshInstance3D = MeshInstance3D.new()
var _segment_material: ShaderMaterial = ShaderMaterial.new()
var _profile: PackedFloat32Array = PackedFloat32Array()
var _cut_line: MeshInstance3D = MeshInstance3D.new()
var _knob_frame: Node3D = Node3D.new()
var _knob: AxisKnob
var _tau_arrows: Array[Arrow3D] = []
var _v_arrow: Arrow3D = Arrow3D.new(Color(0.95, 0.95, 1.0), 0.02)
var _cut_label: Label3D = Text3D.make(34)
var _planks: Array[MeshInstance3D] = []
var _plank_material: ShaderMaterial = ShaderMaterial.new()
var _plank_label: Label3D = Text3D.make(36)
var _section: CrossSection
var _glued: int = -1


func _init() -> void:
	chapter = 6
	title = "Shearing stresses in beams"
	_controls = [
		ControlSpec.slider(&"V", "Shear force V", "kN", Units.KN, 0.0, 200.0, 1.0, 50.0e3, 0),
		ControlSpec.choice(&"section", "Cross-section", SECTION_NAMES, 0),
		ControlSpec.slider(&"y", "Cut level y/c", "", 1.0, -0.98, 0.98, 0.02, 0.5).only_in([1, 2, 3]),
		ControlSpec.choice(&"joint", "Planks", PackedStringArray(["Loose", "Glued"]), 0).only_in([0]),
		ControlSpec.slider(&"F", "Nail capacity F", "kN", Units.KN, 0.2, 5.0, 0.1, 1.0e3, 1).only_in([3]),
	]
	_profile.resize(SAMPLES)
	_segment_material.shader = SECTION_SHADER
	_segment.material_override = _segment_material
	_segment.position = FACE
	_segment.rotation.y = PI / 2.0  # beam axis (local +X) points away from the viewer
	add_child(_segment)
	var line_material := StandardMaterial3D.new()
	line_material.albedo_color = Color(1.0, 0.75, 0.2)
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cut_line.material_override = line_material
	add_child(_cut_line)
	_knob_frame.rotation.z = PI / 2.0  # knob slides along world up
	add_child(_knob_frame)
	_knob = AxisKnob.new(-1.0, 1.0, Color(1.0, 0.75, 0.2))
	_knob_frame.add_child(_knob)
	_knob.slider_moved.connect(func(y: float) -> void: set_control(&"y", y / (model.section.y_max() * DRAW)))
	for i: int in ARROWS:
		var a := Arrow3D.new(Color(0.2, 0.75, 1.0), 0.008)
		a.label.visible = false
		_tau_arrows.append(a)
		add_child(a)
	add_child(_v_arrow)
	add_child(_cut_label)
	_plank_material.shader = BEND_SHADER
	_plank_material.set_shader_parameter("segment_length", PLANK_LENGTH)
	_plank_material.set_shader_parameter("half_depth", PLANK_DEPTH * 1.5)
	_plank_material.set_shader_parameter("curvature", 0.9)  # demonstration only, not computed
	_plank_material.set_shader_parameter("bending_ratio", 0.0)
	for i: int in 3:
		var plank := MeshInstance3D.new()
		plank.material_override = _plank_material
		_planks.append(plank)
		add_child(plank)
	_plank_label.position = PLANKS + Vector3(PLANK_LENGTH / 2.0, 0.55, 0.0)
	add_child(_plank_label)


func _apply() -> void:
	model.shear_force = value(&"V")
	model.section = _sections[int(value(&"section"))]
	var s: CrossSection = model.section
	var c: float = s.y_max()
	var y: float = value(&"y") * c
	if s != _section:
		_section = s
		var profile := SectionProfile.for_section(s).transformed(Transform2D().scaled(Vector2(DRAW, DRAW)))
		_segment.mesh = BeamMeshBuilder.build(profile, SEGMENT_LENGTH)
		_segment_material.set_shader_parameter("half_depth", c * DRAW)
		_knob.slider_limit_min = -c * DRAW
		_knob.slider_limit_max = c * DRAW
		_knob_frame.position = FACE + Vector3(s.z_max() * DRAW + 0.25, 0.0, 0.02)
	for i: int in SAMPLES:
		_profile[i] = model.shear_stress_at(c * (2.0 * i / (SAMPLES - 1) - 1.0)) / maxf(model.max_shear_stress(), 1.0)
	_segment_material.set_shader_parameter("tau_profile", _profile)
	_segment_material.set_shader_parameter("y_cut", y * DRAW)
	_knob.set_value(y * DRAW)
	var line := BoxMesh.new()
	line.size = Vector3(s.width_at(y) * DRAW + 0.12, 0.012, 0.012)
	_cut_line.mesh = line
	_cut_line.position = FACE + Vector3(0.0, y * DRAW, 0.01)
	_cut_label.text = "t = %s,  Q = %s,  τ = %s" % [Units.small_length(s.width_at(y)), Units.first_moment(s.first_moment(y)), Units.stress(model.shear_stress_at(y))]
	_cut_label.position = FACE + Vector3(0.0, c * DRAW + 0.15, 0.05)
	# tau acts on the face in the direction of V (down); arrow length ~ tau(y).
	for i: int in ARROWS:
		var yi: float = c * (2.0 * (i + 0.5) / ARROWS - 1.0)
		var len_t: float = 0.22 * model.shear_stress_at(yi) / maxf(model.max_shear_stress(), 1.0)
		_tau_arrows[i].place(FACE + Vector3(0.0, yi * DRAW + len_t / 2.0, 0.03), Vector3(0.0, -len_t, 0.0))
	_v_arrow.place(FACE + Vector3(-s.z_max() * DRAW - 0.25, 0.3, 0.0), Vector3(0.0, -0.25 - 0.3 * model.shear_force / 200.0e3, 0.0))
	_v_arrow.label.text = "V = " + Units.force(model.shear_force)
	_apply_planks()


## Three planks under the same bending: loose ones bend separately and their ends slip;
## glued ones bend as one beam about a common neutral axis.
func _apply_planks() -> void:
	var glued: int = int(value(&"joint"))
	if glued == _glued:
		return
	_glued = glued
	for i: int in 3:
		var offset: float = (i - 1) * PLANK_DEPTH
		var profile := SectionProfile.for_section(RectSection.new(0.22, PLANK_DEPTH * 0.98))
		if glued == 1:
			_planks[i].mesh = BeamMeshBuilder.build(profile.transformed(Transform2D(), Vector2(0.0, offset)), PLANK_LENGTH)
			_planks[i].position = PLANKS
		else:
			_planks[i].mesh = BeamMeshBuilder.build(profile, PLANK_LENGTH)
			_planks[i].position = PLANKS + Vector3(0.0, offset, 0.0)
	_plank_label.text = "Glued: one beam, no slip" if glued == 1 else "Loose: the planks slide at the ends"


func _show_step() -> void:
	var s: int = step()
	_cut_line.visible = s >= 1 and s <= 3
	_knob.visible = s >= 1 and s <= 3
	_cut_label.visible = s >= 1 and s <= 3
	_segment_material.set_shader_parameter("y_cut", value(&"y") * model.section.y_max() * DRAW if s >= 1 and s <= 3 else 100.0)
	for p: MeshInstance3D in _planks:
		p.visible = s == 0 or s == 3
	_plank_label.visible = s == 0 or s == 3


func refresh() -> void:
	super()
	_show_step()


func set_control(id: StringName, new_value: float) -> void:
	super(id, new_value)
	_show_step()


func set_step(index: int) -> void:
	super(index)
	_show_step()


func step_titles() -> PackedStringArray:
	return ["Why horizontal shear?", "First moment Q", "Shear formula", "Shear flow & fasteners", "I-beams"]


func lesson_text() -> String:
	var F := LessonFormat
	var s: CrossSection = model.section
	var y: float = value(&"y") * s.y_max()
	var t: String = ""
	match step():
		0:
			t += "Stack loose planks on two supports and press down: each plank bends on its own, and their ends [b]slide past each other[/b]. Glue them and they act as one much stiffer beam — the glue must resist that sliding with [b]horizontal shear[/b] stresses.\n"
			t += "In a solid beam carrying a shear force V, the material does the same job everywhere: horizontal shear stresses act on every horizontal plane, and (by equilibrium of a small element) equal vertical shear stresses act on the cross-section.\n"
			t += "Here: V = %s on the %s.\n" % [F.value(Units.force(model.shear_force)), SectionText.describe(s)]
			t += F.try_this("toggle Loose / Glued and compare the ends of the planks.")
		1:
			var a_beyond: float = s.area_beyond(y)
			t += "Cut the section at height y (yellow line, drag the yellow knob). The hatched part is the area A' beyond the cut. Its [b]first moment[/b] about the neutral axis is\n"
			t += F.equation("Q = A'·ȳ'", "%s × %s" % [Units.area(a_beyond), Units.small_length(model.centroid_beyond(y))], Units.first_moment(s.first_moment(y)))
			t += "ȳ' is the distance from the neutral axis to the centroid of A'. Q is zero at the top and bottom (no area beyond) and largest at the neutral axis:\n"
			t += F.equation("Q_max = Q(0)", "", Units.first_moment(s.first_moment(0.0)))
			t += F.try_this("drag the cut from the top down to the middle and watch Q grow (figure).")
		2:
			t += "Equilibrium of the part beyond the cut, between two nearby sections, gives the [b]shear formula[/b]:\n"
			t += F.equation("τ = V·Q/(I·t)", "%s × %s / (%s × %s)" % [Units.force(model.shear_force), Units.first_moment(s.first_moment(y)), Units.inertia(s.moment_of_inertia()), Units.small_length(s.width_at(y))], Units.stress(model.shear_stress_at(y)))
			t += F.equation("τ_max (neutral axis)", "", Units.stress(model.max_shear_stress()))
			t += F.equation("τ_avg = V/A", "", Units.stress(model.average_shear_stress()))
			t += "For a rectangle τ is a parabola with τ_max = 1.5·τ_avg; for a circle τ_max = (4/3)·τ_avg. Colors on the section show τ(y); the blue arrows act in the direction of V.\n"
			t += F.note("The formula assumes τ is uniform across the width t — good for narrow parts, approximate for wide flanges.")
			t += F.try_this("compare τ_max/τ_avg for each section.")
		3:
			var cap: float = value(&"F")
			var spacing: float = model.fastener_spacing(y, cap)
			t += "Built-up beams (planks, plates) are joined by glue, nails or bolts. What they must carry is the [b]shear flow[/b] — horizontal force per unit length along the joint:\n"
			t += F.equation("q = V·Q/I", "%s × %s / %s" % [Units.force(model.shear_force), Units.first_moment(s.first_moment(y)), Units.inertia(s.moment_of_inertia())], "%.1f kN/m" % (model.shear_flow_at(y) / 1e3))
			t += "Q is taken for the part the joint holds on (the hatched part beyond the joint at y). Each fastener of capacity F covers a length s along the beam:\n"
			t += F.equation("s = F/q", "%s / %.1f kN/m" % [Units.force(cap), model.shear_flow_at(y) / 1e3], Units.small_length(spacing) if is_finite(spacing) else "∞")
			t += F.try_this("move the joint toward the neutral axis: q grows, so the nails must be closer together.")
		4:
			t += "In an I-beam the thin [b]web[/b] carries almost all the shear and the [b]flanges[/b] carry almost all the bending:\n"
			t += F.equation("share of V in the web", "", "%.1f %%" % (100.0 * model.web_share()))
			t += "At the flange-web junction t jumps from b_f to t_w, so τ jumps by the ratio b_f/t_w (figure). That is why designers often check shear with the simple τ ≈ V/(d·t_w).\n"
			if s is ISection:
				var i_sec := s as ISection
				t += F.equation("τ ≈ V/(d·t_w)", "%s / (%s × %s)" % [Units.force(model.shear_force), Units.small_length(i_sec.d), Units.small_length(i_sec.t_w)], Units.stress(model.web_average_stress()))
				t += F.equation("exact τ_max", "", Units.stress(model.max_shear_stress()))
			else:
				t += F.note("Select the I-beam cross-section to see the numbers.")
			t += F.try_this("select the I-beam and read the τ(y) plot: almost flat in the web, tiny in the flanges.")
	return t


func fill_figures(figures: FigureArea) -> void:
	var s: CrossSection = model.section
	var c: float = s.y_max()
	var y_cut: float = value(&"y") * c
	if step() == 0:
		return
	var p := figures.plot(0)
	var pts := PackedVector2Array()
	for i: int in 201:
		var y: float = c * (2.0 * i / 200.0 - 1.0)
		var v: float = 0.0
		match step():
			1:
				v = s.first_moment(y) * 1e6       # 10^3 mm^3
			3:
				v = model.shear_flow_at(y) / 1e3  # kN/m
			_:
				v = model.shear_stress_at(y) * Units.MPA
		pts.append(Vector2(v, y * Units.MM))
	match step():
		1:
			p.begin("First moment Q(y)", "Q (10³ mm³)", "y (mm)")
		3:
			p.begin("Shear flow q(y)", "q (kN/m)", "y (mm)")
		_:
			p.begin("Shear stress τ(y)", "τ (MPa)", "y (mm)")
	p.line(pts, Color(0.3, 0.75, 1.0), 3.0, true)
	if step() <= 3:
		p.hline(y_cut * Units.MM, Color(1.0, 0.75, 0.2), "cut")


func view_direction() -> Vector3:
	return Vector3(0.35, 0.3, 1.0)


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([FACE + Vector3(-0.6, -0.75, 0.0), FACE + Vector3(0.6, 0.85, 0.0),
			PLANKS + Vector3(PLANK_LENGTH + 0.1, -0.2, 0.0), PLANKS + Vector3(0.0, 0.7, 0.0)])
