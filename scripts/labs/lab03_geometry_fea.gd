extends LabStation
## Lab 3 - Effect of geometry on the stress and strain distributions (ANSYS). A real finite
## element model (PlaneStressFem) of the cuboid, cylinder and dog-bone specimens, solved
## here so the student can see each step of what ANSYS Mechanical does.

const PLATE := Vector3(-0.6, 1.15, 0.0)
const SIZES: PackedStringArray = ["2 mm", "1 mm", "0.5 mm"]
const SIZE_VALUES: Array[float] = [0.002, 0.001, 0.0005]
const MESH: int = 1
const STRESS: int = 3
const STRAIN: int = 4
const COMPARE: int = 5
const CONVERGENCE: int = 6

var _materials: Array[LabMaterial] = [LabMaterial.steel(), LabMaterial.aluminum()]
var _view: FemPlateView = FemPlateView.new()
var _cache: Dictionary[String, PlaneStressFem] = {}


func _init() -> void:
	lab = 3
	title = "Geometry and stress distribution (ANSYS)"
	handout = "Lab Handout N°3 - Effect of Geometry on the stress and strain distribution using ANSYS.docx"
	_controls = [
		ControlSpec.choice(&"shape", "Specimen", FeaSpecimen.NAMES, 2),
		ControlSpec.choice(&"material", "Material", PackedStringArray(["Structural steel", "Aluminum alloy"]), 0),
		ControlSpec.choice(&"size", "Element size", SIZES, 1),
		ControlSpec.slider(&"d", "Displacement of the free face", "mm", Units.MM, 0.1, 2.0, 0.1, 1.0e-3, 1),
		ControlSpec.slider(&"exaggeration", "Deformation drawn ×", "", 1.0, 1.0, 10.0, 1.0, 1.0, 0),
		ControlSpec.choice(&"edges", "Show the mesh", PackedStringArray(["Yes", "No"]), 0),
	]
	_view.position = PLATE
	add_child(_view)


func _material() -> LabMaterial:
	return _materials[int(value(&"material"))]


## Solved model for a shape and element size at the current material and displacement.
func model(shape: int, size_index: int) -> PlaneStressFem:
	var key: String = "%d %d %d %.5f" % [shape, size_index, int(value(&"material")), value(&"d")]
	if not _cache.has(key):
		if _cache.size() > 12:
			_cache.clear()
		_cache[key] = FeaSpecimen.solve(shape as FeaSpecimen.Shape, SIZE_VALUES[size_index], _material(), value(&"d"))
	return _cache[key]


func _current() -> PlaneStressFem:
	return model(int(value(&"shape")), int(value(&"size")))


func _apply() -> void:
	var fem: PlaneStressFem = _current()
	var strain: bool = step() == STRAIN
	var field: PackedFloat64Array = fem.nodal_average(1 if strain else 0)
	var lo: float = INF
	var hi: float = 0.0
	for k: int in field.size():
		if field[k] > 0.0:
			lo = minf(lo, field[k])
			hi = maxf(hi, field[k])
	if step() < STRESS:
		lo = 0.0
	var fmt := func(v: float) -> String: return Units.strain(v) if strain else Units.stress(v)
	var caption: String = "%s · %s · %d elements" % [FeaSpecimen.NAMES[int(value(&"shape"))],
			"Equivalent elastic strain" if strain else "Equivalent (von Mises) stress", fem.element_count()]
	_view.show_result(fem, field, lo if is_finite(lo) else 0.0, hi, value(&"exaggeration"), value(&"edges") == 0.0, caption, fmt)


func _show_step() -> void:
	_apply()


func step_titles() -> PackedStringArray:
	return ["Objective and FEM", "Geometry and mesh", "Supports, load and solve", "Stress results",
			"Strain results", "Comparing the shapes", "Mesh size and the shoulders", "Report questions"]


