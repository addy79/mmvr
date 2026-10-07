extends Station
## Chapter 2 - Stress and strain, axial loading. Left: a tension test whose specimen
## stretches, necks and breaks while the stress-strain diagram is traced. Right: a bar on
## the bench for delta = PL/AE, Poisson's ratio and thermal stress.

const SPECIMEN_SHADER: Shader = preload("res://shaders/specimen.gdshader")
const MACHINE := Vector3(-1.0, 0.0, 0.0)
const GAUGE: float = 0.6            ## drawn gauge length [m]
const SPECIMEN_RADIUS: float = 0.03
const BENCH := Vector3(0.5, 1.1, 0.0)
const BAR_DRAWN: float = 1.2        ## drawn length of the bench bar [m]
const MAX_DRAWN_STRETCH: float = 0.4
const MATERIAL_NAMES: PackedStringArray = ["Steel", "Aluminum", "Wood"]

var curve: StressStrainCurve
var member: AxialMember = AxialMember.new()

var _materials: Array[LabMaterial] = LabMaterial.presets()
var _specimen: MeshInstance3D = MeshInstance3D.new()
var _specimen_material: ShaderMaterial = ShaderMaterial.new()
var _crosshead: MeshInstance3D = MeshInstance3D.new()
var _test_arrow: Arrow3D = Arrow3D.new(Color(0.95, 0.95, 1.0), 0.018)
var _bar: MeshInstance3D = MeshInstance3D.new()
var _bar_material: ShaderMaterial = ShaderMaterial.new()
var _walls: Array[MeshInstance3D] = [MeshInstance3D.new(), MeshInstance3D.new()]
var _bar_arrow: Arrow3D = Arrow3D.new(Color(0.95, 0.95, 1.0), 0.018)
var _delta_label: Label3D = Text3D.make(36)


func _init() -> void:
	chapter = 2
	title = "Stress and strain: axial loading"
	_controls = [
		ControlSpec.choice(&"material", "Material", MATERIAL_NAMES, 0),
		ControlSpec.slider(&"eps", "Applied strain ε", "%", 100.0, 0.0, 32.0, 0.01, 0.001).only_in([0, 1, 2, 3]),
		ControlSpec.choice(&"unload", "Testing machine", PackedStringArray(["Holding load", "Unloaded"]), 0).only_in([3]),
		ControlSpec.slider(&"P", "Axial load P", "kN", Units.KN, 0.0, 150.0, 1.0, 50.0e3).only_in([4, 5]),
		ControlSpec.slider(&"L", "Bar length L", "m", 1.0, 0.5, 3.0, 0.1, 1.0).only_in([4, 6]),
		ControlSpec.slider(&"d", "Bar diameter d", "mm", Units.MM, 10.0, 60.0, 1.0, 0.025, 0).only_in([4, 5, 6]),
		ControlSpec.slider(&"dT", "Temperature change ΔT", "°C", 1.0, -60.0, 120.0, 1.0, 0.0, 0).only_in([6]),
		ControlSpec.choice(&"ends", "Bar ends", PackedStringArray(["Free", "Both fixed"]), 0).only_in([6]),
		ControlSpec.slider(&"exaggeration", "Bench deformation drawn ×", "", 1.0, 1.0, 2000.0, 1.0, 500.0, 0).only_in([4, 5, 6]),
	]
	_build_machine()
	_build_bench()


func _build_machine() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.3, 0.33, 0.38)
	for x: float in [-0.35, 0.35]:
		var column := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.04
		mesh.bottom_radius = 0.04
		mesh.height = 2.2
		column.mesh = mesh
		column.position = MACHINE + Vector3(x, 1.1, 0.0)
		column.material_override = steel
		add_child(column)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.9, 0.7, 0.5)
	base.mesh = base_mesh
	base.position = MACHINE + Vector3(0.0, 0.35, 0.0)
	base.material_override = steel
	add_child(base)
	var crosshead := BoxMesh.new()
	crosshead.size = Vector3(0.9, 0.12, 0.4)
	_crosshead.mesh = crosshead
	_crosshead.material_override = steel
	add_child(_crosshead)
	_specimen.mesh = BeamMeshBuilder.build(SectionProfile.for_section(CircleSection.new(SPECIMEN_RADIUS)), GAUGE)
	_specimen_material.shader = SPECIMEN_SHADER
	_specimen_material.set_shader_parameter("gauge_length", GAUGE)
	_specimen.material_override = _specimen_material
	_specimen.rotation.z = PI / 2.0  # gauge axis (local +X) points up
	_specimen.position = MACHINE + Vector3(0.0, 0.76, 0.0)
	add_child(_specimen)
	add_child(_test_arrow)


