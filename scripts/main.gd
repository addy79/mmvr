extends Node3D
## Builds the lab in code and wires the signal flow:
##   control panel / load handle  ->  BeamController  --beam_changed-->  views and panels.
## Starts in VR when an OpenXR runtime is running, otherwise in desktop mode.

const BEAM_ORIGIN := Vector3(-2.0, 0.95, 0.0)  ## bottom fiber at support A [m]
## Largest drawn deflection [m]; a bigger exaggeration is reduced so the beam stays on screen.
const MAX_DRAWN_DEFLECTION: float = 0.6
const XR_PLAYER_START := Vector3(0.0, 0.0, 1.6)
const CONTROL_PANEL: PackedScene = preload("res://scenes/control_panel.tscn")
## Loaded only in VR: preloading it in desktop mode logs a "Viewport Texture must be set" error.
const SCREEN_3D_PATH: String = "res://addons/godot-xr-tools/objects/viewport_2d_in_3d.tscn"

var controller: BeamController = BeamController.new()
var data: BeamDataTexture = BeamDataTexture.new()
var beam_view: BeamView = BeamView.new(data)
var load_handle: LoadHandle = LoadHandle.new(BeamController.LENGTH)
var shear_diagram: DiagramView = DiagramView.new(DiagramView.Kind.SHEAR, BeamController.LENGTH, data)
var moment_diagram: DiagramView = DiagramView.new(DiagramView.Kind.MOMENT, BeamController.LENGTH, data)
var formula_panel: FormulaPanel = FormulaPanel.new()
var panel: ControlPanel
var xr_active: bool = false

var _overlay: CanvasLayer
var _relative_to_yield: bool = false
var _requested_exaggeration: float = ControlPanel.DEFAULT_EXAGGERATION


func _ready() -> void:
	InputSetup.register()
	add_child(controller)
	_build_environment()
	_build_lab()
	xr_active = _start_xr()
	if xr_active:
		_build_xr_player()
	else:
		_build_desktop()

	var names := PackedStringArray()
	for s: CrossSection in controller.sections:
		names.append(s.display_name)
	var material_names := PackedStringArray()
	for m: BeamMaterial in controller.materials:
		material_names.append(m.display_name.get_slice(" ", 0))
	panel.setup(names, material_names, BeamController.LENGTH,
			BeamController.MIN_LOAD, BeamController.MAX_LOAD, not xr_active)

	panel.section_selected.connect(controller.set_section_index)
	panel.material_selected.connect(controller.set_material_index)
	panel.load_changed.connect(controller.set_load)
	panel.load_position_changed.connect(controller.set_load_position)
	panel.exaggeration_changed.connect(_set_exaggeration)
	panel.color_scale_changed.connect(_set_color_scale)
	load_handle.slider_moved.connect(controller.set_load_position)
	controller.beam_changed.connect(_on_beam_changed)

	_on_beam_changed(controller.beam)

	if OS.get_cmdline_user_args().has("--selftest"):
		add_child(load("res://tests/scene_selftest.gd").new(self))


func _on_beam_changed(beam: SimplySupportedBeam) -> void:
	data.write(beam)
	beam_view.show_beam(beam)
	load_handle.show_beam(beam)
	shear_diagram.show_beam(beam)
	moment_diagram.show_beam(beam)
	formula_panel.show_beam(beam)
	panel.show_beam(beam, controller.sections.find(beam.section), controller.materials.find(beam.material))
	_update_stress_ratio()
	_apply_exaggeration()


func _set_exaggeration(factor: float) -> void:
	_requested_exaggeration = factor
	_apply_exaggeration()


func _apply_exaggeration() -> void:
	var shown: float = _requested_exaggeration
	var v_max: float = controller.beam.max_deflection()
	if v_max * shown > MAX_DRAWN_DEFLECTION:
		shown = MAX_DRAWN_DEFLECTION / v_max
	beam_view.set_exaggeration(shown)
	load_handle.set_exaggeration(shown)
	panel.show_exaggeration(_requested_exaggeration, shown)


