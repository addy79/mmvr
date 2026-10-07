class_name CircleSection
extends CrossSection
## Solid circle of radius r.

var r: float


func _init(p_r: float) -> void:
	display_name = "Circle"
	r = p_r


# A = pi*r^2
func area() -> float:
	return PI * r * r


# I = pi*r^4/4
func moment_of_inertia() -> float:
	return PI * pow(r, 4) / 4.0


# c = r
func y_max() -> float:
	return r


# Q(y) = (2/3)*(r^2 - y^2)^(3/2) (circular segment above y). Q(0) = 2r^3/3.
func first_moment(y: float) -> float:
	var s: float = r * r - y * y
	return 2.0 / 3.0 * pow(s, 1.5) if s > 0.0 else 0.0


# t(y) = 2*sqrt(r^2 - y^2) (chord length)
func width_at(y: float) -> float:
	var s: float = r * r - y * y
	return 2.0 * sqrt(s) if s > 0.0 else 0.0
