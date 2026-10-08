extends Node
## Windowed end-to-end check of the running lab: visits every station and lesson step,
## drives inputs through the same paths as the student's controls, checks the lesson
## text, and saves screenshots.
## Run:  godot --path . -- --selftest      (exit code = number of failed checks)
##       add --chapter N or --lab N to visit only one bench.

var _main: Node3D
var _failures: int = 0


func _init(main: Node3D) -> void:
	_main = main


func _ready() -> void:
	_run()


func _run() -> void:
	await _frames(10)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: int = int(args[args.find("--chapter") + 1]) if args.has("--chapter") else 0
	var only_lab: int = int(args[args.find("--lab") + 1]) if args.has("--lab") else 0
	for index: int in _main.call("topic_count"):
		var path: String = _main.call("station_path", index)
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var is_lab: bool = index >= _main.STATIONS.size()
		var number: int = index + 1 if not is_lab else int(path.get_file().substr(3, 2))
		if (only > 0 or only_lab > 0) and not ((not is_lab and number == only) or (is_lab and number == only_lab)):
			continue
		_main.call("load_station", index)
		await _frames(4)
		var station: Station = _main.get("station")
		var tag: String = ("lab%02d" % station.lab) if is_lab else ("ch%02d" % station.chapter)
		for s: int in station.step_titles().size():
			station.set_step(s)
			await _frames(2)
			var text: String = station.lesson_text()
			_check(text.length() > 200, "%s step %d has lesson text" % [tag, s + 1])
			await _shot("%s_step%d.png" % [tag, s + 1])
			if OS.get_cmdline_user_args().has("--3d-shots"):
				_hide_panels(true)
				await _frames(2)
				await _shot("%s_step%d_3d.png" % [tag, s + 1])
				_hide_panels(false)
		_hide_panels(true)
		station.set_step(0)
		await _frames(3)
		await _shot("%s_3d.png" % tag)
		_hide_panels(false)
		if is_lab:
			_lab_checks(station)
		else:
			await _station_checks(station)
	var head := get_viewport().get_camera_3d()
	if head is XRCamera3D:
		# --xr-preview: turn the head toward each 3D panel.
		var screens: Array[Node] = _main.find_children("*", "XRToolsViewport2DIn3D", true, false)
		for i: int in screens.size():
			head.look_at((screens[i] as Node3D).global_position)
			await _frames(8)
			await _shot("xr_panel_%d.png" % i)
	print("SELFTEST %s: %d failure(s)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(_failures)


## Station-specific checks: numbers the student sees vs. hand calculations.
func _station_checks(station: Station) -> void:
	match station.chapter:
		1:
			_expect(station, 0, {}, "63.66 MPa", "ch1: σ = P/A for 20 kN on d = 20 mm")
		2:
			_expect(station, 1, {&"eps": 0.001}, "200.00 MPa", "ch2: Hooke's law at ε = 0.1 %")
			_expect(station, 8, {}, "109.13 MPa", "ch2: indeterminate bar σ_AB")
			_expect(station, 7, {}, "545×10⁻⁶", "ch2: generalized Hooke ε_x")
		3:
			_expect(station, 1, {}, "47.16 MPa", "ch3: τ_max = Tc/J")
			_expect(station, 5, {&"a": 0.4, &"L": 1.5, &"do": 0.06, &"d2": 0.04}, "1.77 kN·m", "ch3: indeterminate T_A")
			_expect(station, 6, {&"bw": 0.1, &"bh": 0.06, &"bt": 0.005}, "38.28 MPa", "ch3: thin-walled τ")
		4:
			_expect(station, 2, {}, "15.00 MPa", "ch4: σ_m = Mc/I")
		5:
			_expect(station, 0, {&"a": 1.0, &"w": 0.0}, "7.50 kN", "ch5: a = 1 m gives R_A = 7.50 kN")
		6:
			_expect(station, 2, {}, "3.75 MPa", "ch6: τ_max = 1.5 V/A")
		7:
			_expect(station, 2, {}, "70.00 MPa", "ch7: σ_max of B&J example 7.01")
			_expect(station, 8, {}, "100.00 MPa", "ch7: hoop stress pr/t")
			_expect(station, 9, {}, "118.68 MPa", "ch7: rosette σ_x")
			_expect(station, 7, {&"sx": 80.0e6, &"sy": -200.0e6, &"txy": 0.0, &"material": 2.0}, "Mohr's criterion", "ch7: brittle criteria shown")
		8:
			_expect(station, 2, {}, "103.52 MPa", "ch8: bending stress at the top point")
			_expect(station, 5, {}, "c_min", "ch8: shaft design shown")
		9:
			_expect(station, 1, {&"support": 1.0, &"w": 0.0, &"a": 4.0}, "23.82 mm", "ch9: cantilever PL³/3EI")
			_expect(station, 5, {&"support": 2.0, &"P": 0.0, &"w": 5.0e3}, "7.50 kN", "ch9: propped R_B = 3wL/8")
		10:
			_expect(station, 1, {}, "228.46 kN", "ch10: Euler load")
			_expect(station, 6, {&"P": 50.0e3}, "119.98 kN", "ch10: AISC allowable load")
			_expect(station, 0, {&"P": 300.0e3}, "buckled", "ch10: buckles above P_cr")
			await _shot("ch10_buckled.png")


## Lab benches: the numbers on the panels vs. hand calculations (defaults unless set here).
func _lab_checks(station: Station) -> void:
	match station.lab:
		1:
			_expect(station, 1, {&"n": 1.0}, "9.86 MPa", "lab1: one step, sigma = F/A")
		2:
			_expect(station, 3, {&"readings": 0.0}, "200.0 GPa", "lab2: ideal readings give E = 200 GPa")
		3:
			_expect(station, 2, {&"shape": 0.0}, "75000 N", "lab3: cuboid hand force E*d/L*A")
			_expect(station, 6, {&"shape": 2.0}, "singularity", "lab3: mesh convergence shown")
		4:
			_expect(station, 3, {}, "8.63 MPa", "lab4: base von Mises")
		5:
			_expect(station, 1, {}, "5.13°", "lab5: aluminum twist at 15 N")
		7:
			_expect(station, 1, {}, "3.070 mm", "lab7: Fl^3/48EI for bar 1 at 20 N")
		8:
			_expect(station, 2, {}, "9.155 mm", "lab8: cantilever tip, 15 N at 250 mm")
		9:
			_expect(station, 2, {}, "0.446 N", "lab9: shear at the cut, 200 g at X2")
		10:
			_expect(station, 3, {}, "49.49 MPa", "lab10: W200x52 flange stress")
		11:
			_expect(station, 2, {}, "]55.6[", "lab11: usual bending stress 55.6 MPa")


func _expect(station: Station, step: int, inputs: Dictionary, text: String, label: String) -> void:
	for id: StringName in inputs:
		station.set_control(id, inputs[id])
	station.set_step(step)
	_check(station.lesson_text().contains(text), label)


## Hides (or shows) the desktop panels and re-frames the camera like pressing Tab.
func _hide_panels(hide: bool) -> void:
	var overlay: CanvasLayer = _main.get("_overlay")
	if overlay == null:
		return
	overlay.visible = not hide
	(_main.get("camera") as DesktopCamera).release_view()
	_main.call("_frame_desktop_view")


func _check(ok: bool, label: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _shot(file_name: String) -> void:
	await _main.call("take_screenshot", file_name)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
