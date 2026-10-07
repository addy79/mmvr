class_name SectionShear
extends RefCounted
## Chapter 6: shearing stresses and shear flow on a beam cross-section carrying shear V.

var shear_force: float = 50.0e3   ## V [N]
var section: CrossSection = RectSection.new(0.1, 0.2)


# Shear formula: tau = V*Q/(I*t)
func shear_stress_at(y: float) -> float:
	var t: float = section.width_at(y)
	return shear_force * section.first_moment(y) / (section.moment_of_inertia() * t) if t > 0.0 else 0.0


# Shear flow: q = V*Q/I [N/m], the horizontal force per unit length on the cut at height y
func shear_flow_at(y: float) -> float:
	return shear_force * section.first_moment(y) / section.moment_of_inertia()


# tau_max at the neutral axis (y = 0) for the lab's sections
func max_shear_stress() -> float:
	return shear_stress_at(0.0)


# Centroid distance of A' from the neutral axis: y' = Q/A'
func centroid_beyond(y: float) -> float:
	var a: float = section.area_beyond(y)
	return section.first_moment(y) / a if a > 0.0 else 0.0


# Share of V carried by an I-beam's web: (1/V)*integral of tau*t dy over the web
#   = (1/I)*integral of Q(y) dy over -h_w/2..h_w/2 (midpoint rule). 1 for other sections.
func web_share() -> float:
	if not section is ISection:
		return 1.0
	var s := section as ISection
	var half: float = (s.d - 2.0 * s.t_f) / 2.0
	const STEPS: int = 400
	var total: float = 0.0
	for i: int in STEPS:
		total += section.first_moment(-half + (i + 0.5) * 2.0 * half / STEPS)
	return total * 2.0 * half / STEPS / section.moment_of_inertia()


# Design approximation for I-beams: tau ~ V/(d*t_w) (web carries V uniformly over the full depth)
func web_average_stress() -> float:
	if not section is ISection:
		return INF
	var s := section as ISection
	return shear_force / (s.d * s.t_w)


# Horizontal shear flow in an I-beam flange at distance s from the flange tip:
# q = V*Q/I with Q = (t_f*s)*(d - t_f)/2; largest where the flange meets the web (s = b_f/2)
func flange_shear_flow(s: float) -> float:
	if not section is ISection:
		return 0.0
	var i := section as ISection
	return shear_force * (i.t_f * s) * (i.d - i.t_f) / 2.0 / section.moment_of_inertia()


# tau_avg = V/A (for comparison: a rectangle reaches 1.5*tau_avg)
func average_shear_stress() -> float:
	return shear_force / section.area()


# Fastener spacing: one fastener of capacity F per length s with F = q*s  =>  s = F/q
func fastener_spacing(y: float, fastener_capacity: float) -> float:
	var q: float = shear_flow_at(y)
	return fastener_capacity / q if q > 0.0 else INF
