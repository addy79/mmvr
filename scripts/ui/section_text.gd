class_name SectionText
extends RefCounted
## Human-readable dimensions of a cross-section, in mm.


static func describe(section: CrossSection) -> String:
	if section is RectSection:
		var s := section as RectSection
		return "Rectangle b × h = %.0f × %.0f mm" % [s.b * 1e3, s.h * 1e3]
	if section is CircleSection:
		return "Circle d = %.0f mm" % ((section as CircleSection).r * 2e3)
	if section is TubeSection:
		var t := section as TubeSection
		return "Tube d_o = %.0f mm, wall %.0f mm" % [t.r_o * 2e3, (t.r_o - t.r_i) * 1e3]
	if section is ISection:
		var i := section as ISection
		return "I-beam d = %.0f, b_f = %.0f, t_f = %.1f, t_w = %.2f mm" % [i.d * 1e3, i.b_f * 1e3,
				i.t_f * 1e3, i.t_w * 1e3]
	return section.display_name
