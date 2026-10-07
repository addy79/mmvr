class_name CrossSection
extends RefCounted
## Base class for doubly symmetric cross-sections bent about the horizontal centroidal axis.
## y is measured upward from the neutral axis. SI units: m, m^2, m^3, m^4.

var display_name: String


## Cross-sectional area A [m^2].
func area() -> float:
	return 0.0


## Second moment of area about the neutral axis, I [m^4].
func moment_of_inertia() -> float:
	return 0.0


## Second moment of area about the vertical centroidal axis [m^4].
func moment_of_inertia_vertical() -> float:
	return 0.0


## Half-width: distance from the vertical axis to the extreme fiber [m].
func z_max() -> float:
	return 0.0


## Distance from the neutral axis to the extreme fiber, c = y_max [m].
func y_max() -> float:
	return 0.0


## First moment Q [m^3] of the area beyond height y (|y| above the neutral axis).
func first_moment(_y: float) -> float:
	return 0.0


## Area A' [m^2] of the part beyond height |y| (the area whose first moment is Q).
func area_beyond(_y: float) -> float:
	return 0.0


# Elastic section modulus: S = I/c
func section_modulus() -> float:
	return moment_of_inertia() / y_max()


## Plastic section modulus Z [m^3]: M_p = sigma_Y*Z (first moments of both halves about
## the neutral axis, which for these doubly symmetric sections is the centroid).
func plastic_modulus() -> float:
	return 2.0 * first_moment(0.0)


## Section width t [m] cut by the horizontal line at height y.
func width_at(_y: float) -> float:
	return 0.0
