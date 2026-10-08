extends RefCounted


class ClockCounter extends Node3D:
	var ticks:= 0
	func factory_tick(_delta: float) -> void:
		ticks += 1

var _fails:= 0


func run(probe: Node) -> bool:
	_check_presets()
	var manager:= probe.world.get_node("MachineDrawDistance") as MachineDrawDistance
	var saved: int = Cfg.gfx ["machine_distance"]
	var saved_fog: bool = Cfg.gfx ["fog"]
	Cfg.gfx ["machine_distance"] = 6
	Cfg.gfx ["fog"] = true
	probe.world._apply_render_settings()
	var environment: Environment = probe.world.env_node.environment
	var original_mode:= environment.fog_mode
	var original_density:= environment.fog_density
	var original_colour:= environment.fog_light_color
	var original_volume:= environment.volumetric_fog_enabled
	var root: Node3D = probe.world.builds.pulpers [0]
	var counter:= ClockCounter.new()
	counter.position = Vector3(200, 0, 0)
	root.add_child(counter)
	FactoryClock.join(counter)
	var near:= MeshInstance3D.new()
	near.mesh = BoxMesh.new()
	near.visibility_range_end = 20.0
	near.visibility_range_end_margin = 1.0
	counter.add_child(near)
	var far:= MeshInstance3D.new()
	far.mesh = BoxMesh.new()
	far.visibility_range_begin = 30.0
	far.visible = false
	counter.add_child(far)
	var area:= Area3D.new()
	counter.add_child(area)
	var collision:= CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	area.add_child(collision)
	var before:= counter.ticks
	Cfg.gfx ["machine_distance"] = 0
	manager._refresh()
	_ok(environment.fog_mode == Environment.FOG_MODE_DEPTH and environment.fog_density == 1.0
		and environment.fog_depth_begin == 24.0 and environment.fog_depth_end == 36.0,
		"distance fog becomes opaque before the earliest visual cutoff")
	_ok(environment.volumetric_fog_enabled == original_volume and environment.fog_height_density == 0.0,
		"the border uses depth fog without adding a fog volume or height haze")
	probe.world._apply_render_settings()
	_ok(environment.fog_density == 1.0 and environment.fog_depth_end == 36.0,
		"reapplying graphics retains the selected fog border")
	Cfg.gfx ["fog"] = false
	probe.world._apply_render_settings()
	_ok(not environment.fog_enabled, "the depth fog switch can disable the border")
	Cfg.gfx ["fog"] = true
	probe.world._apply_render_settings()
	await probe.get_tree().physics_frame
	await probe.get_tree().physics_frame
	await probe.get_tree().process_frame
	_ok(near.visibility_range_end == 20.0 and near.visibility_range_end_margin == 1.0,
		"an existing shorter LOD range and margin remain intact")
	_ok(far.visibility_range_begin == 30.0 and far.visibility_range_end > 40.0 and far.visibility_range_end < 42.0,
		"a far mesh retains its begin range and gains a bounds adjusted cutoff")
	_ok(not far.visible and root.visible, "visual state remains under machine control")
	_ok(counter.ticks > before and counter.is_physics_processing(), "a distant machine continues ticking on FactoryClock")
	_ok(not collision.disabled and area.monitoring, "collision and interaction remain enabled")
	var added:= MeshInstance3D.new()
	added.mesh = BoxMesh.new()
	counter.add_child(added)
	await probe.get_tree().process_frame
	await probe.get_tree().process_frame
	_ok(added.visibility_range_end > 40.0, "a newly created machine visual inherits the cutoff")
	added.reparent(probe.world)
	await probe.get_tree().process_frame
	await probe.get_tree().process_frame
	_ok(added.visibility_range_end == 0.0, "a visual moved out of the machine regains its original range")
	Cfg.gfx ["machine_distance"] = 6
	manager._refresh()
	_ok(environment.fog_mode == original_mode and environment.fog_density == original_density
		and environment.fog_light_color == original_colour,
		"Unlimited restores the authored atmosphere")
	_ok(near.visibility_range_end == 20.0 and near.visibility_range_end_margin == 1.0
		and far.visibility_range_end == 0.0, "Unlimited restores every original end range and margin")
	FactoryClock.leave(counter)
	counter.queue_free()
	added.queue_free()
	Cfg.gfx ["machine_distance"] = saved
	Cfg.gfx ["fog"] = saved_fog
	probe.world._apply_render_settings()
	manager._refresh()
	print("MACHINE_DISTANCE_CHECK: %s" % ("PASS" if _fails == 0 else "FAIL"))
	return _fails == 0


func _check_presets() -> void:
	var saved_quality:= Cfg.quality
	var saved_graphics:= Cfg.gfx.duplicate()
	var saved_user:= Cfg._gfx_user.duplicate()
	var saved_readonly:= Cfg.settings_readonly
	Cfg.settings_readonly = true
	Cfg._gfx_user.erase("machine_distance")
	for level in Cfg.PRESETS:
		Cfg.quality = level as Cfg.Quality
		Cfg.sync_gfx_to_preset()
		var expected:= 80.0 if level <= Cfg.Quality.MEDIUM else 120.0
		_ok(Cfg.machine_distance_metres() == expected,
			"%s defaults to %.0f metres" % [Cfg.PRESETS [level] ["name"], expected])
	Cfg.quality = Cfg.Quality.HIGH
	Cfg.sync_gfx_to_preset()
	Cfg.set_gfx("machine_distance", 3)
	Cfg.quality = Cfg.Quality.MEDIUM
	Cfg.sync_gfx_to_preset()
	_ok(Cfg.machine_distance_metres() == 120.0,
		"a deliberate preset matching distance survives a quality change")
	Cfg.set_gfx("machine_distance", 6)
	Cfg.quality = Cfg.Quality.HIGH
	Cfg.sync_gfx_to_preset()
	_ok(Cfg.machine_distance_metres() == 0.0, "an explicit Unlimited override survives a quality change")
	Cfg.reset_gfx()
	_ok(Cfg.machine_distance_metres() == 120.0, "resetting High graphics restores 120 metres")
	Cfg.quality = Cfg.Quality.MEDIUM
	Cfg.reset_gfx()
	_ok(Cfg.machine_distance_metres() == 80.0, "resetting Medium graphics restores 80 metres")
	Cfg.quality = saved_quality
	Cfg.gfx = saved_graphics
	Cfg._gfx_user = saved_user
	Cfg.settings_readonly = saved_readonly
	Cfg.gfx_changed.emit()


func _ok(condition: bool, message: String) -> void:
	print("  %s %s" % ["ok" if condition else "FAIL", message])
	if not condition:
		_fails += 1
