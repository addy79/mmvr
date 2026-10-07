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


# Hollow 30/20 mm: equal-area solid c = sqrt(0.03^2 - 0.02^2) = 22.36 mm
func test_equal_area_solid() -> void:
	var s := TorsionShaft.new()
	s.inner_radius = 0.02
	assert_within_1pct(s.equal_area_solid().outer_radius, 0.022361, "equal area")


# Plastic moduli: rectangle b*h^2/4 = 1.0e-3, circle r = 50: 4r^3/3 = 1.6667e-4,
# tube 50/40: 4(r_o^3 - r_i^3)/3 = 8.1333e-5, W200: 4.8803e-4, box 100x200x10: 3.52e-4 m^3
func test_plastic_moduli() -> void:
	assert_within_1pct(RectSection.new(0.1, 0.2).plastic_modulus(), 1.0e-3, "rect")
	assert_within_1pct(CircleSection.new(0.05).plastic_modulus(), 1.6667e-4, "circle")
	assert_within_1pct(TubeSection.new(0.05, 0.04).plastic_modulus(), 8.1333e-5, "tube")
	assert_within_1pct(ISection.new(0.203, 0.203, 0.011, 0.00724).plastic_modulus(), 4.8803e-4, "I")
	assert_within_1pct(BoxSection.new(0.1, 0.2, 0.01).plastic_modulus(), 3.52e-4, "box")


# Rectangle: shape factor 1.5; at twice the yield curvature M = 1.5*M_Y*(1 - 1/12) = 1.375 M_Y,
# elastic core = c/2.
func test_elastoplastic_bending() -> void:
	var b := PureBending.new()
	assert_within_1pct(b.shape_factor(), 1.5, "k = Z/S")
	var k_y: float = b.yield_curvature()
	assert_within_1pct(b.moment_at_curvature(0.5 * k_y), 0.5 * b.yield_moment(), "elastic part")
	assert_within_1pct(b.moment_at_curvature(2.0 * k_y), 1.375 * b.yield_moment(), "elastoplastic")
	assert_within_1pct(b.elastic_core(2.0 * k_y), 0.05, "core = c/2")
	assert_within_1pct(b.moment_at_curvature(50.0 * k_y), b.plastic_moment(), "tends to M_p")


# P = 100 kN at e = 30 mm on 100 x 200: top 9.5 MPa, bottom 0.5 MPa, neutral axis at
# y = -I/(A e) = -111.1 mm (off the section), kern limit I/(A c) = 33.3 mm.
func test_eccentric_axial() -> void:
	var m := EccentricAxial.new()
	assert_within_1pct(m.stress_at(0.1), 9.5e6, "top")
	assert_within_1pct(m.stress_at(-0.1), 0.5e6, "bottom")
	assert_within_1pct(m.neutral_axis(), -0.11111, "NA")
	assert_within_1pct(m.kern_limit(), 0.033333, "kern")


# Wood 100x200 on a 100x10 steel plate, M = 10 kN*m: n = 15.385, z_bar = 64.35 mm,
# I_t = 1.6266e-4 m^4, wood top -8.954 MPa, steel bottom +60.86 MPa.
func test_composite_section() -> void:
	var c := CompositeSection.new()
	assert_within_1pct(c.modular_ratio(), 15.385, "n")
	assert_within_1pct(c.neutral_axis(), 0.064348, "z_bar")
	assert_within_1pct(c.transformed_inertia(), 1.62664e-4, "I_t")
	assert_within_1pct(c.stress_at(0.21), -8.9541e6, "wood top")
	assert_within_1pct(c.stress_at(0.0), 60.859e6, "steel bottom")


# Steel shaft between walls: c1 = 30 mm L1 = 0.6, c2 = 20 mm L2 = 0.9, T = 2 kN*m at B:
#   T_A = 1767.3 N*m, T_C = 232.7 N*m, tau1 = 41.67 MPa, tau2 = 18.52 MPa, phi_B = 0.010834 rad
func test_indeterminate_shaft() -> void:
	var s := IndeterminateShaft.new()
	assert_within_1pct(s.torque_a(), 1767.27, "T_A")
	assert_within_1pct(s.torque_c(), 232.73, "T_C")
	assert_within_1pct(s.max_shear_1(), 41.670e6, "tau1")
	assert_within_1pct(s.max_shear_2(), 18.520e6, "tau2")
	assert_within_1pct(s.rotation_b(), 0.010834, "phi_B")


# Box 100 x 60 x 5 mm, T = 2 kN*m, L = 1.5 m: A = 95*55 mm^2 = 5.225e-3 m^2, q = 191.39 kN/m,
# tau = 38.28 MPa, phi = 0.021428 rad
func test_thin_walled_shaft() -> void:
	var s := ThinWalledShaft.new()
	assert_within_1pct(s.enclosed_area(), 5.225e-3, "enclosed area")
	assert_within_1pct(s.shear_flow(), 191.39e3, "q")
	assert_within_1pct(s.shear_stress(), 38.278e6, "tau")
	assert_within_1pct(s.angle_of_twist(), 0.021428, "phi")
