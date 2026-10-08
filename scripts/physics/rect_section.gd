class_name RectSection
extends CrossSection
## Solid rectangle, width b by height h.

var b: float
var h: float


func _init(p_b: float, p_h: float) -> void:
	display_name = "Rectangle"
	b = p_b
	h = p_h


# A = b*h
func area() -> float:
	return b * h


# I = b*h^3/12
func moment_of_inertia() -> float:
	return b * h * h * h / 12.0


# I_z = h*b^3/12
func moment_of_inertia_vertical() -> float:
	return h * b * b * b / 12.0


# Shear correction factor of a rectangle: A_s = 5A/6
func shear_area() -> float:
	return 5.0 * area() / 6.0


func z_max() -> float:
	return b / 2.0


# c = h/2
func y_max() -> float:
	return h / 2.0


# Q(y) = (b/2)*(h^2/4 - y^2): area b*(h/2 - y) times centroid (h/2 + y)/2. Q(0) = b*h^2/8.
func first_moment(y: float) -> float:
	var ay: float = absf(y)
	if ay >= h / 2.0:
		return 0.0
	return 0.5 * b * (h * h / 4.0 - ay * ay)


# A' = b*(h/2 - |y|)
func area_beyond(y: float) -> float:
	return b * maxf(h / 2.0 - absf(y), 0.0)


func width_at(y: float) -> float:
	return b if absf(y) <= h / 2.0 else 0.0
