class_name DevBeltStuckProbe
extends Node


var at:= Vector2(7.43, -13.13)
const REACH:= 3.0
const REPORT_AT:= [1, 30, 120, 300, 600]

var world: Node3D
var player: Player


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--beltstuck")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		print("BELTSTUCK: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	if i + 2 < ua.size() and "," in ua [i + 2]:
		var xz:= ua [i + 2].split(",")
		at = Vector2(float(xz [0]), float(xz [1]))
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		print("BELTSTUCK: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	print("BELTSTUCK: %d buildings, %d props, block_save=%s" % [
		(d.get("buildings", []) as Array).size(), (d.get("props", []) as Array).size(),
		world.block_save])
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)


	var real_load:= "--realload" in ua
	if real_load:
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
	world.builds.from_array(d.get("buildings", []))
	BeltPath.debug_props = true


	var strands:= "--strands" in ua
	var empty:= "--empty" in ua or strands
	world.props.from_array([] if empty else d.get("props", []))


	var start:= { }
	for item in world.props.items:
		if is_instance_valid(item) and item.global_position.y > 0.2:
			start [item] = item.global_position
	if real_load:
		for k in 8:
			await get_tree().process_frame
		get_tree().paused = false
		print("BELTSTUCK: restored paused, unpaused now")
	player.noclip = true
	player.global_position = Vector3(at.x - 1.2, 0.0, at.y + 0.9)
	player.velocity = Vector3.ZERO
	print("BELTSTUCK: belt speed %.2f, prop_cap %d, belt_cap %d, prop_decay %s, belt_decay %s"
		% [Tech.belt_speed(), Cfg.prop_cap, Cfg.belt_cap, Cfg.prop_decay, Cfg.belt_decay])
	var feed:= _feed()
	if empty:
		for k in 180:
			await get_tree().physics_frame
		_report(0)
	if empty and not strands:
		print("BELTSTUCK: setting the pair down on %s" % _name(feed))
		var wad_at:= feed._point_at(maxf(feed.path_length() - 0.9, 0.0)) + Vector3.UP * 0.05
		var tuft_at:= feed._point_at(maxf(feed.path_length() - 1.6, 0.0)) + Vector3.UP * 0.05
		world.props.spawn("hay_wad", Transform3D(Basis.IDENTITY, wad_at), { "strands": 187 })
		world.props.spawn("hay_tuft", Transform3D(Basis.IDENTITY, tuft_at), { "strands": 100 })


	var with_wad:= "--wad" in ua
	var rng:= RandomNumberGenerator.new()
	rng.seed = 20260913
	var tick:= 0
	var last: int = 2400 if strands else REPORT_AT [REPORT_AT.size() - 1]
	if with_wad:
		last = 6000
	var dropped:= 0
	var wad: RigidBody3D = null
	var wad_sent:= false
	while tick < last:
		await get_tree().physics_frame
		tick += 1
		if with_wad and not wad_sent and not _caught_asleep.is_empty():
			wad_sent = true
			wad = world.props.spawn("hay_wad", Transform3D(Basis.IDENTITY,
				feed._point_at(maxf(feed.path_length() - 0.9, 0.0)) + Vector3.UP * 0.05),
				{ "strands": 187 }) as RigidBody3D
			world.props.spawn("hay_tuft", Transform3D(Basis.IDENTITY,
				feed._point_at(maxf(feed.path_length() - 1.6, 0.0)) + Vector3.UP * 0.05),
				{ "strands": 100 })
			last = tick + 1200
			print("BELTSTUCK: tick %d, straw stopped, a 187 strand wad and a tuft set on %s" % [tick, _name(feed)])
		if wad_sent and is_instance_valid(wad) and tick % 30 == 0:
			var owner_path = wad.get_meta(LiveStrandManager.META_RIDER) if wad.has_meta(LiveStrandManager.META_RIDER) else null
			var line:= ""
			for p: BeltPath in _paths():
				line += " %s asleep=%s riders=%d;" % [p.name, p._asleep, p._riders.size()]
			print("BELTSTUCK: tick %d, the wad at %v rides %s;%s"
				% [tick, _r(wad.global_position), _name(owner_path), line])
		if strands and not wad_sent and tick < last - 300:

			if tick % 90 < 8:
				var s:= rng.randf_range(0.3, feed.path_length() - 0.3)
				var pos:= feed._point_at(s) + Vector3.UP * 0.12 + feed._basis_at(s).x * rng.randf_range(-0.2, 0.2)
				var b:= Basis(Vector3.UP, rng.randf_range(0.0, TAU))
				if world.live.spawn(pos, b, Vector3(0.0, -0.4, 0.0), Color(0.85, 0.72, 0.42)) != null:
					dropped += 1
		if tick % 10 == 0 and not wad_sent:
			_stranded(tick)
		if tick in REPORT_AT:
			_report(tick)
	var still:= 0
	for item in start.keys():
		if is_instance_valid(item) and item.is_inside_tree() and (item as Node3D).global_position.distance_to(start [item]) < 0.01:
			still += 1
			print("BELTSTUCK: never moved: %s at %v" % [_name(item), _r(start [item])])
	print("BELTSTUCK: %d restored loads up on a deck, %d never moved" % [start.size(), still])
	print("BELTSTUCK: done, %d strands dropped, %d paths ever caught asleep with riders"
		% [dropped, _caught_asleep.size()])
	_report(tick)
	get_tree().quit()


