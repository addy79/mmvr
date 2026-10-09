class_name MttuView
extends Node3D
## The Mechanical Tensile Testing Unit (as in the handout photo, stood upright), drawn 5x real
## size: three springs on the base pull the lower anchor down, the flat dog-bone specimen
## joins it to the upper anchor, and the wheel's lead screw raises the upper anchor along a
## graduated scale. A dial gauge reads the springs' extension dL. The specimen's gauge is
## colored by sigma/sigma_U and splits when broken.

const DRAW: float = 5.0
const TABLE: float = 0.75        ## top of the base [m]
const SPRING_REST: float = 0.18  ## drawn spring length with no load [m]
const GRIP: float = 0.015        ## real grip length of the dog-bone at each end [m]

var _specimen: Array[MeshInstance3D] = [MeshInstance3D.new(), MeshInstance3D.new()]  ## gauge (two halves once broken)
var _grips: Array[MeshInstance3D] = [MeshInstance3D.new(), MeshInstance3D.new()]
var _specimen_material: StandardMaterial3D = StandardMaterial3D.new()
var _lower: MeshInstance3D = MeshInstance3D.new()
var _upper: MeshInstance3D = MeshInstance3D.new()
var _springs: Array[MeshInstance3D] = [MeshInstance3D.new(), MeshInstance3D.new(), MeshInstance3D.new()]
var _wheel: MeshInstance3D = MeshInstance3D.new()
var _needle: Node3D = Node3D.new()
var _screw: MeshInstance3D = MeshInstance3D.new()
var _label: Label3D = Text3D.make(30)
var _dial_label: Label3D = Text3D.make(26)


func _init() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.3, 0.33, 0.38)
	var base := _box(Vector3(0.7, TABLE, 0.4), steel)
	base.position = Vector3(0.0, TABLE / 2.0, 0.0)
	for x: float in [-0.3, 0.3]:
		var column := _box(Vector3(0.05, 1.3, 0.05), steel)
		column.position = Vector3(x, TABLE + 0.65, -0.12)
	var top := _box(Vector3(0.7, 0.08, 0.3), steel)
	top.position = Vector3(0.0, TABLE + 1.3, -0.12)
	var anchor_material := StandardMaterial3D.new()
	anchor_material.albedo_color = Color(0.55, 0.57, 0.6)
	for a: MeshInstance3D in [_lower, _upper]:
		var m := BoxMesh.new()
		m.size = Vector3(0.22, 0.06, 0.12)
		a.mesh = m
		a.material_override = anchor_material
		add_child(a)
	var spring_material := StandardMaterial3D.new()
	spring_material.albedo_color = Color(0.75, 0.6, 0.25)
	for i: int in 3:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.022
		cyl.bottom_radius = 0.022
		cyl.height = 1.0
		_springs[i].mesh = cyl
		_springs[i].material_override = spring_material
		add_child(_springs[i])
	for s: MeshInstance3D in _specimen:
		s.mesh = BoxMesh.new()
		s.material_override = _specimen_material
		add_child(s)
	var grip_material := StandardMaterial3D.new()
	grip_material.albedo_color = Color(0.8, 0.8, 0.78)
	for g: MeshInstance3D in _grips:
		g.mesh = BoxMesh.new()
		g.material_override = grip_material
		add_child(g)
	# Graduated scale beside the upper anchor's path, a tick every 10 mm (real).
	var scale_white := StandardMaterial3D.new()
	scale_white.albedo_color = Color(0.93, 0.93, 0.9)
	var board := _box(Vector3(0.06, 0.6, 0.01), scale_white)
	board.position = Vector3(0.2, TABLE + 0.75, 0.05)
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.1, 0.1, 0.1)
	for i: int in 13:
		var tick := _box(Vector3(0.03 if i % 5 == 0 else 0.015, 0.003, 0.012), ink)
		tick.position = Vector3(0.185, TABLE + 0.45 + i * 0.05, 0.05)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.16
	wheel.bottom_radius = 0.16
	wheel.height = 0.03
	_wheel.mesh = wheel
	_wheel.material_override = steel
	_wheel.position = Vector3(0.0, TABLE + 1.42, 0.0)
	# Lead screw from the wheel down to the upper anchor.
	var screw := CylinderMesh.new()
	screw.top_radius = 0.012
	screw.bottom_radius = 0.012
	screw.height = 1.0
	_screw.mesh = screw
	_screw.material_override = steel
	add_child(_screw)
	add_child(_wheel)
	var spoke := _box(Vector3(0.3, 0.035, 0.035), anchor_material)
	remove_child(spoke)
	_wheel.add_child(spoke)
	# Dial gauge on the front of the base: 1 needle turn = 1 mm.
	var face := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.09
	disc.bottom_radius = 0.09
	disc.height = 0.02
	face.mesh = disc
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.92, 0.9)
	face.material_override = white
	face.rotation.x = PI / 2.0
	face.position = Vector3(0.0, TABLE - 0.2, 0.21)
	add_child(face)
	_needle.position = face.position + Vector3(0.0, 0.0, 0.015)
	add_child(_needle)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.1, 0.1)
	var needle := _box(Vector3(0.008, 0.08, 0.005), red)
	remove_child(needle)
	needle.position.y = 0.04
	_needle.add_child(needle)
	_dial_label.position = face.position + Vector3(0.0, -0.14, 0.02)
	add_child(_dial_label)
	_label.position = Vector3(0.45, TABLE + 0.6, 0.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_label)


