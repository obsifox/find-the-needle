class_name DevForkBeltProbe
extends Node


const DUMPS:= 6
const FILL_TICKS:= 45
const WATCH:= 150
const FAST:= 12.0

const AFTER:= 900

const SWEEP:= 3.0


const RISE:= 2.5

var world: Node3D
var player: Player

var _live: LiveStrandManager
var _rng:= RandomNumberGenerator.new()

var _was_rider:= { }

var _traced:= { }


var _history:= { }
var _crest_kicks:= 0


const CREST:= Vector3(-19.9, 3.9, -25.0)
const BEND:= Vector3(-24.5, 2.9, -21.9)

const HEAP_MIN:= Vector3(-28.5, -1.0, -24.5)
const HEAP_MAX:= Vector3(-25.2, 1.5, -18.0)


func _in_heap(p: Vector3) -> bool:
	return p.x > HEAP_MIN.x and p.x < HEAP_MAX.x and p.y > HEAP_MIN.y and p.y < HEAP_MAX.y and p.z > HEAP_MIN.z and p.z < HEAP_MAX.z


func _heap_count() -> int:
	var n:= 0
	for item in world.props.items:
		if item is HayWad and is_instance_valid(item) and item.is_inside_tree() and _in_heap(item.global_position):
			n += 1
	return n


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	_live = world.live
	_rng.seed = 20260912
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--forkbelt")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		print("FORKBELT: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		print("FORKBELT: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	print("FORKBELT: %d buildings, block_save=%s" % [
		(d.get("buildings", []) as Array).size(), world.block_save])
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)
	world.builds.from_array(d.get("buildings", []))


	var keep:= "--keeplitter" in ua
	world.props.from_array(d.get("props", []) if keep else [])
	await _ticks(60)
	if keep:
		player.noclip = true
		player.global_position = Vector3(-19.188248, 5.612541, -22.682713)
		player.velocity = Vector3.ZERO
		BeltPath.debug_props = true
		var heap_before:= _heap_count()
		print("FORKBELT: litter kept, %d props, %d wads on the floor west of the bend; watching the yard as it was"
			% [world.props.items.size(), heap_before])
		await _watch("the yard as it was", 900)
		print("FORKBELT: wads on the floor west of the bend: %d before, %d after" % [heap_before, _heap_count()])
		get_tree().quit()
		return

	Cfg.tool_mode = Cfg.TOOL_SIMPLE
	Tech.grant_legacy()
	Tech.grant("fork_size", 5)
	GameState.grant_tool("pitchfork")
	player._set_tool(Player.Tool.PITCHFORK)
	var rig: Shovel = player.pitchfork
	rig.reset_aim()
	player.noclip = true

	player.global_position = Vector3(-19.188248, 5.612541, -22.682713)
	player.rotation = Vector3(0.0, 0.3912, 0.0)
	player.head.rotation.x = -0.8817
	player.set("_pitch", -0.8817)
	player.velocity = Vector3.ZERO
	await _ticks(30)
	print("FORKBELT: fork holds %d, blade at %v" % [rig.capacity(), rig.body.global_position])

	for n in DUMPS:
		_fill_pan(rig, rig.capacity())
		await _ticks(FILL_TICKS)
		var held:= rig.carried_strands()
		rig.dump()
		await _watch("dump %d of %d strands" % [n + 1, held], WATCH)

	await _watch("after the last dump", AFTER)
	print("FORKBELT: where every tuft and wad ended up:")
	var props: Array = []
	props.append_array(HayTuft.all)
	for item in world.props.items:
		if item is HayWad:
			props.append(item)
	for b: RigidBody3D in props:
		if is_instance_valid(b) and b.is_inside_tree():
			print("    %s" % _describe(b))
	get_tree().quit()