func _feed() -> BeltPath:
	var feed: BeltPath = null
	var spot:= Vector3(at.x, 0.34, at.y)
	for p: BeltPath in _paths():
		if not (p is Conveyor):
			continue
		if feed == null or p._point_at(p.path_length()).distance_to(spot) < feed._point_at(feed.path_length()).distance_to(spot):
			feed = p
	return feed


var _caught_asleep:= { }


func _stranded(tick: int) -> void:
	for item in BeltPath._live:
		if not is_instance_valid(item):
			continue
		var p:= item as BeltPath
		if not p._asleep or p._riders.is_empty():
			continue
		var id:= p.get_instance_id()
		if _caught_asleep.has(id):
			continue
		_caught_asleep [id] = tick
		print("BELTSTUCK: tick %d, %s is ASLEEP carrying %d" % [tick, _name(p), p._riders.size()])
		for r in p._riders:
			_rider_line(r)


func _rider_line(r) -> void:
	var b = r.body
	var extra:= ""
	if is_instance_valid(b):
		var rb:= b as RigidBody3D
		extra = " layer %d mask %d freeze %s mode %d pinned %s glide %s" % [
			rb.collision_layer, rb.collision_mask, rb.freeze, rb.freeze_mode,
			rb.has_meta(LiveStrandManager.META_PINNED), rb.has_meta(LiveStrandManager.META_GLIDE)]
	print("     rider seq %d %s s %.3f side %.3f reach %.3f gap %.3f speed %.2f ps %.3f%s"
		% [r.seq, _name(b), r.s, r.side, r.reach, r.gap, r.speed, r.ps, extra])


func _near(p: Vector3) -> bool:
	return Vector2(p.x, p.z).distance_to(at) < REACH


func _name(p: Object) -> String:
	if p == null or not is_instance_valid(p):
		return "-"
	var n:= p as Node
	if n == null:
		return str(p)
	var c:= n as Conveyor
	if c != null:
		return "%s[%v -> %v]" % [n.name, _r(c.laid_start()), _r(c.laid_end())]
	return "%s(%s)" % [n.name, n.get_class()]


func _r(v: Vector3) -> Vector3:
	return (v * 100.0).round() / 100.0


func _paths() -> Array [BeltPath]:
	var out: Array [BeltPath] = []
	var all: Array = []
	all.append_array(world.builds.conveyors)
	all.append_array(world.builds.corners)
	for c in all:
		if not is_instance_valid(c):
			continue
		var p:= c as BeltPath
		var n:= p._nearest(Vector3(at.x, 0.34, at.y))
		var q:= p._point_at(float(n ["s"]))
		if Vector2(q.x, q.z).distance_to(at) < 1.2:
			out.append(p)
	return out


func _report(tick: int) -> void:
	print("---- tick %d (%.2f s)" % [tick, tick / 60.0])
	for p: BeltPath in _paths():
		print("  run %s len %.2f speed %.2f ASLEEP %s catching %s blocked %s outlet_held %s hold_back %.2f dead_zone %.2f deck_moved %.3f"
			% [_name(p), p.path_length(), p.drive_speed, p._asleep, p._catching, p._blocked,
				p._outlet_held, p._hold_back, p._catch_dead_zone, p._deck_moved])
		print("     downstream %s" % _name(p.downstream))
		for r in p._riders:
			_rider_line(r)
	var bodies: Array = []
	bodies.append_array(HayTuft.all)
	for item in world.props.items:
		if is_instance_valid(item) and not (item is HayTuft):
			bodies.append(item)
	for b in bodies:
		var rb:= b as RigidBody3D
		if rb == null or not is_instance_valid(rb) or not rb.is_inside_tree():
			continue
		if not _near(rb.global_position):
			continue
		var owner_path = rb.get_meta(LiveStrandManager.META_RIDER) if rb.has_meta(LiveStrandManager.META_RIDER) else null
		var shape:= BeltPath.load_shape(rb)
		print("  prop %s at %v up %v freeze %s sleep %s v %v rider_of %s reach %.3f lift %.3f refused '%s'"
			% [_name(rb), _r(rb.global_position), _r(rb.global_basis.y), rb.freeze, rb.sleeping,
				_r(rb.linear_velocity), _name(owner_path), float(shape ["reach"]), float(shape ["lift"]),
				BeltPath.debug_last_refusal.get(rb.get_instance_id(), "")])
		for p: BeltPath in _paths():
			var n:= p._nearest(rb.global_position)
			print("       on %s: s %.3f side %.3f lift %.3f"
				% [p.name, float(n ["s"]), float(n ["side"]), float(n ["lift"])])
