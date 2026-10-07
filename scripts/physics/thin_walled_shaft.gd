class_name ThinWalledShaft
extends RefCounted
## Chapter 3: thin-walled hollow shaft of rectangular cross-section (centerline a x b,
## uniform wall thickness t) under torque T. The shear flow q = tau*t is constant around
## the closed wall.

var width: float = 0.1           ## outer width [m]
var depth: float = 0.06          ## outer depth [m]
var thickness: float = 0.005     ## t [m]
var torque: float = 2.0e3
var length: float = 1.5
var material: LabMaterial = LabMaterial.steel()


# Area enclosed by the wall centerline: A = (b - t)(h - t)
func enclosed_area() -> float:
	return (width - thickness) * (depth - thickness)


# Shear flow: q = T/(2*A)
func shear_flow() -> float:
	return torque / (2.0 * enclosed_area())


# tau = q/t = T/(2*t*A)
func shear_stress() -> float:
	return shear_flow() / thickness


# phi = T*L/(4*A^2*G) * (closed integral of ds/t), with the integral = 2(a + b)/t
func angle_of_twist() -> float:
	var a: float = width - thickness
	var b: float = depth - thickness
	var a_enc: float = enclosed_area()
	return torque * length * (2.0 * (a + b) / thickness) / (4.0 * a_enc * a_enc * material.shear_modulus())
