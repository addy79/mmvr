class_name SectionProfile
extends RefCounted
## Cross-section outline for meshing, as 2D points (z, y) in meters, plus end-cap triangles.
## Each strip is a run of connected points with outward normals; a sharp corner starts a
## new strip, a smooth curve shares its points.

const CIRCLE_SEGMENTS: int = 20

var strip_points: Array[PackedVector2Array] = []
var strip_normals: Array[PackedVector2Array] = []
var cap_triangles: PackedVector2Array = PackedVector2Array()  ## every 3 points = 1 triangle


static func for_section(section: CrossSection) -> SectionProfile:
	var profile := SectionProfile.new()
	if section is RectSection:
		var rect := section as RectSection
		profile._add_polygon(_box(-rect.b / 2.0, -rect.h / 2.0, rect.b / 2.0, rect.h / 2.0))
		profile._add_box_cap(-rect.b / 2.0, -rect.h / 2.0, rect.b / 2.0, rect.h / 2.0)
	elif section is CircleSection:
		var circle := section as CircleSection
		profile._add_circle(circle.r, 1.0)
		profile._add_annulus_cap(circle.r, 0.0)
	elif section is TubeSection:
		var tube := section as TubeSection
		profile._add_circle(tube.r_o, 1.0)
		profile._add_circle(tube.r_i, -1.0)
		profile._add_annulus_cap(tube.r_o, tube.r_i)
	elif section is ISection:
		profile._add_i_beam(section as ISection)
	elif section is BoxSection:
		profile._add_box_section(section as BoxSection)
	return profile


## Copy transformed by p -> basis * p + offset (normals by the basis only), for drawing
## sections larger than life, turned a quarter turn, or shifted off the axis.
func transformed(basis: Transform2D, offset: Vector2 = Vector2.ZERO) -> SectionProfile:
	var out := SectionProfile.new()
	for s: int in strip_points.size():
		var pts := PackedVector2Array()
		var nrm := PackedVector2Array()
		for i: int in strip_points[s].size():
			pts.append(basis * strip_points[s][i] + offset)
			nrm.append((basis.basis_xform(strip_normals[s][i])).normalized())
		out.strip_points.append(pts)
		out.strip_normals.append(nrm)
	for p: Vector2 in cap_triangles:
		out.cap_triangles.append(basis * p + offset)
	return out


static func _box(z0: float, y0: float, z1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(z0, y0), Vector2(z1, y0), Vector2(z1, y1), Vector2(z0, y1)])


## Sharp-cornered closed polygon, counter-clockwise in (z, y).
func _add_polygon(corners: PackedVector2Array) -> void:
	for i: int in corners.size():
		var p0: Vector2 = corners[i]
		var p1: Vector2 = corners[(i + 1) % corners.size()]
		var d: Vector2 = (p1 - p0).normalized()
		var n := Vector2(d.y, -d.x)
		strip_points.append(PackedVector2Array([p0, p1]))
		strip_normals.append(PackedVector2Array([n, n]))


## Smooth circle; normal_sign -1 makes the normals point inward (bore of a tube).
func _add_circle(radius: float, normal_sign: float) -> void:
	var points := PackedVector2Array()
	var normals := PackedVector2Array()
	for i: int in CIRCLE_SEGMENTS + 1:
		var dir := Vector2.from_angle(TAU * i / CIRCLE_SEGMENTS)
		points.append(dir * radius)
		normals.append(dir * normal_sign)
	strip_points.append(points)
	strip_normals.append(normals)


func _add_box_cap(z0: float, y0: float, z1: float, y1: float) -> void:
	cap_triangles.append_array(PackedVector2Array([
		Vector2(z0, y0), Vector2(z1, y0), Vector2(z1, y1),
		Vector2(z0, y0), Vector2(z1, y1), Vector2(z0, y1)]))


## Ring between two radii (a disc when inner = 0).
func _add_annulus_cap(outer: float, inner: float) -> void:
	for i: int in CIRCLE_SEGMENTS:
		var d0 := Vector2.from_angle(TAU * i / CIRCLE_SEGMENTS)
		var d1 := Vector2.from_angle(TAU * (i + 1) / CIRCLE_SEGMENTS)
		cap_triangles.append_array(PackedVector2Array([d0 * inner, d0 * outer, d1 * outer]))
		if inner > 0.0:
			cap_triangles.append_array(PackedVector2Array([d0 * inner, d1 * outer, d1 * inner]))


## Outer rectangle (counterclockwise, normals out) and inner one (clockwise, normals into the hole).
func _add_box_section(s: BoxSection) -> void:
	var hb: float = s.b / 2.0
	var hh: float = s.h / 2.0
	var ib: float = hb - s.t
	var ih: float = hh - s.t
	_add_polygon(_box(-hb, -hh, hb, hh))
	_add_polygon(PackedVector2Array([Vector2(-ib, -ih), Vector2(-ib, ih), Vector2(ib, ih), Vector2(ib, -ih)]))
	_add_box_cap(-hb, ih, hb, hh)
	_add_box_cap(-hb, -hh, hb, -ih)
	_add_box_cap(-hb, -ih, -ib, ih)
	_add_box_cap(ib, -ih, hb, ih)


func _add_i_beam(s: ISection) -> void:
	var hd: float = s.d / 2.0
	var hb: float = s.b_f / 2.0
	var hw: float = s.t_w / 2.0
	var yw: float = hd - s.t_f
	_add_polygon(PackedVector2Array([
		Vector2(-hb, -hd), Vector2(hb, -hd), Vector2(hb, -yw), Vector2(hw, -yw),
		Vector2(hw, yw), Vector2(hb, yw), Vector2(hb, hd), Vector2(-hb, hd),
		Vector2(-hb, yw), Vector2(-hw, yw), Vector2(-hw, -yw), Vector2(-hb, -yw)]))
	_add_box_cap(-hb, -hd, hb, -yw)
	_add_box_cap(-hw, -yw, hw, yw)
	_add_box_cap(-hb, yw, hb, hd)
