extends Node3D
## Builds the lab in code: environment, the player (VR rig or desktop camera), the two
## panels, and the current chapter station. Signal flow:
##   ControlPanel / station knobs -> Station.set_control -> Station.changed -> panels refresh.
## Starts in VR when an OpenXR runtime is running, otherwise in desktop mode.

const STATIONS: PackedStringArray = [
	"res://scripts/stations/stress_station.gd",
	"res://scripts/stations/axial_station.gd",
	"res://scripts/stations/torsion_station.gd",
	"res://scripts/stations/pure_bending_station.gd",
	"res://scripts/stations/beam_station.gd",
	"res://scripts/stations/shear_station.gd",
	"res://scripts/stations/transformation_station.gd",
	"res://scripts/stations/principal_station.gd",
	"res://scripts/stations/deflection_station.gd",
	"res://scripts/stations/column_station.gd",
]
const TOPIC_TITLES: PackedStringArray = ["1 · Stress", "2 · Axial loading", "3 · Torsion",
	"4 · Pure bending", "5 · Beams", "6 · Shearing stresses", "7 · Stress transformation",
	"8 · Principal stresses", "9 · Beam deflection", "10 · Columns"]
## The course's lab experiments (handouts in "labs handouts/"); "" = no handout yet.
const LAB_STATIONS: Dictionary[int, String] = {
	1: "res://scripts/labs/lab01_specimen_stress.gd",
	2: "res://scripts/labs/lab02_stress_strain.gd",
	3: "res://scripts/labs/lab03_geometry_fea.gd",
	4: "res://scripts/labs/lab04_signpost.gd",
	5: "res://scripts/labs/lab05_torsion.gd",
	6: "",
	7: "res://scripts/labs/lab07_bending.gd",
	8: "res://scripts/labs/lab08_loading_configurations.gd",
	9: "res://scripts/labs/lab09_shear_moment.gd",
	10: "res://scripts/labs/lab10_w_and_s_beams.gd",
	11: "res://scripts/labs/lab11_narrow_hollow.gd",
}
const LAB_TITLES: Dictionary[int, String] = {
	1: "Stress withstood by a specimen", 2: "Stress-strain curve, Young's modulus",
	3: "Geometry and stress (ANSYS)", 4: "Signpost analysis (ANSYS)",
	5: "Torsion: load-angle plot", 6: "No handout yet", 7: "Bending of beams and rods",
	8: "Beam loading configurations", 9: "Shear force and bending moment",
	10: "W and S beams (ANSYS)", 11: "Narrow and hollow beams",
}
const XR_PLAYER_START := Vector3(0.0, 0.0, 2.2)
const XR_SCROLL_SPEED: float = 900.0  ## lesson scroll at full stick [px/s]
const CONTROL_PANEL: PackedScene = preload("res://scenes/control_panel.tscn")
const LESSON_PANEL: PackedScene = preload("res://scenes/lesson_panel.tscn")
## Loaded only in VR: preloading it in desktop mode logs a "Viewport Texture must be set" error.
const SCREEN_3D_PATH: String = "res://addons/godot-xr-tools/objects/viewport_2d_in_3d.tscn"

var station: Station
var station_index: int = -1
var control_panel: ControlPanel
var lesson_panel: LessonPanel
var xr_active: bool = false
var camera: DesktopCamera
var rig: XRRig

var _overlay: CanvasLayer


func _ready() -> void:
	InputSetup.register()
	_build_environment()
	# --xr-preview builds the VR scene without a headset, seen from the XR camera's start pose.
	xr_active = _start_xr() or OS.get_cmdline_user_args().has("--xr-preview")
	if xr_active:
		_build_xr_player()
	else:
		_build_desktop()
	control_panel.topic_selected.connect(load_station)
	control_panel.control_changed.connect(func(id: StringName, v: float) -> void: station.set_control(id, v))
	lesson_panel.step_selected.connect(func(i: int) -> void: station.set_step(i))
	load_station(4)

	if OS.get_cmdline_user_args().has("--selftest"):
		add_child(load("res://tests/scene_selftest.gd").new(self))


func load_station(index: int) -> void:
	if index == station_index:
		return
	if station:
		remove_child(station)
		station.queue_free()
	station_index = index
	station = (load(station_path(index)) as Script).new() as Station
	add_child(station)
	if camera:
		station.add_child(DesktopKnobDrag.new(camera))
	station.refresh()
	station.changed.connect(_on_station_changed)
	control_panel.show_station(station, index)
	lesson_panel.show_station(station)
	if camera:
		camera.release_view()
		_frame_desktop_view()


## Topic index -> script: the chapters first, then the labs in order.
func station_path(index: int) -> String:
	if index < STATIONS.size():
		return STATIONS[index]
	return LAB_STATIONS[LAB_STATIONS.keys()[index - STATIONS.size()]]


func topic_count() -> int:
	return STATIONS.size() + LAB_STATIONS.size()


func lab_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: int in LAB_STATIONS:
		out.append({"number": n, "title": LAB_TITLES[n], "available": not LAB_STATIONS[n].is_empty()})
	return out


func _on_station_changed() -> void:
	control_panel.sync(station)
	lesson_panel.refresh()


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.32, 0.5)
	sky_material.sky_horizon_color = Color(0.6, 0.65, 0.72)
	sky_material.ground_horizon_color = Color(0.6, 0.65, 0.72)
	sky_material.ground_bottom_color = Color(0.15, 0.16, 0.18)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 10.0
	add_child(sun)

	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 0.2, 30.0)
	shape.shape = box
	shape.position.y = -0.1
	floor_body.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.32, 0.33, 0.35)
	floor_mesh.material_override = floor_material
	floor_body.add_child(floor_mesh)
	add_child(floor_body)


