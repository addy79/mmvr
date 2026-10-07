class_name TorsionShaft
extends RefCounted
## Chapter 3: circular shaft (solid when r_i = 0) under torque T, fixed at one end.

var torque: float = 2.0e3         ## T [N*m]
var length: float = 1.5           ## L [m]
var outer_radius: float = 0.03    ## c = r_o [m]
var inner_radius: float = 0.0     ## r_i [m]
var material: LabMaterial = LabMaterial.steel()


# Polar moment of inertia: J = pi*(r_o^4 - r_i^4)/2
func polar_moment() -> float:
	return PI * (pow(outer_radius, 4) - pow(inner_radius, 4)) / 2.0


# Torsion formula: tau = T*rho/J (zero inside the bore)
func shear_stress_at(rho: float) -> float:
	if rho < inner_radius or rho > outer_radius:
		return 0.0
	return torque * rho / polar_moment()


# tau_max = T*c/J
func max_shear_stress() -> float:
	return absf(torque) * outer_radius / polar_moment()


# Angle of twist: phi = T*L/(J*G) [rad]
func angle_of_twist() -> float:
	return torque * length / (polar_moment() * material.shear_modulus())


# Twist at distance x from the fixed end: phi(x) = T*x/(J*G)
func twist_at(x: float) -> float:
	return torque * x / (polar_moment() * material.shear_modulus())


# Shear strain: gamma = rho*phi/L
func shear_strain_at(rho: float) -> float:
	return rho * angle_of_twist() / length


# FS against shear yield, taking tau_Y = sigma_Y/2 (maximum-shear-stress criterion)
func factor_of_safety() -> float:
	var tau: float = max_shear_stress()
	return material.yield_strength / 2.0 / tau if tau > 0.0 else INF


# Smallest solid shaft for an allowable shear stress: tau_all = 2T/(pi*c^3) => c = (2T/(pi*tau_all))^(1/3)
func required_solid_radius(tau_all: float) -> float:
	return pow(2.0 * absf(torque) / (PI * tau_all), 1.0 / 3.0)


# Power transmission: P = T*omega = 2*pi*f*T [W]
func power_at(frequency: float) -> float:
	return 2.0 * PI * frequency * torque
