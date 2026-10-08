class_name DevDismantleCrashProbe
extends Node


const SETTLE:= 30

var world: Node3D
var player: Player

var _log: FileAccess
var _worst_ms:= 0.0
var _last_us:= 0


func run(rounds: int, save_copy: String = "") -> void:
	world.block_save = true
	Cfg.build_fx = true
	GameState.add_money(10000000.0)
	for i in 40:
		await get_tree().process_frame
	if save_copy == "generator":
		await _generator_rounds()
		get_tree().quit(0)
		return
	if save_copy.begins_with("lightpair"):
		await _light_pair(save_copy == "lightpairraw")
		get_tree().quit(0)
		return
	if save_copy != "":
		await _tear_down_copy(save_copy)
		get_tree().quit(0)
		return
	player.global_position = Vector3(0.0, 0.4, 12.0)
	for r in rounds:
		_say("=== round %d of %d ===" % [r + 1, rounds])
		var yard:= await _build_yard()
		await _feed(yard, 8.0 if r % 2 == 0 else 3.0)
		await _tear_down(yard, r)
		for i in SETTLE:
			await get_tree().process_frame
	_say("[dismantlecrash] survived %d rounds" % rounds)
	get_tree().quit(0)


func _process(_delta: float) -> void:
	var now:= Time.get_ticks_usec()
	if _last_us != 0:
		_worst_ms = maxf(_worst_ms, float(now - _last_us) / 1000.0)
	_last_us = now


func _say(line: String) -> void:
	print(line)
	if _log == null:
		_log = FileAccess.open("user://dismantlecrash.log", FileAccess.WRITE)
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _light_pair(raw: bool) -> void:
	var at:= Vector3(0.0, 1.0, 8.0)
	for round_i in 30:
		var light:= OmniLight3D.new()
		light.omni_range = 6.0
		light.light_energy = 2.0
		world.add_child(light)
		light.global_position = at + Vector3(0.0, 1.0, 0.0)
		var meshes: Array [MeshInstance3D] = []
		for k in 8:
			var mi:= MeshInstance3D.new()
			mi.mesh = BoxMesh.new()
			world.add_child(mi)
			mi.global_position = at + Vector3(float(k) * 0.4 - 1.6, 0.0, 0.0)
			meshes.append(mi)

		for i in 4:
			await get_tree().process_frame
		for mi in meshes:
			if raw:
				mi.layers = 0
			else:


				(BeltBatch as Script).call("set_layers", mi, 0)
		for i in 2:
			await get_tree().process_frame
		for mi in meshes:
			mi.queue_free()
		for i in 2:
			await get_tree().process_frame

		light.global_position += Vector3(0.3, 0.0, 0.0)
		for i in 2:
			await get_tree().process_frame
		light.queue_free()
		for i in 2:
			await get_tree().process_frame
	_say("[dismantlecrash] lightpair%s survived 30 rounds" % (" raw" if raw else ""))


func _generator_rounds() -> void:
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build
	player.global_position = Vector3(0.0, 0.4, 14.0)
	for round_i in 12:
		var at:= Vector3(-6.0 + float(round_i % 4) * 4.0, 0.0, 4.0 + float(round_i / 4) * 4.0)
		var caught: Array [Node] = []
		var catch:= func(n: Node) -> void: caught.append(n)
		builds.child_entered_tree.connect(catch)
		var gen: HayGenerator = builds.add_generator(at, 0.0)
		var feed:= builds.add_conveyor(gen.port_in() + Vector3(0.0, 0.0, -4.0), gen.port_in(),
			992000 + round_i)
		builds.child_entered_tree.disconnect(catch)
		tool.show_built(caught)
		for i in 3:
			await get_tree().process_frame
		gen.fuel = 1000.0


		if round_i % 2 == 0:
			var fuse:= 900
			while fuse > 0 and not get_tree().root.find_children("*", "BuildFx", true, false).is_empty():
				fuse -= 1
				await get_tree().process_frame
			for i in 30:
				await get_tree().process_frame
		else:
			for i in 25 + round_i:
				await get_tree().process_frame


		var held:= 0
		if BeltBatch.instance != null:
			held = BeltBatch.instance._records.size()
		_say("  generator %d burning=%s, batch holding %d, dismantle"
			% [round_i, gen.is_burning(), held])
		tool.dismantle(gen)
		for i in 30:
			await get_tree().process_frame
		if is_instance_valid(feed) and not feed.is_queued_for_deletion():
			tool.dismantle(feed)
		for i in 30:
			await get_tree().process_frame
	_say("[dismantlecrash] generator survived 12 rounds")


