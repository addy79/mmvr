class_name SectionPresets
extends RefCounted
## The cross-sections offered in the lab, with comparable overall size (150-203 mm deep).


static func all() -> Array[CrossSection]:
	return [
		RectSection.new(0.1, 0.2),                    # 100 x 200 mm
		CircleSection.new(0.075),                     # d = 150 mm
		TubeSection.new(0.08, 0.07),                  # 160 OD x 10 mm wall
		ISection.new(0.203, 0.203, 0.011, 0.00724),   # W200x46.1 nominal
		BoxSection.new(0.1, 0.2, 0.01),               # 100 x 200 x 10 mm box (HSS)
	]
