extends PhysicsTestCase
## Chapters 3 and 4.


# Solid steel shaft, c = 30 mm, T = 2 kN*m, L = 1.5 m, G = 200/2.6 = 76.92 GPa:
#   J = pi*0.03^4/2 = 1.2723e-6 m^4, tau_max = 2000*0.03/J = 47.16 MPa,
#   phi = 2000*1.5/(J*G) = 0.030652 rad = 1.756 deg; power at 30 Hz = 2*pi*30*2000 = 377.0 kW
func test_solid_shaft() -> void:
	var s := TorsionShaft.new()
	assert_within_1pct(s.material.shear_modulus(), 76.923e9, "G = E/2(1+nu)")
	assert_within_1pct(s.polar_moment(), 1.2723e-6, "J")
	assert_within_1pct(s.max_shear_stress(), 47.157e6, "Tc/J")
	assert_within_1pct(s.angle_of_twist(), 0.030652, "TL/JG")
	assert_within_1pct(s.shear_stress_at(0.015), 47.157e6 / 2.0, "linear in rho")
	assert_within_1pct(s.power_at(30.0), 376.99e3, "P = 2 pi f T")


# Hollow, r_i = 20 mm: J = pi*(0.03^4 - 0.02^4)/2 = 1.0210e-6, tau_max = 58.76 MPa,
# tau at the bore = 2000*0.02/J = 39.18 MPa, zero inside.
func test_hollow_shaft() -> void:
	var s := TorsionShaft.new()
	s.inner_radius = 0.02
	assert_within_1pct(s.polar_moment(), 1.0210e-6, "J hollow")
	assert_within_1pct(s.max_shear_stress(), 58.765e6, "tau_max")
	assert_within_1pct(s.shear_stress_at(0.02), 39.177e6, "tau at bore")
	assert_eq(s.shear_stress_at(0.01), 0.0, "no material")


# M = 5 kN*m, steel rectangle 100 x 200 (I = 6.6667e-5): 1/rho = 3.75e-4 1/m, rho = 2666.7 m,
# sigma_m = 7.5 MPa, S = 6.6667e-4 m^3, M_Y = 250e6*S = 166.67 kN*m, eps_m = 3.75e-5
func test_pure_bending() -> void:
	var b := PureBending.new()
	assert_within_1pct(b.curvature(), 3.75e-4, "M/EI")
	assert_within_1pct(b.radius_of_curvature(), 2666.67, "rho")
	assert_within_1pct(b.max_stress(), 7.5e6, "Mc/I")
	assert_within_1pct(b.section_modulus(), 6.6667e-4, "S = I/c")
	assert_within_1pct(b.yield_moment(), 166.67e3, "M_Y")
	assert_within_1pct(b.max_strain(), 3.75e-5, "c/rho")
	assert_within_1pct(b.strain_at(0.1), -3.75e-5, "top shortens")
	assert_within_1pct(b.stress_at(-0.1), 7.5e6, "bottom tension")


# T = 2 kN*m, tau_all = 60 MPa: c = (2*2000/(pi*60e6))^(1/3) = 27.68 mm
func test_required_radius() -> void:
	assert_within_1pct(TorsionShaft.new().required_solid_radius(60.0e6), 0.027679, "c_min")
