extends Node


const TICKS:= 3600

const KICK:= 2.5

var world: Node3D
var player: Player

var _tick:= 0
var _tracks:= { }
var _hist:= { }
var _was_rider:= { }
var _launched_at:= { }
var _last_loose:= { }
var _loose_kicks:= 0
var _hooked:= { }
var _sum_kicks:= 0
var _sum_landed:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--launchland")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		print("LAUNCHLAND: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		print("LAUNCHLAND: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	print("LAUNCHLAND: %d buildings, block_save=%s" % [
		(d.get("buildings", []) as Array).size(), world.block_save])
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)
	world.builds.from_array(d.get("buildings", []))
	world.props.from_array(d.get("props", []))
	player.noclip = true
	player.global_position = Vector3(0.0, 8.0, 0.0)
	player.velocity = Vector3.ZERO
	BeltPath.debug_props = true
	for gun in world.builds.tube_launchers:
		gun.launched.connect(_on_launched.bind(gun))
		_hooked [gun.get_instance_id()] = true
	print("LAUNCHLAND: %d launchers hooked" % _hooked.size())
	for t in TICKS:
		await get_tree().physics_frame
		_tick += 1
		_step_all()
	print("LAUNCHLAND: %d launched loads landed and were followed, %d kicked over %.1f m/s, %d loose kicks elsewhere"
		% [_sum_landed, _sum_kicks, KICK, _loose_kicks])
	get_tree().quit()


func _desc(b: RigidBody3D) -> String:
	var kind:= "tuft" if b is HayTuft else "wad"
	var p:= b.global_position
	var v:= b.linear_velocity
	var fl:= ""
	if b.freeze:
		fl += " FROZEN"
	if BeltPath.is_rider(b):
		fl += " RIDER"
	if b.has_meta(LiveStrandManager.META_HOLD_UNTIL):
		fl += " held"
	return "%s#%d p=(%.2f,%.2f,%.2f) v=(%.2f,%.2f,%.2f) w=%.1f%s ref=%s" % [kind,
		b.get_instance_id() % 100000, p.x, p.y, p.z, v.x, v.y, v.z,
		b.angular_velocity.length(), fl,
		str(BeltPath.debug_last_refusal.get(b.get_instance_id(), "-"))]


func _under(b: RigidBody3D) -> String:
	var q:= PhysicsRayQueryParameters3D.create(b.global_position + Vector3(0, 0.3, 0),
		b.global_position - Vector3(0, 1.5, 0))
	q.exclude = [b.get_rid()]
	var r:= b.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return "nothing"
	var c: Object = r ["collider"]
	var s:= "?"
	if c is Node:
		var n: Node = c
		s = "%s(%s)" % [n.name, n.get_class()]
		var par:= n.get_parent()
		if par != null:
			s += "<%s" % par.name
			if par.get_parent() != null:
				s += "<%s" % par.get_parent().name
	return "%s y%.2f" % [s, (r ["position"] as Vector3).y]


func _contacts(b: RigidBody3D) -> String:
	var shape_owner:= b.get_shape_owners()
	if shape_owner.is_empty():
		return ""
	var shape: Shape3D = b.shape_owner_get_shape(shape_owner [0], 0)
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = b.global_transform * b.shape_owner_get_transform(shape_owner [0])
	q.exclude = [b.get_rid()]
	q.margin = 0.02
	var hits:= b.get_world_3d().direct_space_state.intersect_shape(q, 12)
	var names:= PackedStringArray()
	for h: Dictionary in hits:
		var c: Object = h ["collider"]
		if c is Node:
			var n: Node = c
			var par:= n.get_parent()
			names.append("%s(%s)%s" % [n.name, n.get_class(),
				("<" + String(par.name)) if par != null else ""])
	return ", ".join(names)


func _bodies() -> Array:
	var out: Array = []
	for it in world.props.items:
		if it is HayWad and is_instance_valid(it) and (it as Node).is_inside_tree():
			out.append(it)
	return out


func _near(b: RigidBody3D, bodies: Array) -> Array [String]:
	var out: Array [String] = []
	for o: RigidBody3D in bodies:
		if o != b and o.global_position.distance_to(b.global_position) < 1.2:
			out.append(_desc(o))
	return out


