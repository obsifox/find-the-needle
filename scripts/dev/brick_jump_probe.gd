class_name DevBrickJumpProbe
extends Node


var world: Node3D
var player: Player

const WATCH_SECONDS:= 120.0


const JUMP:= 0.5

var _last: Dictionary = { }
var _owner_last: Dictionary = { }

var _history: Dictionary = { }
const HISTORY:= 40
var _jumps:= 0
var _ticks:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	world.block_save = true
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--brickjump")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		print("BRICKJUMP: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	var f:= SaveManager.open_for_read(path)
	var d: Dictionary = f.get_var(true)
	f.close()
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)
	var heights: PackedFloat32Array = d.get("heights", PackedFloat32Array())
	if heights.size() > 0:
		world.field.generate(int(GameState.run_seed), heights)
		GameState.from_dict(d.get("state", { }))
	world.builds.from_array(d.get("buildings", []))
	world.props.from_array(d.get("props", []))
	if world.props.items.size() > Cfg.prop_cap:
		Cfg.prop_cap = world.props.items.size()
	if player != null and d.has("player"):
		player.global_transform = d ["player"]
	print("BRICKJUMP: %d buildings, %d props, block_save=%s, belt speed %.2f"
		% [(d.get("buildings", []) as Array).size(), world.props.items.size(),
			world.block_save, Tech.belt_speed()])
	var all:= "--all" in ua
	get_tree().physics_frame.connect(_sample.bind(all))
	await get_tree().create_timer(WATCH_SECONDS).timeout
	_report_feeds()
	print("BRICKJUMP: %d ticks, %d jumps, %d switches to an unjoined belt"
		% [_ticks, _jumps, _switches])
	get_tree().quit(0)


func _sample(all: bool) -> void:
	_ticks += 1
	var seen:= { }
	for item in world.props.items:
		if not is_instance_valid(item):
			continue
		if not all and not (item is EcoBrick):
			continue
		var id: int = item.get_instance_id()
		seen [id] = true
		var at: Vector3 = item.global_position
		var who: String = _owner(item)
		if _last.has(id):
			var was: Vector3 = _last [id]
			if was.distance_to(at) > JUMP:
				_jumps += 1
				print("JUMP t=%.2f %s #%d %.2f m  %s -> %s  before: %s  now: %s  frozen=%s"
					% [_ticks / 60.0, item.get_class() if not (item is EcoBrick) else "brick",
						id, was.distance_to(at), _v(was), _v(at), _owner_last.get(id, "?"),
						who, item.freeze])
				if "--history" in OS.get_cmdline_user_args():
					for line: String in _history.get(id, []):
						print("    ", line)
		elif _ticks > 1:
			print("NEW t=%.2f #%d at %s  %s  nearest pelletizer %.1f m"
				% [_ticks / 60.0, id, _v(at), who, _nearest_pelletizer(at)])
		_check_switch(item, id, at)
		_last [id] = at
		_owner_last [id] = who
		var h: Array = _history.get(id, [])
		h.append("t=%.2f %s %s" % [_ticks / 60.0, _v(at), who])
		if h.size() > HISTORY:
			h.pop_front()
		_history [id] = h
	for id in _last.keys():
		if not seen.has(id):
			_last.erase(id)
			_owner_last.erase(id)
			_history.erase(id)


var _rode: Dictionary = { }
var _switches:= 0


func _check_switch(item: Carryable, id: int, at: Vector3) -> void:
	var belt: Variant = (item.get_meta(LiveStrandManager.META_RIDER)
		if item.has_meta(LiveStrandManager.META_RIDER) else null)
	if not (belt is BeltPath) or not is_instance_valid(belt):
		return
	var now:= belt as BeltPath
	var before: Array = _rode.get(id, [])
	_rode [id] = [now, at, _ticks]
	if before.is_empty():
		return
	var prev: Variant = before [0]
	if not is_instance_valid(prev) or is_same(prev, now):
		return
	if is_same((prev as BeltPath).downstream, now):
		return
	_switches += 1
	var left: Vector3 = before [1]
	print("SWITCH t=%.2f brick #%d from %s to %s, off the belt %.2f s, fell %.2f m, %s -> %s"
		% [_ticks / 60.0, id, _belt_name(prev as BeltPath), _belt_name(now),
			(_ticks - int(before [2])) / 60.0, left.y - at.y, _v(left), _v(at)])


func _belt_name(bp: BeltPath) -> String:
	if bp is Conveyor:
		return "run %s -> %s" % [_v((bp as Conveyor).a), _v((bp as Conveyor).b)]
	return "%s at %s" % [str(bp.get_script().get_global_name()), _v(bp.global_position)]


func _owner(item: Carryable) -> String:
	var parts: Array [String] = []
	var belt: Variant = (item.get_meta(LiveStrandManager.META_RIDER)
		if item.has_meta(LiveStrandManager.META_RIDER) else null)
	if belt is BeltPath and is_instance_valid(belt):
		var bp:= belt as BeltPath
		var line:= "path"
		if bp is Conveyor:
			line = "run %s -> %s" % [_v((bp as Conveyor).a), _v((bp as Conveyor).b)]
		parts.append("rider of %s %s" % [str(bp.get_script().get_global_name()), line])
	else:
		parts.append("v=%.2f" % item.linear_velocity.length())
	for arm in world.builds.robotic_arms:
		if is_instance_valid(arm) and arm._payload_prop == item:
			parts.append("in arm %s" % _v(arm.global_position))
	if item.has_meta(PropManager.META_CLAIM):
		parts.append("claimed")
	if item.is_held():
		parts.append("held")
	return ", ".join(parts)


func _report_feeds() -> void:
	var b: BuildManager = world.builds
	var linked:= 0
	for gen: HayGenerator in b.generators:
		if not is_instance_valid(gen):
			continue
		var run: Conveyor = b.feed_run_into(gen.intake_port())
		var ok:= run != null and run.downstream == gen.deck()
		if ok:
			linked += 1
		print("FEED generator %s: %s" % [_v(gen.global_position),
			("linked, run %s -> %s" % [_v(run.a), _v(run.b)]) if ok
			else ("NOT LINKED, run into port: %s" % (_v(run.a) if run != null else "none"))])
	print("BRICKJUMP: %d of %d generators have a linked feed" % [linked, b.generators.size()])


func _nearest_pelletizer(at: Vector3) -> float:
	var best:= INF
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if not (n is HayPelletizer):
			continue
		best = minf(best, (n as Node3D).global_position.distance_to(at))
	return best


func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]
