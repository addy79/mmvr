class_name Units
extends RefCounted
## SI -> display-unit formatting. The only place unit conversions happen.


static func force(newtons: float) -> String:
	return "%.2f kN" % (newtons / 1.0e3)


## Force with an explicit sign: "+7.50 kN" / "−2.50 kN".
static func signed_force(newtons: float) -> String:
	return ("+" if newtons >= 0.0 else "−") + force(absf(newtons))


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


## Conversion factors to display units, for plots.
const KN: float = 1.0e-3
const MPA: float = 1.0e-6
const MM: float = 1.0e3


static func angle(radians: float) -> String:
	return "%.2f°" % rad_to_deg(radians)


static func strain(value: float) -> String:
	if absf(value) < 0.01:
		return "%.0f×10⁻⁶" % (value * 1.0e6)
	return "%.2f %%" % (value * 100.0)


static func distributed(newtons_per_meter: float) -> String:
	return "%.2f kN/m" % (newtons_per_meter / 1.0e3)


static func energy_density(joules_per_m3: float) -> String:
	if joules_per_m3 >= 1.0e6:
		return "%.2f MJ/m³" % (joules_per_m3 / 1.0e6)
	return "%.1f kJ/m³" % (joules_per_m3 / 1.0e3)


static func power(watts: float) -> String:
	return "%.1f kW" % (watts / 1.0e3)


static func temperature_change(kelvin: float) -> String:
	return "%+.0f °C" % kelvin


static func factor(value: float) -> String:
	return "∞" if is_inf(value) else "%.2f" % value
