class_name DevFarBlobProbe
extends Node


const STAGE_FRAMES:= 3000


const CAM_ORIGIN:= Vector3(-14.2, 34.1, -4.6)
const YAW_MID:= 1.59
const YAW_SWING:= 0.35
const PITCH_MID:= -0.09
const PITCH_SWING:= 0.07

var world: Node3D
var player: Player

var _cam: Camera3D
var _frame:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	Cfg.apply_quality(Cfg.Quality.ULTRA)
	world._apply_render_settings()
	_cam = Camera3D.new()
	_cam.fov = player.camera.fov
	_cam.near = player.camera.near
	_cam.far = player.camera.far
	_cam.attributes = player.camera.attributes
	world.add_child(_cam)
	_cam.current = true
	player.global_position = CAM_ORIGIN + Vector3(0.0, -1.66, 0.0)
	player.set_physics_process(false)
	if world.hud != null:
		world.hud.visible = false
	world.field.update_lod(CAM_ORIGIN)
	for k in 120:
		await _step()


	var e:= _env()
	var attrs:= world._cam_attrs as CameraAttributesPractical
	var sky_mode:= e.background_mode


	var dof_off:= func() -> void: attrs.dof_blur_near_enabled = false
	var dof_on:= func() -> void: attrs.dof_blur_near_enabled = true
	var stages:= [
		["no_dof_a", dof_off, dof_on],
		["no_dof_b", dof_off, dof_on],
		["no_dof_c", dof_off, dof_on],
	] if "--farblob-dof" in OS.get_cmdline_user_args() else [
		["ultra", func() -> void: pass, func() -> void: pass],
		["no_vfog", func() -> void: e.volumetric_fog_enabled = false,
			func() -> void: e.volumetric_fog_enabled = true],
		["no_fog", func() -> void: e.fog_enabled = false,
			func() -> void: e.fog_enabled = true],
		["no_terrain", func() -> void: world.terrain.visible = false,
			func() -> void: world.terrain.visible = true],
		["no_sky", func() -> void: e.background_mode = Environment.BG_COLOR,
			func() -> void: e.background_mode = sky_mode],
		["no_ssao", func() -> void: e.ssao_enabled = false,
			func() -> void: e.ssao_enabled = true],
		["no_autoexp", func() -> void: attrs.auto_exposure_enabled = false,
			func() -> void: attrs.auto_exposure_enabled = true],
		["no_dof", func() -> void: attrs.dof_blur_near_enabled = false,
			func() -> void: attrs.dof_blur_near_enabled = true],
		["no_pile", func() -> void: world.field.visible = false,
			func() -> void: world.field.visible = true],
	]
	for s: Array in stages:
		(s [1] as Callable).call()

		for k in 30:
			await _step()
		print("FARBLOB stage %s starts at frame %d" % [s [0], _frame])
		for k in STAGE_FRAMES:
			await _step()
		(s [2] as Callable).call()
	print("FARBLOB done at frame %d" % _frame)
	get_tree().quit()


func _step() -> void:
	var t:= float(_frame) / 60.0
	var yaw:= YAW_MID + YAW_SWING * sin(t * 0.7)
	var pitch:= PITCH_MID + PITCH_SWING * sin(t * 1.3 + 0.4)
	_cam.global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), CAM_ORIGIN)
	_frame += 1
	await get_tree().process_frame


func _env() -> Environment:
	return (world.get_node("Environment") as WorldEnvironment).environment
