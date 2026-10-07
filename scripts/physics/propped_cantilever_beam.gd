class_name ProppedCantileverBeam
extends BeamModel
## Fixed at x = 0, roller at x = L: statically indeterminate to the first degree.
## Solved by superposition: remove the roller (a cantilever under the loads), then add the
## roller reaction R_B that brings the end back to v(L) = 0.


## The released structure: a cantilever with the same loads.
func _released() -> CantileverBeam:
	var c := CantileverBeam.new(length, load, load_position, section, material)
	c.distributed_load = distributed_load
	return c


## The redundant alone: a cantilever loaded by R_B at its end (subtracted, since R_B acts upward).
func _redundant() -> CantileverBeam:
	return CantileverBeam.new(length, reaction_b(), length, section, material)


# Compatibility: v_B(loads) - R_B*L^3/(3EI) = 0  =>  R_B = 3EI*v_B(loads)/L^3
func reaction_b() -> float:
	return 3.0 * flexural_rigidity() * _released().deflection_at(length) / pow(length, 3)


# R_A = P + w*L - R_B
func reaction_a() -> float:
	return load + distributed_load * length - reaction_b()


func fixed_end_moment() -> float:
	return moment_at(0.0)


# Superposition of the released cantilever and the upward R_B at the end
func shear_at(x: float) -> float:
	return _released().shear_at(x) - reaction_b()


func moment_at(x: float) -> float:
	return _released().moment_at(x) + reaction_b() * (length - x)


func slope_at(x: float) -> float:
	return _released().slope_at(x) - _redundant().slope_at(x)


func deflection_at(x: float) -> float:
	return _released().deflection_at(x) - _redundant().deflection_at(x)


# V is piecewise linear: its extremes are at the ends or at the load
func max_shear() -> float:
	var best: float = 0.0
	for x: float in [0.0, load_position, load_position + 1e-9, length]:
		best = maxf(best, absf(shear_at(minf(x, length))))
	return best


# Candidates: the fixed end, the load, and points where V = 0 (V(x) = V(0) - w*x on each side)
func max_moment_position() -> float:
	var candidates: Array[float] = [0.0, load_position]
	if distributed_load > 0.0:
		candidates.append(shear_at(0.0) / distributed_load)
		candidates.append((shear_at(0.0) - load) / distributed_load)
	var best: float = 0.0
	for x: float in candidates:
		if x >= 0.0 and x <= length and absf(moment_at(x)) > absf(moment_at(best)):
			best = x
	return best


# v_max where dv/dx = 0 inside the span (v'(0) = 0 at the wall, v' < 0 at the roller)
func max_deflection_position() -> float:
	var lo: float = length * 1e-3
	var hi: float = length
	if slope_at(lo) <= 0.0:
		return 0.0
	for i: int in 60:
		var mid: float = 0.5 * (lo + hi)
		if slope_at(mid) > 0.0:
			lo = mid
		else:
			hi = mid
	return 0.5 * (lo + hi)
