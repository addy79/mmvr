class_name Arrow3D
extends Node3D
## Straight arrow for forces and stresses. place(tail, vector) draws it from tail along
## vector (its length in meters); place_onto(tip, vector) ends it at tip instead.

const HEAD_LENGTH: float = 0.09

var label: Label3D = Text3D.make(32)
var _shaft: MeshInstance3D = MeshInstance3D.new()
var _head: MeshInstance3D = MeshInstance3D.new()
var _pivot: Node3D = Node3D.new()


func _init(color: Color, radius: float = 0.014) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.35
	var shaft := CylinderMesh.new()
	shaft.top_radius = radius
	shaft.bottom_radius = radius
	shaft.height = 1.0
	shaft.radial_segments = 10
	shaft.rings = 1
	_shaft.mesh = shaft
	_shaft.material_override = material
	_shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = radius * 3.2
	head.height = HEAD_LENGTH
	head.radial_segments = 12
	head.rings = 1
	_head.mesh = head
	_head.material_override = material
	_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pivot)
	_pivot.add_child(_shaft)
	_pivot.add_child(_head)
	add_child(label)


func place(tail: Vector3, vector: Vector3) -> void:
	var length: float = vector.length()
	visible = length > 1e-4
	if not visible:
		return
	var dir: Vector3 = vector / length
	_pivot.position = tail
	_pivot.basis = _basis_along(dir)
	var head: float = minf(HEAD_LENGTH, length * 0.5)
	_head.scale = Vector3.ONE * (head / HEAD_LENGTH)
	_head.position.y = length - head / 2.0
	_shaft.scale.y = length - head
	_shaft.position.y = (length - head) / 2.0
	label.position = tail + vector + dir * 0.08


func place_onto(tip: Vector3, vector: Vector3) -> void:
	place(tip - vector, vector)
	label.position = tip - vector - vector.normalized() * 0.08


static func _basis_along(dir: Vector3) -> Basis:
	if dir.dot(Vector3.UP) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, dir))
