extends Node
## Windowed end-to-end check of the running lab: drives it through the same signals the
## student's controls use, checks what the views show, and saves screenshots.
## Run:  godot --path . -- --selftest      (exit code = number of failed checks)

var _main: Node3D
var _failures: int = 0


func _init(main: Node3D) -> void:
	_main = main


func _ready() -> void:
	_run()


func _run() -> void:
	var controller: BeamController = _main.get("controller")
	var load_handle: LoadHandle = _main.get("load_handle")
	var panel: ControlPanel = _main.get("panel")
	var board: FormulaPanel = _main.get("formula_panel")
	var data: BeamDataTexture = _main.get("data")
	await _frames(15)
	_check(board.summary().contains("R_A = P·b/L = 5.00 kN"), "default: midspan load splits 5/5 kN")
	_check(board.summary().contains("v_max = 1.00 mm"), "default: v_max = PL³/48EI = 1.00 mm")
	_check(board.summary().contains("load at midspan"), "default: midspan check shown")
	await _shot("01_default.png")

	load_handle.move_slider(1.0)  # same path as a VR grab or desktop drag
	await _frames(3)
	_check(is_equal_approx(controller.beam.load_position, 1.0), "grab moves the load to a = 1 m")
	_check(board.summary().contains("R_A = P·b/L = 7.50 kN"), "a = 1 m: R_A = 7.50 kN")
	_check(board.summary().contains("M_max = P·a·b/L = 7.50 kN·m"), "a = 1 m: M_max = 7.50 kN·m")
	_check(is_equal_approx(data.sample(0, 1).r, 1.0), "shear texture: V(0)/|V|max = 1")
	_check(absf(data.sample(BeamDataTexture.SAMPLES - 1, 1).r + 1.0 / 3.0) < 0.002, "shear texture: V(L) = −R_B = −|V|max/3")
	await _shot("02_load_at_1m.png")

	var camera := get_viewport().get_camera_3d()
	if camera is DesktopCamera:
		# Real mouse events: press on the knob, drag to above x = 3 m, release.
		var beam_frame := load_handle.get_parent() as Node3D
		_mouse_button(camera.unproject_position(load_handle.handle.global_position), true)
		await _frames(2)
		var motion := InputEventMouseMotion.new()
		motion.position = camera.unproject_position(beam_frame.to_global(Vector3(3.0, 0.5, 0.0)))
		Input.parse_input_event(motion)
		await _frames(2)
		_mouse_button(motion.position, false)
		await _frames(2)
		_check(absf(controller.beam.load_position - 3.0) < 0.02, "mouse drag moves the load to a ≈ 3 m (a = %.3f)" % controller.beam.load_position)
		_check(board.summary().contains("R_B = P·a/L = 7.50 kN"), "after drag: R_B = 7.50 kN")
		load_handle.move_slider(1.0)
		await _frames(2)

	for i: int in controller.sections.size():
		panel.section_selected.emit(i)
		await _frames(3)
		_check(controller.beam.section == controller.sections[i], "section button %d" % i)
		await _shot("03_section_%d.png" % i)

	panel.section_selected.emit(0)
	panel.material_selected.emit(2)
	panel.color_scale_changed.emit(true)
	await _frames(3)
	_check(board.summary().contains("Douglas fir"), "material switch to wood")
	_check(board.summary().contains("full color at ±40.00 MPa"), "yield color scale")
	await _shot("04_wood_yield_scale.png")

	panel.load_changed.emit(BeamController.MAX_LOAD)
	panel.load_position_changed.emit(2.0)
	await _frames(3)
	# sigma_max = (50000*4/4)*0.1/6.6667e-5 = 75 MPa > 40 MPa  ->  FS = 0.53
	_check(board.summary().contains("FS = σ_Y/σ_max = 0.53") and board.summary().contains("YIELDS!"),
			"overload: FS = 0.53 flagged")
	_check(absf(beam_drawn_deflection(_main) - 0.6) < 1e-6, "huge deflection drawn capped at 0.6 m")
	await _shot("05_overload.png")

	if camera is DesktopCamera:
		# Camera: physical W key (Z on AZERTY), left-drag on empty sky, scroll.
		var start: Transform3D = camera.global_transform
		var key := InputEventKey.new()
		key.physical_keycode = KEY_W
		key.pressed = true
		Input.parse_input_event(key)
		await _frames(20)
		key = key.duplicate() as InputEventKey
		key.pressed = false
		Input.parse_input_event(key)
		await _frames(2)
		_check(camera.global_position.distance_to(start.origin) > 0.1, "forward key moves the camera")
		var yaw_before: float = camera.rotation.y
		_mouse_button(Vector2(40, 40), true)
		var drag := InputEventMouseMotion.new()
		drag.position = Vector2(140, 40)
		drag.relative = Vector2(100, 0)
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(drag)
		await _frames(2)
		_mouse_button(Vector2(140, 40), false)
		await _frames(2)
		_check(absf(camera.rotation.y - yaw_before + 0.4) < 0.01, "left-drag on the background turns the view")
		var before_scroll: Vector3 = camera.global_position
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.factor = 1.0
		wheel.position = Vector2(40, 40)
		Input.parse_input_event(wheel)
		await _frames(2)
		_check(camera.global_position.distance_to(before_scroll) > 0.3, "scroll moves the camera forward")
		(camera as DesktopCamera).reset_view(board.to_global(Vector3(0.0, 0.0, 1.3)), board.global_position)
		await _frames(3)
		await _shot("06_formula_board.png")

	if camera is XRCamera3D:
		# --xr-preview: turn the head toward each panel.
		for screen: Node in _main.find_children("*", "XRToolsViewport2DIn3D", true, false):
			camera.look_at((screen as Node3D).global_position)
			await _frames(5)
			await _shot("07_xr_control_panel.png")
		camera.look_at(board.global_position)
		await _frames(3)
		await _shot("08_xr_formula_board.png")

	print("SELFTEST %s: %d failure(s)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(_failures)


static func beam_drawn_deflection(main: Node3D) -> float:
	var view: BeamView = main.get("beam_view")
	return (view.material_override as ShaderMaterial).get_shader_parameter("deflection_scale")


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	Input.parse_input_event(event)


func _check(ok: bool, label: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _shot(file_name: String) -> void:
	var path: String = await _main.call("take_screenshot", file_name)
	print("  screenshot: ", path)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
