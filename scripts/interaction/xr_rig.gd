class_name XRRig
extends XROrigin3D
## VR player built from XR Tools: hands, grip pickup on both hands (grabs the load knob),
## trigger laser pointer on the right hand (UI panels), left-stick walk, right-stick turn.
## Nodes use XR Tools' default names: its helpers look them up by name because nodes
## built in code have no scene owner.

const LEFT_HAND: PackedScene = preload("res://addons/godot-xr-tools/hands/scenes/lowpoly/left_hand_low.tscn")
const RIGHT_HAND: PackedScene = preload("res://addons/godot-xr-tools/hands/scenes/lowpoly/right_hand_low.tscn")
const PICKUP: PackedScene = preload("res://addons/godot-xr-tools/functions/function_pickup.tscn")
const POINTER: PackedScene = preload("res://addons/godot-xr-tools/functions/function_pointer.tscn")
const MOVE_DIRECT: PackedScene = preload("res://addons/godot-xr-tools/functions/movement_direct.tscn")
const MOVE_TURN: PackedScene = preload("res://addons/godot-xr-tools/functions/movement_turn.tscn")
const PLAYER_BODY: PackedScene = preload("res://addons/godot-xr-tools/player/player_body.tscn")


func _init() -> void:
	var camera := XRCamera3D.new()
	camera.name = "Camera"
	camera.position.y = 1.6
	add_child(camera)
	var left: XRController3D = _controller(&"left_hand", "LeftHand", LEFT_HAND)
	var right: XRController3D = _controller(&"right_hand", "RightHand", RIGHT_HAND)
	var walk: Node = MOVE_DIRECT.instantiate()
	walk.set("strafe", true)
	walk.set("max_speed", 1.5)
	left.add_child(walk)
	right.add_child(MOVE_TURN.instantiate())
	right.add_child(POINTER.instantiate())
	add_child(PLAYER_BODY.instantiate())


func _controller(tracker_name: StringName, node_name: String, hand: PackedScene) -> XRController3D:
	var controller := XRController3D.new()
	controller.name = node_name
	controller.tracker = tracker_name
	controller.pose = &"aim"
	controller.add_child(hand.instantiate())
	controller.add_child(PICKUP.instantiate())
	add_child(controller)
	return controller