func _tear_down_copy(path: String) -> void:
	var f:= SaveManager.open_for_read(path)
	if f == null:
		_say("[dismantlecrash] cannot open %s" % path)
		return
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
	GameState.add_money(100000000.0)
	var where: Transform3D = d.get("player", Transform3D.IDENTITY)
	player.global_position = where.origin
	for i in 240:
		await get_tree().process_frame
	var builds: BuildManager = world.builds
	var all: Array [Node3D] = builds.all_buildings()
	_say("[dismantlecrash] %s: %d buildings, %d runs, %d props"
		% [path.get_file(), all.size(), world.builds.conveyors.size(), world.props.items.size()])
	var tool: BuildTool = player.build
	var k:= 0
	for target in all:
		if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_inside_tree():
			continue
		k += 1
		var label:= "%d %s at %s" % [k, BuildTool._report_name(target),
			target.global_position.snappedf(0.1)]
		tool._wreck = target
		tool._wreck_time = BuildTool.DISMANTLE_HOLD * 0.9
		tool._tick_wreck_glow()
		await get_tree().process_frame
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			tool._wreck = null
			continue
		_say("  dismantle %s" % label)
		_worst_ms = 0.0
		tool.dismantle(target)
		tool._wreck = null
		tool._tick_wreck_glow()
		for i in (1 if k % 3 != 0 else 12):
			await get_tree().process_frame
		_say("    ok, worst frame %.1f ms" % _worst_ms)
	for i in 240:
		await get_tree().process_frame
	_say("[dismantlecrash] yard down: %d buildings left" % world.builds.all_buildings().size())


func _build_yard() -> Dictionary:
	var builds: BuildManager = world.builds
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var yard:= { }
	var tool: BuildTool = player.build
	var caught: Array [Node] = []
	var catch:= func(n: Node) -> void: caught.append(n)
	builds.child_entered_tree.connect(catch)

	var pulper_l: HayPulper = builds.add_pulper(Vector3(-3.5, deck_y, 2.0), 0.0)
	var pulper_r: HayPulper = builds.add_pulper(Vector3(3.5, deck_y, 2.0), 0.0)
	var splitter: ConveyorUSplitter = builds.add_u_splitter(Vector3(0.0, deck_y, -9.0), 0.0)

	var feed_to:= splitter.port_in()
	var feeder:= builds.add_conveyor(feed_to - splitter.forward() * 5.0, feed_to, 991001)


	var arms: Array = []
	var line:= 991010
	for pair in [[splitter.port_left(), pulper_l], [splitter.port_right(), pulper_r]]:
		var from: Vector3 = pair [0]
		var into: HayPulper = pair [1]
		var mid:= Vector3(into.port_in().x, from.y, from.z + 2.5)
		var a:= builds.add_conveyor(from, mid, line)
		var b:= builds.add_conveyor(mid, into.port_in(), line)
		arms.append(a)
		arms.append(b)
		line += 1
	var pumps: Array = []
	var mains: Array = []
	for p: HayPulper in [pulper_l, pulper_r]:
		var side:= -1.0 if p == pulper_l else 1.0
		var pump: BoreholePump = builds.add_borehole(
			Vector3(p.global_position.x + side * 6.0, 0.0, 6.0), 0.0)
		pumps.append(pump)
		if pump != null:
			mains.append(builds.add_water_main(pump.water_port(), p.water_port()))
	builds.child_entered_tree.disconnect(catch)
	tool.show_built(caught)
	for i in SETTLE:
		await get_tree().physics_frame
	yard ["pulpers"] = [pulper_l, pulper_r]
	yard ["splitter"] = splitter
	yard ["feeder"] = feeder
	yard ["arms"] = arms
	yard ["pumps"] = pumps
	yard ["mains"] = mains
	_say("built: pulpers %s %s, splitter %s, feeder %s, arms %d, pumps %d, mains %d, wet %s"
		% [pulper_l != null, pulper_r != null, splitter != null, feeder != null,
			arms.filter(func(x: Variant) -> bool: return x != null).size(),
			pumps.filter(func(x: Variant) -> bool: return x != null).size(),
			mains.filter(func(x: Variant) -> bool: return x != null).size(),
			[pulper_l.water if pulper_l else -1.0, pulper_r.water if pulper_r else -1.0]])
	return yard


