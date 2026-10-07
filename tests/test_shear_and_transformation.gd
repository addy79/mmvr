extends PhysicsTestCase
## Chapters 6, 7, 8.


# V = 50 kN on the 100 x 200 rectangle: tau_max = 1.5*V/A = 3.75 MPa, tau_avg = 2.5 MPa,
# q(0) = V*Q/I = 50000*5e-4/6.6667e-5 = 375 kN/m; at y = 50 mm q = 281.25 kN/m so
# 2 kN nails need s = 2000/281250 = 7.11 mm.
func test_section_shear() -> void:
	var s := SectionShear.new()
	assert_within_1pct(s.max_shear_stress(), 3.75e6, "1.5 V/A")
	assert_within_1pct(s.average_shear_stress(), 2.5e6, "V/A")
	assert_within_1pct(s.shear_flow_at(0.0), 375.0e3, "q at NA")
	assert_within_1pct(s.fastener_spacing(0.05, 2000.0), 7.111e-3, "nail spacing")


# Beer & Johnston Example 7.01: sigma_x = 50, sigma_y = -10, tau_xy = 40 MPa:
#   sigma_max = 70, sigma_min = -30, theta_p = 26.6 deg, tau_max = 50 MPa,
#   von Mises = sqrt(70^2 + 70*30 + 30^2) = 88.88 MPa.
# At theta = 30 deg: sigma_x' = 69.64, sigma_y' = -29.64, tau_x'y' = -5.98 MPa.
func test_plane_stress() -> void:
	var p := PlaneStress.new(50.0e6, -10.0e6, 40.0e6)
	assert_within_1pct(p.principal_1(), 70.0e6, "sigma_max")
	assert_within_1pct(p.principal_2(), -30.0e6, "sigma_min")
	assert_within_1pct(rad_to_deg(p.principal_angle()), 26.565, "theta_p")
	assert_within_1pct(p.max_inplane_shear(), 50.0e6, "tau_max")
	assert_within_1pct(p.von_mises(), 88.882e6, "von Mises")
	var t: Vector3 = p.transformed(deg_to_rad(30.0))
	assert_within_1pct(t.x, 69.641e6, "sigma_x'")
	assert_within_1pct(t.y, -29.641e6, "sigma_y'")
	assert_within_1pct(t.z, -5.9808e6, "tau_x'y'")
	assert_within_1pct(t.x + t.y, 40.0e6, "invariant sum")


# Both principal stresses positive (s1 = 80, s2 = 20): tau_abs,max = s1/2 = 40 MPa, not (s1 - s2)/2.
func test_absolute_max_shear() -> void:
	var p := PlaneStress.new(80.0e6, 20.0e6, 0.0)
	assert_within_1pct(p.max_inplane_shear(), 30.0e6, "in plane")
	assert_within_1pct(p.absolute_max_shear(), 40.0e6, "out of plane governs")
	assert_within_1pct(p.tresca_safety(250.0e6), 125.0e6 / 40.0e6, "Tresca FS")


# Pipe r_o = 50, r_i = 40 mm (A = 2.8274e-3, I = 2.8981e-6), P = 5 kN at L = 1.2 m, T = 1.5 kN*m:
#   top: sigma = P*L*c/I = 103.52 MPa, tau_T = T*c/J = 12.94 MPa
#   side: tau_V = V*Q/(I*t) = 3.508 MPa (Q = 4.0667e-5, t = 20 mm)
#   top principal: s1 = 105.11 MPa, s2 = -1.593 MPa, theta_p = 7.02 deg, von Mises = 105.91 MPa
func test_combined_loading() -> void:
	var c := CombinedLoading.new()
	assert_within_1pct(c.normal_stress(CombinedLoading.Point.TOP), 103.515e6, "bending at top")
	assert_within_1pct(c.normal_stress(CombinedLoading.Point.BOTTOM), -103.515e6, "bottom")
	assert_within_1pct(c.torsion_shear(), 12.939e6, "Tc/J")
	assert_within_1pct(c.transverse_shear(), 3.508e6, "VQ/It")
	assert_within_1pct(c.shear_stress(CombinedLoading.Point.FRONT), 12.939e6 + 3.508e6, "add on front")
	assert_within_1pct(c.shear_stress(CombinedLoading.Point.BACK), 12.939e6 - 3.508e6, "subtract on back")
	var top: PlaneStress = c.stress_state(CombinedLoading.Point.TOP)
	assert_within_1pct(top.principal_1(), 105.108e6, "s1")
	assert_within_1pct(top.principal_2(), -1.5929e6, "s2")
	assert_within_1pct(rad_to_deg(top.principal_angle()), 7.018, "theta_p")
	assert_within_1pct(top.von_mises(), 105.914e6, "von Mises")


# Area beyond y (numerical integration of the width): rectangle 100x200 at 50 mm: 0.1*0.05 = 5e-3;
# circle r = 50 at 25 mm: 1.5355e-3; tube 50/40 at 25 mm: 8.830e-4; W200 at NA: 2.8882e-3,
# in the flange at 95 mm: 1.3195e-3. Web of the W200 carries 94.6% of V.
func test_area_beyond_and_web_share() -> void:
	assert_within_1pct(RectSection.new(0.1, 0.2).area_beyond(0.05), 5.0e-3, "rect")
	assert_within_1pct(CircleSection.new(0.05).area_beyond(0.025), 1.5355e-3, "circle")
	assert_within_1pct(TubeSection.new(0.05, 0.04).area_beyond(0.025), 8.830e-4, "tube")
	var ib := ISection.new(0.203, 0.203, 0.011, 0.00724)
	assert_within_1pct(ib.area_beyond(0.0), 2.8882e-3, "I at NA")
	assert_within_1pct(ib.area_beyond(0.095), 1.3195e-3, "I in flange")
	var s := SectionShear.new()
	assert_within_1pct(s.centroid_beyond(0.05), 3.75e-4 / 5.0e-3, "y' = Q/A'")
	s.section = ib
	assert_within_1pct(s.web_share(), 0.94634, "web share")


# Every point of the drawn yield surfaces sits exactly at yield.
func test_yield_boundaries() -> void:
	for i: int in 12:
		var p: Vector2 = PlaneStress.von_mises_boundary(TAU * i / 12.0, 250.0e6)
		assert_within_1pct(PlaneStress.new(p.x, p.y, 0.0).von_mises(), 250.0e6, "von Mises ellipse")
	for corner: Vector2 in PlaneStress.tresca_boundary(250.0e6):
		assert_within_1pct(PlaneStress.new(corner.x, corner.y, 0.0).absolute_max_shear(), 125.0e6, "Tresca hexagon")


# W200 web approximation, V = 50 kN: 50000/(0.203*0.00724) = 34.02 MPa
func test_web_average_stress() -> void:
	var s := SectionShear.new()
	s.section = ISection.new(0.203, 0.203, 0.011, 0.00724)
	assert_within_1pct(s.web_average_stress(), 34.02e6, "V/(d t_w)")
