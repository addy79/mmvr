extends PhysicsTestCase
## Simply supported beam vs. hand calculations.
## Reference beam: L = 4 m, P = 10 kN, steel E = 200 GPa, rectangle 100 x 200 mm
## (I = 6.6667e-5 m^4, c = 0.1 m, Q(0) = 5e-4 m^3, t = 0.1 m), so EI = 1.3333e7 N*m^2.

const L: float = 4.0
const P: float = 10000.0


func _beam(a: float) -> SimplySupportedBeam:
	return SimplySupportedBeam.new(L, P, a, RectSection.new(0.1, 0.2), BeamMaterial.steel())


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
	var unloaded := SimplySupportedBeam.new(L, 0.0, 1.0, RectSection.new(0.1, 0.2), BeamMaterial.steel())
	assert_eq(unloaded.factor_of_safety(), INF, "unloaded FS")


# Load on a support: everything goes into one reaction, no bending.
func test_load_at_support() -> void:
	var beam := _beam(0.0)
	assert_within_1pct(beam.reaction_a(), P, "R_A = P")
	assert_almost_eq(beam.max_moment(), 0.0, 1e-9, "M_max")
	assert_almost_eq(beam.max_deflection(), 0.0, 1e-12, "v_max")
