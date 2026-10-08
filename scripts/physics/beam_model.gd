class_name BeamModel
extends RefCounted
## Common interface of the statically determinate beam solvers: one point load P at x = a
## and a uniform load w over the whole span.
## Sign conventions (Beer & Johnston): loads > 0 act downward; V and M positive per the
## standard convention (M > 0 sags); y measured upward from the neutral axis;
## deflection v > 0 is DOWNWARD and slope = dv/dx; sigma > 0 is tension.

var length: float            ## L [m]
var load: float              ## P [N], downward positive
var load_position: float     ## a [m], from the left end
var distributed_load: float = 0.0  ## w [N/m], downward positive, whole span
var section: CrossSection
var material: LabMaterial


func _init(p_length: float, p_load: float, p_load_position: float,
		p_section: CrossSection, p_material: LabMaterial) -> void:
	length = p_length
	load = p_load
	load_position = p_load_position
	section = p_section
	material = p_material


## b = L - a [m]
func load_offset_from_b() -> float:
	return length - load_position


func reaction_a() -> float:
	return 0.0


func reaction_b() -> float:
	return 0.0


func shear_at(_x: float) -> float:
	return 0.0


func moment_at(_x: float) -> float:
	return 0.0


func slope_at(_x: float) -> float:
	return 0.0


func deflection_at(_x: float) -> float:
	return 0.0


## Position of the largest |M|.
func max_moment_position() -> float:
	return 0.0


## Largest |V| over the span.
func max_shear() -> float:
	return 0.0


func max_deflection_position() -> float:
	return 0.0


## Signed bending moment where |M| is largest.
func max_moment() -> float:
	return moment_at(max_moment_position())


func max_deflection() -> float:
	return deflection_at(max_deflection_position())


# Flexure formula: sigma = -M*y/I
func bending_stress(x: float, y: float) -> float:
	return -moment_at(x) * y / section.moment_of_inertia()


# sigma_max = |M|max*c/I
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


# Shear flow: q = V*Q/I [N/m]
func shear_flow(x: float, y: float) -> float:
	return shear_at(x) * section.first_moment(y) / section.moment_of_inertia()


# FS = sigma_Y / sigma_max (INF when unloaded)
func factor_of_safety() -> float:
	var sigma: float = max_bending_stress()
	return material.yield_strength / sigma if sigma > 0.0 else INF


# Area method: M(x1) - M(x0) = integral of V dx from x0 to x1 (midpoint rule)
func shear_area(x0: float, x1: float) -> float:
	const STEPS: int = 2000
	var h: float = (x1 - x0) / STEPS
	var total: float = 0.0
	for i: int in STEPS:
		total += shear_at(x0 + (i + 0.5) * h) * h
	return total


## Moment-area theorems between x0 and x1 (midpoint rule), with the curvature M/EI:
##   x = integral of M/EI dx            (first theorem:  theta(x1) - theta(x0) = -x, v downward)
##   y = integral of (x1 - x)*M/EI dx  (second theorem: tangential deviation of x1 from the tangent at x0)
func moment_area(x0: float, x1: float) -> Vector2:
	const STEPS: int = 2000
	var h: float = (x1 - x0) / STEPS
	var area: float = 0.0
	var first: float = 0.0
	for i: int in STEPS:
		var x: float = x0 + (i + 0.5) * h
		var k: float = curvature_at(x) * h
		area += k
		first += (x1 - x) * k
	return Vector2(area, first)


# Strength design: S_min = |M|max/sigma_all
func required_section_modulus(allowable_stress: float) -> float:
	return absf(max_moment()) / allowable_stress


# Curvature 1/rho = M/(EI) (sagging positive); d^2v/dx^2 = -M/(EI) for downward v
func curvature_at(x: float) -> float:
	return moment_at(x) / flexural_rigidity()


# Stiffness design: v is proportional to 1/I, so the I that brings v_max down to `limit` is
# I_req = I * v_max/limit
func required_inertia(limit: float) -> float:
	return section.moment_of_inertia() * absf(max_deflection()) / limit


# EI [N*m^2]
func flexural_rigidity() -> float:
	return material.youngs_modulus * section.moment_of_inertia()


# von Mises stress at (x, y) from bending and transverse shear: sigma_v = sqrt(sigma^2 + 3*tau^2)
func von_mises(x: float, y: float) -> float:
	return sqrt(pow(bending_stress(x, y), 2) + 3.0 * pow(shear_stress(x, y), 2))


## Largest von Mises stress in the beam: sampled along the span (plus the supports, the
## load and the largest-moment section) and through the depth, including both sides of a
## flange-web junction (where the width jumps).
func max_von_mises() -> float:
	return _max_over_beam(false)


## Largest maximum shear stress (what ANSYS calls "Maximum Shear Stress", the Tresca
## measure): tau_max = sqrt((sigma/2)^2 + tau^2) at each point, same sampling.
func max_combined_shear() -> float:
	return _max_over_beam(true)


func _max_over_beam(tresca: bool) -> float:
	var c: float = section.y_max()
	var ys := PackedFloat64Array()
	for k: int in 21:
		ys.append(c * k / 20.0)
	if section is ISection:
		var junction: float = c - (section as ISection).t_f
		ys.append(junction - 1e-7)
		ys.append(junction + 1e-7)
	var xs := PackedFloat64Array([0.0, length - 1e-9, max_moment_position(), load_position - 1e-9, load_position + 1e-9])
	for i: int in 41:
		xs.append(length * i / 40.0)
	var best: float = 0.0
	for x: float in xs:
		var xc: float = clampf(x, 0.0, length - 1e-9)
		var m: float = moment_at(xc)
		var v: float = shear_at(xc)
		for y: float in ys:
			var sigma: float = -m * y / section.moment_of_inertia()
			var t: float = section.width_at(y)
			var tau: float = v * section.first_moment(y) / (section.moment_of_inertia() * t) if t > 0.0 else 0.0
			var measure: float = sqrt(sigma * sigma / 4.0 + tau * tau) if tresca else sqrt(sigma * sigma + 3.0 * tau * tau)
			best = maxf(best, measure)
	return best
