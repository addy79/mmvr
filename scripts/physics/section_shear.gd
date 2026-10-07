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


# tau_avg = V/A (for comparison: a rectangle reaches 1.5*tau_avg)
func average_shear_stress() -> float:
	return shear_force / section.area()


# Fastener spacing: one fastener of capacity F per length s with F = q*s  =>  s = F/q
func fastener_spacing(y: float, fastener_capacity: float) -> float:
	var q: float = shear_flow_at(y)
	return fastener_capacity / q if q > 0.0 else INF