func lesson_text() -> String:
	var F := LessonFormat
	var fem: PlaneStressFem = _current()
	var shape: int = int(value(&"shape"))
	var m: LabMaterial = _material()
	var d: float = value(&"d")
	var t: String = ""
	match step():
		0:
			t += "Goal: pull three specimens of different shapes (cuboid, cylinder, dog-bone) by the same amount in ANSYS Mechanical and see how the [b]geometry[/b] changes where the stress and strain go.\n"
			t += "ANSYS solves this with the [b]finite element method (FEM)[/b]. The idea, which this bench actually runs:\n"
			t += "1. Cut the body into many small, simple pieces (elements) joined at nodes: the [b]mesh[/b].\n"
			t += "2. Inside each element assume a simple displacement field (here bilinear, from the 4 corner nodes). Strains are its derivatives, stresses follow from Hooke's law.\n"
			t += "3. Each element then behaves like a small spring system: K_e·u_e = f_e. Adding all of them gives one large linear system for every nodal displacement:\n"
			t += F.equation("K·u = F", "K = stiffness matrix, u = nodal displacements, F = nodal forces")
			t += "4. Apply the supports (known displacements) and loads, solve for u, then compute the stresses and strains in every element ([b]post-processing[/b]).\n"
			t += "The answer is approximate; it improves as the elements get smaller, except where the exact answer is infinite (step 7).\n"
			t += F.note("The workflow in the handout maps to it: Geometry (SpaceClaim) → Model (mesh, supports, displacement) → Solve → Solution (equivalent stress and strain).")
			t += F.note("This bench models each specimen as a thin plate seen from the side (plane stress), a 2D version of ANSYS's 3D model. The cylinder is a 3 mm strip whose thickness gives it the same area.")
			t += handout_note()
		MESH:
			t += "Geometry of the %s (80 mm long). The mesh divides it into %s elements with %s nodes, so %s unknown displacements (2 per node):\n" % [
					FeaSpecimen.NAMES[shape], F.value(str(fem.element_count())), F.value(str(fem.used_node_count())), F.value(str(2 * fem.used_node_count()))]
			t += F.equation("element size", "", "%s × %s" % [Units.mm(fem.element_size, 2), Units.mm(fem.element_height, 2)])
			t += F.equation("narrowest cross-section", "", "%s mm²" % Units.fixed(FeaSpecimen.narrowest_area(shape) * 1e6, 2))
			t += "A [b]mesh[/b] is needed because the governing equations cannot be solved exactly for an arbitrary shape; on small elements a simple assumed field is a good approximation, and the computer can handle millions of them. Smaller elements: more accurate, but more unknowns and longer solve times. The handout asks for 1 mm elements.\n"
			t += F.try_this("switch between the shapes and element sizes and watch the element count. On the dog-bone, see how the narrow gauge gets only a few elements across with 2 mm elements.")
		2:
			var f: float = -fem.reaction_x(0)
			t += "Supports and load, as in the handout: the left face is a [b]fixed support[/b] (no displacement at all), the right face gets a [b]displacement[/b] of %s along the axis (1 mm/s, at t = 1 s). The other directions of the right face are free, so the specimen can narrow (Poisson effect).\n" % Units.mm(d, 1)
			t += "Prescribing a displacement instead of a force is how a testing machine works: the crosshead moves, the specimen resists. The solver finds every nodal displacement, and the force needed comes out as the [b]reaction[/b] at the support:\n"
			t += F.equation("reaction force", "", Units.newtons(f, 0))
			t += F.equation("hand check (springs in series)", "", Units.newtons(FeaSpecimen.hand_force(shape, m, d), 0))
			t += F.note("The solver here factors a banded matrix with %d unknowns (Cholesky). ANSYS uses the same kind of direct solver for small models." % (2 * fem.used_node_count()))
		STRESS:
			var mid: float = fem.von_mises_at(fem.nx / 2, fem.ny / 2)
			t += "Equivalent (von Mises) stress, the scalar ANSYS shows by default: it combines all stress components into one number to compare with the yield strength (chapter 7).\n"
			t += F.equation("σ_v = √(σ_x² − σ_xσ_y + σ_y² + 3τ_xy²)", "")
			t += F.equation("maximum", "", Units.stress(fem.max_value(0)))
			t += F.equation("minimum", "", Units.stress(fem.min_value(0)))
			t += F.equation("middle of the specimen", "", Units.stress(mid))
			t += F.equation("hand check σ = F/A_narrow", "", Units.stress(FeaSpecimen.hand_stress(shape, m, d)))
			t += F.note("The colors are averaged at the nodes (ANSYS's default 'averaged' contours), so the legend's top value is a little below the largest element value quoted here.")
			t += "Away from the ends, a prismatic bar is uniformly stressed: σ = E·δ/L = %s, the same for the cuboid and the cylinder whatever their areas (a displacement is imposed, not a force). Near the fixed face the stress is not uniform: the support stops the material from narrowing, which creates local extra stresses in the corners.\n" % Units.stress(m.youngs_modulus * d / FeaSpecimen.LENGTH)
			if m.youngs_modulus * d / FeaSpecimen.LENGTH > m.yield_strength:
				t += F.note("These stresses are far above the yield strength (%s): a linear elastic analysis does not know the material yields, so the numbers are only valid for small displacements. A real 1 mm pull would yield the specimen; try 0.1 mm." % Units.stress(m.yield_strength))
		STRAIN:
			t += "Equivalent elastic strain, the strain counterpart of the von Mises stress (ANSYS: 'Equivalent Elastic Strain'). For uniaxial stress it equals σ/E:\n"
			t += F.equation("maximum", "", Units.strain(fem.max_value(1)))
			t += F.equation("middle of the specimen", "", Units.strain(fem.equivalent_strain((fem.nx / 2) * fem.ny + fem.ny / 2)))
			t += F.equation("average strain δ/L", "%s / 80 mm" % Units.mm(d, 1), Units.strain(d / FeaSpecimen.LENGTH))
			t += "Strain follows the same pattern as stress (linear elastic: ε = σ/E). In the dog-bone the narrow gauge strains much more than the grips: all parts carry the same force, so the smaller section stretches more.\n"
		COMPARE:
			var rows: Array[PackedStringArray] = []
			for s: int in 3:
				var f2: PlaneStressFem = model(s, int(value(&"size")))
				rows.append(PackedStringArray([FeaSpecimen.NAMES[s], Units.stress(f2.max_value(0)), Units.stress(f2.von_mises_at(f2.nx / 2, f2.ny / 2)),
						Units.strain(f2.max_value(1)), Units.newtons(-f2.reaction_x(0), 0)]))
			t += "All three pulled by %s, %s mesh:\n" % [Units.mm(d, 1), SIZES[int(value(&"size"))]]
			t += F.table(["Shape", "σ_v max", "σ_v middle", "ε max", "Force"], rows)
			t += "• [b]Cuboid and cylinder[/b]: the same uniform stress E·δ/L in the middle, whatever their sections; only the force differs (proportional to the area). The fixed end disturbs the field over about one width (Saint-Venant).\n"
			t += "• [b]Dog-bone[/b]: the narrow gauge concentrates the deformation and carries the highest uniform stress, while the wide grips are lightly loaded. The highest values sit at the sharp shoulders, where the section changes suddenly.\n"
			t += "That is why tensile specimens are dog-bones: the gauge has a known, uniform stress state, and failure happens there, not in the grips where the clamping disturbs the stresses. Real specimens have generous fillets at the shoulders to avoid a stress concentration.\n"
		CONVERGENCE:
			var rows: Array[PackedStringArray] = []
			for k: int in 3:
				var f3: PlaneStressFem = model(FeaSpecimen.Shape.DOG_BONE, k)
				rows.append(PackedStringArray([SIZES[k], str(f3.element_count()), Units.stress(f3.von_mises_at(f3.nx / 2, f3.ny / 2)), Units.stress(f3.max_value(0))]))
			t += "The dog-bone solved with three element sizes:\n"
			t += F.table(["Element size", "Elements", "σ_v in the gauge", "σ_v max"], rows)
			t += "In the gauge the result barely changes: it has [b]converged[/b]. The maximum, at the sharp re-entrant corners of the shoulders, keeps growing as the mesh is refined. For a perfectly sharp corner the exact elastic stress is infinite (a [b]singularity[/b]), so no mesh gives 'the' maximum there. Real parts have a fillet radius, and with it the peak converges to K·σ_nominal.\n"
			t += F.note("Good practice: check results by refining the mesh; trust converged values; treat peaks at sharp corners and point supports with suspicion.")
		7:
			t += F.question("Briefly describe FEM.", "Use step 1: discretize the body into elements connected at nodes, assume a simple displacement field in each element, assemble the element stiffnesses into K·u = F, apply supports and loads, solve for the nodal displacements, and derive strains and stresses. Mention that it is approximate and converges as the mesh is refined.")
			t += F.question("What is a mesh? Why do we use it?", "The set of elements and nodes covering the geometry. It turns a continuum problem (infinitely many unknowns) into a finite number of unknowns that a computer can solve; its size controls accuracy and cost (step 2 and step 7).")
			t += F.question("Describe and compare the distributions for the three shapes.", "Use step 6 and your animations: uniform stress in the middle of the prismatic bars, equal for cuboid and cylinder; concentration at the fixed face corners; in the dog-bone the gauge carries the highest stress and strain with peaks at the shoulders. State your material: the stress values scale with E (strains do not change with E for an imposed displacement).")
			t += F.question("Conclusions", "Geometry controls where the stress goes. Sudden changes of section concentrate stress; the dog-bone shape puts the highest uniform stress in a known region, which is why it is the standard tensile specimen.")
	return t