func _build_bench() -> void:
	_bar.mesh = BeamMeshBuilder.build(SectionProfile.for_section(CircleSection.new(0.04)), BAR_DRAWN)
	_bar_material.shader = SPECIMEN_SHADER
	_bar_material.set_shader_parameter("gauge_length", BAR_DRAWN)
	_bar.material_override = _bar_material
	_bar.position = BENCH
	add_child(_bar)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.35, 0.37, 0.4)
	for i: int in 2:
		var wall := BoxMesh.new()
		wall.size = Vector3(0.12, 0.5, 0.5)
		_walls[i].mesh = wall
		_walls[i].material_override = grey
		_walls[i].position = BENCH + Vector3(-0.06 if i == 0 else BAR_DRAWN + 0.06, 0.0, 0.0)
		add_child(_walls[i])
	add_child(_bar_arrow)
	_delta_label.position = BENCH + Vector3(BAR_DRAWN / 2.0, 0.32, 0.0)
	add_child(_delta_label)


func _apply() -> void:
	var material: LabMaterial = _materials[int(value(&"material"))]
	curve = StressStrainCurve.new(material)
	member.material = material
	member.load = 0.0 if step() == 6 else value(&"P")  # only temperature acts in the thermal step
	member.length = value(&"L")
	member.diameter = value(&"d")
	member.temperature_change = value(&"dT")
	member.ends_fixed = value(&"ends") == 1.0

	# Tension test: show the specimen at the applied strain, or after unloading.
	var eps: float = _applied_strain()
	var broken: bool = eps >= material.fracture_strain
	var unloaded: bool = value(&"unload") == 1.0 and step() == 3
	var shown_eps: float = curve.permanent_set(eps) if unloaded else eps
	var sigma: float = 0.0 if unloaded or broken else curve.stress_at(eps)
	_specimen_material.set_shader_parameter("stretch", 1.0 + shown_eps)
	_specimen_material.set_shader_parameter("diameter_ratio", curve.diameter_ratio(shown_eps))
	_specimen_material.set_shader_parameter("neck", curve.neck_reduction(eps))
	_specimen_material.set_shader_parameter("stress_ratio", sigma / material.ultimate_strength)
	_specimen_material.set_shader_parameter("broken", broken)
	var top: float = 0.76 + GAUGE * (1.0 + shown_eps) + (0.08 if broken else 0.0)
	_crosshead.position = MACHINE + Vector3(0.0, top + 0.06, 0.0)
	_test_arrow.place(MACHINE + Vector3(0.0, top + 0.14, 0.0), Vector3(0.0, 0.15 + 0.3 * sigma / material.ultimate_strength, 0.0))
	_test_arrow.label.text = "σ = %s" % Units.stress(sigma)

	# Bench bar: drawn elongation and diameter change, exaggerated.
	var k: float = value(&"exaggeration")
	var stretch: float = clampf(member.elongation() / member.length * k, -0.3, MAX_DRAWN_STRETCH / BAR_DRAWN)
	_bar_material.set_shader_parameter("stretch", 1.0 + stretch)
	_bar_material.set_shader_parameter("diameter_ratio", clampf(1.0 + member.lateral_strain() * k, 0.5, 1.5) if step() != 6 else 1.0)
	_bar_material.set_shader_parameter("stress_ratio", absf(member.stress()) / material.yield_strength)
	var free_end: float = BAR_DRAWN * (1.0 + stretch)
	_bar_arrow.place(BENCH + Vector3(free_end, 0.0, 0.0), Vector3(0.15 + 0.35 * member.load / 150.0e3, 0.0, 0.0))
	_bar_arrow.label.text = "P = " + Units.force(member.load)
	_delta_label.text = "δ = %s,  σ = %s   (drawn ×%d)" % [Units.small_length(member.elongation()), Units.stress(member.stress()), int(k)]
	var bench: bool = step() >= 4
	for node: Node3D in [_bar, _walls[0], _delta_label]:
		node.visible = bench
	_walls[1].visible = step() == 6 and member.ends_fixed
	_bar_arrow.visible = bench and step() != 6


