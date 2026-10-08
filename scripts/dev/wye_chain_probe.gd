class_name DevWyeChainProbe
extends Node


var world: Node3D
var player: Player

const CHAIN:= 4
const LINK:= 1.6
const PRESS_RUN:= 2.4
const PRESS_EVERY:= 2.0
const PRESS_OPEN:= 0.35
const FEED:= 40
const FEED_GAP:= 0.6
const SETTLE_FRAMES:= 30

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	player.global_position = Vector3(10.0, 0.4, 10.0)
	GameState.add_money(50000.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame


	await _chain("main arm carries on, presses on overflow", ConveyorSplitter.LEFT,
		Vector3(-12.0, 0.0, -12.0))
	await _chain("main arm is the press, chain on overflow", ConveyorSplitter.RIGHT,
		Vector3(4.0, 0.0, -12.0))
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _chain(title: String, onward: int, origin: Vector3) -> void:
	print("\n=== %s ===" % title)
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var at:= Vector3(origin.x, deck_y, origin.z)
	var heading:= Vector3(0.0, 0.0, 1.0)
	var feed_from:= at
	at += heading * 3.0
	var splitters: Array [ConveyorSplitter] = []
	var presses: Array [Conveyor] = []
	var feed: Conveyor = null
	var prev_port:= Vector3.ZERO
	for k in CHAIN:
		var centre:= at + heading * Cfg.SPLITTER_PORT_R
		var s: ConveyorSplitter = world.builds.add_splitter(centre,
			atan2(heading.x, heading.z))
		if k == 0:
			feed = world.builds.add_conveyor(feed_from, s.port_in())
		else:
			world.builds.add_conveyor(prev_port, s.port_in())
		var press_side:= ConveyorSplitter.RIGHT if onward == ConveyorSplitter.LEFT else ConveyorSplitter.LEFT
		var press_dir:= (s.port(press_side) - s.global_position)
		press_dir.y = 0.0
		press_dir = press_dir.normalized()
		presses.append(world.builds.add_conveyor(s.port(press_side),
			s.port(press_side) + press_dir * PRESS_RUN))
		var on_dir:= (s.port(onward) - s.global_position)
		on_dir.y = 0.0
		heading = on_dir.normalized()
		prev_port = s.port(onward)
		at = prev_port + heading * LINK
		splitters.append(s)


	world.builds.add_conveyor(prev_port, prev_port + heading * LINK)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	for s in splitters:
		s.set_priority_side(ConveyorSplitter.LEFT)
	for p in presses:
		p.set_blocked(true)

	var took:= []
	for k in CHAIN:
		took.append([0, 0])
		for side in ConveyorSplitter.SIDES:
			var route:= splitters [k].route(side)
			route.caught_record.connect(func(_seq: int, _kind: int, _n: int) -> void:
				took [k] [side] += 1)
			route.caught.connect(func(_b: RigidBody3D) -> void:
				took [k] [side] += 1)

	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	var spawn_at:= feed.a + feed.forward * 0.8 + Vector3(0.0, 0.45, 0.0)
	var yaw:= atan2(feed.forward.x, feed.forward.z)
	var fed:= 0
	var t:= 0.0
	var next_feed:= 0.0
	var next_press:= PRESS_EVERY
	var press_until:= -1.0


	var starved:= []
	var shut_all:= []
	var waiting:= []
	var busy_read_blocked:= []
	for k in CHAIN:
		busy_read_blocked.append(0)
		starved.append(0)
		shut_all.append(0)
		waiting.append(0)
	var total:= FEED * FEED_GAP + 30.0
	var timeline:= ""
	var last_line:= -1.0
	while t < total:
		if fed < FEED and t >= next_feed:
			world.props.spawn("hay_wad", Transform3D(Basis(Vector3.UP, yaw), spawn_at))
			fed += 1
			next_feed += FEED_GAP
		if t >= next_press:
			next_press += PRESS_EVERY
			press_until = t + PRESS_OPEN
			for p in presses:
				p.set_blocked(false)
		elif press_until > 0.0 and t >= press_until:
			press_until = -1.0
			for p in presses:
				p.set_blocked(true)
		await get_tree().physics_frame
		t += step
		for k in CHAIN:
			var s:= splitters [k]
			if s._stalled(ConveyorSplitter.LEFT) and not s.route(ConveyorSplitter.LEFT).has_load_waiting():
				busy_read_blocked [k] += 1
			var fdr:= s.feeder()
			var queued:= fdr != null and fdr.has_load_waiting()
			if not queued:
				continue
			waiting [k] += 1
			var open:= s._open_side()
			if open < 0:
				shut_all [k] += 1
			if open != ConveyorSplitter.LEFT and s._has_room(ConveyorSplitter.LEFT):
				starved [k] += 1
		if t - last_line >= 1.0:
			last_line = t
			var row:= "  t %5.1f" % t
			for k in CHAIN:
				var s:= splitters [k]
				var fdr:= s.feeder()
				var main:= s.route(ConveyorSplitter.LEFT)
				row += "  | S%d open %2d stall %2d/%2d room %s/%s q %d arm %d%s" % [k,
					s._open_side(), s._stall [0], s._stall [1],
					"y" if s._has_room(0) else "n", "y" if s._has_room(1) else "n",
					_aboard(fdr), _aboard(main), " W" if main.has_load_waiting() else ""]
			timeline += row + "\n"
	print(timeline)
	for k in CHAIN:
		print("  S%d took %d main (left), %d right; wad waiting in front %d ticks, both shut %d, main clear yet not open %d, main stalled with no wad parked at its end %d"
			% [k, took [k] [0], took [k] [1], waiting [k], shut_all [k], starved [k], busy_read_blocked [k]])
	var worst:= 0
	for k in CHAIN:
		worst = maxi(worst, starved [k])
	_check("%s: no splitter holds a wad back from a clear main arm (worst %d ticks)"
		% [title, worst], worst < 30)


	var shut:= 0
	var busy:= 0
	for k in CHAIN:
		shut += shut_all [k]
		busy += busy_read_blocked [k]
	_check("%s: no splitter shuts both arms on a line that never backs up (%d ticks)"
		% [title, shut], shut == 0)
	_check("%s: a main arm streaming wads is never read as stalled (%d ticks)"
		% [title, busy], busy == 0)
	if onward == ConveyorSplitter.LEFT:
		var spilled:= 0
		for k in CHAIN:
			spilled += int(took [k] [1])
		_check("%s: every wad stays on the main line, none spill to a press (%d spilled)"
			% [title, spilled], spilled == 0)
	for p in presses:
		p.set_blocked(false)


static func _aboard(path: BeltPath) -> int:
	return path.riders().size() + path.run.count() if path != null else 0


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
