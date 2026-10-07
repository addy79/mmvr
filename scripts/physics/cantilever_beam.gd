class_name CantileverBeam
extends BeamModel
## Fixed at x = 0, free at x = L; point load P at x = a plus uniform load w.


# Fixed-end vertical reaction: R_A = P + w*L
func reaction_a() -> float:
	return load + distributed_load * length


# Fixed-end moment (hogging): M_A = -(P*a + w*L^2/2)
func fixed_end_moment() -> float:
	return moment_at(0.0)


# V(x) = P*[x < a] + w*(L - x)  (from the free-end side)
func shear_at(x: float) -> float:
	return (load if x <= load_position else 0.0) + distributed_load * (length - x)


# M(x) = -P*(a - x)*[x < a] - w*(L - x)^2/2
func moment_at(x: float) -> float:
	var u: float = length - x
	var m: float = -distributed_load * u * u / 2.0
	if x < load_position:
		m -= load * (load_position - x)
	return m


# |V| and |M| are largest at the fixed end
func max_shear() -> float:
	return absf(shear_at(0.0))


func max_moment_position() -> float:
	return 0.0


# Slope dv/dx (downward positive):
#   point load: x <= a: P*x*(2a - x)/(2EI); x > a: P*a^2/(2EI)
#   uniform load: w*x*(x^2 - 3Lx + 3L^2)/(6EI)
func slope_at(x: float) -> float:
	var a: float = load_position
	var l: float = length
	var ei: float = flexural_rigidity()
	var theta: float = distributed_load * x * (x * x - 3.0 * l * x + 3.0 * l * l) / (6.0 * ei)
	if x <= a:
		theta += load * x * (2.0 * a - x) / (2.0 * ei)
	else:
		theta += load * a * a / (2.0 * ei)
	return theta


# Elastic curve (downward positive):
#   point load: x <= a: P*x^2*(3a - x)/(6EI); x > a: P*a^2*(3x - a)/(6EI)
#   uniform load: w*x^2*(x^2 - 4Lx + 6L^2)/(24EI)
func deflection_at(x: float) -> float:
	var a: float = load_position
	var l: float = length
	var ei: float = flexural_rigidity()
	var v: float = distributed_load * x * x * (x * x - 4.0 * l * x + 6.0 * l * l) / (24.0 * ei)
	if x <= a:
		v += load * x * x * (3.0 * a - x) / (6.0 * ei)
	else:
		v += load * a * a * (3.0 * x - a) / (6.0 * ei)
	return v


# Downward loads: the free end deflects most
func max_deflection_position() -> float:
	return length
