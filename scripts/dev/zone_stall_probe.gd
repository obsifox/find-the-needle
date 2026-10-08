class_name DevZoneStallProbe
extends Node


var world: Node3D
var player: Player


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	world.block_save = true
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--zonestall")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		print("ZONESTALL: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		print("ZONESTALL: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	print("ZONESTALL: %s, %d buildings, block_save=%s"
		% [path.get_file(), (d.get("buildings", []) as Array).size(), world.block_save])
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)
	var field: HayField = world.field
	var builds: BuildManager = world.builds
	var heights: PackedFloat32Array = d.get("heights", PackedFloat32Array())
	if heights.size() > 0:
		field.generate(int(GameState.run_seed), heights)
		GameState.from_dict(d.get("state", { }))
	builds.from_array(d.get("buildings", []))
	for k in 30:
		await get_tree().process_frame

	var zone: LandingZone = world.landing_zone
	var panel: LoadPanel = world.load_panel
	print("ZONESTALL: pile size %s, field verts %d, lot tier %d"
		% [str(Cfg.pile_size) if "pile_size" in Cfg else "?", Cfg.field_verts(), GameState.lot_tier])


	var out_buildings:= 0
	var out_shapes:= 0
	for building: Node3D in builds.all_buildings():
		if not building.is_inside_tree():
			out_buildings += 1
			print("  OUT OF TREE building %s (%s) parent=%s"
				% [building.name, building.get_class(), building.get_parent()])
		for cs: CollisionShape3D in LandingZone.body_shapes(building):
			if not cs.is_inside_tree():
				out_shapes += 1
				print("  OUT OF TREE shape %s under %s" % [cs.get_path() if cs.is_inside_tree()
					else NodePath(str(cs.name)), building.name])
	print("ZONESTALL: %d buildings, %d out of the tree, %d shapes out of the tree"
		% [builds.all_buildings().size(), out_buildings, out_shapes])

	var t0:= Time.get_ticks_usec()
	panel.open()
	var t1:= Time.get_ticks_usec()
	print("ZONESTALL: panel open %.1f ms, zone %.2f m out and %.2f m tall, step 2 says '%s'"
		% [(t1 - t0) / 1000.0, LandingZone.radius(), LandingZone.height(), panel._zone_state.text])

	t0 = Time.get_ticks_usec()
	zone.refresh()
	t1 = Time.get_ticks_usec()
	print("ZONESTALL: refresh %.1f ms, %d in the way" % [(t1 - t0) / 1000.0, zone.blockers().size()])


	var worst:= 0
	for k in 120:
		panel._pay_dirty = true
		var a:= Time.get_ticks_usec()
		await get_tree().process_frame
		worst = maxi(worst, Time.get_ticks_usec() - a)
	print("ZONESTALL: worst frame with the panel up %.1f ms" % (worst / 1000.0))
	panel.set_open(false)
	print("ZONESTALL: done")
	get_tree().quit()
