class_name SupportsView
extends Node3D
## Pin support at A (x = 0) and roller at B (x = L) on two pedestals. The node origin is
## the support contact point at A, i.e. the beam's bottom fiber.

const SIZE: float = 0.16
const BASE_THICKNESS: float = 0.04


func _init(length: float, height_above_floor: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.37, 0.4)
	var prism := PrismMesh.new()
	prism.size = Vector3(SIZE, SIZE, 0.3)
	_add_mesh(prism, Vector3(0.0, -SIZE / 2.0, 0.0), material)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = SIZE / 2.0
	cylinder.bottom_radius = SIZE / 2.0
	cylinder.height = 0.3
	_add_mesh(cylinder, Vector3(length, -SIZE / 2.0, 0.0), material).rotation.x = PI / 2.0
	var pedestal_top: float = -SIZE - BASE_THICKNESS
	var pedestal_height: float = height_above_floor + pedestal_top
	for x: float in [0.0, length]:
		var base := BoxMesh.new()
		base.size = Vector3(0.3, BASE_THICKNESS, 0.4)
		_add_mesh(base, Vector3(x, -SIZE - BASE_THICKNESS / 2.0, 0.0), material)
		var pedestal := BoxMesh.new()
		pedestal.size = Vector3(0.22, pedestal_height, 0.3)
		_add_mesh(pedestal, Vector3(x, pedestal_top - pedestal_height / 2.0, 0.0), material)


func _add_mesh(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	add_child(instance)
	return instance
