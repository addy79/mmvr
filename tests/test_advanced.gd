extends PhysicsTestCase
## University-level extensions: area method, moment-area, flange shear flow, pressure
## vessels, strain rosettes, brittle criteria, shaft design, propped cantilever, AISC.

const EI_REF: float = 200.0e9 * 0.1 * 0.2 * 0.2 * 0.2 / 12.0  # steel 100 x 200: 1.3333e7 N*m^2


# P = 10 kN at a = 1 on L = 4: area under V from 0 to 1 = 7500 N*m = M(1) - M(0)
func test_area_method() -> void:
	var b := SimplySupportedBeam.new(4.0, 10.0e3, 1.0, RectSection.new(0.1, 0.2), LabMaterial.steel())
	assert_within_1pct(b.shear_area(0.0, 1.0), 7500.0, "integral of V")
	assert_within_1pct(b.shear_area(0.0, 3.0), b.moment_at(3.0), "area = M(3)")


# Uniform load w = 5 kN/m on L = 4: area of M/EI over the span = wL^3/(12EI) = 2.0e-3 rad,
# equal to theta(0) - theta(L) (first moment-area theorem, downward v).
func test_moment_area() -> void:
	var b := SimplySupportedBeam.new(4.0, 0.0, 1.0, RectSection.new(0.1, 0.2), LabMaterial.steel())
	b.distributed_load = 5000.0
	var ma: Vector2 = b.moment_area(0.0, 4.0)
	assert_within_1pct(ma.x, 2.0e-3, "area of M/EI")
	assert_within_1pct(ma.x, b.slope_at(0.0) - b.slope_at(4.0), "theta_A - theta_B")
	# Second theorem: deviation of B from the tangent at A equals v(B) - v(A) - theta_A*L, sign-adjusted.
	assert_within_1pct(ma.y, b.slope_at(0.0) * 4.0, "t_B/A = theta_A*L since v(B) = 0")


# W200, V = 50 kN: flange shear flow at the web, s = b_f/2: 119.67 kN/m; at s = 50 mm: 58.95 kN/m
func test_flange_shear_flow() -> void:
	var s := SectionShear.new()
	s.section = ISection.new(0.203, 0.203, 0.011, 0.00724)
	assert_within_1pct(s.flange_shear_flow(0.1015), 119.675e3, "q at web")
	assert_within_1pct(s.flange_shear_flow(0.05), 58.953e3, "q at 50 mm")


# p = 2 MPa, r = 0.5 m, t = 10 mm: hoop 100 MPa, axial 50 MPa, sphere 50 MPa, tau_abs = 50 MPa
func test_pressure_vessel() -> void:
	var v := PressureVessel.new()
	assert_within_1pct(v.hoop_stress(), 100.0e6, "pr/t")
	assert_within_1pct(v.axial_stress(), 50.0e6, "pr/2t")
	assert_within_1pct(v.absolute_max_shear(), 50.0e6, "sigma_1/2 out of plane")
	v.spherical = true
	assert_within_1pct(v.hoop_stress(), 50.0e6, "sphere pr/2t")


# Rosette 600 / 400 / -200 microstrain on steel: gamma = 400e-6, eps_1,2 = 647.2, -247.2e-6,
# sigma_x = 118.68 MPa, sigma_y = -4.396 MPa, tau_xy = 30.77 MPa
func test_strain_rosette() -> void:
	var r := StrainRosette.new()
	assert_within_1pct(r.shear_strain(), 400.0e-6, "gamma_xy")
	assert_within_1pct(r.principal_strains().x, 647.21e-6, "eps_1")
	assert_within_1pct(r.principal_strains().y, -247.21e-6, "eps_2")
	assert_within_1pct(r.strain_at(PI / 4.0), 400.0e-6, "reads gauge b back")
	var s: PlaneStress = r.stress_state()
	assert_within_1pct(s.sigma_x, 118.68e6, "sigma_x")
	assert_within_1pct(s.sigma_y, -4.3956e6, "sigma_y")
	assert_within_1pct(s.tau_xy, 30.769e6, "tau_xy")


# sigma_1 = 80, sigma_2 = -200 MPa, sigma_UT = 150, sigma_UC = 600: Rankine FS = 1.875,
# Mohr FS = 1/(80/150 + 200/600) = 1.1538
func test_brittle_criteria() -> void:
	var p := PlaneStress.new(80.0e6, -200.0e6, 0.0)
	assert_within_1pct(p.max_normal_safety(150.0e6, 600.0e6), 1.875, "Rankine")
	assert_within_1pct(p.mohr_safety(150.0e6, 600.0e6), 1.1538, "Mohr")


# M = 5 kN x 1.2 m = 6 kN*m, T = 1.5 kN*m, tau_all = 60 MPa: c = (2*sqrt(M^2+T^2)/(pi*60e6))^(1/3) = 40.33 mm
func test_shaft_design() -> void:
	assert_within_1pct(CombinedLoading.new().design_radius(60.0e6), 0.040335, "c_min")


# Propped cantilever, L = 4: uniform w = 5 kN/m: R_B = 3wL/8 = 7.5 kN, M_A = -wL^2/8 = -10 kN*m,
# M_max+ = 9wL^2/128 = 5.625 kN*m at 5L/8 from the wall, v_max = wL^4/(185EI) at 0.5785L.
# Point load 10 kN at midspan: R_B = 5P/16 = 3.125 kN, M_A = -3PL/16 = -7.5 kN*m.
func test_propped_cantilever() -> void:
	var b := ProppedCantileverBeam.new(4.0, 0.0, 2.0, RectSection.new(0.1, 0.2), LabMaterial.steel())
	b.distributed_load = 5000.0
	assert_within_1pct(b.reaction_b(), 7500.0, "R_B = 3wL/8")
	assert_within_1pct(b.fixed_end_moment(), -10000.0, "M_A = -wL^2/8")
	assert_within_1pct(b.moment_at(2.5), 5625.0, "9wL^2/128")
	assert_almost_eq(b.deflection_at(4.0), 0.0, 1e-12, "roller does not move")
	assert_within_1pct(b.max_deflection(), 5000.0 * 256.0 / (185.0 * EI_REF), "wL^4/185EI")
	assert_within_1pct(b.max_deflection_position(), 0.5785 * 4.0, "at 0.5785L")
	assert_within_1pct(b.max_moment(), -10000.0, "largest |M| at the wall")
	var p := ProppedCantileverBeam.new(4.0, 10.0e3, 2.0, RectSection.new(0.1, 0.2), LabMaterial.steel())
	assert_within_1pct(p.reaction_b(), 3125.0, "R_B = 5P/16")
	assert_within_1pct(p.fixed_end_moment(), -7500.0, "M_A = -3PL/16")


# AISC: 50 x 100 steel column, K = 1. L = 3 m: L/r = 207.8 > 133.2 (elastic), sigma_cr = 0.877*45.69
# = 40.07 MPa, P_all = 119.98 kN. L = 1 m: L/r = 69.28, sigma_e = 411.2 MPa,
# sigma_cr = 0.658^(250/411.2)*250 = 193.84 MPa, P_all = 580.35 kN.
func test_aisc_columns() -> void:
	var c := EulerColumn.new()
	assert_within_1pct(c.aisc_critical_stress(), 40.073e6, "elastic range")
	assert_within_1pct(c.aisc_allowable_load(), 119.98e3, "P_all")
	c.length = 1.0
	assert_within_1pct(c.aisc_critical_stress(), 193.84e6, "inelastic range")
	assert_within_1pct(c.aisc_allowable_load(), 580.35e3, "P_all short")
