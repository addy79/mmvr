class_name AxialMember
extends RefCounted
## Chapter 2: a straight round bar under axial load P and a temperature change dT.
## Free ends: it stretches. Both ends fixed: the walls stop it, so dT causes stress.

var load: float = 50.0e3          ## P [N], tension positive (free member only)
var length: float = 1.0           ## L [m]
var diameter: float = 0.025       ## d [m]
var temperature_change: float = 0.0  ## dT [K]
var ends_fixed: bool = false
var material: LabMaterial = LabMaterial.steel()


# A = pi*d^2/4
func area() -> float:
	return PI * diameter * diameter / 4.0


# Free: sigma = P/A. Fixed ends: delta = 0 => sigma = -E*alpha*dT
func stress() -> float:
	if ends_fixed:
		return -material.youngs_modulus * material.thermal_expansion * temperature_change
	return load / area()


# Hooke's law: eps = sigma/E (mechanical strain)
func strain() -> float:
	return stress() / material.youngs_modulus


# Thermal strain: eps_T = alpha*dT
func thermal_strain() -> float:
	return material.thermal_expansion * temperature_change


# delta = P*L/(A*E) + alpha*dT*L (free); 0 when both ends are fixed
func elongation() -> float:
	if ends_fixed:
		return 0.0
	return load * length / (area() * material.youngs_modulus) + thermal_strain() * length


# Poisson: eps_lateral = -nu*eps (from the mechanical strain)
func lateral_strain() -> float:
	return -material.poisson_ratio * strain()


# Change of diameter: delta_d = eps_lateral*d
func diameter_change() -> float:
	return lateral_strain() * diameter


# Axial stiffness k = A*E/L [N/m]
func stiffness() -> float:
	return area() * material.youngs_modulus / length
