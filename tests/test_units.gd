extends GutTest
## SI -> display conversions.


func test_conversions() -> void:
	assert_eq(Units.force(7500.0), "7.50 kN")
	assert_eq(Units.moment(7500.0), "7.50 kN·m")
	assert_eq(Units.stress(11.25e6), "11.25 MPa")
	assert_eq(Units.modulus(200.0e9), "200 GPa")
	assert_eq(Units.small_length(5.625e-4), "0.56 mm")
	assert_eq(Units.area(0.02), "20000 mm²")
	assert_eq(Units.inertia(6.6667e-5), "66.67×10⁶ mm⁴")
	assert_eq(Units.first_moment(5.0e-4), "500.0×10³ mm³")
