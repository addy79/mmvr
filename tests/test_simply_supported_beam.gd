extends PhysicsTestCase
## Simply supported beam vs. hand calculations.
## Reference beam: L = 4 m, P = 10 kN, steel E = 200 GPa, rectangle 100 x 200 mm
## (I = 6.6667e-5 m^4, c = 0.1 m, Q(0) = 5e-4 m^3, t = 0.1 m), so EI = 1.3333e7 N*m^2.

const L: float = 4.0
const P: float = 10000.0


func _beam(a: float) -> SimplySupportedBeam:
	return SimplySupportedBeam.new(L, P, a, RectSection.new(0.1, 0.2), LabMaterial.steel())


# a = 1, b = 3: R_A = 10000*3/4 = 7500 N, R_B = 10000*1/4 = 2500 N
func test_reactions() -> void:
	var beam := _beam(1.0)
	assert_within_1pct(beam.reaction_a(), 7500.0, "R_A")
	assert_within_1pct(beam.reaction_b(), 2500.0, "R_B")
	assert_within_1pct(beam.reaction_a() + beam.reaction_b(), P, "sum Fy = 0")


# a = 1: V = +7500 N left of the load, -2500 N right of it.
# M(0.5) = 7500*0.5 = 3750 N*m, M(1) = 7500 N*m = P*a*b/L, M(3) = 2500*(4 - 3) = 2500 N*m
func test_shear_and_moment() -> void:
	var beam := _beam(1.0)
	assert_within_1pct(beam.shear_at(0.5), 7500.0, "V left")
	assert_within_1pct(beam.shear_at(2.0), -2500.0, "V right")
	assert_within_1pct(beam.moment_at(0.5), 3750.0, "M(0.5)")
	assert_within_1pct(beam.moment_at(1.0), 7500.0, "M(a)")
	assert_within_1pct(beam.moment_at(3.0), 2500.0, "M(3)")
	assert_within_1pct(beam.max_moment(), 7500.0, "M_max")
	assert_within_1pct(beam.max_shear(), 7500.0, "|V|max = R_A")
	assert_within_1pct(_beam(3.5).max_shear(), 8750.0, "|V|max = R_B = 10000*3.5/4")
	assert_almost_eq(beam.moment_at(0.0), 0.0, 1e-9, "M(0) = 0")
	assert_almost_eq(beam.moment_at(L), 0.0, 1e-9, "M(L) = 0")


# Central load: v_max = P*L^3/(48*E*I) = 10000*64/(48*1.3333e7) = 1.0e-3 m, at x = L/2
func test_central_load_deflection() -> void:
	var beam := _beam(2.0)
	assert_within_1pct(beam.deflection_at(2.0), 1.0e-3, "v(L/2) vs PL^3/48EI")
	assert_within_1pct(beam.max_deflection(), 1.0e-3, "v_max")
	assert_within_1pct(beam.max_deflection_position(), 2.0, "x at v_max")


# a = 1, b = 3, 6EIL = 6*1.3333e7*4 = 3.2e8:
#   v(1) = 10000*3*1*(16 - 9 - 1)/3.2e8 = 5.625e-4 m  (= P*a^2*b^2/(3EIL))
#   v(3) = 10000*1*1*(16 - 1 - 1)/3.2e8 = 4.375e-4 m  (mirrored branch)
#   x_m = 4 - sqrt((16 - 1)/3) = 1.7639 m
#   v_max = 10000*1*15^1.5/(9*sqrt(3)*1.3333e7*4) = 6.988e-4 m
func test_off_center_deflection() -> void:
	var beam := _beam(1.0)
	assert_within_1pct(beam.deflection_at(1.0), 5.625e-4, "v(a)")
	assert_within_1pct(beam.deflection_at(3.0), 4.375e-4, "v(3)")
	assert_within_1pct(beam.max_deflection_position(), 1.7639, "x_m")
	assert_within_1pct(beam.max_deflection(), 6.988e-4, "v_max")


# Supports don't move, and the curve is continuous where the formula switches at x = a.
func test_deflection_boundary_conditions() -> void:
	var beam := _beam(1.3)
	assert_almost_eq(beam.deflection_at(0.0), 0.0, 1e-12, "v(0)")
	assert_almost_eq(beam.deflection_at(L), 0.0, 1e-12, "v(L)")
	assert_within_1pct(beam.deflection_at(1.3 + 1e-6), beam.deflection_at(1.3), "continuity at a")


# The closed-form v_max must be the largest sampled value.
func test_max_deflection_is_maximum_of_curve() -> void:
	var beam := _beam(3.1)
	var sampled: float = 0.0
	for i: int in 4001:
		sampled = maxf(sampled, beam.deflection_at(L * i / 4000.0))
	assert_within_1pct(beam.max_deflection(), sampled, "closed form vs sampled")


