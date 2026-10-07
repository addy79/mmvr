class_name StrainRosette
extends RefCounted
## Chapter 7: a 45-degree (rectangular) strain rosette glued on a free surface. Gauges a, b, c
## read normal strains at 0, 45 and 90 degrees from x. Gives the plane strain state, its
## principal strains, and (with Hooke's law for plane stress) the stresses.

var strain_a: float = 600.0e-6   ## eps at 0 deg
var strain_b: float = 400.0e-6   ## eps at 45 deg
var strain_c: float = -200.0e-6  ## eps at 90 deg
var material: LabMaterial = LabMaterial.steel()


# eps_x = eps_a, eps_y = eps_c, and eps_45 = (eps_x + eps_y)/2 + gamma_xy/2 => gamma_xy = 2*eps_b - (eps_a + eps_c)
func shear_strain() -> float:
	return 2.0 * strain_b - (strain_a + strain_c)


# Principal strains: (eps_x + eps_y)/2 +- sqrt(((eps_x - eps_y)/2)^2 + (gamma_xy/2)^2)
func principal_strains() -> Vector2:
	var avg: float = (strain_a + strain_c) / 2.0
	var r: float = sqrt(pow((strain_a - strain_c) / 2.0, 2) + pow(shear_strain() / 2.0, 2))
	return Vector2(avg + r, avg - r)


# Normal strain read at angle theta: eps = (eps_x + eps_y)/2 + (eps_x - eps_y)/2*cos2t + gamma/2*sin2t
func strain_at(theta: float) -> float:
	return (strain_a + strain_c) / 2.0 + (strain_a - strain_c) / 2.0 * cos(2.0 * theta) + shear_strain() / 2.0 * sin(2.0 * theta)


## Plane-stress Hooke's law:
# sigma_x = E/(1 - nu^2)*(eps_x + nu*eps_y), sigma_y = E/(1 - nu^2)*(eps_y + nu*eps_x), tau_xy = G*gamma_xy
func stress_state() -> PlaneStress:
	var e: float = material.youngs_modulus
	var nu: float = material.poisson_ratio
	var k: float = e / (1.0 - nu * nu)
	return PlaneStress.new(k * (strain_a + nu * strain_c), k * (strain_c + nu * strain_a),
			material.shear_modulus() * shear_strain())
