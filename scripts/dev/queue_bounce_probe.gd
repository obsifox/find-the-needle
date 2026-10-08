class_name DevQueueBounceProbe
extends Node


var world: Node3D
var player: Node3D

const SETTLE:= 40


const FILL_SECONDS:= 24.0

const FILL_EVERY:= 24

const JUDGE_SECONDS:= 3.0
const SIZES:= [20, 60, 120, 200]

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	player.global_position = Vector3(11.0, 0.4, 0.0)
	GameState.add_money(20000.0)
	await _case("flat", Vector3(-6.0, 0.75, -12.5), Vector3(2.0, 0.75, -12.5))
	await _case("climb", Vector3(-6.0, 0.75, -9.0), Vector3(2.0, 2.75, -9.0))
	await _case_shut_intake()
	await _case_short_queue()
	await _case_shut_wye()
	print("\n[queuebounce] %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _case(label: String, a: Vector3, b: Vector3) -> void:
	var belt: Conveyor = world.builds.add_conveyor(a, b)
	if belt == null:
		print("[queuebounce] could not lay the %s run" % label)
		_fails += 1
		return
	for i in SETTLE:
		await get_tree().physics_frame
	var path: BeltPath = belt
	path.set_outlet_held(true)
	var props: PropManager = world.props

	var ticks:= int(FILL_SECONDS / get_physics_process_delta_time())
	for t in ticks:
		if t % FILL_EVERY == 0:
			_set_down(props, path, 0.35, 0.0, 60)
		await get_tree().physics_frame
	print("\n=== %s run, %.1f m, holding %d wads ===" % [label, path.path_length(),
		path.riders_debug().size()])

	var mid:= path.path_length() * 0.5
	for n: int in SIZES:
		var r:= Cfg.WAD_BASE_SIZE.x * Cfg.WAD_COLLIDER_SHRINK * HayWad.scale_for(n) * 0.5
		var toward:= maxf(Cfg.BELT_WIDTH * 0.5 - Cfg.BELT_RAIL_T - r - 0.02, 0.0)
		for side: float in [0.0, toward, - toward]:
			await _judge(props, path, label, n, mid, side)


func _set_down(props: PropManager, path: BeltPath, s: float, side: float,
		strands: int) -> RigidBody3D:
	var basis:= path._basis_at(s)
	var at:= path._point_at(s) + basis.x * side + basis.y * 0.1
	return props.spawn("hay_wad", Transform3D(basis, at), { "strands": strands }) as RigidBody3D


func _judge(props: PropManager, path: BeltPath, label: String, n: int, s: float,
		side: float) -> void:
	var rb:= _set_down(props, path, s, side, n)
	if rb == null:
		print("  [FAIL] %s: could not set down a %d strand wad" % [label, n])
		_fails += 1
		return
	var kicks:= 0
	var last_until:= 0.0
	for t in int(JUDGE_SECONDS / get_physics_process_delta_time()):
		await get_tree().physics_frame
		if not is_instance_valid(rb):
			break
		var until:= float(rb.get_meta(BeltPath.META_QUEUE_BOUNCE, 0.0))
		if until != last_until:
			kicks += 1
			last_until = until
	if not is_instance_valid(rb):
		print("  [FAIL] %s: the %d strand wad was freed" % [label, n])
		_fails += 1
		return
	var at: Dictionary = path._nearest(rb.global_position)
	var off:= rb.global_position - path._point_at(float(at ["s"]))
	var basis:= path._basis_at(float(at ["s"]))
	var across:= absf(off.dot(basis.x))
	var below:= off.dot(basis.y)
	var aboard:= BeltPath.is_rider(rb)
	var clear:= not aboard and (across > Cfg.BELT_WIDTH * 0.5 or below < -0.3)
	print("  %s %s: %3d strands set down %+.2f across, kicked %d, now %.2f across, %.2f %s the deck%s"
		% ["[ok]  " if clear else "[FAIL]", label, n, side, kicks, across, absf(below),
			"below" if below < 0.0 else "above", ", ABOARD" if aboard else ""])
	if not clear:
		_fails += 1


func _case_short_queue() -> void:
	print("\n=== a wad set down on a short queue ===")
	var belt: Conveyor = world.builds.add_conveyor(Vector3(-6.0, 0.75, -3.0), Vector3(2.0, 0.75, -3.0))
	for i in SETTLE:
		await get_tree().physics_frame
	var path: BeltPath = belt
	path.set_outlet_held(true)
	var props: PropManager = world.props
	var dt:= get_physics_process_delta_time()
	for n in 4:
		_set_down(props, path, 0.35, 0.0, 60)
		for t in int(1.5 / dt):
			await get_tree().physics_frame
	for t in int(4.0 / dt):
		await get_tree().physics_frame


	var on_queue:= path.run.s_of(path.run.first() + 1) if path.run.count() > 1 else 0.0
	var heads:= PackedStringArray()
	for i in path.run.count():
		heads.append("%.2f" % path.run.s_of(path.run.first() + i))
	print("  queue records at s %s of %.2f, setting down at %.2f" % [", ".join(heads),
		path.path_length(), on_queue])
	var rb:= _set_down(props, path, on_queue, 0.0, 60)
	var clear_rb:= _set_down(props, path, 1.0, 0.0, 60)
	for t in int(JUDGE_SECONDS / dt):
		await get_tree().physics_frame
	var off:= _off_belt(path, rb)
	print("  %s set down on the queue with room behind it: %s"
		% ["[ok]  " if off else "[FAIL]", "off the belt" if off else "still on it"])
	if not off:
		_fails += 1
	var boarded:= not is_instance_valid(clear_rb) or not clear_rb.is_inside_tree() or BeltPath.is_rider(clear_rb)
	print("  %s set down on clear belt: %s"
		% ["[ok]  " if boarded else "[FAIL]", "taken aboard" if boarded else "not taken"])
	if not boarded:
		_fails += 1


	var count_before:= path.run.count()
	var thrown:= _set_down(props, path, on_queue, 0.0, 60)
	BeltPath.mark_machine_throw(thrown)
	var kicked:= false
	for t in int(JUDGE_SECONDS / dt):
		await get_tree().physics_frame
		if is_instance_valid(thrown) and thrown.has_meta(BeltPath.META_QUEUE_BOUNCE):
			kicked = true
	var joined:= not kicked and (not is_instance_valid(thrown) or not thrown.is_inside_tree() or BeltPath.is_rider(thrown)) and path.run.count() == count_before + 1
	print("  %s machine throw onto the queue: %s, %d records now (%d before)"
		% ["[ok]  " if joined else "[FAIL]", "kicked off" if kicked else "joined the queue"
			if joined else "not taken", path.run.count(), count_before])
	if not joined:
		_fails += 1


func _case_shut_wye() -> void:
	print("\n=== a brick set down on a shut splitter ===")
	var s: ConveyorSplitter = world.builds.add_splitter(Vector3(20.0, 0.75, -20.0), 0.0)
	if s == null:
		print("  [FAIL] could not place a splitter")
		_fails += 1
		return
	for i in SETTLE:
		await get_tree().physics_frame
	var outs: Array [BeltPath] = []
	for side in ConveyorSplitter.SIDES:
		var from:= s.port(side)
		var dir:= (from - s.global_position)
		dir.y = 0.0
		var run: Conveyor = world.builds.add_conveyor(from, from + dir.normalized() * 2.0)
		if run != null:
			run.set_outlet_held(true)
			outs.append(run)
	var back:= s.port_in() - s.global_position
	back.y = 0.0
	var feeder: Conveyor = world.builds.add_conveyor(s.port_in() + back.normalized() * 4.0, s.port_in())
	for i in SETTLE:
		await get_tree().physics_frame
	var props: PropManager = world.props
	var dt:= get_physics_process_delta_time()
	var shut:= false
	for t in int(120.0 / dt):
		if t % 150 == 0 and feeder != null:
			_set_down(props, feeder, 0.35, 0.0, 60)
		await get_tree().physics_frame
		shut = true
		for r in s.routes():
			shut = shut and not r._catching
		if shut:
			break
	print("  both routes shut: %s" % shut)
	if not shut:
		print("  [FAIL] could not shut the splitter")
		_fails += 1
		return
	var at:= s.global_position + Vector3.UP * 0.9


	var boarded:= 0
	var refused:= 0
	BeltPath.debug_props = true
	for r in s.routes():
		var rows:= PackedStringArray()
		for i in r.run.count():
			rows.append("%.2f" % r.run.s_of(r.run.first() + i))
		print("  route %s len %.2f records at %s" % [r.name, r.path_length(), ", ".join(rows)])
	for n in 12:
		var brick:= props.spawn("eco_brick", Transform3D(Basis(), at),
			{ "strands": Cfg.PELLETIZER_BRICK_STRANDS }) as RigidBody3D
		var kicks:= 0
		var last_until:= 0.0
		for t in int(JUDGE_SECONDS / dt):
			await get_tree().physics_frame
			if not is_instance_valid(brick) or not brick.is_inside_tree():
				break
			var until:= float(brick.get_meta(BeltPath.META_QUEUE_BOUNCE, 0.0))
			if until != last_until:
				kicks += 1
				last_until = until
		if not is_instance_valid(brick) or not brick.is_inside_tree():
			boarded += 1
			continue
		print("    refused because: %s" % BeltPath.debug_last_refusal.get(brick.get_instance_id(), "?"))
		var clear:= brick.global_position.y < s.global_position.y - 0.3
		var ok:= kicks == 1 and clear
		print("  %s brick %d refused: kicked %d time(s), now %s (splitter at %s)"
			% ["[ok]  " if ok else "[FAIL]", n, kicks, _v3(brick.global_position),
				_v3(s.global_position)])
		if not ok:
			_fails += 1
		refused += 1
		props.remove(brick)
		if refused >= 2:
			break
	var took:= boarded > 0
	print("  %s the shut splitter took %d brick(s) while it had room"
		% ["[ok]  " if took else "[FAIL]", boarded])
	if not took:
		_fails += 1


func _off_belt(path: BeltPath, rb) -> bool:
	if not is_instance_valid(rb) or not rb.is_inside_tree() or BeltPath.is_rider(rb):
		return false
	var at: Dictionary = path._nearest(rb.global_position)
	var pos: Vector3 = rb.global_position
	var off:= pos - path._point_at(float(at ["s"]))
	var basis:= path._basis_at(float(at ["s"]))
	return absf(off.dot(basis.x)) > Cfg.BELT_WIDTH * 0.5 or off.dot(basis.y) < -0.3


func _v3(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


func _case_shut_intake() -> void:
	print("\n=== bricks onto a shut generator's intake ===")
	var gen: HayGenerator = world.builds.add_generator(Vector3(8.0, 0.0, 6.0), 0.0)
	if gen == null:
		print("  [FAIL] could not place a generator")
		_fails += 1
		return
	for i in SETTLE:
		await get_tree().physics_frame

	gen.set_switched_off(true)
	await get_tree().physics_frame
	var deck:= gen.deck()
	var props: PropManager = world.props
	var dt:= get_physics_process_delta_time()
	var bricks: Array [RigidBody3D] = []
	var badge_seen:= false
	for n in 12:
		var s:= deck.path_length() * randf_range(0.25, 0.75)
		var basis:= deck._basis_at(s)
		var at:= deck._point_at(s) + basis.y * 0.6 + basis.x * randf_range(-0.1, 0.1)
		var b:= props.spawn("eco_brick", Transform3D(basis, at),
			{ "strands": Cfg.PELLETIZER_BRICK_STRANDS }) as RigidBody3D
		if b != null:
			bricks.append(b)
		for t in int(0.5 / dt):
			await get_tree().physics_frame
			var badge:= deck.get_node_or_null("FullBadge") as FullBadge
			if badge != null and badge._label != null and badge._label.visible:
				badge_seen = true
	for t in int(JUDGE_SECONDS / dt):
		await get_tree().physics_frame
	var on_deck:= 0
	var boarded:= 0
	for b in bricks:
		if not is_instance_valid(b) or not b.is_inside_tree():
			boarded += 1
			continue
		var at: Dictionary = deck._nearest(b.global_position)
		var off:= b.global_position - deck._point_at(float(at ["s"]))
		var basis:= deck._basis_at(float(at ["s"]))
		if absf(off.dot(basis.x)) <= Cfg.BELT_WIDTH * 0.5 and off.dot(basis.y) > -0.1 and float(at ["s"]) > 0.0 and float(at ["s"]) < deck.path_length():
			on_deck += 1
	var ok:= on_deck == 0
	print("  %s 12 bricks dropped: %d boarded, %d lying loose on the deck"
		% ["[ok]  " if ok else "[FAIL]", boarded, on_deck])
	if not ok:
		_fails += 1
	print("  %s FULL shows over the deck" % ["[ok]  " if badge_seen else "[FAIL]"])
	if not badge_seen:
		_fails += 1
