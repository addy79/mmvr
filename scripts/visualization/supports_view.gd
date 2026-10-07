class_name SupportsView
extends Node3D
## Beam supports drawn under the bottom fiber (the node origin is the bottom fiber at x = 0):
## a pin at A and a roller at B on pedestals, or a wall for a cantilever's fixed end.

const SIZE: float = 0.16
const BASE_THICKNESS: float = 0.04

var _material: StandardMaterial3D = StandardMaterial3D.new()
var _height: float


func _init(height_above_floor: float) -> void:
	_height = height_above_floor
	_material.albedo_color = Color(0.35, 0.37, 0.4)


func show_simple(length: float) -> void:
	_clear()
	var prism := PrismMesh.new()
	prism.size = Vector3(SIZE, SIZE, 0.3)
	_add(prism, Vector3(0.0, -SIZE / 2.0, 0.0))
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = SIZE / 2.0
	cylinder.bottom_radius = SIZE / 2.0
	cylinder.height = 0.3
	_add(cylinder, Vector3(length, -SIZE / 2.0, 0.0)).rotation.x = PI / 2.0
	var top: float = -SIZE - BASE_THICKNESS
	var pedestal_height: float = _height + top
	for x: float in [0.0, length]:
		var base := BoxMesh.new()
		base.size = Vector3(0.3, BASE_THICKNESS, 0.4)
		_add(base, Vector3(x, -SIZE - BASE_THICKNESS / 2.0, 0.0))
		var pedestal := BoxMesh.new()
		pedestal.size = Vector3(0.22, pedestal_height, 0.3)
		_add(pedestal, Vector3(x, top - pedestal_height / 2.0, 0.0))


## Wall at x = 0 reaching the floor, for a cantilever of depth `depth`.
func show_fixed(depth: float) -> void:
	_clear()
	var wall := BoxMesh.new()
	wall.size = Vector3(0.3, _height + depth + 0.6, 0.8)
	_add(wall, Vector3(-0.15, (depth + 0.6 - _height) / 2.0, 0.0))


func _clear() -> void:
	for child: Node in get_children():
		child.queue_free()


func _add(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _material
	add_child(instance)
	return instance
