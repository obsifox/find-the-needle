class_name DevWyeProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 30


const BURSTS:= 6
const PER_BURST:= 40
const BURST_SECONDS:= 1.2


const WATCH_SECONDS:= 6.0


const OVERLAP:= Cfg.STRAND_THICK * 2.0
const REACH:= 2.4

var _rng:= RandomNumberGenerator.new()

var _worst:= 0
var _worst_note:= ""


func run() -> void:
	_rng.seed = 20260823
	for i in 40:
		await get_tree().process_frame
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	player.global_position = Vector3(-9.0, 0.4, 0.0)
	GameState.add_money(20000.0)
	for i in SETTLE:
		await get_tree().process_frame

	await _splitter(deck_y)
	world.builds.clear()
	for i in SETTLE * 2:
		await get_tree().physics_frame
	await _joiner(deck_y)
	get_tree().quit(0)


func _splitter(deck_y: float) -> void:
	print("\n=== splitter under load ===")
	var at:= Vector3(-13.0, deck_y, -4.0)
	var mod: ConveyorSplitter = world.builds.add_splitter(at, 0.0)
	var feed: Conveyor = world.builds.add_conveyor(mod.port_in() - Vector3(0, 0, 5.0), mod.port_in())


	var reach:= { ConveyorSplitter.LEFT: 1.4, ConveyorSplitter.RIGHT: 4.0 }
	for side in ConveyorSplitter.SIDES:
		var mouth: Vector3 = mod.port(side)
		var dir:= (mouth - at).normalized()
		world.builds.add_conveyor(mouth, mouth + dir * float(reach [side]))
	for i in SETTLE:
		await get_tree().physics_frame
	await _wads(mod, feed, mod.port_in() - Vector3(0, 0, 2.0), Vector3.BACK,
		[mod.port_left(), mod.port_right()])
	await _load(mod.port_in() - Vector3(0, 0, 4.6), Vector3.BACK, mod, mod.routes())
	_report(mod, mod.routes())


func _joiner(deck_y: float) -> void:
	print("\n=== joiner under load ===")
	var at:= Vector3(-13.0, deck_y, -4.0)
	var mod: ConveyorJoiner = world.builds.add_joiner(at, 0.0)
	var feeds:= { }
	for side in ConveyorJoiner.SIDES:
		var mouth: Vector3 = mod.port(side)
		feeds [side] = world.builds.add_conveyor(mouth - mod.arm_travel(side) * 5.0, mouth)
	world.builds.add_conveyor(mod.port_out(), mod.port_out() + mod.forward() * 1.6)
	for i in SETTLE:
		await get_tree().physics_frame
	await _wads(mod, feeds [ConveyorJoiner.LEFT] as Conveyor, mod.port(ConveyorJoiner.LEFT)
		- mod.arm_travel(ConveyorJoiner.LEFT) * 2.0,
		mod.arm_travel(ConveyorJoiner.LEFT), [mod.port_out()])
	await _load(mod.port(ConveyorJoiner.LEFT)
		- mod.arm_travel(ConveyorJoiner.LEFT) * 4.6,
		mod.arm_travel(ConveyorJoiner.LEFT), mod, mod.paths(),
		mod.port(ConveyorJoiner.RIGHT) - mod.arm_travel(ConveyorJoiner.RIGHT) * 4.6,
		mod.arm_travel(ConveyorJoiner.RIGHT))
	_report(mod, mod.paths())


