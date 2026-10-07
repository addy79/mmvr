class_name SimplySupportedBeam
extends RefCounted
## Simply supported beam (pin at A, x = 0; roller at B, x = L) with one point load.
## Sign conventions (Beer & Johnston): load P > 0 acts downward; V and M positive per the
## standard convention (M > 0 sags); y measured upward from the neutral axis;
## deflection v > 0 is DOWNWARD; sigma > 0 is tension.

var length: float          ## L [m]
var load: float            ## P [N], downward positive
var load_position: float   ## a [m], distance from support A
var section: CrossSection
var material: BeamMaterial


func _init(p_length: float, p_load: float, p_load_position: float,
		p_section: CrossSection, p_material: BeamMaterial) -> void:
	length = p_length
	load = p_load
	load_position = p_load_position
	section = p_section
	material = p_material


## b = L - a [m]
func load_offset_from_b() -> float:
	return length - load_position


# R_A = P*b/L (moments about B)
func reaction_a() -> float:
	return load * load_offset_from_b() / length


# R_B = P*a/L (moments about A)
func reaction_b() -> float:
	return load * load_position / length


# V(x) = R_A for x <= a, V(x) = -R_B for x > a (the jump of P at x = a is assigned to the right).
func shear_at(x: float) -> float:
	return reaction_a() if x <= load_position else -reaction_b()


# M(x) = R_A*x for x <= a, M(x) = R_B*(L - x) for x > a
func moment_at(x: float) -> float:
	if x <= load_position:
		return reaction_a() * x
	return reaction_b() * (length - x)


# |V|max = max(|R_A|, |R_B|): V is constant on each side of the load
func max_shear() -> float:
	return maxf(absf(reaction_a()), absf(reaction_b()))


# M_max = P*a*b/L, at the load
func max_moment() -> float:
	return load * load_position * load_offset_from_b() / length


# Elastic curve, downward positive:
#   x <= a: v(x) = P*b*x*(L^2 - b^2 - x^2) / (6*E*I*L)
#   x >  a: same formula mirrored (x -> L - x, b -> a):
#           v(x) = P*a*(L - x)*(L^2 - a^2 - (L - x)^2) / (6*E*I*L)
func deflection_at(x: float) -> float:
	var l: float = length
	var b: float = load_offset_from_b()
	var a: float = load_position
	if x <= a:
		return load * b * x * (l * l - b * b - x * x) / (6.0 * _flexural_rigidity() * l)
	var xm: float = l - x
	return load * a * xm * (l * l - a * a - xm * xm) / (6.0 * _flexural_rigidity() * l)


# Maximum deflection, in the longer segment where dv/dx = 0:
#   a >= b: x_m = sqrt((L^2 - b^2)/3), v_max = P*b*(L^2 - b^2)^(3/2) / (9*sqrt(3)*E*I*L)
#   a <  b: mirrored (b -> a, x_m measured from B)
func max_deflection_position() -> float:
	var l: float = length
	var a: float = load_position
	var b: float = load_offset_from_b()
	if a >= b:
		return sqrt((l * l - b * b) / 3.0)
	return l - sqrt((l * l - a * a) / 3.0)


func max_deflection() -> float:
	var l: float = length
	var short: float = minf(load_position, load_offset_from_b())
	return load * short * pow(l * l - short * short, 1.5) / (9.0 * sqrt(3.0) * _flexural_rigidity() * l)


# Flexure formula: sigma = -M*y/I
func bending_stress(x: float, y: float) -> float:
	return -moment_at(x) * y / section.moment_of_inertia()


# sigma_max = |M_max|*c/I
func max_bending_stress() -> float:
	return absf(max_moment()) * section.y_max() / section.moment_of_inertia()


# Shear formula: tau = V*Q/(I*t)
func shear_stress(x: float, y: float) -> float:
	var t: float = section.width_at(y)
	if t <= 0.0:
		return 0.0
	return shear_at(x) * section.first_moment(y) / (section.moment_of_inertia() * t)


# tau_max = |V|max*Q(0)/(I*t(0)); max at the neutral axis for all four supported sections
func max_shear_stress() -> float:
	return max_shear() * section.first_moment(0.0) / (section.moment_of_inertia() * section.width_at(0.0))


# FS = sigma_Y / sigma_max (INF when unloaded)
func factor_of_safety() -> float:
	var sigma: float = max_bending_stress()
	return material.yield_strength / sigma if sigma > 0.0 else INF


# EI [N*m^2]
func _flexural_rigidity() -> float:
	return material.youngs_modulus * section.moment_of_inertia()
