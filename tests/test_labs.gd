extends PhysicsTestCase
## Lab experiments: models checked against hand calculations.


# (1, 2), (2, 4.1), (3, 5.9): n = 3, Sx = 6, Sy = 12, Sxx = 14, Sxy = 27.9
#   m = (3*27.9 - 6*12)/(3*14 - 36) = 1.95, b = (12 - 1.95*6)/3 = 0.1; through 0: m = 27.9/14
func test_linear_fit() -> void:
	var pts := PackedVector2Array([Vector2(1, 2), Vector2(2, 4.1), Vector2(3, 5.9)])
	var fit := LinearFit.of(pts)
	assert_within_1pct(fit.slope, 1.95, "slope")
	assert_within_1pct(fit.intercept, 0.1, "intercept")
	assert_gt(fit.r_squared, 0.99, "R^2")
	assert_within_1pct(LinearFit.of(pts, true).slope, 1.992857, "through origin")


# MTTU, pure aluminum, A = 2 x 5 = 10 mm^2, L0 = 50 mm, k = 200 N/mm. One step (0.5 mm):
#   F*(1/200 + 50/(69000*10)) = 0.5 mm  =>  F = 98.57 N, sigma = 9.857 MPa, dL = 0.4929 mm,
#   delta = 0.00714 mm, RC = 10 - 0.4929 = 9.507 mm
func test_tensile_rig_elastic_step() -> void:
	var rig := TensileRig.new()
	var s: Dictionary = rig.state_at(1)
	assert_within_1pct(s.force, 98.57, "F")
	assert_within_1pct(s.stress, 9.857e6, "sigma")
	assert_within_1pct(s.spring, 0.49286e-3, "dL")
	assert_within_1pct(s.elongation, 0.00714e-3, "delta")
	assert_within_1pct(s.dial, 9.5071e-3, "RC")


# Ten steps (5 mm): F/k + eps*L0 = 5 mm with sigma on the hardening parabola
#   sigma = 76 - 48*((0.25 - eps)/(0.25 - 0.000406))^2 MPa  =>  eps = 0.05385, sigma = 46.25 MPa.
# Fracture: L_up(eps_f) = 0.8*76*10/200 + 0.39*50 = 22.54 mm = 45.08 steps -> broken at step 46.
func test_tensile_rig_plastic_and_fracture() -> void:
	var rig := TensileRig.new()
	assert_within_1pct(rig.state_at(10).stress, 46.25e6, "sigma after 10 steps")
	assert_within_1pct(rig.state_at(10).strain, 0.05385, "eps after 10 steps")
	assert_eq(rig.steps_to_fracture(), 46, "breaks at step 46")
	assert_true(rig.state_at(46).broken, "broken")
	assert_eq(rig.state_at(46).force, 0.0, "no force once broken")


# Uniform bar 80 x 10 mm, t = 3 mm, steel, pulled 0.1 mm with free lateral contraction:
#   sigma = E*delta/L = 250 MPa everywhere, reaction = 250 MPa*30 mm^2 = 7500 N,
#   eps_eq = 0.00125, top edge moves -nu*eps*H = -3.75e-3 mm.
func test_fem_uniform_bar() -> void:
	var fem := PlaneStressFem.new(0.08, 0.01, 0.002, func(_x: float, _y: float) -> bool: return true)
	fem.thickness = 0.003
	for j: int in fem.ny + 1:
		fem.prescribe(0, j, 0, 0.0)
		fem.prescribe(fem.nx, j, 0, 1.0e-4)
	fem.prescribe(0, 0, 1, 0.0)
	fem.solve()
	assert_eq(fem.element_count(), 200, "40 x 5 elements")
	assert_within_1pct(fem.max_value(0), 250.0e6, "max von Mises")
	assert_within_1pct(fem.min_value(0), 250.0e6, "min von Mises")
	assert_within_1pct(fem.max_value(1), 0.00125, "equivalent strain")
	assert_within_1pct(-fem.reaction_x(0), 7500.0, "reaction")
	assert_within_1pct(fem.displacement(fem.nx, fem.ny).y, -3.75e-6, "Poisson contraction")