func _load(head_a: Vector3, dir_a: Vector3, mod: Node3D, paths: Array [BeltPath],
		head_b = null, dir_b = null) -> void:
	var ticks:= int(BURST_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	for burst in BURSTS:
		_spill(head_a, dir_a)
		if head_b != null:
			_spill(head_b, dir_b)
		for i in ticks:
			await get_tree().physics_frame
			_sample(mod, paths)
	var watch:= int(WATCH_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	for i in watch:
		await get_tree().physics_frame
		_sample(mod, paths)


func _spill(at: Vector3, along: Vector3) -> void:
	var across:= Vector3.UP.cross(along).normalized()
	for i in PER_BURST:
		var p:= at + along * _rng.randf_range(0.0, 1.2) + across * _rng.randf_range(-0.25, 0.25) + Vector3.UP * 0.25
		world.live.spawn(p, StrandFactory.random_strand_basis(_rng), Vector3.ZERO,
			Cfg.COL_HAY_LIGHT)


func _sample(mod: Node3D, paths: Array [BeltPath]) -> void:
	var pairs:= 0
	var note:= ""
	for i in paths.size():
		for j in range(i + 1, paths.size()):
			var on_j:= paths [j].load_marks()
			for a in paths [i].load_marks():
				for b in on_j:
					var d:= (a ["pos"] as Vector3).distance_to(b ["pos"] as Vector3)
					if d > OVERLAP:
						continue
					pairs += 1
					if note == "":
						var local: Vector3 = mod.global_transform.affine_inverse() * (a ["pos"] as Vector3)
						note = "%s over %s at x=%+.2f z=%+.2f, %.3f m apart" % [
							paths [i].name, paths [j].name, local.x, local.z, d]
	if pairs > _worst:
		_worst = pairs
		_worst_note = note


func _wads(mod: Node3D, feed: Conveyor, at: Vector3, along: Vector3, exits: Array) -> void:
	print("  -- wads --")


	var caught_by:= { }
	var mod_paths: Array = []
	if mod.has_method("routes"):
		mod_paths = mod.call("routes")
	elif mod.has_method("paths"):
		mod_paths = mod.call("paths")
	for path in mod_paths:
		var named: String = (path as BeltPath).name
		caught_by [named] = 0
		(path as BeltPath).caught.connect(func(b: RigidBody3D) -> void:
			if b.collision_layer & Cfg.L_PROP:
				caught_by [named] = int(caught_by [named]) + 1)
		(path as BeltPath).caught_record.connect(func(_seq: int, _kind: int, _strands: int) -> void:
			caught_by [named] = int(caught_by [named]) + 1)
	var seqs: Array [int] = []
	var note_seq:= func(b: RigidBody3D) -> void:
		if b is HayWad:
			seqs.append(feed.run.last_seq)
	feed.caught.connect(note_seq)
	var fed: Array [Node3D] = []
	for i in 8:
		var p:= at + along * (i * 0.6) + Vector3.UP * 0.35
		var wad: Carryable = world.props.spawn("hay_wad",
			Transform3D(Basis.IDENTITY, p))
		if wad != null:
			fed.append(wad)
		for k in int(0.9 / maxf(get_physics_process_delta_time(), 1e-06)):
			await get_tree().physics_frame
	var rode_low:= INF
	var rode_high:= - INF
	for i in int(9.0 / maxf(get_physics_process_delta_time(), 1e-06)):
		await get_tree().physics_frame
		for seq in seqs:
			var where:= BeltPath.record_where(seq)
			if where.is_empty():
				continue
			var over: float = (where ["pose"] as Transform3D).origin.y - mod.global_position.y
			rode_low = minf(rode_low, over)
			rode_high = maxf(rode_high, over)
	feed.caught.disconnect(note_seq)
	if rode_high > - INF:
		print("    carried between %+.3f and %+.3f m over the deck plane"
			% [rode_low, rode_high])
	var through:= 0
	var stuck:= 0


	var by_exit:= { }
	var places: Array = []
	for seq in seqs:
		var where:= BeltPath.record_where(seq)
		if not where.is_empty():
			places.append({ "at": (where ["pose"] as Transform3D).origin, "rec": true, "body": null })
	for wad in fed:
		if is_instance_valid(wad) and wad.is_inside_tree():
			places.append({ "at": wad.global_position, "rec": false, "body": wad })
	for place: Dictionary in places:
		var here: Vector3 = place ["at"]


		var out:= false
		for mouth: Vector3 in exits:
			var leg:= (mouth - mod.global_position)
			if (here - mod.global_position).dot(leg.normalized()) >= leg.length() - 0.2:
				out = true
				var key:= "x%+.1f z%+.1f" % [leg.x, leg.z]
				by_exit [key] = int(by_exit.get(key, 0)) + 1
		if out:
			through += 1
		elif here.distance_to(mod.global_position) < Cfg.SPLITTER_PORT_R + 0.3:
			stuck += 1
			var local: Vector3 = mod.global_transform.affine_inverse() * here
			if bool(place ["rec"]):
				print("    stuck at x=%+.2f z=%+.2f as a record" % [local.x, local.z])
			else:
				var wad:= place ["body"] as RigidBody3D
				print("    stuck at x=%+.2f z=%+.2f, |v|=%.2f  rider=%s frozen=%s"
					% [local.x, local.z, wad.linear_velocity.length(),
						"yes" if BeltPath.is_rider(wad) else "no",
						"yes" if wad.freeze else "no"])
	print("    %d of %d wads crossed the machine, %d still on it (%d followed as records)"
		% [through, fed.size(), stuck, seqs.size()])
	for key: String in by_exit:
		print("      %d left by the mouth at %s" % [int(by_exit [key]), key])
	for key: String in caught_by:
		print("      %s took %d of them aboard" % [key, int(caught_by [key])])


	for seq in seqs:
		var where:= BeltPath.record_where(seq)
		if where.is_empty():
			continue
		var over: float = (where ["pose"] as Transform3D).origin.y - mod.global_position.y
		print("    a carried wad rides %+.3f m over the deck" % over)
		break


func _report(mod: Node3D, paths: Array [BeltPath]) -> void:
	var inv:= mod.global_transform.affine_inverse()
	var riding:= 0
	for p in paths:
		riding += p.riders().size() + p.run.count()
	var loose:= 0
	var asleep:= 0
	var grid:= { }
	for b in world.live._active:
		if not is_instance_valid(b) or not b.is_inside_tree() or BeltPath.is_rider(b):
			continue
		var local: Vector3 = inv * b.global_position
		if Vector2(local.x, local.z).length() > REACH:
			continue
		loose += 1
		if b.sleeping:
			asleep += 1
		var key:= Vector2i(int(round(local.x / 0.25)), int(round(local.z / 0.25)))
		grid [key] = int(grid.get(key, 0)) + 1
	print("  %d riding the module, %d loose within %.1f m of it (%d asleep)"
		% [riding, loose, REACH, asleep])
	print("  worst cross-path overlap: %d pairs%s"
		% [_worst, ("  --  " + _worst_note) if _worst_note != "" else ""])
	var cells:= int(REACH / 0.25)
	print("  loose hay (module +X right, +Z down, one cell 0.25 m):")
	for z in range(- cells, cells + 1):
		var line:= "    "
		for x in range(- cells, cells + 1):
			var n: int = int(grid.get(Vector2i(x, z), 0))
			line += "." if n == 0 else ("%d" % mini(n, 9))
		print(line)
	_worst = 0
	_worst_note = ""
