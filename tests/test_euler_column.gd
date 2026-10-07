extends PhysicsTestCase
## Chapter 10. Steel rectangle 50 x 100 mm (I_min = 0.1*0.05^3/12 = 1.0417e-6 m^4,
## A = 5e-3 m^2, r = 14.434 mm), L = 3 m.


# P_cr = pi^2*E*I/(K*L)^2: K = 1 -> 228.46 kN, 2 -> 57.12 kN, 0.699 -> 467.59 kN, 0.5 -> 913.85 kN
func test_critical_loads() -> void:
	var c := EulerColumn.new()
	var expected: Array[float] = [228.463e3, 57.116e3, 467.586e3, 913.852e3]
	for ends: int in 4:
		c.ends = ends as EulerColumn.Ends
		assert_within_1pct(c.critical_load(), expected[ends], "P_cr ends %d" % ends)


# r = 14.434 mm, L/r = 207.8, (L/r)_c = pi*sqrt(200e9/250e6) = 88.86, sigma_cr = 45.69 MPa
func test_slenderness() -> void:
	var c := EulerColumn.new()
	assert_within_1pct(c.radius_of_gyration(), 0.014434, "r")
	assert_within_1pct(c.slenderness(), 207.85, "L/r")
	assert_within_1pct(c.transition_slenderness(), 88.858, "transition")
	assert_within_1pct(c.critical_stress(), 228.463e3 / 5.0e-3, "sigma_cr")


# Secant formula, P = 50 kN, e = 5 mm, c = 25 mm:
#   y_max = 0.005*(sec(pi/2*sqrt(50/228.46)) - 1) = 1.7391 mm, sigma_max = 18.087 MPa
func test_secant_formula() -> void:
	var c := EulerColumn.new()
	c.eccentricity = 0.005
	assert_within_1pct(c.max_deflection(), 1.7391e-3, "y_max")
	assert_within_1pct(c.max_stress(), 18.087e6, "sigma_max")
	c.load = 300.0e3
	assert_eq(c.max_deflection(), INF, "beyond P_cr")


# Mode shapes satisfy their end conditions and peak at 1.
func test_mode_shapes() -> void:
	var c := EulerColumn.new()
	for ends: int in 4:
		c.ends = ends as EulerColumn.Ends
		assert_almost_eq(c.mode_shape(0.0), 0.0, 1e-6, "no deflection at the base")
		var peak: float = 0.0
		for i: int in 201:
			peak = maxf(peak, absf(c.mode_shape(i / 200.0)))
		assert_almost_eq(peak, 1.0, 1e-3, "peak 1, ends %d" % ends)
	c.ends = EulerColumn.Ends.FIXED_PINNED
	assert_almost_eq(c.mode_shape(1.0), 0.0, 1e-4, "pinned top")


# Pinned-pinned eccentric column: the exact curve peaks at midheight with the secant
# y_max = 1.7391 mm, and the concave face carries sigma_max = -18.087 MPa there.
func test_deflected_shape_and_face_stress() -> void:
	var c := EulerColumn.new()
	c.eccentricity = 0.005
	assert_within_1pct(c.lateral_deflection_at(0.5), 1.7391e-3, "y(L/2)")
	assert_almost_eq(c.lateral_deflection_at(0.0), 0.0, 1e-9, "y(0)")
	assert_within_1pct(c.stress_at(0.5, 1.0), -18.087e6, "concave face")
	c.ends = EulerColumn.Ends.FIXED_FREE
	assert_within_1pct(c.lateral_deflection_at(1.0), c.max_deflection(), "free top deflects most")


# Squash load of the 50 x 100 steel rectangle: 250e6*5e-3 = 1250 kN
func test_squash_load() -> void:
	assert_within_1pct(EulerColumn.new().squash_load(), 1.25e6, "sigma_Y*A")
