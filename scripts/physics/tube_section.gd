class_name TubeSection
extends CrossSection
## Hollow circular tube, outer radius r_o, inner radius r_i.
## Every property is the outer circle minus the inner circle.

var r_o: float
var r_i: float


func _init(p_r_o: float, p_r_i: float) -> void:
	display_name = "Hollow tube"
	r_o = p_r_o
	r_i = p_r_i


# A = pi*(r_o^2 - r_i^2)
func area() -> float:
	return PI * (r_o * r_o - r_i * r_i)


# I = pi*(r_o^4 - r_i^4)/4
func moment_of_inertia() -> float:
	return PI * (pow(r_o, 4) - pow(r_i, 4)) / 4.0


# Same about every diameter
func moment_of_inertia_vertical() -> float:
	return moment_of_inertia()


func z_max() -> float:
	return r_o


# c = r_o
func y_max() -> float:
	return r_o


# Q(y) = (2/3)*[(r_o^2 - y^2)^(3/2) - (r_i^2 - y^2)^(3/2)]. Q(0) = 2(r_o^3 - r_i^3)/3.
func first_moment(y: float) -> float:
	return _segment_q(r_o, y) - _segment_q(r_i, y)


# t(y) = 2*[sqrt(r_o^2 - y^2) - sqrt(r_i^2 - y^2)] (two wall cuts). t(0) = 2(r_o - r_i).
func width_at(y: float) -> float:
	return _chord(r_o, y) - _chord(r_i, y)


# A' = outer segment - inner segment
func area_beyond(y: float) -> float:
	return _segment_area(r_o, y) - _segment_area(r_i, y)


# Circular segment beyond |y|: A = r^2*acos(|y|/r) - |y|*sqrt(r^2 - y^2)
static func _segment_area(radius: float, y: float) -> float:
	var ay: float = absf(y)
	if ay >= radius:
		return 0.0
	return radius * radius * acos(ay / radius) - ay * sqrt(radius * radius - ay * ay)


# Circular segment above y: Q = (2/3)*(r^2 - y^2)^(3/2)
static func _segment_q(radius: float, y: float) -> float:
	var s: float = radius * radius - y * y
	return 2.0 / 3.0 * pow(s, 1.5) if s > 0.0 else 0.0


# Chord length 2*sqrt(r^2 - y^2)
static func _chord(radius: float, y: float) -> float:
	var s: float = radius * radius - y * y
	return 2.0 * sqrt(s) if s > 0.0 else 0.0