func _on_launched(item: Carryable, gun: Node) -> void:
	var rb:= item as RigidBody3D
	if rb == null:
		return
	var id:= rb.get_instance_id()
	_launched_at [id] = _tick
	_tracks [id] = { "gun": String(gun.name), "t0": _tick, "v0": rb.linear_velocity,
		"phase": "air", "prev_v": rb.linear_velocity, "land_t": -1,
		"land_p": Vector3.ZERO, "land_v": Vector3.ZERO, "under": "", "bounce": 0.0,
		"kick": 0.0, "kick_t": -1, "boarded": -1, "letgo": 0, "printed": false }


func _step_all() -> void:
	for gun in world.builds.tube_launchers:
		if is_instance_valid(gun) and not _hooked.has(gun.get_instance_id()):
			_hooked [gun.get_instance_id()] = true
			gun.launched.connect(_on_launched.bind(gun))
	var bodies:= _bodies()
	for b: RigidBody3D in bodies:
		_step(b, bodies)


func _print_kick(title: String, b: RigidBody3D, h: Array, bodies: Array) -> void:
	print(title)
	for l: String in h:
		print("      %s" % l)
	for n: String in _near(b, bodies):
		print("    beside: %s" % n)
	print("    under: %s" % _under(b))
	print("    touching: %s" % _contacts(b))


func _step(b: RigidBody3D, bodies: Array) -> void:
	var id:= b.get_instance_id()
	var v:= b.linear_velocity
	var rider:= BeltPath.is_rider(b)
	var h: Array = _hist.get(id, [])
	h.append("t%d %s | %s" % [_tick, _desc(b), _contacts(b) if not b.freeze else ""])
	while h.size() > 20:
		h.pop_front()
	_hist [id] = h
	var was:= bool(_was_rider.get(id, false))
	_was_rider [id] = rider
	if _tracks.has(id):
		var t: Dictionary = _tracks [id]
		var pv: Vector3 = t ["prev_v"]
		if String(t ["phase"]) == "air":
			if rider or b.freeze or v.y - pv.y > 1.5 or (_tick - int(t ["t0"]) > 5 and v.length() < 1.0):
				t ["phase"] = "ground"
				t ["land_t"] = _tick
				t ["land_p"] = b.global_position
				t ["land_v"] = pv
				t ["under"] = _under(b)
				_sum_landed += 1
		else:
			var dt:= _tick - int(t ["land_t"])
			if rider and int(t ["boarded"]) < 0:
				t ["boarded"] = dt
			if was and not rider:
				t ["letgo"] = int(t ["letgo"]) + 1
			if not b.freeze and dt <= 4:
				t ["bounce"] = maxf(float(t ["bounce"]), v.y)
			if not b.freeze and dt > 4 and v.y > float(t ["kick"]):
				t ["kick"] = v.y
				t ["kick_t"] = dt
				if v.y > KICK and not bool(t ["printed"]):
					t ["printed"] = true
					_sum_kicks += 1
					var lp: Vector3 = t ["land_p"]
					_print_kick("KICK: load from %s, %.1f m/s up, %d ticks after landing at (%.2f,%.2f,%.2f) on %s"
						% [t ["gun"], v.y, dt, lp.x, lp.y, lp.z, t ["under"]], b, h, bodies)
			if dt > 300:
				_finish(t, b)
				_tracks.erase(id)
				return
		t ["prev_v"] = v
		return
	if not b.freeze and v.y > 3.0 and b.global_position.y < 4.0 and _tick - int(_launched_at.get(id, -100000)) > 400 and _tick - int(_last_loose.get(id, -100000)) > 60 and _loose_kicks < 10:
		_loose_kicks += 1
		_last_loose [id] = _tick
		_print_kick("LOOSE KICK (not a launched load) %.1f m/s up" % v.y, b, h, bodies)


func _finish(t: Dictionary, b: RigidBody3D) -> void:
	var lp: Vector3 = t ["land_p"]
	var lv: Vector3 = t ["land_v"]
	var v0: Vector3 = t ["v0"]
	print("SUM %-14s v0 %4.1f  landed (%6.2f,%5.2f,%6.2f) at %4.1f m/s (vy %5.1f) on %s | bounce %4.1f  kick %4.1f at +%d  boarded +%d  let go %d  end %s"
		% [t ["gun"], v0.length(), lp.x, lp.y, lp.z, lv.length(), lv.y, t ["under"],
		float(t ["bounce"]), float(t ["kick"]), int(t ["kick_t"]), int(t ["boarded"]),
		int(t ["letgo"]), _desc(b)])