func show_state(rig: TensileRig, state: Dictionary) -> void:
	var lower_y: float = TABLE + SPRING_REST + state.spring * DRAW
	for i: int in 3:
		_springs[i].scale.y = lower_y - TABLE
		_springs[i].position = Vector3(-0.07 + 0.07 * i, (TABLE + lower_y) / 2.0, 0.0)
	_lower.position = Vector3(0.0, lower_y + 0.03, 0.0)
	var grip: float = GRIP * DRAW
	var bottom: float = lower_y + 0.06 + grip
	var length: float = (rig.gauge_length + state.elongation) * DRAW
	var size := Vector3(rig.width * DRAW, 0.0, rig.thickness * DRAW)
	var broken: bool = state.broken
	for i: int in 2:
		var piece: float = length / 2.0 if broken else length
		var box := _specimen[i].mesh as BoxMesh
		box.size = Vector3(size.x, piece - (0.01 if broken else 0.0), size.z)
		_specimen[i].position = Vector3(0.0, bottom + piece / 2.0 + (piece if i == 1 else 0.0), 0.0)
		_specimen[i].visible = broken or i == 0
		(_grips[i].mesh as BoxMesh).size = Vector3(size.x * 2.0, grip, size.z)
		_grips[i].position = Vector3(0.0, bottom - grip / 2.0 if i == 0 else bottom + length + grip / 2.0, 0.0)
	var ratio: float = state.stress / rig.material.ultimate_strength
	_specimen_material.albedo_color = Color(0.86, 0.86, 0.84).lerp(Color(0.9, 0.15, 0.1), clampf(ratio, 0.0, 1.0))
	_upper.position = Vector3(0.0, bottom + length + grip + 0.03, 0.0)
	var screw_bottom: float = _upper.position.y + 0.03
	_screw.scale.y = TABLE + 1.42 - screw_bottom
	_screw.position = Vector3(0.0, (screw_bottom + TABLE + 1.42) / 2.0, 0.0)
	_wheel.rotation.y = -state.travel / TensileRig.TRAVEL_PER_STEP * TAU / 3.0
	_needle.rotation.z = -state.spring * 1.0e3 * TAU
	_dial_label.text = "RC = " + Units.mm(state.dial)
	_label.text = "L_up = %s\nΔL = %s\nF = %s\nσ = %s%s" % [Units.mm(state.travel, 1), Units.mm(state.spring),
			Units.newtons(state.force, 0), Units.stress(state.stress), "\nbroken" if broken else ""]


func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = material
	add_child(m)
	return m
