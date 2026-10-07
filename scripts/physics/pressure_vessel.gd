class_name PressureVessel
extends RefCounted
## Chapter 7: thin-walled pressure vessel (wall thickness t much smaller than radius r) under
## gauge pressure p. Stresses from equilibrium of half the vessel.

var pressure: float = 2.0e6      ## p [Pa]
var radius: float = 0.5          ## inner radius r [m]
var thickness: float = 0.01      ## t [m]
var spherical: bool = false


# Cylinder hoop stress: sigma_1 = p*r/t (sphere: p*r/(2t) in every direction)
func hoop_stress() -> float:
	return pressure * radius / (thickness * (2.0 if spherical else 1.0))


# Longitudinal stress: sigma_2 = p*r/(2t)
func axial_stress() -> float:
	return pressure * radius / (2.0 * thickness)


## Stress element on the wall: x along the axis, y around the circumference.
func stress_state() -> PlaneStress:
	return PlaneStress.new(axial_stress(), hoop_stress(), 0.0)


# Maximum shear: sigma_3 = 0 (outer surface) makes the out-of-plane value sigma_1/2 govern
func absolute_max_shear() -> float:
	return stress_state().absolute_max_shear()
