class_name DevLandingZoneProbe
extends Node


const LOG:= "res://landing_zone_probe.log"


const HAY:= LandingZone.HAY_EPS

var world: Node3D
var player: Player

var _fails: PackedStringArray = PackedStringArray()
var _inside: Conveyor
var _outside: Conveyor


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	await _settle(8)

	_case_the_zone_covers_the_load()
	_finish_the_lot()
	await _case_an_empty_yard_is_clear()
	await _case_named_and_only_that()
	await _case_the_order_is_refused()
	await _case_the_switch()
	await _case_the_load_comes()

	if _fails.is_empty():
		_log("OK")
	else:
		for f in _fails:
			_log("FAIL  " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_the_zone_covers_the_load() -> void:
	var field: HayField = world.field
	var zone: LandingZone = world.landing_zone
	var nv:= Cfg.field_verts()
	var c:= LandingZone.centre()
	for k in 4:
		var seed_value:= LandingZone.next_seed()
		field.refill(seed_value)
		_check(GameState.run_seed == seed_value,
			"load %d was not shaped from the seed the zone was for" % k)
		var h:= field.heights
		var reach:= 0.0
		var peak:= 0.0
		for j in nv:
			for i in nv:
				var at:= h [j * nv + i]
				if at <= HAY:
					continue
				var wx:= - Cfg.FIELD_EXTENT + i * Cfg.CELL - c.x
				var wz:= - Cfg.FIELD_EXTENT + j * Cfg.CELL - c.z
				reach = maxf(reach, Vector2(wx, wz).length())
				peak = maxf(peak, at)
		_log("  load %d: hay reaches %.2f m and stands %.2f m, the zone is %.2f m out and %.2f m tall"
			% [k, reach, peak, zone.radius(), zone.height()])
		_check(reach <= zone.radius(),
			"load %d put hay %.2f m out, past the zone's %.2f m" % [k, reach, zone.radius()])
		_check(peak <= zone.height(),
			"load %d stood %.2f m tall, over the zone's %.2f m" % [k, peak, zone.height()])


func _finish_the_lot() -> void:
	for type in NeedleTypes.pool(GameState.lot_tier):
		GameState.discover(int(type), Vector3.ZERO)
	_check(GameState.may_order_pile(), "the probe filled the case and the gate is still shut")


func _case_an_empty_yard_is_clear() -> void:
	var zone: LandingZone = world.landing_zone
	await _physics(2)
	zone.refresh()
	_check(not zone.is_blocked(),
		"an empty yard reads as blocked by %s" % _names(zone))


func _case_named_and_only_that() -> void:
	var builds: BuildManager = world.builds
	var zone: LandingZone = world.landing_zone
	var c:= LandingZone.centre()
	var lift:= Vector3(0.0, 0.05, 0.0)


	var in_z:= LandingZone.radius() * 0.5
	_inside = builds.add_conveyor(c + Vector3(-3.0, 0.0, in_z) + lift,
		c + Vector3(3.0, 0.0, in_z) + lift)


	var out_dir:= Vector3(1.0, 0.0, 1.0).normalized()
	var along:= Vector3(- out_dir.z, 0.0, out_dir.x)
	var mid:= c + out_dir * (LandingZone.radius() + 2.5) + lift
	_outside = builds.add_conveyor(mid - along * 7.0, mid + along * 7.0)
	await _physics(2)

	var box:= _world_box(_outside)
	var nearest:= Vector2(clampf(c.x, box.position.x, box.end.x),
		clampf(c.z, box.position.z, box.end.z))
	_check(nearest.distance_to(Vector2(c.x, c.z)) < LandingZone.radius(),
		"the diagonal belt's box does not reach into the zone, so this case proves nothing")

	zone.refresh()
	var found:= zone.blockers()
	_check(found.has(_inside), "a belt across the load is not named as in the way")
	_check(not found.has(_outside), "a belt laid past the load is named as in the way")
	var rows:= zone.summary()
	_check(rows.size() == 1 and str(rows [0] ["name"]) == BuildCatalog.display_name("belt")
			and int(rows [0] ["count"]) == 1,
		"the list should read one belt, and reads %s" % str(rows))


func _case_the_order_is_refused() -> void:
	var zone: LandingZone = world.landing_zone
	var panel: LoadPanel = world.load_panel
	var card: ZoneCard = world.zone_card
	var seed_before:= GameState.run_seed

	_look_at_note()
	_check(_press(), "E on the note was dropped rather than answered")
	await _settle(2)
	_check(panel.is_open(), "E on the note did not open the order panel")
	_check(GameState.run_seed == seed_before, "E on the note tipped a load without the panel")

	panel.press_order()
	await _settle(2)
	_check(GameState.run_seed == seed_before, "the panel tipped a load onto a belt in the zone")
	_check(panel.is_open(), "the refusal closed the panel as if the order had gone")
	_check(zone.is_shown(), "the order was refused and the wall did not go up")
	_check(card.visible, "the wall is up and the card on the HUD is not")
	_check(zone.marks_drawn() > 0, "the belt in the way is not tinted")


	world._deliver_new_pile()
	await _settle(2)
	_check(GameState.run_seed == seed_before, "the world tipped a load onto a belt in the zone")
	await _photograph()


func _photograph() -> void:
	var dir:= _shots_dir()
	if dir == "":
		return
	if DisplayServer.get_name() == "headless":
		_log("  --shots asked for on a headless run, so there is nothing to photograph")
		return
	var panel: LoadPanel = world.load_panel
	var zone: LandingZone = world.landing_zone
	var c:= LandingZone.centre()
	var edge:= LandingZone.radius()
	await _shot(dir, "zone_panel.png")


	var was_found:= GameState.needles_found
	zone.set_shown(false)
	GameState.needles_found = 2
	panel.refresh()
	await _shot(dir, "zone_panel_locked.png")
	GameState.needles_found = Cfg.LANDING_WALL_NEEDLES
	panel.refresh()
	await _shot(dir, "zone_panel_unlocked.png")
	GameState.needles_found = was_found
	zone.set_shown(true)
	panel.set_open(false)
	_stand_looking(c + Vector3(-5.0, 0.0, edge + 2.5), c + Vector3(0.0, 0.4, edge - 1.5))
	await _shot(dir, "zone_wall_near.png")
	_stand_looking(c + Vector3(12.0, 0.0, 12.0), c + Vector3(0.0, 3.0, 0.0))
	await _shot(dir, "zone_wall_corner.png")


	var hidden: Array [Node3D] = []
	for n: Node3D in [world.field, world.get("detail")]:
		if n != null and n.visible:
			n.visible = false
			hidden.append(n)
	var in_z:= LandingZone.radius() * 0.5
	_stand_looking(c + Vector3(2.5, 0.0, in_z + 3.5), c + Vector3(0.0, 0.3, in_z))
	await _shot(dir, "zone_belt_tint.png")
	for n: Node3D in hidden:
		n.visible = true


func _case_the_switch() -> void:
	var zone: LandingZone = world.landing_zone
	var panel: LoadPanel = world.load_panel
	var card: ZoneCard = world.zone_card


	var batch:= BeltBatch.instance
	var sections:= _inside.find_child("Sections", true, false) as GeometryInstance3D
	_check(batch != null and sections != null,
		"no belt batch or no Sections node on the belt, so the tint is untested")
	if batch != null and sections != null:
		_check(batch.holds(sections),
			"the tinted belt was lifted out of the batch, which puts every part back to a call of its own")
		_check(batch.tint_of(sections) != null, "the belt in the way is not tinted")
		_check(sections.material_overlay == null,
			"the belt wears the overlay on a node the batch has taken off every layer")
		_check(_tint_tiles(batch) > 0, "the batch has no tint tile over the belt in the way")
		await _case_the_belt_changes_hands(zone, batch, sections)
	panel.press_zone()
	await _settle(2)
	_check(not zone.is_shown(), "HIDE THE ZONE left the wall standing")
	_check(not card.visible, "the wall came down and the card stayed on the HUD")
	_check(zone.marks_drawn() == 0, "the wall came down and the red tint stayed")
	if batch != null and sections != null:
		_check(sections.material_overlay == null, "the wall came down and the belt is still red")
		_check(batch.holds(sections), "the belt is not in the batch after the wall came down")
		_check(batch.tint_of(sections) == null, "the wall came down and the batch still tints the belt")
		_check(_tint_tiles(batch) == 0,
			"the wall came down and %d tint tiles are still drawn" % _tint_tiles(batch))


	var button:= panel.find_child("ZoneButton", true, false) as Button
	GameState.needles_found = Cfg.LANDING_WALL_NEEDLES - 1
	panel.refresh()
	_check(button != null and button.visible and button.icon != null,
		"SHOW WHERE IT LANDS has no padlock with %d needles found" % GameState.needles_found)
	panel.press_zone()
	await _settle(2)
	_check(not zone.is_shown(), "SHOW WHERE IT LANDS put the wall up before it was unlocked")

	GameState.needles_found = Cfg.LANDING_WALL_NEEDLES
	panel.refresh()
	_check(button != null and button.visible and button.icon == null,
		"SHOW WHERE IT LANDS is still locked with %d needles found" % GameState.needles_found)
	panel.press_zone()
	await _settle(2)
	_check(zone.is_shown(), "SHOW THE ZONE did not put the wall back up")
	_check(card.visible, "the wall went back up without its card")


func _case_the_belt_changes_hands(zone: LandingZone, batch: BeltBatch,
		sections: GeometryInstance3D) -> void:
	batch.drop(sections)
	zone.refresh()
	zone._retint()
	await _settle(2)
	_check(sections.material_overlay != null,
		"a belt lifted out of the batch under the wall is not tinted")
	_check(batch.tint_of(sections) == null, "the batch still tints a belt it does not hold")
	BeltBatch.adopt(sections)
	zone.refresh()
	zone._retint()
	await _settle(2)
	_check(batch.holds(sections), "the belt did not go back into the batch")
	_check(sections.material_overlay == null,
		"a belt handed back to the batch still wears the overlay")
	_check(batch.tint_of(sections) != null, "a belt handed back to the batch lost its tint")
	_check(_tint_tiles(batch) > 0, "a belt handed back to the batch has no tint tile over it")


func _tint_tiles(batch: BeltBatch) -> int:
	var n:= 0
	for child: Node in batch.get_children():
		var mmi:= child as MultiMeshInstance3D
		if mmi == null or mmi.is_queued_for_deletion() or not String(mmi.name).begins_with("Tint_"):
			continue
		if mmi.multimesh != null and mmi.multimesh.instance_count > 0:
			n += 1
	return n


func _case_the_load_comes() -> void:
	var builds: BuildManager = world.builds
	var props: PropManager = world.props
	var field: HayField = world.field
	var zone: LandingZone = world.landing_zone
	var panel: LoadPanel = world.load_panel
	var c:= LandingZone.centre()

	builds.demolish(_inside)
	await _physics(2)
	zone.refresh()
	_check(not zone.is_blocked(),
		"the belt came down and the zone still reads as blocked by %s" % _names(zone))

	var bucket:= props.spawn("bucket", Transform3D(Basis(), c + Vector3(-2.0, 0.4, 4.0)))
	await _physics(20)

	var seed_before:= GameState.run_seed
	var promised:= LandingZone.next_seed()
	panel.press_order()
	await _physics(4)
	_check(GameState.run_seed != seed_before, "the zone was clear and the load did not come")
	_check(GameState.run_seed == promised, "the load that came is not the one the zone showed")
	_check(not panel.is_open(), "the load came and the panel stayed open")
	_check(not zone.is_shown(), "the load came and the wall stayed up")
	_check(is_instance_valid(_outside) and not _outside.is_queued_for_deletion(),
		"the belt outside the load did not survive the delivery")

	_check(is_instance_valid(bucket), "the bucket left on the slab is gone")
	if is_instance_valid(bucket):
		var p:= bucket.global_position
		var surface:= field.height_at(p.x, p.z)
		_check(surface > 0.5,
			"no hay landed where the bucket was, so this case proves nothing")
		_check(p.y >= surface - 0.05,
			"the bucket is %.2f m under the new hay" % (surface - p.y))


func _world_box(building: Node3D) -> AABB:
	var out:= AABB()
	var first:= true
	for cs: CollisionShape3D in LandingZone.body_shapes(building):
		var here: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
		out = here if first else out.merge(here)
		first = false
	return out


func _names(zone: LandingZone) -> String:
	var parts:= PackedStringArray()
	for row: Dictionary in zone.summary():
		parts.append("%s x%d" % [str(row ["name"]), int(row ["count"])])
	return ", ".join(parts) if not parts.is_empty() else "nothing"


func _look_at_note() -> void:
	var board: DeliveryBoard = world.delivery_board
	var at:= board.note_point()
	var out:= board.global_transform.basis * DeliveryBoard.face_normal()
	out.y = 0.0
	var stand:= at + out.normalized() * 1.4
	stand.y = 0.2
	player.global_position = stand
	var to_sheet:= at - player.eye_position()
	player.set_look(atan2(- to_sheet.x, - to_sheet.z),
		atan2(to_sheet.y, Vector2(to_sheet.x, to_sheet.z).length()))


func _press() -> bool:
	var board: DeliveryBoard = world.delivery_board
	return board.take_press(player.eye_position(), player.look_direction())


func _shots_dir() -> String:
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--shots")
	if at < 0 or at + 1 >= args.size():
		return ""
	return args [at + 1]


func _stand_looking(at: Vector3, target: Vector3) -> void:
	player.global_position = at
	var to:= target - player.eye_position()
	player.set_look(atan2(- to.x, - to.z), atan2(to.y, Vector2(to.x, to.z).length()))


func _shot(dir: String, file_name: String) -> void:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [dir, file_name]
	get_viewport().get_texture().get_image().save_png(path)
	_log("  wrote " + path)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _check(ok: bool, why: String) -> void:
	if not ok and why != "":
		_fails.append(why)


func _log(line: String) -> void:
	print("[landingzone] " + line)
	var f:= FileAccess.open(LOG, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()