func _set_color_scale(relative_to_yield: bool) -> void:
	_relative_to_yield = relative_to_yield
	formula_panel.set_color_scale(relative_to_yield)
	_update_stress_ratio()


## Full color at sigma_max (auto) or at sigma_Y, where sigma_max/sigma_Y = 1/FS.
func _update_stress_ratio() -> void:
	beam_view.set_stress_ratio(1.0 / controller.beam.factor_of_safety() if _relative_to_yield else 1.0)


func _build_lab() -> void:
	var beam_root := Node3D.new()
	beam_root.name = "Beam"
	beam_root.position = BEAM_ORIGIN
	add_child(beam_root)
	beam_root.add_child(SupportsView.new(BeamController.LENGTH, BEAM_ORIGIN.y))
	beam_root.add_child(beam_view)
	beam_root.add_child(load_handle)
	shear_diagram.position = Vector3(0.0, 0.8, -0.6)
	moment_diagram.position = Vector3(0.0, 1.4, -0.6)
	beam_root.add_child(shear_diagram)
	beam_root.add_child(moment_diagram)
	formula_panel.position = Vector3(3.2, 1.45, 0.55)
	formula_panel.rotation.y = deg_to_rad(-38.0)
	add_child(formula_panel)


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
	var rig := XRRig.new()
	rig.position = XR_PLAYER_START
	add_child(rig)
	var screen := (load(SCREEN_3D_PATH) as PackedScene).instantiate() as XRToolsViewport2DIn3D
	screen.screen_size = Vector2(0.6, 0.8)
	screen.viewport_size = Vector2(600.0, 800.0)
	screen.update_mode = XRToolsViewport2DIn3D.UpdateMode.UPDATE_THROTTLED
	screen.position = Vector3(-2.9, 1.35, 0.9)
	screen.rotation.y = deg_to_rad(40.0)
	add_child(screen)
	screen.scene = CONTROL_PANEL
	panel = screen.get_scene_instance() as ControlPanel


func _build_desktop() -> void:
	var camera := DesktopCamera.new()
	camera.fov = 65.0
	add_child(camera)
	camera.current = true
	add_child(DesktopLoadDrag.new(camera, load_handle))
	_overlay = CanvasLayer.new()
	add_child(_overlay)
	panel = CONTROL_PANEL.instantiate() as ControlPanel
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 10)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_overlay.add_child(panel)
	panel.resized.connect(_frame_desktop_view.bind(camera))
	get_viewport().size_changed.connect(_frame_desktop_view.bind(camera))


## Fits the lab into the part of the window above the control strip.
func _frame_desktop_view(camera: DesktopCamera) -> void:
	var window: Vector2 = get_viewport().get_visible_rect().size
	if window.y <= 0.0:
		return
	var points := PackedVector3Array([
		BEAM_ORIGIN + Vector3(-0.2, -0.2, 0.2), BEAM_ORIGIN + Vector3(BeamController.LENGTH + 0.2, -0.2, 0.2),
		BEAM_ORIGIN + Vector3(-0.7, 1.9, -0.6), BEAM_ORIGIN + Vector3(BeamController.LENGTH, 1.9, -0.6)])
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		points.append(formula_panel.to_global(Vector3(corner.x, corner.y, 0.0) * 0.5
				* Vector3(FormulaPanel.SIZE.x, FormulaPanel.SIZE.y, 0.0)))
	var free: float = 1.0 - (panel.size.y + 20.0) / window.y if _overlay.visible else 1.0
	camera.fit_view(points, free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("toggle_panel") and _overlay:
		_overlay.visible = not _overlay.visible
	elif event.is_action_pressed("screenshot"):
		print("Screenshot saved: ", await take_screenshot())


## Saves the current frame under res://screenshots and returns the absolute path.
func take_screenshot(file_name: String = "") -> String:
	await RenderingServer.frame_post_draw
	var dir: String = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	if file_name.is_empty():
		file_name = "mmlabvr_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	return path
