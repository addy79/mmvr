class_name RodAndPin
extends RefCounted
## Chapter 1: a round rod pulled by P, attached to a clevis by a pin.
## The rod's flat eye (thickness t) bears on the pin; the pin is in single or double shear.

var load: float = 20.0e3            ## P [N], tension
var rod_diameter: float = 0.02      ## d [m]
var pin_diameter: float = 0.016     ## d_p [m]
var eye_thickness: float = 0.02     ## t [m]
var double_shear: bool = true
var plane_angle: float = 0.0        ## theta [rad] between the cut plane's normal and the rod axis
var material: LabMaterial = LabMaterial.steel()


# A = pi*d^2/4
func rod_area() -> float:
	return PI * rod_diameter * rod_diameter / 4.0


# A_pin = pi*d_p^2/4
func pin_area() -> float:
	return PI * pin_diameter * pin_diameter / 4.0


# Normal stress: sigma = P/A
func normal_stress() -> float:
	return load / rod_area()


# Average shear in the pin: tau = P/(n*A_pin), n = 1 (single) or 2 (double shear)
func pin_shear_stress() -> float:
	return load / ((2.0 if double_shear else 1.0) * pin_area())


# Bearing stress on the eye: sigma_b = P/(t*d_p) (projected contact area)
func bearing_stress() -> float:
	return load / (eye_thickness * pin_diameter)


# Oblique plane: sigma_theta = (P/A)*cos^2(theta)
func oblique_normal_stress() -> float:
	return normal_stress() * cos(plane_angle) * cos(plane_angle)


# Oblique plane: tau_theta = (P/A)*sin(theta)*cos(theta); largest, P/(2A), at 45 degrees
func oblique_shear_stress() -> float:
	return normal_stress() * sin(plane_angle) * cos(plane_angle)


# FS = sigma_Y / sigma for the rod
func factor_of_safety() -> float:
	return material.yield_strength / normal_stress() if load > 0.0 else INF