# Cantilever 100 x 10 mm, t = 1 mm, steel, 100 N down at the free end:
#   PL^3/(3EI) + PL/(kGA) = 100*0.1^3/(3*200e9*8.333e-11) + 100*0.1/(5/6*76.92e9*1e-5) = 2.0156 mm
# (within 3%: the clamped edge also stops the section from warping).
func test_fem_cantilever_bending() -> void:
	var fem := PlaneStressFem.new(0.1, 0.01, 0.001, func(_x: float, _y: float) -> bool: return true)
	for j: int in fem.ny + 1:
		fem.fix(0, j)
		fem.add_force(fem.nx, j, 1, -100.0 / fem.ny * (0.5 if j == 0 or j == fem.ny else 1.0))
	fem.solve()
	assert_almost_eq(-fem.displacement(fem.nx, fem.ny / 2).y, 2.0156e-3, 0.03 * 2.0156e-3, "tip deflection")


# Signpost (handout values), post 0.5 x 0.5 m: N = 11000 + 1340*4 = 16360 N,
#   M_x = 700*8.5^3/3 = 143.30 kN*m, M_y = 3600*(8.5 + 1.25) = 35.10 kN*m, S = 0.5^3/6,
#   sigma = -0.0654 + 6.878 + 1.685 = 8.497 MPa (tension), -8.628 MPa (compression).
func test_signpost_base_stresses() -> void:
	var s := Signpost.new()
	assert_within_1pct(s.base_axial_force(), 16360.0, "N")
	assert_within_1pct(s.base_shear_x(), 25287.5, "V_x")
	assert_within_1pct(s.moment_x_at(0.0), 143295.8, "M_x")
	assert_within_1pct(s.moment_y_at(0.0), 35100.0, "M_y")
	assert_within_1pct(s.max_tension_stress(), 8.497e6, "sigma_t")
	assert_within_1pct(s.max_compression_stress(), -8.628e6, "sigma_c")
	assert_within_1pct(s.max_von_mises(), 8.628e6, "von Mises at a corner")


# Triangular load (w0 = 700*8.5 = 5950 N/m at the top): v = 11*w0*L^4/(120EI) = 2.733 mm,
# theta = w0*L^3/(8EI) = 4.385e-4, sign top: 2.733 + 0.4385*2.5 = 3.829 mm.
# y: F = 3600 N and M = 3600*1.25 at the post top: v = FL^3/3EI + ML^2/2EI = 0.8635 mm,
# theta = 1.6157e-4, sign top: 1.2674 mm.
func test_signpost_deflections() -> void:
	var s := Signpost.new()
	assert_within_1pct(s.post_deflection(8.5, 0), 2.733e-3, "post top, x")
	assert_within_1pct(s.sign_top_displacement().x, 3.829e-3, "sign top, x")
	assert_within_1pct(s.post_deflection(8.5, 1), 0.8635e-3, "post top, y")
	assert_within_1pct(s.sign_top_displacement().y, 1.2674e-3, "sign top, y")


# Overhang: L = 0.5, s = 0.4, P = 10 N at the tip, 20 x 4 mm steel bar (EI = 21.333 N*m^2):
#   R_B = 10*0.5/0.4 = 12.5 N, R_A = -2.5 N, M_B = -1 N*m,
#   v_tip = P*c^2*(s + c)/(3EI) = 10*0.01*0.5/64 = 0.78125 mm
func test_overhang_beam() -> void:
	var b := OverhangBeam.new(0.5, 10.0, 0.5, RectSection.new(0.02, 0.004), LabMaterial.steel(), 0.4)
	assert_within_1pct(b.reaction_b(), 12.5, "R_B")
	assert_within_1pct(b.reaction_a(), -2.5, "R_A")
	assert_within_1pct(b.moment_at(0.4), -1.0, "M_B")
	assert_within_1pct(b.deflection_at(0.5), 7.8125e-4, "tip")
	assert_almost_eq(b.deflection_at(0.4), 0.0, 1e-12, "no deflection at B")
	var ss := SimplySupportedBeam.new(0.5, 10.0, 0.2, RectSection.new(0.02, 0.004), LabMaterial.steel())
	var as_ss := OverhangBeam.new(0.5, 10.0, 0.2, RectSection.new(0.02, 0.004), LabMaterial.steel(), 0.5)
	assert_within_1pct(as_ss.deflection_at(0.3), ss.deflection_at(0.3), "s = L is simply supported")


