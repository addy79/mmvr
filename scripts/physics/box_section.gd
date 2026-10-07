class_name BoxSection
extends CrossSection
## Hollow rectangular (box / HSS) section: outer b x h, uniform wall thickness t.
## Properties are the outer rectangle minus the inner one, h_i = h - 2t, b_i = b - 2t.

var b: float
var h: float
var t: float


func _init(p_b: float, p_h: float, p_t: float) -> void:
	display_name = "Box"
	b = p_b
	h = p_h
	t = p_t


# A = b*h - b_i*h_i
func area() -> float:
	return b * h - (b - 2.0 * t) * (h - 2.0 * t)


# I = (b*h^3 - b_i*h_i^3)/12
func moment_of_inertia() -> float:
	var hi: float = h - 2.0 * t
	return (b * h * h * h - (b - 2.0 * t) * hi * hi * hi) / 12.0


# I_v = (h*b^3 - h_i*b_i^3)/12
func moment_of_inertia_vertical() -> float:
	var bi: float = b - 2.0 * t
	return (h * b * b * b - (h - 2.0 * t) * bi * bi * bi) / 12.0


func z_max() -> float:
	return b / 2.0


func y_max() -> float:
	return h / 2.0


# Flange (|y| >= h_i/2): Q = (b/2)*(h^2/4 - y^2).
# Webs: Q = b*t*(h - t)/2 + 2*(t/2)*(h_i^2/4 - y^2)
func first_moment(y: float) -> float:
	var ay: float = absf(y)
	var half_i: float = h / 2.0 - t
	if ay >= h / 2.0:
		return 0.0
	if ay >= half_i:
		return 0.5 * b * (h * h / 4.0 - ay * ay)
	return b * t * (h - t) / 2.0 + t * (half_i * half_i - ay * ay)


# Flange: A' = b*(h/2 - |y|); webs: A' = b*t + 2t*(h_i/2 - |y|)
func area_beyond(y: float) -> float:
	var ay: float = absf(y)
	var half_i: float = h / 2.0 - t
	if ay >= h / 2.0:
		return 0.0
	if ay >= half_i:
		return b * (h / 2.0 - ay)
	return b * t + 2.0 * t * (half_i - ay)


# Width: b in the flanges, 2t through the two webs
func width_at(y: float) -> float:
	var ay: float = absf(y)
	if ay > h / 2.0:
		return 0.0
	return b if ay >= h / 2.0 - t else 2.0 * t

