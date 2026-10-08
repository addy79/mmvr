class_name FeaSpecimen
extends RefCounted
## Lab 3's three specimens (80 mm long), fixed on the left face and pulled d along +x on the
## right face, modeled as plane-stress plates seen from the side:
##   cuboid    80 x 10 mm, 3 mm thick
##   cylinder  diameter 3 mm, drawn as an 80 x 3 mm strip whose thickness pi*d/4 gives the
##             same area pi*d^2/4 (a 2D stand-in for the round bar)
##   dog-bone  2 mm thick, grips 20 mm long x 10 mm wide, gauge 40 mm long x 3 mm wide, sharp
##             shoulders (the handout gives no fillet radius)

enum Shape { CUBOID, CYLINDER, DOG_BONE }

const LENGTH: float = 0.08
const NAMES: PackedStringArray = ["Cuboid", "Cylinder", "Dog-bone"]


static func height(shape: Shape) -> float:
	return 0.003 if shape == Shape.CYLINDER else 0.01


static func thickness(shape: Shape) -> float:
	match shape:
		Shape.CUBOID:
			return 0.003
		Shape.CYLINDER:
			return PI * 0.003 / 4.0
	return 0.002


## Material cell test for the shape (x, y in the plate frame, y from the bottom edge).
static func inside(shape: Shape) -> Callable:
	if shape != Shape.DOG_BONE:
		return func(_x: float, _y: float) -> bool: return true
	return func(x: float, y: float) -> bool: return x < 0.02 or x > 0.06 or absf(y - 0.005) < 0.0015


## Meshes and solves one specimen. Dog-bone rows are 0.5 mm so the gauge edges fall on grid lines.
static func solve(shape: Shape, element_size: float, material: LabMaterial, pull: float) -> PlaneStressFem:
	var rows: int = 20 if shape == Shape.DOG_BONE else maxi(2, roundi(height(shape) / element_size))
	var fem := PlaneStressFem.new(LENGTH, height(shape), element_size, inside(shape), rows)
	fem.thickness = thickness(shape)
	fem.youngs_modulus = material.youngs_modulus
	fem.poisson_ratio = material.poisson_ratio
	fem.pull_right_edge(pull)
	fem.solve()
	return fem


# Cross-section area of the narrowest part: cuboid 10*3, cylinder pi*3^2/4, dog-bone 3*2 [m^2]
static func narrowest_area(shape: Shape) -> float:
	return (0.003 if shape == Shape.DOG_BONE else height(shape)) * thickness(shape)


# Hand estimate, the specimen as springs in series (uniform stress in each part):
#   d = F*sum(L_i/(E*A_i))  =>  F = d / sum(L_i/(E*A_i)),  sigma = F/A_narrowest
# Prismatic bars: sigma = E*d/L whatever the area.
static func hand_force(shape: Shape, material: LabMaterial, pull: float) -> float:
	var e: float = material.youngs_modulus
	if shape != Shape.DOG_BONE:
		return e * narrowest_area(shape) * pull / LENGTH
	var t: float = thickness(shape)
	var flexibility: float = 2.0 * 0.02 / (e * 0.01 * t) + 0.04 / (e * 0.003 * t)
	return pull / flexibility


static func hand_stress(shape: Shape, material: LabMaterial, pull: float) -> float:
	return hand_force(shape, material, pull) / narrowest_area(shape)