## The strain slider, stopped at fracture.
func _applied_strain() -> float:
	return minf(value(&"eps"), curve.material.fracture_strain)


func _show_step() -> void:
	_apply()


func step_titles() -> PackedStringArray:
	return ["Tension test", "Hooke's law", "Yield to fracture", "Unloading", "Deformation PL/AE",
			"Poisson's ratio", "Thermal stress"]


func lesson_text() -> String:
	var F := LessonFormat
	var m: LabMaterial = curve.material
	var eps: float = _applied_strain()
	var t: String = ""
	match step():
		0:
			t += "A standard specimen is pulled in a testing machine while the load P and the elongation δ of the gauge length L₀ are measured. Dividing by the original area and length removes the specimen's size:\n"
			t += F.equation("σ = P/A₀", "engineering stress")
			t += F.equation("ε = δ/L₀", "engineering (normal) strain, dimensionless")
			t += "Plotting σ against ε gives the material's [b]stress-strain diagram[/b] (figure). Now: ε = %s, σ = %s.\n" % [F.value(Units.strain(eps)), F.value(Units.stress(curve.stress_at(eps)))]
			t += "Reading the curve from left to right: a steep straight [b]elastic[/b] part, [b]yielding[/b] (large strain at almost constant stress), [b]strain hardening[/b] up to the ultimate strength σ_U, then [b]necking[/b] and [b]fracture[/b].\n"
			t += F.try_this("drag the strain slider slowly from 0 to 30 % with steel and watch the specimen yield, harden, neck and break.")
		1:
			var ey: float = curve.yield_strain()
			t += "In the elastic region stress is proportional to strain: [b]Hooke's law[/b]. The slope is the modulus of elasticity E, a stiffness property of the material.\n"
			t += F.equation("σ = E·ε", "%s × %s" % [Units.modulus(m.youngs_modulus), Units.strain(minf(eps, ey))], Units.stress(curve.stress_at(minf(eps, ey))))
			t += F.equation("ε_Y = σ_Y/E", "%s / %s" % [Units.stress(m.yield_strength), Units.modulus(m.youngs_modulus)], Units.strain(ey))
			t += "Elastic strains are tiny: steel yields at about 0.1 %. Inside this range the specimen returns exactly to its original length when unloaded.\n"
			t += "The area under the elastic part is the energy stored per unit volume, the [b]modulus of resilience[/b]:\n"
			t += F.equation("u_Y = σ_Y²/(2E)", "", Units.energy_density(curve.modulus_of_resilience()))
			t += F.try_this("compare steel and aluminum: E is 200 vs 70 GPa, so aluminum stretches about three times more at the same stress.")
		2:
			t += "Past ε_Y the material [b]yields[/b]: it keeps stretching with little extra stress (mild steel shows a flat plateau, aluminum a gradual curve). Then [b]strain hardening[/b] raises the stress to the ultimate strength, where the specimen starts to [b]neck[/b] and the engineering stress falls until fracture.\n"
			t += F.equation("σ_Y", "", Units.stress(m.yield_strength))
			t += F.equation("σ_U", "", Units.stress(m.ultimate_strength))
			t += F.equation("ductility: elongation at fracture", "", "%.0f %%" % (100.0 * m.fracture_strain))
			t += F.equation("modulus of toughness u_T = ∫σ dε", "", Units.energy_density(curve.modulus_of_toughness()))
			t += "Ductile materials (steel, aluminum) give warning by stretching a lot; [b]brittle[/b] materials (here, wood along the grain) break at small strain without yielding.\n"
			t += F.try_this("switch to wood: the diagram is a straight line that ends abruptly, and the toughness is tiny.")
		3:
			var set_eps: float = curve.permanent_set(eps)
			t += "If the load is removed after yielding, the specimen unloads along a straight line [b]parallel to the elastic line[/b] (slope E). Only the elastic part of the strain is recovered; the rest is a [b]permanent set[/b].\n"
			t += F.equation("ε_p = ε − σ/E", "%s − %s / %s" % [Units.strain(eps), Units.stress(curve.stress_at(eps)), Units.modulus(m.youngs_modulus)], Units.strain(set_eps))
			t += "Reloading follows the same line up to the previous stress: the material now behaves elastically to a higher stress (cold working).\n"
			t += F.try_this("pull steel to 5 %, then switch the machine to 'Unloaded': the specimen stays longer by the permanent set.")
		4:
			t += "For a bar in the elastic range, combine σ = P/A, ε = δ/L and σ = Eε:\n"
			t += F.equation("δ = P·L/(A·E)", "%s × %s / (%s × %s)" % [Units.force(member.load), Units.length(member.length), Units.area(member.area()), Units.modulus(member.material.youngs_modulus)], Units.small_length(member.elongation()))
			t += F.equation("σ = P/A", "", Units.stress(member.stress()))
			t += "The bar acts like a spring of stiffness k = AE/L = %s.\n" % F.value("%.1f MN/m" % (member.stiffness() / 1.0e6))
			t += F.note("The bench bar is drawn with its deformation exaggerated; the specimen on the left is drawn at true strain.")
			t += F.try_this("double L: δ doubles. Double d: A is four times larger, so δ drops to a quarter.")
		5:
			t += "A bar that stretches also gets thinner. The ratio of lateral to axial strain is [b]Poisson's ratio[/b] ν, a material constant (about 0.3 for metals):\n"
			t += F.equation("ε_lateral = −ν·ε_axial", "−%.2f × %s" % [member.material.poisson_ratio, Units.strain(member.strain())], Units.strain(member.lateral_strain()))
			t += F.equation("Δd = ε_lateral·d", "", "%.4f mm" % (member.diameter_change() * 1e3))
			t += "E, ν and the shear modulus G are related for isotropic materials:\n"
			t += F.equation("G = E/(2(1 + ν))", "", Units.modulus(member.material.shear_modulus()))
			t += F.try_this("pull harder and watch the drawn bar neck down along its whole length (exaggerated).")
		6:
			var a: float = member.material.thermal_expansion
			var free := AxialMember.new()
			free.material = member.material
			free.length = member.length
			free.load = 0.0
			free.temperature_change = member.temperature_change
			var held := AxialMember.new()
			held.material = member.material
			held.ends_fixed = true
			held.temperature_change = member.temperature_change
			t += "Heating makes a bar grow: thermal strain ε_T = α·ΔT. If it is free, nothing resists, so there is [b]no stress[/b]:\n"
			t += F.equation("δ_T = α·ΔT·L", "%.1f×10⁻⁶/°C × %s × %s" % [a * 1e6, Units.temperature_change(member.temperature_change), Units.length(member.length)], Units.small_length(free.elongation()))
			t += "Held between two walls, the bar cannot change length (δ = 0). The walls push back with exactly the force that would squeeze the free expansion out (superposition: δ_T + δ_P = 0):\n"
			t += F.equation("σ = −E·α·ΔT", "−%s × %.1f×10⁻⁶ × %s" % [Units.modulus(member.material.youngs_modulus), a * 1e6, Units.temperature_change(member.temperature_change)], Units.stress(held.stress()))
			t += F.note("The thermal stress does not depend on L or on the cross-section, only on E·α·ΔT.")
			t += F.try_this("fix both ends and heat steel by 100 °C: about −234 MPa, close to yield. Rails and bridges need expansion joints.")
	return t