func _feed(yard: Dictionary, seconds: float) -> void:
	var feeder: Conveyor = yard ["feeder"]
	if feeder == null:
		return
	var rng:= RandomNumberGenerator.new()
	rng.seed = 991
	var props: PropManager = world.props
	var t:= 0.0
	var k:= 0
	while t < seconds:
		var at:= feeder.a + Vector3(rng.randf_range(-0.2, 0.2), 0.6, 0.3)
		if k % 3 == 0:
			props.spawn("hay_wad", Transform3D(Basis(), at))
		else:
			props.spawn("hay_tuft", Transform3D(Basis(), at), { "strands": 40 })
		for s in 3:
			world.live.spawn(at + Vector3(0.0, 0.3, 0.2 * s),
				StrandFactory.random_strand_basis(rng), Vector3.ZERO, Cfg.COL_HAY_LIGHT)
		k += 1
		for i in 20:
			await get_tree().process_frame
		t += 20.0 / 60.0
	var riding:= 0
	for p in BeltPath._live:
		riding += (p as BeltPath)._riders.size()
	var p0: HayPulper = yard ["pulpers"] [0]
	_say("fed %d loads, %d riders, pulper stored %d" % [k, riding, p0.stored if p0 else -1])


func _tear_down(yard: Dictionary, round_i: int) -> void:
	var order: Array = []
	var feeder: Variant = yard ["feeder"]
	var splitter: Variant = yard ["splitter"]
	var arms: Array = yard ["arms"]
	var pulpers: Array = yard ["pulpers"]
	var pumps: Array = yard ["pumps"]
	var mains: Array = yard ["mains"]
	match round_i % 5:
		0:
			order = [feeder, splitter] + arms + pulpers + mains + pumps
		1:
			order = [splitter] + pulpers + arms + [feeder] + pumps + mains
		2:
			order = pulpers + [splitter] + pumps + arms + [feeder] + mains
		3:
			order = mains + pumps + pulpers + arms + [splitter, feeder]
		4:
			order = arms.duplicate()
			order.reverse()
			order += pulpers + [feeder, splitter] + mains + pumps
	var tool: BuildTool = player.build
	for n: Variant in order:
		if n == null or not is_instance_valid(n) or (n as Node).is_queued_for_deletion():
			continue
		var target:= n as Node3D
		var label:= "%s at %s" % [BuildTool._report_name(target), target.global_position.snappedf(0.1)]

		tool._wreck = target
		tool._wreck_time = BuildTool.DISMANTLE_HOLD * 0.9
		tool._tick_wreck_glow()
		for i in 3:
			await get_tree().process_frame
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			tool._wreck = null
			continue
		_say("  dismantle %s" % label)
		_worst_ms = 0.0
		tool.dismantle(target)
		tool._wreck = null
		tool._tick_wreck_glow()


		var wait:= 1 if round_i % 2 == 0 else 20
		for i in wait:
			await get_tree().process_frame
		_say("    ok, worst frame %.1f ms" % _worst_ms)
	for i in 180:
		await get_tree().process_frame
	_say("round %d down: %d runs, %d buildings left" % [round_i + 1,
		world.builds.conveyors.size(), world.builds.all_buildings().size()])
