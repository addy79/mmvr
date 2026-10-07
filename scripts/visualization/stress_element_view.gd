class_name StressElementView
extends Node3D
## A small square stress element in its local XY plane, rotated by theta about Z, with
## normal-stress arrows (outward = tension) and shear arrows on all four faces.
## A faint outline shows the unrotated x-y element.

const SIZE: float = 0.4
const NORMAL_COLOR := Color(0.95, 0.35, 0.3)
const SHEAR_COLOR := Color(0.35, 0.8, 0.95)

## Arrow length [m] for a stress of `reference` (display scale), capped at MAX_ARROW.
var reference: float = 100.0e6
const MAX_ARROW: float = 0.35

var _plate: Node3D = Node3D.new()
var _normals: Array[Arrow3D] = []
var _shears: Array[Arrow3D] = []
var _caption_x: Label3D = Text3D.make(30)
var _caption_y: Label3D = Text3D.make(30)
var _caption_t: Label3D = Text3D.make(30)


func _init() -> void:
	var ghost := MeshInstance3D.new()
	var ghost_mesh := BoxMesh.new()
	ghost_mesh.size = Vector3(SIZE, SIZE, 0.004)
	ghost.mesh = ghost_mesh
	var ghost_material := StandardMaterial3D.new()
	ghost_material.albedo_color = Color(1, 1, 1, 0.12)
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.material_override = ghost_material
	add_child(ghost)
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SIZE, SIZE, 0.03)
	plate.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.85, 0.8)
	plate.material_override = material
	_plate.add_child(plate)
	add_child(_plate)
	for i: int in 4:
		var n := Arrow3D.new(NORMAL_COLOR, 0.012)
		n.label.visible = false
		_normals.append(n)
		_plate.add_child(n)
		var s := Arrow3D.new(SHEAR_COLOR, 0.010)
		s.label.visible = false
		_shears.append(s)
		_plate.add_child(s)
	for c: Label3D in [_caption_x, _caption_y, _caption_t]:
		_plate.add_child(c)


## Stresses [Pa] acting on the rotated element (x' and y' faces).
func show_stresses(sigma_x: float, sigma_y: float, tau: float, theta: float) -> void:
	_plate.rotation.z = theta
	var h: float = SIZE / 2.0
	var faces: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.LEFT, Vector3.DOWN]
	var sigmas: Array[float] = [sigma_x, sigma_y, sigma_x, sigma_y]
	for i: int in 4:
		var n: Vector3 = faces[i]
		var tangent := Vector3(-n.y, n.x, 0.0)  # +y on the +x face, -x on the +y face...
		if i % 2 == 1:
			tangent = -tangent                  # ...but tau_xy acts along +x on the +y face
		var len_n: float = _length(sigmas[i])
		var face_center: Vector3 = n * h
		if sigmas[i] >= 0.0:
			_normals[i].place(face_center, n * len_n)
		else:
			_normals[i].place_onto(face_center, -n * len_n)
		var len_s: float = _length(tau) * signf(tau)
		_shears[i].place(face_center + n * 0.03 - tangent * len_s / 2.0, tangent * len_s)
	_caption_x.text = "σx' = %s" % Units.stress(sigma_x)
	_caption_x.position = Vector3(h + 0.55, 0.0, 0.0)
	_caption_y.text = "σy' = %s" % Units.stress(sigma_y)
	_caption_y.position = Vector3(0.0, h + 0.5, 0.0)
	_caption_t.text = "τx'y' = %s" % Units.stress(tau)
	_caption_t.position = Vector3(h + 0.45, h + 0.3, 0.0)


func _length(stress: float) -> float:
	return minf(absf(stress) / reference * 0.25, MAX_ARROW)