func fill_figures(figures: FigureArea) -> void:
	if step() < STRESS or step() == 7:
		return
	var p := figures.plot(0)
	var strain: bool = step() == STRAIN
	p.begin("%s along the specimen's middle line" % ("Equivalent strain (%)" if strain else "von Mises stress (MPa)"), "x (mm)", "ε (%)" if strain else "σ_v (MPa)")
	var colors: Array[Color] = [Color(0.5, 0.8, 1.0), Color(0.5, 0.95, 0.5), Color(1.0, 0.6, 0.35)]
	var shapes: Array[int] = [0, 1, 2]
	if step() != COMPARE:
		shapes = [int(value(&"shape"))]
	for s: int in shapes:
		var fem: PlaneStressFem = model(s, int(value(&"size")))
		var pts := PackedVector2Array()
		var j: int = fem.ny / 2
		for i: int in fem.nx:
			var e: int = i * fem.ny + j
			var v: float = fem.equivalent_strain(e) * 100.0 if strain else fem.von_mises(e) * Units.MPA
			pts.append(Vector2((i + 0.5) * fem.element_size * Units.MM, v))
		p.line(pts, colors[s], 2.5)
		p.marker(pts[pts.size() / 2], colors[s], FeaSpecimen.NAMES[s])


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([PLATE + Vector3(-0.15, -0.35, 0.0), PLATE + Vector3(2.3, 0.4, 0.0)])


func view_direction() -> Vector3:
	return Vector3(0.0, 0.15, 1.0)
