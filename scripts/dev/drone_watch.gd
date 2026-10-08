class_name DevDroneWatch
extends Node


const OUT_DIR:= "res://captures/dronewatch"
const TRACE:= "res://captures/dronewatch/trace.txt"

var world: Node3D
var player: Player

var _cam: Camera3D
var _drone: HayDrone
var _log:= PackedStringArray()
var _shot:= 0


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.02
	_cam.far = 320.0
	world.add_child(_cam)
	_cam.current = true

	for i in 90:
		await get_tree().process_frame


	var pad:= Vector3(11.6, 0.02, -6.4)
	player.global_position = Vector3(6.0, 0.4, -3.0)
	GameState.add_money(40000.0)
	for i in 40:
		await get_tree().physics_frame

	_drone = world.builds.add_hay_drone(pad, 0.0)
	for i in 40:
		await get_tree().physics_frame

	_measure(pad)


	var wad: Carryable = world.props.spawn("hay_wad",
		Transform3D(Basis.IDENTITY, pad + Vector3(2.2, 0.6, 1.4)),
		{ "strands": 120 })
	wad.name = "Watched"


	_drone.set_mode(HayDrone.Mode.COLLECT)
	_drone.set_zone(pad + Vector3(2.2, - pad.y, 1.4), 1.5)
	_drone.set_drop(pad + Vector3(-4.5, - pad.y, 0.0), HayDrone.Drop.FLOOR)
	_say("zone %v, drop %v, route %s" % [_drone.zone_at, _drone.drop_at, _drone._route_why])
	for i in 60:
		await get_tree().physics_frame


	var last:= _drone._phase
	var frames:= 0
	var since:= 0
	while frames < 6000:
		await get_tree().physics_frame
		frames += 1
		since += 1
		_trace(frames)
		if _drone._phase != last:
			_say("--- %s -> %s at frame %d"
				% [HayDrone.Phase.keys() [last], HayDrone.Phase.keys() [_drone._phase], frames])
			last = _drone._phase
			await _frame_shot("%s_enter" % HayDrone.Phase.keys() [last].to_lower())
			since = 0
		elif since >= 40 and (last == HayDrone.Phase.TO_DROP
				or last == HayDrone.Phase.DELIVER or last == HayDrone.Phase.RELEASE):
			await _frame_shot("%s_hold" % HayDrone.Phase.keys() [last].to_lower())
			since = 0
		if frames % 30 == 0:
			_census(frames)
		if _drone._phase == HayDrone.Phase.IDLE and frames > 200:
			break


	_look_at_plate()
	for i in 6:
		for j in 40:
			await get_tree().physics_frame
		_census(frames)
		await _write("after_%d" % i)

	_say("\nreleases: %d" % _drone._releases)
	var f:= FileAccess.open(TRACE, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log))
		f.close()
	print("\n".join(_log))
	world.block_save = true
	get_tree().quit(0)


func _measure(pad: Vector3) -> void:
	var stand: HaySellingStand = world.stand
	var plate: Vector3 = _drone._plate_point()
	_say("pad           %s" % pad)
	_say("stand         %s" % stand.global_position)
	_say("belt head     %s" % stand.to_global(stand._belt_head))
	_say("mouth centre  %s" % stand.mouth_centre())
	_say("plate (aim)   %s  -- %.2f m below the mouth centre"
		% [plate, stand.mouth_centre().y - plate.y])
	_say("release cargo at y=%.2f (%.2f m of clearance)"
		% [plate.y + Cfg.DRONE_DROP_CLEAR, Cfg.DRONE_DROP_CLEAR])


	_say("aircraft hovers at y=%.2f" % (plate.y + HayDrone.HOVER_GAP))
	_say("airspace over the plate: %s" % _clear_above(plate))


func _clear_above(at: Vector3) -> String:
	var space:= world.get_world_3d().direct_space_state
	var hits:= PackedStringArray()
	var span:= 0.62
	for off in [Vector3.ZERO, Vector3(span, 0, span), Vector3(span, 0, - span),
			Vector3(- span, 0, span), Vector3(- span, 0, - span)]:
		var ray:= PhysicsRayQueryParameters3D.create(
			at + off + Vector3.UP * (HayDrone.HOVER_GAP + 1.5),
			at + off + Vector3.UP * (Cfg.DRONE_DROP_CLEAR + 0.05))
		ray.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_PROP
		var hit: Dictionary = space.intersect_ray(ray)
		if not hit.is_empty():
			hits.append("%s at %.2f m (%+.2f,%+.2f)"
				% [hit ["collider"].name, (hit ["position"] as Vector3).y, off.x, off.z])
	if hits.is_empty():
		return "open"
	return "BLOCKED: %s" % "; ".join(hits)


func _census(frame: int) -> void:
	var rows:= PackedStringArray()
	for item in world.props.items:
		if not is_instance_valid(item):
			continue
		if not item.has_method("sale_strands"):
			continue
		var rb:= item as RigidBody3D
		rows.append("%s@(%.2f,%.2f,%.2f) frozen=%s layer=%d held=%s%s" % [
			item.name, item.global_position.x, item.global_position.y,
			item.global_position.z, rb.freeze, rb.collision_layer,
			item.call("is_held") if item.has_method("is_held") else "?",
			" <-HOOK" if item == _drone._held else ""])
	if rows.is_empty():
		return
	_say("  [%4d] props: %s" % [frame, "; ".join(rows)])


func _trace(frame: int) -> void:
	if frame % 10 != 0:
		return
	var m: Node3D = _drone.get_node_or_null("Model")
	if m == null:
		return
	var cargo:= _drone._cargo.global_position if _drone._cargo != null else Vector3.INF


	var body: Node3D = _drone._body


	var lean:= Vector3.ZERO
	if body != null:
		lean = (body.transform * _drone._body_rest.affine_inverse()).basis.get_euler()
	var v: Vector3 = _drone._vel
	_say("  [%4d] %-9s craft=(%.2f,%.2f,%.2f) v=(%.2f,%.2f) pitch=%+5.1f roll=%+5.1f drop=%.2f cargo_y=%.2f claw=%s hatch=%s held=%s" % [
		frame, HayDrone.Phase.keys() [_drone._phase],
		m.global_position.x, m.global_position.y, m.global_position.z,
		Vector2(v.x, v.z).length(), v.y,
		rad_to_deg(lean.x), rad_to_deg(lean.z),
		_drone._drop, cargo.y, _drone._claw_state, _drone._hatch_state,
		_drone._held.name if _drone._held != null and is_instance_valid(_drone._held) else "-"])


func _frame_shot(label: String) -> void:
	var m: Node3D = _drone.get_node_or_null("Model")
	if m == null:
		return
	var at:= m.global_position
	_cam.look_at_from_position(at + Vector3(-3.4, 2.0, 3.4),
		at + Vector3(0, -0.9, 0), Vector3.UP)
	await _write("%02d_%s" % [_shot, label])
	_shot += 1


func _look_at_plate() -> void:
	var plate: Vector3 = _drone._plate_point()
	_cam.look_at_from_position(plate + Vector3(2.6, 1.8, 2.6), plate, Vector3.UP)


func _write(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT_DIR, label])


func _say(line: String) -> void:
	_log.append(line)
