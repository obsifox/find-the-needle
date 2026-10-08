class_name DevRipProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 20

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(10.5, 0.4, 6.0)
	GameState.add_money(200000.0)
	for i in SETTLE:
		await get_tree().process_frame

	await _check_blocks_declare()
	await _check_rip()
	await _check_wad_rip()
	await _check_roll_rip()
	await _check_hold()
	await _check_press()
	await _check_mill()
	await _check_wrapper()
	await _check_scanner()
	await _check_save()

	print("\n=== rip probe: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _check_blocks_declare() -> void:
	print("\n=== what can be ripped ===")
	var cases:= {
		"hay_bale": [true, false], "foiled_bale": [true, false],
		"eco_brick": [true, false], "hay_wad": [true, true],
		"paper_roll": [true, false],
		"bucket": [false, false],
	}
	var x:= 12.0
	for id: String in cases:
		var item: Carryable = world.props.spawn(id,
			Transform3D(Basis(), Vector3(x, 1.0, 6.0)))
		if item == null:
			_ok("%s spawns" % id, false)
			continue
		_ok("%s can_rip is %s" % [id, cases [id] [0]], item.can_rip() == cases [id] [0])
		_ok("%s rips_loose is %s" % [id, cases [id] [1]],
			item.rips_loose() == cases [id] [1])


		_ok("%s rips_to_shreds is %s" % [id, id == "paper_roll"],
			item.rips_to_shreds() == (id == "paper_roll"))
		_ok("%s starts with nothing in it" % id, not item.holds_needle())
		world.props.remove(item)
		x += 1.5


func _check_rip() -> void:
	print("\n=== the rip ===")
	var bale:= world.props.spawn("hay_bale",
		Transform3D(Basis(), Vector3(14.0, 1.0, 10.0)), { "strands": 60 }) as HayBale
	if bale == null:
		_ok("bale spawns", false)
		return
	bale.needle_index = 0
	var before: int = world.live.needles.size()
	var sale:= bale.sale_strands()
	var needle: RigidBody3D = world.props.rip(bale)
	for i in SETTLE:
		await get_tree().process_frame
	_ok("the needle falls out", needle != null)
	_ok("it is in the world's needle list", world.live.needles.size() == before + 1)
	var wad:= _nearest_wad(Vector3(14.0, 1.0, 10.0))
	_ok("a wad is left behind", wad != null)
	if wad != null:
		_ok("holding the contents (60)", wad.strands == 60)


		_ok("worth less than the bale was (%.1f < %.1f)" % [wad.sale_strands(), sale],
			wad.sale_strands() < sale)
		world.props.remove(wad)
	if needle != null:
		world.live.consume_needle(needle)


func _check_wad_rip() -> void:
	print("\n=== a wad comes apart too ===")
	var at:= Vector3(16.0, 1.0, 12.0)
	var wad:= world.props.spawn("hay_wad", Transform3D(Basis(), at),
		{ "strands": 40 }) as HayWad
	if wad == null:
		_ok("wad spawns", false)
		return
	wad.needle_index = 1
	var before_needles: int = world.live.needles.size()
	var before_active: int = world.live.active_count()
	var before_books:= GameState.hay_total
	var needle: RigidBody3D = world.props.rip(wad)
	for i in 4:
		await get_tree().process_frame
	_ok("the wad is gone", not is_instance_valid(wad))


	_ok("nothing is left standing in its place", _nearest_wad(at) == null)
	var made: int = world.live.active_count() - before_active
	_ok("its 40 strands are lying there (%d)" % made, made == 40)


	_ok("the pile's books did not move (%+.1f)" % (GameState.hay_total - before_books),
		is_equal_approx(GameState.hay_total, before_books))
	_ok("the needle falls out of a wad too", needle != null)
	_ok("...and into the world's needle list",
		world.live.needles.size() == before_needles + 1)
	if needle != null:
		world.live.consume_needle(needle)


	for body in world.live.claim_hay_near(at, 4.0, 200):
		world.live.consume(body)


func _check_roll_rip() -> void:
	print("\n=== a paper roll opens into nothing ===")
	var at:= Vector3(18.0, 1.0, 8.0)
	var roll:= world.props.spawn("paper_roll", Transform3D(Basis(), at),
		{ "strands": 90 }) as PaperRoll
	if roll == null:
		_ok("roll spawns", false)
		return
	roll.needle_index = 2


	_ok("the prompt does not promise the hay back (%s)" % roll.rip_label(),
		roll.rip_label() != "Rip apart the %s" % roll.display_name.to_lower())
	var before_needles: int = world.live.needles.size()
	var before_active: int = world.live.active_count()
	var before_books:= GameState.hay_total
	var needle: RigidBody3D = world.props.rip(roll)
	for i in SETTLE:
		await get_tree().process_frame
	_ok("the roll is gone", not is_instance_valid(roll))
	_ok("nothing is standing in its place", _nearest_wad(at) == null)
	var made: int = world.live.active_count() - before_active
	_ok("and no loose hay was spilled (%d)" % made, made == 0)
	_ok("the pile's books did not move (%+.1f)" % (GameState.hay_total - before_books),
		is_equal_approx(GameState.hay_total, before_books))

	_ok("the needle still falls out", needle != null)
	_ok("...and into the world's needle list",
		world.live.needles.size() == before_needles + 1)
	if needle != null:
		world.live.consume_needle(needle)


	var burst:= _find_shreds()
	_ok("a shred burst was left where it stood", burst != null)
	if burst != null:
		_ok("...standing at the roll", burst.global_position.distance_to(at) < 1.0)


		var id:= burst.get_instance_id()
		var still_there:= func() -> bool:
			return instance_from_id(id) == null
		var gone:= await _wait_until(still_there)
		_ok("...and it clears itself up", gone)


func _find_shreds() -> ShredBurst:
	for child in world.props.get_children():
		var fx:= child as ShredBurst
		if fx != null:
			return fx
	return null


func _check_hold() -> void:
	print("\n=== holding the key ===")
	var bale:= world.props.spawn("hay_bale",
		Transform3D(Basis(), player.global_position + Vector3(0.0, 1.0, 1.2)),
		{ "strands": 60 }) as HayBale
	if bale == null or player.carry == null:
		_ok("a bale to hold", false)
		return
	player.carry.take(bale)
	for i in 4:
		await get_tree().process_frame
	_ok("the bale is in the hands", player.carry.held() == bale)
	_ok("and X is offered on it", player.carry.rip_target() == bale)
	_ok("with no hold running yet", player.carry.rip_progress() < 0.0)


	_press(true)
	var started:= await _wait_until(func() -> bool:
		return player.carry.rip_progress() >= 0.0)
	_ok("the key starts a hold", started)
	var half:= await _wait_until(func() -> bool:
		return player.carry.rip_progress() > 0.35)
	_ok("the meter fills while the key is held", half)
	_ok("...and the bale is still whole part-way in", is_instance_valid(bale))
	_ok("...and the readout under the crosshair is up", _meter_visible())
	_press(false)
	for i in 4:
		await get_tree().process_frame
	_ok("letting go ends the hold", player.carry.rip_progress() < 0.0)
	_ok("...and puts the readout away", not _meter_visible())
	_ok("...and the bale survives", is_instance_valid(bale))

	_press(true)
	var gone:= await _wait_until(func() -> bool:
		return not is_instance_valid(bale))
	_press(false)
	for i in SETTLE:
		await get_tree().process_frame
	_ok("held to the end, the bale comes apart", gone)
	_ok("...and the hold is over", player.carry.rip_progress() < 0.0)
	_ok("...and the hands are empty", not player.carry.is_carrying())
	var wad:= _nearest_wad(player.global_position)
	_ok("...leaving a wad of its contents", wad != null and wad.strands == 60)
	if wad != null:
		world.props.remove(wad)


func _check_press() -> void:
	print("\n=== the press bales a needle ===")
	var press:= HayCompressor.new()
	press.live = world.live
	press.props = world.props
	world.add_child(press)
	press.setup(Vector3(30.0, 0.0, 6.0), 0.0)
	for i in SETTLE:
		await get_tree().process_frame
	press.pending_needles = PackedInt32Array([3, 7, 11])
	var got: Array [int] = []
	for i in 3:
		press.stored = 10000
		press._batch = 60
		press._release_bale()
		for f in 4:
			await get_tree().process_frame
		var bale:= _nearest_bale(press.global_position)
		if bale == null:
			_ok("bale %d is released" % i, false)
			continue
		got.append(bale.needle_index)
		world.props.remove(bale)
	_ok("one needle per bale, in order: %s" % str(got), got == [3, 7, 11])
	_ok("the press is empty afterwards", press.pending_needles.is_empty())
	press.queue_free()
	for i in 4:
		await get_tree().process_frame


func _check_mill() -> void:
	print("\n=== the mill bricks a needle ===")
	var mill:= HayPelletizer.new()
	mill.live = world.live
	mill.props = world.props
	world.add_child(mill)
	mill.setup(Vector3(40.0, 0.0, 6.0), 0.0)
	for i in SETTLE:
		await get_tree().process_frame
	mill.pending_needles = PackedInt32Array([5])
	mill._batch = 45
	mill._throw_brick()
	for i in SETTLE:
		await get_tree().process_frame
	var brick:= _nearest_brick(mill.global_position)
	_ok("a brick is discharged", brick != null)
	if brick != null:
		_ok("with the needle in it", brick.needle_index == 5)
		world.props.remove(brick)
	_ok("the mill is empty afterwards", mill.pending_needles.is_empty())
	mill.queue_free()
	for i in 4:
		await get_tree().process_frame


func _check_wrapper() -> void:
	print("\n=== the wrapper carries it through ===")
	var wrap:= HayWrapper.new()
	wrap.props = world.props
	world.add_child(wrap)
	wrap.setup(Vector3(50.0, 0.0, 6.0), 0.0)
	for i in SETTLE:
		await get_tree().process_frame
	wrap.queued = [60]
	wrap.queued_needles = [9]
	wrap._start_wrap()
	wrap._release_product()
	for i in SETTLE:
		await get_tree().process_frame
	var foiled:= _nearest_foiled(wrap.global_position)
	_ok("a foiled bale comes out", foiled != null)
	if foiled != null:
		_ok("carrying the count (60)", foiled.strands == 60)
		_ok("carrying the needle (9)", foiled.needle_index == 9)
		world.props.remove(foiled)
	wrap.queue_free()
	for i in 4:
		await get_tree().process_frame


func _check_scanner() -> void:
	print("\n=== every scanner looks through a block ===")
	var top:= Cfg.SCANNER_TIERS.size() - 1


	var mk1:= HaystackScanner.new()
	mk1.live = world.live
	mk1.props = world.props
	mk1.setup(Vector3(60.0, 0.0, 6.0), 0.0, 0)
	world.add_child(mk1)
	var best:= HaystackScanner.new()
	best.live = world.live
	best.props = world.props
	best.setup(Vector3(70.0, 0.0, 6.0), 0.0, top)
	world.add_child(best)
	for i in SETTLE:
		await get_tree().process_frame

	var ride:= world.props.spawn("hay_bale",
		Transform3D(Basis(), mk1.global_position + Vector3.UP), { "strands": 60 }) as HayBale
	ride.needle_index = 2
	mk1._take_block(ride)
	_ok("MK I takes the block off the deck", mk1.has_block())


	for i in 4:
		await get_tree().process_frame
	_ok("...and the block is out of the world", not is_instance_valid(ride))

	var eaten:= world.props.spawn("hay_bale",
		Transform3D(Basis(), best.global_position + Vector3.UP), { "strands": 60 }) as HayBale
	eaten.needle_index = 2
	best._take_block(eaten)
	_ok("the top tier takes it too", best.has_block())
	_ok("and closes its own deck while it holds one",
		best._belt == null or best._belt.is_blocked())


	var second:= world.props.spawn("hay_bale",
		Transform3D(Basis(), best.global_position + Vector3.UP * 1.4), { "strands": 40 }) as HayBale
	second.needle_index = 5
	best._take_block(second)
	_ok("a second block arriving mid-hold is taken, not passed",
		best.blocks.size() == 2)
	for i in 4:
		await get_tree().process_frame
	_ok("...and it is out of the world too", not is_instance_valid(second))

	var banked:= best.banked.size()


	best.blocks [0] ["left"] = 0.0
	for i in 60:
		await get_tree().process_frame
		if best.blocks.size() < 2:
			break
	_ok("the first block is put back down", best.blocks.size() == 1)
	_ok("the needle is banked to the drawer", best.banked.size() == banked + 1)


	var out:= _nearest_bale(best.global_position)
	for i in 120:
		if out != null:
			break
		await get_tree().process_frame
		out = _nearest_bale(best.global_position)
	_ok("what comes out is a bale, not a wad", out != null)
	if out != null:
		_ok("with its count intact (60)", out.strands == 60)
		_ok("and nothing left inside it", not out.holds_needle())
		world.props.remove(out)

	best.blocks [0] ["left"] = 0.0
	for i in 60:
		await get_tree().process_frame
		if not best.has_block():
			break
	_ok("the queued block follows it out", not best.has_block())
	_ok("with its needle banked as well", best.banked.size() == banked + 2)
	var trailer:= _nearest_bale(best.global_position)
	for i in 120:
		if trailer != null:
			break
		await get_tree().process_frame
		trailer = _nearest_bale(best.global_position)
	if trailer != null:
		_ok("and its own count intact (40)", trailer.strands == 40)
		world.props.remove(trailer)
	mk1.queue_free()
	best.queue_free()
	for i in 4:
		await get_tree().process_frame


func _check_save() -> void:
	print("\n=== across a save ===")
	var bale:= world.props.spawn("hay_bale",
		Transform3D(Basis(), Vector3(16.0, 1.0, 14.0)), { "strands": 60 }) as HayBale
	bale.needle_index = 13
	var rows: Array = world.props.to_array()
	world.props.from_array(rows)
	for i in SETTLE:
		await get_tree().process_frame
	var back:= _nearest_bale(Vector3(16.0, 1.0, 14.0))
	_ok("the bale comes back", back != null)
	if back != null:
		_ok("still holding needle 13", back.needle_index == 13)
		world.props.remove(back)

	var press:= HayCompressor.new()
	press.live = world.live
	press.props = world.props
	world.add_child(press)
	press.setup(Vector3(80.0, 0.0, 6.0), 0.0)
	for i in 4:
		await get_tree().process_frame
	press.pending_needles = PackedInt32Array([4, 6])
	var d: Dictionary = press.to_dict()
	_ok("the press writes its needles", d.has("needles"))
	_ok("both of them", Array(d ["needles"] as PackedInt32Array) == [4, 6])
	press.queue_free()
	for i in 4:
		await get_tree().process_frame


func _press(down: bool) -> void:
	for e in InputMap.action_get_events("dismantle"):
		var key:= e as InputEventKey
		if key == null:
			continue
		var ev:= key.duplicate() as InputEventKey
		ev.pressed = down
		Input.parse_input_event(ev)
		return
	_ok("the dismantle action has a key bound", false)


func _meter_visible() -> bool:
	var hud: Node = world.get("hud")
	if hud == null:
		return false
	var meter: Control = hud.get("_wreck")
	return meter != null and meter.visible


func _wait_until(test: Callable) -> bool:
	var waited:= 0.0
	while waited < 4.0:
		if bool(test.call()):
			return true
		waited += get_process_delta_time()
		await get_tree().process_frame
	return false


func _nearest_wad(at: Vector3) -> HayWad:
	return _nearest(at, "HayWad") as HayWad


func _nearest_bale(at: Vector3) -> HayBale:
	return _nearest(at, "HayBale") as HayBale


func _nearest_foiled(at: Vector3) -> FoiledBale:
	return _nearest(at, "FoiledBale") as FoiledBale


func _nearest_brick(at: Vector3) -> EcoBrick:
	return _nearest(at, "EcoBrick") as EcoBrick


func _nearest(at: Vector3, what: String) -> Carryable:
	var best: Carryable = null
	var near:= INF
	for item in world.props.items:
		if not is_instance_valid(item) or item.get_class() == "":
			continue
		if not item.is_class("RigidBody3D"):
			continue
		var script: Script = item.get_script()
		if script == null or script.get_global_name() != what:
			continue
		var d: float = item.global_position.distance_to(at)
		if d < near:
			near = d
			best = item
	return best


func _ok(what: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("  PASS  %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)
