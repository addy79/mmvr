extends Node
## Windowed end-to-end check of the running lab: visits every station and lesson step,
## drives inputs through the same paths as the student's controls, checks the lesson
## text, and saves screenshots.
## Run:  godot --path . -- --selftest      (exit code = number of failed checks)

var _main: Node3D
var _failures: int = 0


func _init(main: Node3D) -> void:
	_main = main


func _ready() -> void:
	_run()


func _run() -> void:
	await _frames(10)
	var panel: LessonPanel = _main.get("lesson_panel")
	for index: int in 10:
		if not ResourceLoader.exists(_main.STATIONS[index]):
			continue
		_main.call("load_station", index)
		await _frames(4)
		var station: Station = _main.get("station")
		for s: int in station.step_titles().size():
			station.set_step(s)
			await _frames(2)
			var text: String = station.lesson_text()
			_check(text.length() > 200, "ch%d step %d has lesson text" % [station.chapter, s + 1])
			await _shot("ch%02d_step%d.png" % [station.chapter, s + 1])
			if OS.get_cmdline_user_args().has("--3d-shots"):
				_main.get("_overlay").visible = false
				await _frames(2)
				await _shot("ch%02d_step%d_3d.png" % [station.chapter, s + 1])
				_main.get("_overlay").visible = true
		_main.get("_overlay").visible = false
		station.set_step(0)
		await _frames(3)
		await _shot("ch%02d_3d.png" % station.chapter)
		_main.get("_overlay").visible = true
		await _station_checks(station)
	print("SELFTEST %s: %d failure(s)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(_failures)


## Station-specific checks of numbers shown to the student.
func _station_checks(station: Station) -> void:
	match station.chapter:
		5:
			station.set_step(0)
			station.set_control(&"a", 1.0)
			station.set_control(&"w", 0.0)
			await _frames(2)
			_check(station.lesson_text().contains("7.50 kN"), "ch5: a = 1 m gives R_A = 7.50 kN")


func _check(ok: bool, label: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _shot(file_name: String) -> void:
	await _main.call("take_screenshot", file_name)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