# Shear deflection of a 30 x 60 mm steel cantilever, L = 0.4 m, P = 1 kN:
#   P*L/(G*5A/6) = 1000*0.4/(76.923e9*1.5e-3) = 3.467e-6 m. Box 30 x 60 x 5: A_s = 2*5*60 mm^2.
func test_shear_deflection() -> void:
	var c := CantileverBeam.new(0.4, 1000.0, 0.4, RectSection.new(0.03, 0.06), LabMaterial.steel())
	assert_within_1pct(c.shear_deflection_at_tip(), 3.467e-6, "rectangle")
	assert_within_1pct(BoxSection.new(0.03, 0.06, 0.005).shear_area(), 6.0e-4, "box webs")


# Lab 3 hand estimates, steel, pulled 1 mm: prismatic sigma = 200e9*1/80 = 2500 MPa;
# dog-bone F = 1/(40/(200000*20) + 40/(200000*6)) N/mm... = 1e-3/(2*0.02/(200e9*2e-5) + 0.04/(200e9*6e-6))
#   = 23077 N, sigma = 23077/6e-6 = 3846 MPa. The FEM gauge-middle stress is within 6 %.
func test_fea_specimens() -> void:
	var steel := LabMaterial.steel()
	assert_within_1pct(FeaSpecimen.hand_stress(FeaSpecimen.Shape.CUBOID, steel, 1e-3), 2500.0e6, "cuboid")
	assert_within_1pct(FeaSpecimen.hand_force(FeaSpecimen.Shape.DOG_BONE, steel, 1e-3), 23077.0, "dog-bone F")
	assert_within_1pct(FeaSpecimen.hand_stress(FeaSpecimen.Shape.DOG_BONE, steel, 1e-3), 3846.2e6, "dog-bone sigma")
	var fem := FeaSpecimen.solve(FeaSpecimen.Shape.DOG_BONE, 0.001, steel, 1e-3)
	assert_almost_eq(fem.von_mises_at(fem.nx / 2, fem.ny / 2), 3846.2e6, 0.06 * 3846.2e6, "FEM gauge stress")
	var cyl := FeaSpecimen.solve(FeaSpecimen.Shape.CYLINDER, 0.001, steel, 1e-3)
	assert_within_1pct(-cyl.reaction_x(0), 2500.0e6 * PI * 0.0015 * 0.0015, "cylinder force = sigma*A")


# Lab 5: steel, d = 6 mm (J = pi*0.003^4/2 = 1.2723e-10 m^4), L = 0.3 m, arm 0.1 m, F = 15 N:
#   phi = F*r*L/(G*J) = 1.5*0.3/(76.923e9*1.2723e-10) = 0.04598 rad = 2.634 deg,
#   slope J*G/(r*L) = 326.2 N/rad, and G back from that slope.
func test_torsion_lever() -> void:
	var s := TorsionShaft.new()
	s.outer_radius = 0.003
	s.length = 0.3
	s.torque = 15.0 * 0.1
	assert_within_1pct(s.angle_of_twist(), 0.04598, "phi")
	assert_within_1pct(s.load_per_radian(0.1), 326.2, "slope")
	assert_within_1pct(s.modulus_from_slope(326.2, 0.1), 76.923e9, "G from slope")


