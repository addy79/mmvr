class_name PureBending
extends RefCounted
## Chapter 4: a prismatic member bent by equal and opposite couples M (no shear).
## M > 0 sags (top in compression); y is measured upward from the neutral axis.

var moment: float = 5.0e3         ## M [N*m]
var section: CrossSection = RectSection.new(0.1, 0.2)
var material: LabMaterial = LabMaterial.steel()


# Curvature: 1/rho = M/(E*I) [1/m]
func curvature() -> float:
	return moment / (material.youngs_modulus * section.moment_of_inertia())


# rho = E*I/M [m] (INF for M = 0)
func radius_of_curvature() -> float:
	var k: float = curvature()
	return 1.0 / absf(k) if k != 0.0 else INF


# Plane sections remain plane: eps_x = -y/rho = -y*(1/rho)
func strain_at(y: float) -> float:
	return -y * curvature()


# Flexure formula: sigma_x = -M*y/I (= E*eps_x in the elastic range)
func stress_at(y: float) -> float:
	return -moment * y / section.moment_of_inertia()


# Elastic section modulus: S = I/c
func section_modulus() -> float:
	return section.section_modulus()


# sigma_m = |M|/S = |M|*c/I
func max_stress() -> float:
	return absf(moment) / section_modulus()


# eps_m = c/rho
func max_strain() -> float:
	return section.y_max() * absf(curvature())


# Largest elastic moment: M_Y = sigma_Y*S
func yield_moment() -> float:
	return material.yield_strength * section_modulus()


# Plastic moment: the whole section at +-sigma_Y, M_p = sigma_Y*Z
func plastic_moment() -> float:
	return material.yield_strength * section.plastic_modulus()


# Shape factor k = M_p/M_Y = Z/S
func shape_factor() -> float:
	return section.plastic_modulus() / section_modulus()


## Elastic-perfectly-plastic moment-curvature relation, any section:
# M(k) = -integral over the depth of sigma(y)*y*t(y) dy with sigma = clamp(-E*k*y, -sigma_Y, sigma_Y)
# (midpoint rule). Equals E*I*k while elastic and tends to M_p.
func moment_at_curvature(k: float) -> float:
	const STEPS: int = 600
	var c: float = section.y_max()
	var dy: float = 2.0 * c / STEPS
	var total: float = 0.0
	for i: int in STEPS:
		var y: float = -c + (i + 0.5) * dy
		total -= stress_at_curvature(k, y) * y * section.width_at(y) * dy
	return total


# Elastic-perfectly-plastic fiber stress at curvature k: sigma = clamp(-E*k*y, -sigma_Y, sigma_Y)
func stress_at_curvature(k: float, y: float) -> float:
	var sy: float = material.yield_strength
	return clampf(-material.youngs_modulus * k * y, -sy, sy)


# Curvature at first yield: k_Y = sigma_Y/(E*c)
func yield_curvature() -> float:
	return material.yield_strength / (material.youngs_modulus * section.y_max())


# Half-depth of the elastic core at curvature k: y_Y = eps_Y/k (capped at c)
func elastic_core(k: float) -> float:
	if k == 0.0:
		return section.y_max()
	return minf(material.yield_strength / (material.youngs_modulus * absf(k)), section.y_max())


func factor_of_safety() -> float:
	var sigma: float = max_stress()
	return material.yield_strength / sigma if sigma > 0.0 else INF
