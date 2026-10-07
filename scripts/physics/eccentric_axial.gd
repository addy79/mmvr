class_name EccentricAxial
extends RefCounted
## Chapter 4: axial load P applied at a distance e above the centroid (in the plane of
## symmetry). Equivalent to a centric load P plus a couple M = P*e; the stresses superpose.

var load: float = 100.0e3        ## P [N], tension positive
var eccentricity: float = 0.03   ## e [m], above the centroid
var section: CrossSection = RectSection.new(0.1, 0.2)


# M = P*e (bends so that the side of the load gets the extra tension)
func moment() -> float:
	return load * eccentricity


# sigma(y) = P/A + P*e*y/I
func stress_at(y: float) -> float:
	return load / section.area() + load * eccentricity * y / section.moment_of_inertia()


# Neutral axis (sigma = 0): y_0 = -I/(A*e); off the section when |y_0| > c
func neutral_axis() -> float:
	return -section.moment_of_inertia() / (section.area() * eccentricity) if eccentricity != 0.0 else -INF


# Kern limit: the stress keeps one sign while |e| <= I/(A*c)
func kern_limit() -> float:
	return section.moment_of_inertia() / (section.area() * section.y_max())
