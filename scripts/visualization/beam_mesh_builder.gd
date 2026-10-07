class_name BeamMeshBuilder
extends RefCounted
## Builds a straight prismatic beam mesh along +x from a section outline.
## UV.x = x/L so the shaders can look up per-position results; deflection is applied
## in the vertex shader, so this mesh is rebuilt only when the cross-section changes.

const STATIONS: int = 33  ## rings along the beam (32 segments)


static func build(profile: SectionProfile, length: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for s: int in profile.strip_points.size():
		var points: PackedVector2Array = profile.strip_points[s]
		var strip_normals: PackedVector2Array = profile.strip_normals[s]
		var base: int = verts.size()
		for i: int in STATIONS:
			var u: float = float(i) / (STATIONS - 1)
			for j: int in points.size():
				verts.append(Vector3(u * length, points[j].y, points[j].x))
				normals.append(Vector3(0.0, strip_normals[j].y, strip_normals[j].x))
				uvs.append(Vector2(u, 0.0))
		var n: int = points.size()
		for i: int in STATIONS - 1:
			for j: int in n - 1:
				var a: int = base + i * n + j
				_add_quad(indices, verts, normals, a, a + 1, a + n + 1, a + n)

	for end: int in 2:
		var x: float = length * end
		var cap_normal := Vector3(1.0 if end == 1 else -1.0, 0.0, 0.0)
		for k: int in profile.cap_triangles.size():
			var p: Vector2 = profile.cap_triangles[k]
			verts.append(Vector3(x, p.y, p.x))
			normals.append(cap_normal)
			uvs.append(Vector2(float(end), 0.0))
		var first: int = verts.size() - profile.cap_triangles.size()
		for t: int in range(first, verts.size(), 3):
			_add_triangle(indices, verts, normals, t, t + 1, t + 2)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _add_quad(indices: PackedInt32Array, verts: PackedVector3Array,
		normals: PackedVector3Array, a: int, b: int, c: int, d: int) -> void:
	_add_triangle(indices, verts, normals, a, b, c)
	_add_triangle(indices, verts, normals, a, c, d)


## Appends a triangle wound so its front face matches the vertex normals
## (Godot treats clockwise-wound triangles as front-facing).
static func _add_triangle(indices: PackedInt32Array, verts: PackedVector3Array,
		normals: PackedVector3Array, a: int, b: int, c: int) -> void:
	var face: Vector3 = (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if face.dot(normals[a] + normals[b] + normals[c]) > 0.0:
		indices.append_array(PackedInt32Array([a, c, b]))
	else:
		indices.append_array(PackedInt32Array([a, b, c]))