# a = 1, at the load M = 7500 N*m:
#   bottom fiber sigma = -7500*(-0.1)/6.6667e-5 = +11.25 MPa (tension)
#   top fiber = -11.25 MPa (compression), neutral axis = 0
func test_bending_stress() -> void:
	var beam := _beam(1.0)
	assert_within_1pct(beam.bending_stress(1.0, -0.1), 11.25e6, "bottom tension")
	assert_within_1pct(beam.bending_stress(1.0, 0.1), -11.25e6, "top compression")
	assert_almost_eq(beam.bending_stress(1.0, 0.0), 0.0, 1e-6, "neutral axis")
	assert_within_1pct(beam.max_bending_stress(), 11.25e6, "sigma_max")


# a = 1, left segment V = 7500 N:
#   tau(NA) = 7500*5e-4/(6.6667e-5*0.1) = 0.5625 MPa (= 1.5*V/A)
#   tau(y = 0.05) = 7500*3.75e-4/(6.6667e-5*0.1) = 0.4219 MPa
func test_shear_stress() -> void:
	var beam := _beam(1.0)
	assert_within_1pct(beam.shear_stress(0.5, 0.0), 0.5625e6, "tau at NA")
	assert_within_1pct(beam.shear_stress(0.5, 0.05), 0.42188e6, "tau at c/2")
	assert_almost_eq(beam.shear_stress(0.5, 0.1), 0.0, 1e-6, "tau at free surface")
	assert_within_1pct(beam.max_shear_stress(), 0.5625e6, "tau_max")


# FS = 250 MPa / 11.25 MPa = 22.22
func test_factor_of_safety() -> void:
	assert_within_1pct(_beam(1.0).factor_of_safety(), 22.222, "FS")
	var unloaded := SimplySupportedBeam.new(L, 0.0, 1.0, RectSection.new(0.1, 0.2), LabMaterial.steel())
	assert_eq(unloaded.factor_of_safety(), INF, "unloaded FS")


# Load on a support: everything goes into one reaction, no bending.
func test_load_at_support() -> void:
	var beam := _beam(0.0)
	assert_within_1pct(beam.reaction_a(), P, "R_A = P")
	assert_almost_eq(beam.max_moment(), 0.0, 1e-9, "M_max")
	assert_almost_eq(beam.max_deflection(), 0.0, 1e-12, "v_max")


func _udl_beam(w: float, p: float) -> SimplySupportedBeam:
	var beam := SimplySupportedBeam.new(L, p, 1.0, RectSection.new(0.1, 0.2), LabMaterial.steel())
	beam.distributed_load = w
	return beam


# Uniform load only, w = 5 kN/m: M_max = wL^2/8 = 10 kN*m at L/2,
# v_max = 5wL^4/(384EI) = 5*5000*256/(384*1.3333e7) = 1.25e-3 m at L/2
func test_uniform_load() -> void:
	var beam := _udl_beam(5000.0, 0.0)
	assert_within_1pct(beam.reaction_a(), 10000.0, "R_A = wL/2")
	assert_within_1pct(beam.max_moment(), 10000.0, "wL^2/8")
	assert_within_1pct(beam.max_moment_position(), 2.0, "at midspan")
	assert_within_1pct(beam.max_deflection(), 1.25e-3, "5wL^4/384EI")
	assert_within_1pct(beam.max_deflection_position(), 2.0, "at midspan")


# P = 10 kN at a = 1 plus w = 5 kN/m:
#   R_A = 7500 + 10000 = 17500 N, R_B = 2500 + 10000 = 12500 N
#   V = 0 right of the load at x = (R_A - P)/w = 1.5 m: M = 17500*1.5 - 5000*1.5^2/2 - 10000*0.5 = 15625 N*m
#   v_max = 1.9414e-3 m at x = 1.917 m (found by sampling the superposed curve)
func test_point_plus_uniform_load() -> void:
	var beam := _udl_beam(5000.0, 10000.0)
	assert_within_1pct(beam.reaction_a(), 17500.0, "R_A")
	assert_within_1pct(beam.reaction_b(), 12500.0, "R_B")
	assert_within_1pct(beam.max_moment_position(), 1.5, "x where V = 0")
	assert_within_1pct(beam.max_moment(), 15625.0, "M_max")
	assert_within_1pct(beam.max_deflection(), 1.9414e-3, "v_max")
	assert_within_1pct(beam.max_deflection_position(), 1.917, "x of v_max")


# The slope is the derivative of the deflection (central difference check), and EI*v'' = -M.
func test_slope_and_curvature_are_consistent() -> void:
	var beam := _udl_beam(5000.0, 10000.0)
	var h: float = 1e-4
	for x: float in [0.4, 1.7, 3.2]:
		var numeric: float = (beam.deflection_at(x + h) - beam.deflection_at(x - h)) / (2.0 * h)
		assert_within_1pct(beam.slope_at(x), numeric, "dv/dx at %.1f" % x)
		var curvature: float = (beam.slope_at(x + h) - beam.slope_at(x - h)) / (2.0 * h)
		assert_within_1pct(beam.flexural_rigidity() * curvature, -beam.moment_at(x), "EI v'' = -M at %.1f" % x)


# Shear flow q = VQ/I: 7500*5e-4/6.6667e-5 = 56250 N/m at the neutral axis, left of the load
func test_shear_flow() -> void:
	assert_within_1pct(_beam(1.0).shear_flow(0.5, 0.0), 56250.0, "q at NA")