## OpenXR is initialized by the engine at startup when a runtime (Quest, SteamVR...) is present.
func _start_xr() -> bool:
	var xr: XRInterface = XRServer.find_interface("OpenXR")
	if xr == null or not xr.is_initialized():
		return false
	get_viewport().use_xr = true
	return true


func _build_xr_player() -> void:
	rig = XRRig.new()
	rig.position = XR_PLAYER_START
	add_child(rig)
	if not get_viewport().use_xr:
		get_viewport().get_camera_3d().fov = 100.0  # preview: roughly a Quest's field of view
	# Controls at arm's length on the left, the lesson on the right, clear of the bench.
	var left := _screen(Vector2(0.62, 1.05), Vector2(620, 1050), CONTROL_PANEL)
	left.position = XR_PLAYER_START + Vector3(-0.95, 1.25, -0.25)
	left.rotation = Vector3(deg_to_rad(-10.0), deg_to_rad(65.0), 0.0)
	control_panel = left.get_scene_instance() as ControlPanel
	control_panel.setup(TOPIC_TITLES, lab_entries(), 22, "", true)
	var right := _screen(Vector2(0.9, 1.15), Vector2(900, 1150), LESSON_PANEL)
	right.position = XR_PLAYER_START + Vector3(1.05, 1.35, -0.3)
	right.rotation = Vector3(deg_to_rad(-8.0), deg_to_rad(-62.0), 0.0)
	lesson_panel = right.get_scene_instance() as LessonPanel
	lesson_panel.setup(26)


func _screen(meters: Vector2, pixels: Vector2, content: PackedScene) -> XRToolsViewport2DIn3D:
	var screen := (load(SCREEN_3D_PATH) as PackedScene).instantiate() as XRToolsViewport2DIn3D
	screen.screen_size = meters
	screen.viewport_size = pixels
	screen.update_mode = XRToolsViewport2DIn3D.UpdateMode.UPDATE_THROTTLED
	add_child(screen)
	screen.scene = content
	return screen


func _build_desktop() -> void:
	camera = DesktopCamera.new()
	camera.fov = 60.0
	add_child(camera)
	camera.current = true
	_overlay = CanvasLayer.new()
	add_child(_overlay)
	control_panel = CONTROL_PANEL.instantiate() as ControlPanel
	control_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_overlay.add_child(control_panel)
	var k := InputSetup.key_label
	control_panel.setup(TOPIC_TITLES, lab_entries(), 16, ("Move %s %s %s %s · up/down %s %s · drag the background or "
			+ "use the arrow keys to look · scroll to zoom · %s resets the view · drag the colored "
			+ "knobs to interact · Tab hides the panels") % [k.call("move_forward"), k.call("move_left"),
			k.call("move_back"), k.call("move_right"), k.call("move_up"), k.call("move_down"), k.call("reset_view")])
	lesson_panel = LESSON_PANEL.instantiate() as LessonPanel
	lesson_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_overlay.add_child(lesson_panel)
	lesson_panel.setup(17)
	get_viewport().size_changed.connect(_layout_desktop)
	_layout_desktop()


## Left: controls; right: lesson; the 3D bench fills the space between.
func _layout_desktop() -> void:
	var window: Vector2 = get_viewport().get_visible_rect().size
	var left_w: float = clampf(window.x * 0.2, 270.0, 360.0)
	var right_w: float = clampf(window.x * 0.3, 360.0, 600.0)
	control_panel.position = Vector2(8, 8)
	control_panel.size = Vector2(left_w, window.y - 16)
	lesson_panel.position = Vector2(window.x - right_w - 8, 8)
	lesson_panel.size = Vector2(right_w, window.y - 16)
	if station:
		_frame_desktop_view()


func _frame_desktop_view() -> void:
	var window: Vector2 = get_viewport().get_visible_rect().size
	var free := Rect2(0, 0, 1, 1)
	if _overlay.visible:
		var x0: float = (control_panel.position.x + control_panel.size.x + 8) / window.x
		var x1: float = lesson_panel.position.x / window.x
		free = Rect2(x0, 0.0, x1 - x0, 1.0)
	camera.fit_view(station.frame_points(), free, station.view_direction())


## VR: the right stick's up/down scrolls the lesson (left/right is snap turn).
func _process(delta: float) -> void:
	if rig == null:
		return
	var stick: float = rig.right_hand.get_vector2("primary").y
	if absf(stick) > 0.3:
		lesson_panel.scroll_by(-stick * XR_SCROLL_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("toggle_panel") and _overlay:
		_overlay.visible = not _overlay.visible
		_frame_desktop_view()
	elif event.is_action_pressed("screenshot"):
		print("Screenshot saved: ", await take_screenshot())


## Saves the current frame under res://screenshots and returns the absolute path.
func take_screenshot(file_name: String = "") -> String:
	await RenderingServer.frame_post_draw
	var dir: String = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	if not FileAccess.file_exists(dir.path_join(".gdignore")):
		FileAccess.open(dir.path_join(".gdignore"), FileAccess.WRITE)  # keep the editor from importing them
	if file_name.is_empty():
		file_name = "mmlabvr_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	return path
