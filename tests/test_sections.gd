extends PhysicsTestCase
## Section properties vs. hand calculations. Q(c/2) values were checked by numerically
## integrating Q = integral(eta * t(eta) d eta) from y to c.


# Rectangle b = 100 mm, h = 200 mm:
#   A = 0.1*0.2 = 0.02 m^2
#   I = 0.1*0.2^3/12 = 6.6667e-5 m^4
#   Q(0) = b*h^2/8 = 0.1*0.04/8 = 5.0e-4 m^3
#   Q(0.05) = 0.1*(0.1 - 0.05)*(0.1 + 0.05)/2 = 3.75e-4 m^3
func test_rectangle() -> void:
	var s := RectSection.new(0.1, 0.2)
	assert_within_1pct(s.area(), 0.02, "A")
	assert_within_1pct(s.moment_of_inertia(), 6.6667e-5, "I")
	assert_within_1pct(s.y_max(), 0.1, "c")
	assert_within_1pct(s.first_moment(0.0), 5.0e-4, "Q(0)")
	assert_within_1pct(s.first_moment(-0.05), 3.75e-4, "Q(-c/2)")
	assert_within_1pct(s.width_at(0.0), 0.1, "t(0)")
	assert_eq(s.first_moment(0.1), 0.0, "Q at extreme fiber")


# Circle r = 50 mm:
#   A = pi*0.05^2 = 7.8540e-3 m^2
#   I = pi*0.05^4/4 = 4.9087e-6 m^4
#   Q(0) = 2r^3/3 = 8.3333e-5 m^3, t(0) = 2r = 0.1 m
#   Q(0.025) = (2/3)*(0.05^2 - 0.025^2)^1.5 = 5.4127e-5 m^3, t = 2*sqrt(0.0025 - 0.000625) = 0.08660 m
func test_circle() -> void:
	var s := CircleSection.new(0.05)
	assert_within_1pct(s.area(), 7.8540e-3, "A")
	assert_within_1pct(s.moment_of_inertia(), 4.9087e-6, "I")
	assert_within_1pct(s.y_max(), 0.05, "c")
	assert_within_1pct(s.first_moment(0.0), 8.3333e-5, "Q(0)")
	assert_within_1pct(s.width_at(0.0), 0.1, "t(0)")
	assert_within_1pct(s.first_moment(0.025), 5.4127e-5, "Q(c/2)")
	assert_within_1pct(s.width_at(0.025), 0.08660, "t(c/2)")


# Tube r_o = 50 mm, r_i = 40 mm:
#   A = pi*(0.0025 - 0.0016) = 2.8274e-3 m^2
#   I = pi*(6.25e-6 - 2.56e-6)/4 = 2.8981e-6 m^4
#   Q(0) = 2*(1.25e-4 - 6.4e-5)/3 = 4.0667e-5 m^3, t(0) = 2*(0.05 - 0.04) = 0.02 m
#   Q(0.025) = 3.3830e-5 m^3, t(0.025) = 2*(0.04330 - 0.03122) = 0.02415 m
func test_tube() -> void:
	var s := TubeSection.new(0.05, 0.04)
	assert_within_1pct(s.area(), 2.8274e-3, "A")
	assert_within_1pct(s.moment_of_inertia(), 2.8981e-6, "I")
	assert_within_1pct(s.first_moment(0.0), 4.0667e-5, "Q(0)")
	assert_within_1pct(s.width_at(0.0), 0.02, "t(0)")
	assert_within_1pct(s.first_moment(0.025), 3.3830e-5, "Q(c/2)")
	assert_within_1pct(s.width_at(0.025), 0.02415, "t(c/2)")


# I-beam with W200x46.1 nominal dimensions (d = 203, b_f = 203, t_f = 11.0, t_w = 7.24 mm),
# no fillets, so A and I come out ~2% below the handbook (5890 mm^2, 45.5e6 mm^4).
#   h_w = 0.203 - 0.022 = 0.181 m
#   A = 2*0.203*0.011 + 0.00724*0.181 = 5.7765e-3 m^2
#   I = (0.203*0.203^3 - 0.19576*0.181^3)/12 = 4.4782e-5 m^4
#   Q(0) = 0.203*0.011*0.096 + 0.00724*0.0905^2/2 = 2.1437e-4 + 2.9649e-5 = 2.4402e-4 m^3
#   Q(0.095) (in flange) = 0.203*(0.1015^2 - 0.095^2)/2 = 1.2964e-4 m^3
func test_i_beam() -> void:
	var s := ISection.new(0.203, 0.203, 0.011, 0.00724)
	assert_within_1pct(s.area(), 5.7765e-3, "A")
	assert_within_1pct(s.moment_of_inertia(), 4.4782e-5, "I")
	assert_within_1pct(s.y_max(), 0.1015, "c")
	assert_within_1pct(s.first_moment(0.0), 2.4402e-4, "Q(0)")
	assert_within_1pct(s.width_at(0.0), 0.00724, "t(0) = web")
	assert_within_1pct(s.first_moment(0.095), 1.2964e-4, "Q in flange")
	assert_within_1pct(s.width_at(0.095), 0.203, "t in flange")
