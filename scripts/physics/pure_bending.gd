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
	return section.moment_of_inertia() / section.y_max()


# sigma_m = |M|/S = |M|*c/I
func max_stress() -> float:
	return absf(moment) / section_modulus()


# eps_m = c/rho
func max_strain() -> float:
	return section.y_max() * absf(curvature())


# Largest elastic moment: M_Y = sigma_Y*S
func yield_moment() -> float:
	return material.yield_strength * section_modulus()


func factor_of_safety() -> float:
	var sigma: float = max_stress()
	return material.yield_strength / sigma if sigma > 0.0 else INF
