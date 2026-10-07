class_name Units
extends RefCounted
## SI -> display-unit formatting. The only place unit conversions happen.


static func force(newtons: float) -> String:
	return "%.2f kN" % (newtons / 1.0e3)


static func moment(newton_meters: float) -> String:
	return "%.2f kN·m" % (newton_meters / 1.0e3)


static func stress(pascals: float) -> String:
	return "%.2f MPa" % (pascals / 1.0e6)


static func modulus(pascals: float) -> String:
	return "%.0f GPa" % (pascals / 1.0e9)


static func length(meters: float) -> String:
	return "%.3f m" % meters


static func small_length(meters: float) -> String:
	return "%.2f mm" % (meters * 1.0e3)


static func area(square_meters: float) -> String:
	return "%.0f mm²" % (square_meters * 1.0e6)


## I in 10^6 mm^4 (1 m^4 = 10^12 mm^4)
static func inertia(meters4: float) -> String:
	return "%.2f×10⁶ mm⁴" % (meters4 * 1.0e6)


## Q in 10^3 mm^3 (1 m^3 = 10^9 mm^3)
static func first_moment(meters3: float) -> String:
	return "%.1f×10³ mm³" % (meters3 * 1.0e6)
