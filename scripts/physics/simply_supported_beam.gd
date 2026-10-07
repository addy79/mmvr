class_name SimplySupportedBeam
extends BeamModel
## Pin at A (x = 0), roller at B (x = L); point load P at x = a plus uniform load w.
## All results superpose the two load cases.


# R_A = P*b/L + w*L/2 (moments about B)
func reaction_a() -> float:
	return load * load_offset_from_b() / length + distributed_load * length / 2.0


# R_B = P*a/L + w*L/2 (moments about A)
func reaction_b() -> float:
	return load * load_position / length + distributed_load * length / 2.0


# V(x) = R_A - w*x - P*[x > a] (the jump of P at x = a is assigned to the right)
func shear_at(x: float) -> float:
	return reaction_a() - distributed_load * x - (load if x > load_position else 0.0)


# M(x) = R_A*x - w*x^2/2 - P*(x - a)*[x > a]
func moment_at(x: float) -> float:
	var m: float = reaction_a() * x - distributed_load * x * x / 2.0
	if x > load_position:
		m -= load * (x - load_position)
	return m


# |V| is largest at an end: V falls monotonically from R_A to -R_B
func max_shear() -> float:
	return maxf(absf(reaction_a()), absf(reaction_b()))


# M peaks under the load or where V = 0: x = R_A/w (left of a) or x = (R_A - P)/w (right of a)
func max_moment_position() -> float:
	var best: float = load_position
	var w: float = distributed_load
	if w > 0.0:
		for x: float in [reaction_a() / w, (reaction_a() - load) / w]:
			if x >= 0.0 and x <= length and absf(moment_at(x)) > absf(moment_at(best)):
				best = x
	return best


# Slope dv/dx (downward-positive v), superposed:
#   point load, x <= a: P*b*(L^2 - b^2 - 3x^2) / (6EIL)
#   point load, x >  a: -P*a*(L^2 - a^2 - 3(L - x)^2) / (6EIL)   (mirror image)
#   uniform load:       w*(L^3 - 6Lx^2 + 4x^3) / (24EI)
func slope_at(x: float) -> float:
	var l: float = length
	var a: float = load_position
	var b: float = load_offset_from_b()
	var ei: float = flexural_rigidity()
	var theta: float = distributed_load * (l * l * l - 6.0 * l * x * x + 4.0 * x * x * x) / (24.0 * ei)
	if x <= a:
		theta += load * b * (l * l - b * b - 3.0 * x * x) / (6.0 * ei * l)
	else:
		var u: float = l - x
		theta -= load * a * (l * l - a * a - 3.0 * u * u) / (6.0 * ei * l)
	return theta


# Elastic curve, downward positive, superposed:
#   point load, x <= a: v(x) = P*b*x*(L^2 - b^2 - x^2) / (6EIL)
#   point load, x >  a: same formula mirrored (x -> L - x, b -> a)
#   uniform load:       v(x) = w*x*(L^3 - 2Lx^2 + x^3) / (24EI)
func deflection_at(x: float) -> float:
	var l: float = length
	var a: float = load_position
	var b: float = load_offset_from_b()
	var ei: float = flexural_rigidity()
	var v: float = distributed_load * x * (l * l * l - 2.0 * l * x * x + x * x * x) / (24.0 * ei)
	if x <= a:
		v += load * b * x * (l * l - b * b - x * x) / (6.0 * ei * l)
	else:
		var u: float = l - x
		v += load * a * u * (l * l - a * a - u * u) / (6.0 * ei * l)
	return v


# v_max where dv/dx = 0. For downward loads the slope falls monotonically from
# dv/dx(0) >= 0 to dv/dx(L) <= 0, so bisection on the exact slope finds it.
func max_deflection_position() -> float:
	var lo: float = 0.0
	var hi: float = length
	if slope_at(lo) <= 0.0 and slope_at(hi) >= 0.0:
		return length / 2.0
	for i: int in 60:
		var mid: float = 0.5 * (lo + hi)
		if slope_at(mid) > 0.0:
			lo = mid
		else:
			hi = mid
	return 0.5 * (lo + hi)