func fill_figures(figures: FigureArea) -> void:
	var m: LabMaterial = curve.material
	var eps: float = _applied_strain()
	match step():
		0, 2, 3:
			var p := figures.plot(0)
			p.begin("Stress-strain diagram (%s)" % m.display_name, "ε (%)", "σ (MPa)")
			p.line(_curve_points(m.fracture_strain), Color(0.95, 0.75, 0.35), 3.0, step() == 2)
			p.marker(Vector2(eps * 100.0, curve.stress_at(eps) * Units.MPA), Color(1, 1, 1), "now")
			if m.behavior != LabMaterial.Behavior.BRITTLE:
				p.hline(m.yield_strength * Units.MPA, Color(0.5, 0.8, 1.0), "σ_Y")
			p.hline(m.ultimate_strength * Units.MPA, Color(1.0, 0.5, 0.4), "σ_U")
			if step() == 3:
				var ep: float = curve.permanent_set(eps)
				p.line(PackedVector2Array([Vector2(eps * 100.0, curve.stress_at(eps) * Units.MPA), Vector2(ep * 100.0, 0.0)]),
						Color(0.4, 0.9, 1.0), 2.5)
				p.marker(Vector2(ep * 100.0, 0.0), Color(0.4, 0.9, 1.0), "permanent set")
		1:
			var p := figures.plot(0)
			var ey: float = curve.yield_strain()
			p.begin("Elastic region (shaded area = resilience)", "ε (%)", "σ (MPa)")
			p.line(_curve_points(minf(3.0 * ey, m.fracture_strain)), Color(0.95, 0.75, 0.35), 3.0)
			p.line(PackedVector2Array([Vector2.ZERO, Vector2(ey * 100.0, m.yield_strength * Units.MPA)]), Color(0.4, 0.9, 0.5), 3.0, true)
			p.marker(Vector2(ey * 100.0, m.yield_strength * Units.MPA), Color(0.5, 0.8, 1.0), "yield")
			p.marker(Vector2(minf(eps, 3.0 * ey) * 100.0, curve.stress_at(minf(eps, 3.0 * ey)) * Units.MPA), Color(1, 1, 1), "now")
		4:
			var p := figures.plot(0)
			p.begin("Load-elongation: a straight line of slope AE/L", "δ (mm)", "P (kN)")
			var probe := AxialMember.new()
			probe.material = member.material
			probe.length = member.length
			probe.diameter = member.diameter
			probe.load = 150.0e3
			p.line(PackedVector2Array([Vector2.ZERO, Vector2(probe.elongation() * Units.MM, 150.0)]), Color(0.95, 0.75, 0.35), 3.0)
			p.marker(Vector2(member.elongation() * Units.MM, member.load * Units.KN), Color(1, 1, 1), "now")
		6:
			var p := figures.plot(0)
			p.begin("Fixed ends: thermal stress vs ΔT", "ΔT (°C)", "σ (MPa)")
			var probe := AxialMember.new()
			probe.material = member.material
			probe.ends_fixed = true
			var pts := PackedVector2Array()
			for d_t: float in [-60.0, 120.0]:
				probe.temperature_change = d_t
				pts.append(Vector2(d_t, probe.stress() * Units.MPA))
			p.line(pts, Color(0.4, 0.7, 1.0), 3.0)
			p.hline(-member.material.yield_strength * Units.MPA, Color(1.0, 0.4, 0.4), "−σ_Y")
			probe.temperature_change = member.temperature_change
			p.marker(Vector2(member.temperature_change, probe.stress() * Units.MPA), Color(1, 1, 1), "now")


func _curve_points(eps_end: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var ey: float = curve.yield_strain()
	pts.append(Vector2.ZERO)
	pts.append(Vector2(minf(ey, eps_end) * 100.0, curve.stress_at(minf(ey, eps_end)) * Units.MPA))
	for i: int in 301:
		var e: float = ey + (eps_end - ey) * i / 300.0
		if e > ey:
			pts.append(Vector2(e * 100.0, curve.stress_at(e) * Units.MPA))
	return pts


func frame_points() -> PackedVector3Array:
	return PackedVector3Array([MACHINE + Vector3(-0.5, 0.0, 0.3), MACHINE + Vector3(-0.5, 2.2, 0.0),
			BENCH + Vector3(BAR_DRAWN + 0.6, -0.3, 0.3), BENCH + Vector3(BAR_DRAWN + 0.6, 0.5, 0.0)])
