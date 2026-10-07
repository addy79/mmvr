extends PhysicsTestCase
## Chapters 1 and 2: rod and pin, axial member.


# P = 20 kN, d = 20 mm (A = 314.16 mm^2), pin 16 mm (A = 201.06 mm^2), eye t = 20 mm:
#   sigma = 63.66 MPa, double shear tau = 20000/(2*201.06e-6) = 49.74 MPa (single 99.47),
#   bearing = 20000/(0.02*0.016) = 62.5 MPa
#   theta = 30 deg: sigma = 63.66*cos^2 = 47.75 MPa, tau = 63.66*sin*cos = 27.57 MPa; at 45: 31.83
func test_rod_and_pin() -> void:
	var r := RodAndPin.new()
	assert_within_1pct(r.normal_stress(), 63.662e6, "P/A")
	assert_within_1pct(r.pin_shear_stress(), 49.736e6, "double shear")
	r.double_shear = false
	assert_within_1pct(r.pin_shear_stress(), 99.472e6, "single shear")
	assert_within_1pct(r.bearing_stress(), 62.5e6, "bearing")
	r.plane_angle = deg_to_rad(30.0)
	assert_within_1pct(r.oblique_normal_stress(), 47.746e6, "sigma_30")
	assert_within_1pct(r.oblique_shear_stress(), 27.566e6, "tau_30")
	r.plane_angle = deg_to_rad(45.0)
	assert_within_1pct(r.oblique_shear_stress(), 31.831e6, "tau_max = P/2A")


# P = 50 kN, L = 1 m, d = 25 mm steel: sigma = 101.86 MPa, delta = PL/AE = 0.5093 mm,
# delta_d = -0.3*(101.86e6/200e9)*0.025 = -3.82e-6 m
func test_axial_member() -> void:
	var m := AxialMember.new()
	assert_within_1pct(m.stress(), 101.859e6, "P/A")
	assert_within_1pct(m.elongation(), 5.093e-4, "PL/AE")
	assert_within_1pct(m.diameter_change(), -3.8197e-6, "Poisson")


# dT = 50 K: free bar grows alpha*dT*L = 11.7e-6*50 = 0.585 mm; held between walls it
# carries sigma = -E*alpha*dT = -117 MPa.
func test_thermal() -> void:
	var m := AxialMember.new()
	m.load = 0.0
	m.temperature_change = 50.0
	assert_within_1pct(m.elongation(), 5.85e-4, "free thermal growth")
	m.ends_fixed = true
	assert_within_1pct(m.stress(), -117.0e6, "thermal stress")
	assert_eq(m.elongation(), 0.0)


# Allowables 150 / 75 / 225 MPa: rod 150e6*314.16e-6 = 47.12 kN, pin (double) 75e6*2*201.06e-6
# = 30.16 kN, bearing 225e6*0.02*0.016 = 72.0 kN.
func test_allowable_loads() -> void:
	var r := RodAndPin.new()
	assert_within_1pct(r.allowable_load_rod(150.0e6), 47.124e3, "rod")
	assert_within_1pct(r.allowable_load_pin(75.0e6), 30.159e3, "pin")
	assert_within_1pct(r.allowable_load_bearing(225.0e6), 72.0e3, "bearing")
