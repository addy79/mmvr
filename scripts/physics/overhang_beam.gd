class_name OverhangBeam
extends BeamModel
## Pin at x = 0, roller at x = s (s <= L), the part beyond s overhangs; point load P at x = a
## (anywhere on 0..L). Used for lab 8's over-hanging configuration. With s = L it is a simply
## supported beam. Macaulay brackets: <x - a> = x - a when x > a, else 0.

var support_span: float = 0.4  ## s [m]


func _init(p_length: float, p_load: float, p_load_position: float, p_section: CrossSection,
		p_material: LabMaterial, p_span: float) -> void:
	super(p_length, p_load, p_load_position, p_section, p_material)
	support_span = p_span


# Moments about A: R_B*s = P*a  =>  R_B = P*a/s
func reaction_b() -> float:
	return load * load_position / support_span


# R_A = P - R_B (negative = A pulls down when the load is on the overhang)
func reaction_a() -> float:
	return load - reaction_b()


# V(x) = R_A - P*[x > a] + R_B*[x > s]
func shear_at(x: float) -> float:
	var v: float = reaction_a()
	if x > load_position:
		v -= load
	if x > support_span:
		v += reaction_b()
	return v


# M(x) = R_A*x - P*<x - a> + R_B*<x - s>
func moment_at(x: float) -> float:
	return reaction_a() * x - load * _mac(x, load_position) + reaction_b() * _mac(x, support_span)


# EI*v'' = -M (v downward). Integrating twice:
#   EI*v = -(R_A*x^3/6 - P*<x - a>^3/6 + R_B*<x - s>^3/6) + C1*x,  v(0) = 0,
#   v(s) = 0  =>  C1 = (R_A*s^3/6 - P*<s - a>^3/6)/s
func deflection_at(x: float) -> float:
	return (-_third(x) + _c1() * x) / flexural_rigidity()


# EI*v' = -(R_A*x^2/2 - P*<x - a>^2/2 + R_B*<x - s>^2/2) + C1
func slope_at(x: float) -> float:
	var s: float = reaction_a() * x * x / 2.0 - load * pow(_mac(x, load_position), 2) / 2.0 \
			+ reaction_b() * pow(_mac(x, support_span), 2) / 2.0
	return (-s + _c1()) / flexural_rigidity()


func _third(x: float) -> float:
	return reaction_a() * pow(x, 3) / 6.0 - load * pow(_mac(x, load_position), 3) / 6.0 \
			+ reaction_b() * pow(_mac(x, support_span), 3) / 6.0


func _c1() -> float:
	return _third(support_span) / support_span


func _mac(x: float, at: float) -> float:
	return maxf(x - at, 0.0)


# V is piecewise constant: check each segment
func max_shear() -> float:
	var best: float = 0.0
	for x: float in [0.0, load_position + 1e-9, support_span + 1e-9, length]:
		best = maxf(best, absf(shear_at(minf(x, length))))
	return best


# M is piecewise linear: its extremes are at the load or the roller
func max_moment_position() -> float:
	return load_position if absf(moment_at(load_position)) >= absf(moment_at(support_span)) else support_span


# Largest |v| by sampling (the elastic curve has at most one extremum per segment)
func max_deflection_position() -> float:
	var best: float = 0.0
	for i: int in 1001:
		var x: float = length * i / 1000.0
		if absf(deflection_at(x)) > absf(deflection_at(best)):
			best = x
	return best
