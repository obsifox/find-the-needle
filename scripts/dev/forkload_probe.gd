class_name DevForkLoadProbe
extends Node


const CLICKS:= 16


const BETWEEN:= 45

const SETTLE:= 90


const OVERLAP_DIST:= 0.02


const SPAM_CLICKS:= 40
const SPAM_GAP:= 3


const OVERLAP_SAMPLE:= 300

var world: Node3D
var player: Player

var _rows: Array = []

var _fails_extra: Array [String] = []


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	var live: LiveStrandManager = world.live
	_clear_hay(live)
	_stand_at_the_pile()
	GameState.grant_tool("pitchfork")
	player._set_tool(Player.Tool.PITCHFORK)
	player.pitchfork.reset_aim()
	for i in 20:
		await get_tree().physics_frame

	print("\n=== clicking a pitchfork at the pile, %d times ===" % CLICKS)
	print("   n   lifted  carried    live   overlaps   load_h    aim_h   phys_ms")
	var fork:= player.pitchfork
	for n in CLICKS:
		var lifted:= fork.scoop()
		var worst:= 0.0
		var aimed:= 0.0
		var pan_y: float = (fork.pan_geometry() ["origin"] as Vector3).y
		for i in BETWEEN:
			await get_tree().physics_frame
			worst = maxf(worst, Performance.get_monitor(
				Performance.TIME_PHYSICS_PROCESS) * 1000.0)


			aimed = maxf(aimed, fork._load_top - pan_y)
		var held:= _held_bodies(fork)
		var row:= {
			"n": n + 1,
			"lifted": lifted,
			"carried": fork.carried_strands(),
			"live": live.active_count(),
			"overlaps": _overlapping(held),
			"height": _load_height(fork, held),
			"aimed": aimed,
			"ms": worst,
		}
		_rows.append(row)
		print("  %2d   %6d   %6d  %6d   %8d   %6.3f   %6.3f   %7.2f"
			% [row ["n"], row ["lifted"], row ["carried"], row ["live"],
				row ["overlaps"], row ["height"], row ["aimed"], row ["ms"]])


	print("\n=== the same fork with the button held down ===")
	var spam_aim:= 0.0
	var spam_pan: float = (fork.pan_geometry() ["origin"] as Vector3).y
	for n in SPAM_CLICKS:
		fork.scoop()
		for i in SPAM_GAP:
			await get_tree().physics_frame
			spam_aim = maxf(spam_aim, fork._load_top - spam_pan)
	print("  %d clicks at %d a second aimed at most %.3f m above the pan"
		% [SPAM_CLICKS, 60 / SPAM_GAP, spam_aim])
	if spam_aim > 0.4:
		_fails_extra.append("a held button aimed a bite %.2f m above the pan" % spam_aim)

	for i in SETTLE:
		await get_tree().physics_frame
	var held:= _held_bodies(fork)
	print("\n  after settling: %d on the fork, %d live in the world, %d overlapping"
		% [fork.carried_strands(), live.active_count(), _overlapping(held)])
	print("  the fork's own basin is %.3f m deep" % _basin_height(fork))

	await _switching_with_a_load(fork)
	await _the_load_lands_clear(fork)
	await _the_next_blade_does_not_take_it(fork)

	var fails:= 0
	var last: Dictionary = _rows [_rows.size() - 1]


	if int(last ["carried"]) > 600:
		fails += 1
		print("  FAIL  %d strands still on the fork after %d clicks"
			% [last ["carried"], CLICKS])

	if float(last ["height"]) > 0.4:
		fails += 1
		print("  FAIL  the load stands %.2f m above the tines" % last ["height"])


	var highest:= 0.0
	for r: Dictionary in _rows:
		highest = maxf(highest, float(r ["aimed"]))
	if highest > 0.4:
		fails += 1
		print("  FAIL  a bite was aimed %.2f m above the pan" % highest)
	for f in _fails_extra:
		fails += 1
		print("  FAIL  %s" % f)
	print("\n[probe] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _switching_with_a_load(fork: Shovel) -> void:
	print("\r\n=== switching tools with a load on the fork ===")
	GameState.grant_tool("spade")
	GameState.grant_tool("broom")
	var carried:= fork.carried_strands()
	if carried <= 0:
		_fails_extra.append("nothing left on the fork to test the switch with")
		return
	print("  %d strands on the tines" % carried)


	for t: Array in [[Player.Tool.SHOVEL, "the spade"],
			[Player.Tool.BROOM, "the broom"],
			[Player.Tool.HAND, "bare hands"]]:
		await _reload(fork)
		player._set_tool(t [0] as Player.Tool)
		await get_tree().physics_frame
		var went: bool = player.current_tool == t [0]
		var emptied: bool = fork.carried_strands() == 0
		print("  %s  reaching for %-12s  fork now holds %d"
			% ["ok  " if went and emptied else "FAIL", t [1], fork.carried_strands()])
		if not went:
			_fails_extra.append("a loaded fork would not be swapped for %s" % t [1])
		if not emptied:
			_fails_extra.append("the fork kept %d strands after reaching for %s"
				% [fork.carried_strands(), t [1]])
		player._set_tool(Player.Tool.PITCHFORK, true)
		await get_tree().physics_frame


	if BuildCatalog.has_id("belt"):
		Tech.grant(BuildCatalog.unlock_of("belt"), 1)
		await _reload(fork)
		player.equip_build("belt")
		await get_tree().physics_frame
		var went: bool = player.current_tool == Player.Tool.BUILD
		var emptied: bool = fork.carried_strands() == 0
		print("  %s  raising the belt hologram          fork now holds %d"
			% ["ok  " if went and emptied else "FAIL", fork.carried_strands()])
		if not went:
			_fails_extra.append("a loaded fork would not be swapped for the belt hologram")
		if not emptied:
			_fails_extra.append("the fork kept %d strands after raising the hologram"
				% fork.carried_strands())
		player._set_tool(Player.Tool.PITCHFORK, true)
		await get_tree().physics_frame


func _the_load_lands_clear(fork: Shovel) -> void:
	print("\n=== where the dropped load ends up ===")


	_clear_hay(world.live)
	for i in 20:
		await get_tree().physics_frame
	await _reload(fork)
	var load:= _held_bodies(fork)
	if load.size() < 8:
		_fails_extra.append("only %d strands on the fork to follow" % load.size())
		return
	var foot:= player.global_position
	var look:= player.look_direction()
	look.y = 0.0
	look = look.normalized()

	player._set_tool(Player.Tool.HAND)


	for i in 120:
		await get_tree().physics_frame

	var ahead:= 0
	var clear:= 0
	var seen:= 0
	var reach:= 0.0
	var nearest:= 99.0
	var mean:= 0.0
	for b in load:
		if not is_instance_valid(b) or not b.is_inside_tree():
			continue
		seen += 1
		var off:= b.global_position - foot
		off.y = 0.0
		if off.dot(look) > 0.0:
			ahead += 1
		if off.length() > Player.CAP_RADIUS:
			clear += 1
		reach = maxf(reach, off.dot(look))
		nearest = minf(nearest, off.length())
		mean += off.dot(look)
	if seen == 0:
		_fails_extra.append("every dropped strand vanished before it landed")
		return
	mean /= float(seen)
	print("  %d of %d landed, %.2f m ahead on average, furthest %.2f, nearest %.2f from the boots"
		% [seen, load.size(), mean, reach, nearest])
	print("  %d ahead of the crosshair, %d outside the capsule (%.2f m)"
		% [ahead, clear, Player.CAP_RADIUS])


	if float(ahead) / float(seen) < 0.8:
		_fails_extra.append("only %d of %d dropped strands went forward"
			% [ahead, seen])
	if float(clear) / float(seen) < 0.8:
		_fails_extra.append("only %d of %d dropped strands cleared the player"
			% [clear, seen])
	player._set_tool(Player.Tool.PITCHFORK, true)
	await get_tree().physics_frame


func _the_next_blade_does_not_take_it(fork: Shovel) -> void:
	print("\n=== the blade you switch TO does not inherit the load ===")
	_clear_hay(world.live)
	for i in 20:
		await get_tree().physics_frame
	GameState.grant_tool("spade")
	await _reload(fork)
	var start:= fork.carried_strands()
	if start <= 0:
		_fails_extra.append("nothing on the fork to hand over")
		return
	player._set_tool(Player.Tool.SHOVEL)


	for i in 90:
		await get_tree().physics_frame
	var onto:= player.shovel.carried_strands()
	print("  fork held %d, switched to the spade, spade now holds %d" % [start, onto])
	if onto > 0:
		_fails_extra.append(
			"the spade inherited %d of the fork's %d strands on the switch"
				% [onto, start])


	_clear_hay(world.live)
	for i in 20:
		await get_tree().physics_frame
	_stand_at_the_pile()
	player._set_tool(Player.Tool.SHOVEL)
	for i in 10:
		await get_tree().physics_frame
	player.shovel.scoop()
	for i in 45:
		await get_tree().physics_frame
	var back:= player.shovel.carried_strands()
	player._set_tool(Player.Tool.PITCHFORK)
	for i in 90:
		await get_tree().physics_frame
	var forked:= fork.carried_strands()
	print("  spade held %d, switched to the fork, fork now holds %d" % [back, forked])
	if back <= 0:
		_fails_extra.append("nothing on the spade to hand back")
	elif forked > 0:
		_fails_extra.append(
			"the fork inherited %d of the spade's %d strands on the switch"
				% [forked, back])
	await get_tree().physics_frame


func _reload(fork: Shovel) -> void:
	if fork.carried_strands() > 0:
		return
	_stand_at_the_pile()
	player._set_tool(Player.Tool.PITCHFORK, true)
	for i in 10:
		await get_tree().physics_frame
	fork.scoop()
	for i in 45:
		await get_tree().physics_frame


func _held_bodies(fork: Shovel) -> Array [RigidBody3D]:
	var out: Array [RigidBody3D] = []
	for id: int in fork._riding:
		var b: Variant = fork._riding [id]
		if b is RigidBody3D and is_instance_valid(b) and (b as RigidBody3D).is_inside_tree():
			out.append(b as RigidBody3D)
	return out


func _overlapping(held: Array [RigidBody3D]) -> int:
	var n: int = mini(held.size(), OVERLAP_SAMPLE)
	var d2:= OVERLAP_DIST * OVERLAP_DIST
	var pairs:= 0
	for i in n:
		var p:= held [i].global_position
		for j in range(i + 1, n):
			if p.distance_squared_to(held [j].global_position) < d2:
				pairs += 1
	return pairs


func _load_height(fork: Shovel, held: Array [RigidBody3D]) -> float:
	if held.is_empty():
		return 0.0
	var into:= fork.body.global_transform.orthonormalized().affine_inverse()
	var g:= fork.pan_geometry()
	var floor_y: float = (g ["origin"] as Vector3).y
	var top:= -1000.0
	for b in held:
		top = maxf(top, (into * b.global_position).y)
	return top - floor_y


func _basin_height(fork: Shovel) -> float:
	var box:= fork._basin_shape.shape as BoxShape3D if fork._basin_shape != null else null
	return box.size.y if box != null else 0.0


func _clear_hay(live: LiveStrandManager) -> void:
	for b in live._active.duplicate():
		live._despawn(b)


func _stand_at_the_pile() -> void:
	player.global_position = Vector3(11.5, 0.4, 0.0)
	player.rotation = Vector3(0, PI * 0.5, 0)
	player.head.rotation.x = -0.55
	player.velocity = Vector3.ZERO
