extends PhysicsTestCase
## Idealized tension-test curves.


# Steel A36: elastic 200 GPa up to eps_Y = 250/200000 = 0.00125, plateau at 250 MPa,
# peak 400 MPa at eps_u = 0.20.
func test_steel_curve_landmarks() -> void:
	var curve := StressStrainCurve.new(LabMaterial.steel())
	assert_within_1pct(curve.yield_strain(), 0.00125, "eps_Y")
	assert_within_1pct(curve.stress_at(0.001), 200.0e6, "Hooke's law")
	assert_within_1pct(curve.stress_at(0.01), 250.0e6, "yield plateau")
	assert_within_1pct(curve.stress_at(0.20), 400.0e6, "sigma_U")
	assert_within_1pct(curve.stress_at(0.30), 320.0e6, "fracture at 0.8 sigma_U")
	assert_eq(curve.stress_at(0.31), 0.0, "broken")


# Unload from eps = 0.1: sigma = 400 - 150*((0.2 - 0.1)/0.185)^2 = 356.17 MPa,
# permanent set = 0.1 - 356.17e6/200e9 = 0.098219
func test_unloading_and_permanent_set() -> void:
	var curve := StressStrainCurve.new(LabMaterial.steel())
	assert_within_1pct(curve.stress_at(0.1), 356.17e6, "sigma(0.1)")
	assert_within_1pct(curve.permanent_set(0.1), 0.098219, "permanent set")
	assert_almost_eq(curve.unloading_stress(0.1, 0.098219), 0.0, 1.0e5, "zero stress at the set")
	assert_eq(curve.permanent_set(0.001), 0.0, "elastic: fully recovered")


# Resilience u_Y = 250e6^2/(2*200e9) = 156.25 kJ/m^3; toughness by fine numerical
# integration of the same curve = 105.68 MJ/m^3.
func test_energy_densities() -> void:
	var curve := StressStrainCurve.new(LabMaterial.steel())
	assert_within_1pct(curve.modulus_of_resilience(), 156.25e3, "resilience")
	assert_within_1pct(curve.modulus_of_toughness(), 105.68e6, "toughness")


# Wood is brittle: linear to sigma_U = 100 MPa at eps = 100/13000.
func test_brittle_curve() -> void:
	var curve := StressStrainCurve.new(LabMaterial.wood())
	assert_within_1pct(curve.stress_at(0.005), 65.0e6, "linear")
	assert_eq(curve.stress_at(0.008), 0.0, "fractured")


# Elastic: d/d0 = 1 - 0.3*0.001 = 0.9997. Plastic at eps = 0.21: 1/sqrt(1.21) = 0.9091.
# Neck halfway between eps_u = 0.20 and eps_f = 0.30: 0.35*0.5 = 0.175.
func test_specimen_shape() -> void:
	var curve := StressStrainCurve.new(LabMaterial.steel())
	assert_within_1pct(curve.diameter_ratio(0.001), 0.9997, "Poisson")
	assert_within_1pct(curve.diameter_ratio(0.21), 0.90909, "constant volume")
	assert_eq(curve.neck_reduction(0.1), 0.0, "no neck before sigma_U")
	assert_within_1pct(curve.neck_reduction(0.25), 0.175, "neck")
