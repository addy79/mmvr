extends PhysicsTestCase
## Cantilever (fixed at x = 0) vs. hand calculations. L = 2 m, steel rectangle 100 x 200 mm,
## EI = 1.3333e7 N*m^2.

func _beam(p: float, a: float, w: float) -> CantileverBeam:
	var beam := CantileverBeam.new(2.0, p, a, RectSection.new(0.1, 0.2), LabMaterial.steel())
	beam.distributed_load = w
	return beam


# End load P = 1 kN: v(L) = PL^3/(3EI) = 1000*8/(3*1.3333e7) = 2.0e-4 m; M_A = -PL = -2000 N*m
func test_end_load() -> void:
	var beam := _beam(1000.0, 2.0, 0.0)
	assert_within_1pct(beam.max_deflection(), 2.0e-4, "PL^3/3EI")
	assert_within_1pct(beam.fixed_end_moment(), -2000.0, "M_A")
	assert_within_1pct(beam.reaction_a(), 1000.0, "R_A")
	assert_within_1pct(beam.slope_at(2.0), 1000.0 * 4.0 / (2.0 * beam.flexural_rigidity()), "PL^2/2EI")


# Uniform load w = 2 kN/m: v(L) = wL^4/(8EI) = 2000*16/(8*1.3333e7) = 3.0e-4 m; M_A = -wL^2/2 = -4000
func test_uniform_load() -> void:
	var beam := _beam(0.0, 2.0, 2000.0)
	assert_within_1pct(beam.max_deflection(), 3.0e-4, "wL^4/8EI")
	assert_within_1pct(beam.max_moment(), -4000.0, "M_A")
	assert_within_1pct(beam.max_shear(), 4000.0, "V_A = wL")


# Load inside the span, a = 1.2 m: v(L) = P*a^2*(3L - a)/(6EI) = 1000*1.44*4.8/(6*1.3333e7) = 8.64e-5 m
func test_interior_load() -> void:
	var beam := _beam(1000.0, 1.2, 0.0)
	assert_within_1pct(beam.deflection_at(2.0), 8.64e-5, "free-end deflection")
	assert_almost_eq(beam.moment_at(1.5), 0.0, 1e-9, "no moment beyond the load")


# Fixed end: no deflection, no slope; EI*v'' = -M everywhere.
func test_fixed_end_and_curvature() -> void:
	var beam := _beam(1000.0, 1.2, 2000.0)
	assert_almost_eq(beam.deflection_at(0.0), 0.0, 1e-12, "v(0)")
	assert_almost_eq(beam.slope_at(0.0), 0.0, 1e-12, "v'(0)")
	var h: float = 1e-4
	for x: float in [0.5, 1.6]:
		var curvature: float = (beam.slope_at(x + h) - beam.slope_at(x - h)) / (2.0 * h)
		assert_within_1pct(beam.flexural_rigidity() * curvature, -beam.moment_at(x), "EI v'' = -M")