func _watch(label: String, ticks: int) -> void:
	var speed:= 0.0
	var speed_at:= 0
	var what:= ""
	var swept_ids:= { }
	var thrown_ids:= { }
	var top_thrown:= 0.0
	for tick in range(1, ticks + 1):
		await get_tree().physics_frame
		var bodies: Array = []
		bodies.append_array(_live._active)
		bodies.append_array(HayTuft.all)
		for item in world.props.items:
			if item is HayWad:
				bodies.append(item)
		var sweeps: Array = []
		for b: RigidBody3D in bodies:
			if not is_instance_valid(b) or not b.is_inside_tree():
				continue
			var v:= b.linear_velocity.length()

			if b is HayTuft or b is HayWad:
				if b.global_position.distance_to(CREST) < 1.5:
					var lines: Array = _history.get(b.get_instance_id(), [])
					lines.append("tick %3d  %s  refused: %s" % [tick, _describe(b),
						str(BeltPath.debug_last_refusal.get(b.get_instance_id(), "-"))])
					while lines.size() > 14:
						lines.pop_front()
					_history [b.get_instance_id()] = lines
					if not b.freeze and b.linear_velocity.y > RISE and _crest_kicks < 3:
						_crest_kicks += 1
						print("    a kick at the crest, the ticks before it:")
						for l in lines:
							print("        %s" % str(l))
				var rider:= BeltPath.is_rider(b)
				var was:= bool(_was_rider.get(b.get_instance_id(), false))
				if rider != was:
					print("    tick %3d  %s  %s" % [tick, "CAUGHT" if rider else "LET GO", _describe(b)])
					if not rider and (b.global_position.distance_to(CREST) < 1.2
							or b.global_position.distance_to(BEND) < 1.2) and _traced.size() < 6:
						_traced [b.get_instance_id()] = 45
				_was_rider [b.get_instance_id()] = rider
				if _traced.has(b.get_instance_id()):
					var left:= int(_traced [b.get_instance_id()]) - 1
					print("        trace %2d  %s  refused: %s" % [left, _describe(b),
						str(BeltPath.debug_last_refusal.get(b.get_instance_id(), "-"))])
					if left <= 0:
						_traced.erase(b.get_instance_id())
					else:
						_traced [b.get_instance_id()] = left
			if b.freeze and v > SWEEP:
				sweeps.append(b)
				if not swept_ids.has(b.get_instance_id()):
					swept_ids [b.get_instance_id()] = true
					if v > FAST:
						print("    tick %3d  SWEEP %7.1f m/s  %s" % [tick, v, _describe(b)])
			if v > speed:
				speed = v
				speed_at = tick
				what = _describe(b)
		for b: RigidBody3D in bodies:
			if not is_instance_valid(b) or not b.is_inside_tree() or b.freeze:
				continue
			if b.linear_velocity.y < RISE or b.global_position.y > 6.0:
				continue
			top_thrown = maxf(top_thrown, b.linear_velocity.y)
			if thrown_ids.has(b.get_instance_id()):
				continue
			thrown_ids [b.get_instance_id()] = true
			var near:= ""
			var best:= 1000000000.0
			for s: RigidBody3D in sweeps:
				var d:= s.global_position.distance_to(b.global_position)
				if d < best:
					best = d
					near = "%.2f m from a sweep at %.1f m/s (%s)" % [d,
						s.linear_velocity.length(), _describe(s)]
			if thrown_ids.size() <= 60:
				print("    tick %3d  UP %5.1f m/s  %s  |  %s" % [tick, b.linear_velocity.y,
					_describe(b), near if near != "" else "no sweep this tick"])

				for o: RigidBody3D in bodies:
					if o == b or not is_instance_valid(o) or not o.is_inside_tree():
						continue
					if o.global_position.distance_to(b.global_position) < 0.8 and o.linear_velocity.length() > 4.0:
						print("             beside it: %s" % _describe(o))
	print("FORKBELT: %s: %d thrown up over %.0f m/s (fastest rise %.1f), %d sweeps; fastest anything %.1f m/s at tick %d: %s"
		% [label, thrown_ids.size(), RISE, top_thrown, swept_ids.size(), speed, speed_at, what])


func _describe(b: RigidBody3D) -> String:
	var kind:= "strand"
	if b is HayTuft:
		kind = "tuft(%d)" % (b as HayTuft).strands
	elif b is HayWad:
		kind = "wad"
	var flags:= PackedStringArray()
	if b.freeze:
		flags.append("frozen")
	if BeltPath.is_rider(b):
		flags.append("rider")
	if b is not HayTuft and b is not HayWad and not (b.collision_mask & Cfg.L_STRAND):
		flags.append("blind")
	if b.has_meta(LiveStrandManager.META_GLIDE):
		flags.append("gliding")
	if b is HayTuft and (b as HayTuft)._emerging > 0.0:
		flags.append("emerging")
	return "%s %s at %v v=%v" % [kind, " ".join(flags), b.global_position, b.linear_velocity]


func _fill_pan(rig: Shovel, count: int) -> Array [RigidBody3D]:
	var made: Array [RigidBody3D] = []
	var at:= rig._hold_centre()
	for i in count:
		var jitter:= Vector3(_rng.randf_range(-0.05, 0.05),
			_rng.randf_range(0.01, 0.07), _rng.randf_range(-0.07, 0.07))
		var b:= _live.spawn(at + jitter, StrandFactory.random_strand_basis(_rng),
			Vector3.ZERO, StrandFactory.random_tint(_rng))
		if b != null:
			made.append(b)
	return made


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
