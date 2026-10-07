class_name CompositeSection
extends RefCounted
## Chapter 4: a rectangular beam of material 1 (b1 x h1) resting on a plate of material 2
## (b2 x h2), bonded so they bend together. Transformed-section method: material 2 is
## replaced by material 1 of width n*b2, n = E2/E1. Heights z are measured up from the
## bottom of the plate.

var b1: float = 0.1
var h1: float = 0.2
var b2: float = 0.1
var h2: float = 0.01
var material_1: LabMaterial = LabMaterial.wood()
var material_2: LabMaterial = LabMaterial.steel()
var moment: float = 10.0e3        ## M [N*m], sagging positive


# Modular ratio n = E2/E1
func modular_ratio() -> float:
	return material_2.youngs_modulus / material_1.youngs_modulus


# Neutral axis of the transformed section: z_bar = sum(A_i*z_i)/sum(A_i), A_2 = n*b2*h2
func neutral_axis() -> float:
	var a2: float = modular_ratio() * b2 * h2
	var a1: float = b1 * h1
	return (a2 * h2 / 2.0 + a1 * (h2 + h1 / 2.0)) / (a2 + a1)


# Parallel-axis theorem: I_t = sum(I_i + A_i*d_i^2)
func transformed_inertia() -> float:
	var n: float = modular_ratio()
	var z: float = neutral_axis()
	var d2: float = z - h2 / 2.0
	var d1: float = h2 + h1 / 2.0 - z
	return n * b2 * h2 * h2 * h2 / 12.0 + n * b2 * h2 * d2 * d2 + b1 * h1 * h1 * h1 / 12.0 + b1 * h1 * d1 * d1


## Bending stress at height z: sigma_1 = -M*y/I_t in material 1, sigma_2 = -n*M*y/I_t in
## material 2, with y = z - z_bar.
func stress_at(z: float) -> float:
	var y: float = z - neutral_axis()
	var s: float = -moment * y / transformed_inertia()
	return s * modular_ratio() if z < h2 else s


func total_height() -> float:
	return h1 + h2