# Lab 9: 400 g at x = 0.15 m, L = 0.44 m, cut at 0.30 m, a = 0.105 m:
#   W = 3.924 N, Q = W*x/L = 1.3377 N (W1 = 136.4 g), M = Q*(L - c) = 0.18728 N*m (W2 = 181.8 g)
func test_shear_moment_rig() -> void:
	var r := ShearMomentRig.new()
	r.load_mass = 0.4
	assert_within_1pct(r.theoretical_shear(), 1.3377, "Q")
	assert_within_1pct(r.theoretical_moment(), 0.18728, "M")
	assert_within_1pct(r.shear_hanger_mass(), 0.13637, "W1")
	assert_within_1pct(r.moment_hanger_mass(), 0.18182, "W2")
	assert_within_1pct(r.moment_from_mass(0.18182), 0.18728, "M back from W2")


# W200x52 (d 206, b_f 204, t_f 12.6, t_w 7.9 mm), propped cantilever, L = 1 m, w = 200 kN/m:
#   I = (204*206^3 - 196.1*180.8^3)/12 = 52.03e6 mm^4; at the wall M = wL^2/8 = 25 kN*m,
#   V = 5wL/8 = 125 kN. Fiber: sigma = 25e3*0.103/52.03e-6 = 49.49 MPa. Junction (y = 90.4 mm):
#   sigma = 43.44 MPa, Q = 204*12.6*96.7 = 248.6e3 mm^3, tau = 125e3*248.6e-6/(52.03e-6*7.9e-3) = 75.6 MPa,
#   sigma_v = sqrt(43.44^2 + 3*75.6^2) = 137.9 MPa. Neutral axis: Q = 248.6e3 + 7.9*90.4^2/2
#   = 280.8e3 mm^3, tau = 85.40 MPa, sigma_v = sqrt(3)*85.40 = 147.9 MPa: the web governs.
func test_i_beam_von_mises() -> void:
	var beam := ProppedCantileverBeam.new(1.0, 0.0, 0.5, ISection.new(0.206, 0.204, 0.0126, 0.0079), LabMaterial.steel())
	beam.distributed_load = 200.0e3
	assert_within_1pct(beam.section.moment_of_inertia(), 52.03e-6, "I")
	assert_within_1pct(absf(beam.moment_at(0.0)), 25.0e3, "M at the wall")
	assert_within_1pct(beam.max_bending_stress(), 49.49e6, "fiber stress")
	assert_within_1pct(beam.von_mises(0.0, 0.0904 - 1e-7), 137.9e6, "junction von Mises")
	assert_within_1pct(beam.max_von_mises(), 147.9e6, "largest: web at the neutral axis")


# Lab 11: steel cantilever 30 x 60 mm (load along the 60 mm), L = 0.5 m, P = 2 kN at the tip:
#   I = 30*60^3/12 = 5.4e-7 m^4, v_b = PL^3/(3EI) = 0.7716 mm, sigma = PLc/I = 55.56 MPa,
#   Tresca max shear = sigma/2 = 27.78 MPa (top fiber at the wall; tau_NA = 1.5V/A = 1.667 MPa).
#   Turned (load along 30 mm): I/4, so v = 3.086 mm and sigma = 111.1 MPa.
func test_narrow_vs_usual() -> void:
	var usual := CantileverBeam.new(0.5, 2000.0, 0.5, RectSection.new(0.03, 0.06), LabMaterial.steel())
	var narrow := CantileverBeam.new(0.5, 2000.0, 0.5, RectSection.new(0.06, 0.03), LabMaterial.steel())
	assert_within_1pct(usual.deflection_at(0.5), 0.7716e-3, "usual deflection")
	assert_within_1pct(usual.max_bending_stress(), 55.56e6, "usual sigma")
	assert_within_1pct(usual.max_combined_shear(), 27.78e6, "Tresca shear")
	assert_within_1pct(usual.max_shear_stress(), 1.667e6, "transverse shear")
	assert_within_1pct(narrow.deflection_at(0.5), 3.086e-3, "narrow deflection")
	assert_within_1pct(narrow.max_bending_stress(), 111.1e6, "narrow sigma")
