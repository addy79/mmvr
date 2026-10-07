class_name ISection
extends CrossSection
## Symmetric I-beam (wide flange) without fillets.
## d = overall depth, b_f = flange width, t_f = flange thickness, t_w = web thickness.

var d: float
var b_f: float
var t_f: float
var t_w: float


func _init(p_d: float, p_b_f: float, p_t_f: float, p_t_w: float) -> void:
	display_name = "I-beam"
	d = p_d
	b_f = p_b_f
	t_f = p_t_f
	t_w = p_t_w


# A = 2*b_f*t_f + t_w*(d - 2*t_f)
func area() -> float:
	return 2.0 * b_f * t_f + t_w * _web_height()


# I = b_f*d^3/12 - (b_f - t_w)*h_w^3/12 (outer box minus the two side voids)
func moment_of_inertia() -> float:
	var h_w: float = _web_height()
	return (b_f * d * d * d - (b_f - t_w) * h_w * h_w * h_w) / 12.0


# c = d/2
func y_max() -> float:
	return d / 2.0


# In the flange (|y| >= h_w/2): Q = (b_f/2)*(d^2/4 - y^2).
# In the web: Q = flange Q + (t_w/2)*(h_w^2/4 - y^2),
# with flange Q = b_f*t_f*(d - t_f)/2 (flange area times its centroid distance).
func first_moment(y: float) -> float:
	var ay: float = absf(y)
	var half_d: float = d / 2.0
	var half_w: float = _web_height() / 2.0
	if ay >= half_d:
		return 0.0
	if ay >= half_w:
		return 0.5 * b_f * (half_d * half_d - ay * ay)
	return b_f * t_f * (d - t_f) / 2.0 + 0.5 * t_w * (half_w * half_w - ay * ay)


func width_at(y: float) -> float:
	var ay: float = absf(y)
	if ay > d / 2.0:
		return 0.0
	return t_w if ay < _web_height() / 2.0 else b_f


# h_w = d - 2*t_f
func _web_height() -> float:
	return d - 2.0 * t_f
