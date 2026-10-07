class_name StressStrainCurve
extends RefCounted
## Idealized engineering stress-strain curve of a tension test, with elastic unloading.

const NECK_DROP: float = 0.2  ## engineering stress falls 20% from sigma_U to fracture

var material: LabMaterial


func _init(p_material: LabMaterial) -> void:
	material = p_material


# eps_Y = sigma_Y / E (Hooke's law at the yield point)
func yield_strain() -> float:
	return material.yield_strength / material.youngs_modulus


## Engineering stress [Pa] at engineering strain eps (0 after fracture).
## Elastic: sigma = E*eps. Plateau: sigma = sigma_Y. Hardening: parabola rising to sigma_U at
## eps_u with zero slope. Necking: parabola falling to (1 - NECK_DROP)*sigma_U at eps_f.
func stress_at(eps: float) -> float:
	var m: LabMaterial = material
	if eps <= 0.0:
		return 0.0
	if eps > m.fracture_strain:
		return 0.0
	if m.behavior == LabMaterial.Behavior.BRITTLE:
		return m.youngs_modulus * eps
	var eps_y: float = yield_strain()
	if eps <= eps_y:
		return m.youngs_modulus * eps
	var start: float = m.hardening_strain if m.behavior == LabMaterial.Behavior.YIELD_PLATEAU else eps_y
	if eps <= start:
		return m.yield_strength
	if eps <= m.ultimate_strain:
		var t: float = (m.ultimate_strain - eps) / (m.ultimate_strain - start)
		return m.ultimate_strength - (m.ultimate_strength - m.yield_strength) * t * t
	var n: float = (eps - m.ultimate_strain) / (m.fracture_strain - m.ultimate_strain)
	return m.ultimate_strength * (1.0 - NECK_DROP * n * n)


## Stress after loading to eps_max and unloading back to eps: elastic line of slope E.
# sigma = sigma(eps_max) - E*(eps_max - eps), not below zero
func unloading_stress(eps_max: float, eps: float) -> float:
	return maxf(stress_at(eps_max) - material.youngs_modulus * (eps_max - eps), 0.0)


# Permanent set: eps_p = eps_max - sigma(eps_max)/E (elastic strain is recovered)
func permanent_set(eps_max: float) -> float:
	return maxf(eps_max - stress_at(eps_max) / material.youngs_modulus, 0.0)


# Modulus of resilience: u_Y = sigma_Y^2 / (2E) (area under the elastic part) [J/m^3]
func modulus_of_resilience() -> float:
	var s: float = material.yield_strength if material.behavior != LabMaterial.Behavior.BRITTLE \
			else material.ultimate_strength
	return s * s / (2.0 * material.youngs_modulus)


# Modulus of toughness: u_T = integral of sigma d(eps) from 0 to eps_f (trapezoid rule) [J/m^3]
func modulus_of_toughness() -> float:
	const STEPS: int = 4000
	var h: float = material.fracture_strain / STEPS
	var total: float = 0.0
	for i: int in STEPS:
		total += 0.5 * (stress_at(i * h) + stress_at(minf((i + 1) * h, material.fracture_strain))) * h
	return total
