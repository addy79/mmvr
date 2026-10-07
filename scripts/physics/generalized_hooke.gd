class_name GeneralizedHooke
extends RefCounted
## Chapter 2: strains of an isotropic element under normal stresses on all three faces
## (generalized Hooke's law, by superposition of three uniaxial cases with Poisson effects).

var sigma_x: float = 100.0e6
var sigma_y: float = -50.0e6
var sigma_z: float = 20.0e6
var material: LabMaterial = LabMaterial.steel()


# eps_x = (sigma_x - nu*(sigma_y + sigma_z))/E, and cyclically
func strain_x() -> float:
	return (sigma_x - material.poisson_ratio * (sigma_y + sigma_z)) / material.youngs_modulus


func strain_y() -> float:
	return (sigma_y - material.poisson_ratio * (sigma_x + sigma_z)) / material.youngs_modulus


func strain_z() -> float:
	return (sigma_z - material.poisson_ratio * (sigma_x + sigma_y)) / material.youngs_modulus


# Dilatation (volume change per unit volume): e = eps_x + eps_y + eps_z = (1 - 2nu)(sx + sy + sz)/E
func dilatation() -> float:
	return strain_x() + strain_y() + strain_z()


# Bulk modulus: k = E/(3(1 - 2nu)), so that e = -p/k under hydrostatic pressure p
func bulk_modulus() -> float:
	return material.youngs_modulus / (3.0 * (1.0 - 2.0 * material.poisson_ratio))
