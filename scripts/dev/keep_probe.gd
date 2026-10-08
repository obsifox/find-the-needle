class_name DevKeepProbe
extends Node


const LOG:= "res://keep_probe.log"


const TAG_THROWN:= Color(0.0, 1.0, 0.0)
const TAG_BELT:= Color(0.0, 0.0, 1.0)
const TAG_BURIED:= Color(1.0, 0.0, 1.0)


const OVERHANG:= 0.5

var world: Node3D
var player: Player

var _fails: PackedStringArray = PackedStringArray()
var _rng:= RandomNumberGenerator.new()


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	_rng.seed = 20260823
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	GameState.add_money(2000.0)
	await _settle(30)

	await _case_thrown_at_the_pile()
	await _case_belt()
	await _case_needle_on_ground()
	await _case_needle_under_floor()
	await _case_buried_is_still_lost()

	if _fails.is_empty():
		_log("OK")
	else:
		for f in _fails:
			_log("FAIL: %s" % f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_thrown_at_the_pile() -> void:
	_log("\n=== thrown at the pile ===")


	player.global_position = Cfg.PILE_CENTER + Vector3(0, Cfg.PILE_HEIGHT + 1.0, 0)
	await _settle(20)

	var made: Array [RigidBody3D] = []
	for i in 40:
		var ang:= TAU * float(i) / 40.0
		var dir:= Vector3(cos(ang), 0.0, sin(ang))
		var from: Vector3 = Cfg.PILE_CENTER + dir * (Cfg.PILE_RADIUS + 2.5)
		from.y = 1.5
		var b: RigidBody3D = world.live.spawn(from,
			StrandFactory.random_strand_basis(_rng),
			- dir * 6.0 + Vector3(0, 1.0, 0), TAG_THROWN)
		if b != null:
			made.append(b)
	_log("  threw %d strands at the flank from all round" % made.size())

	var last: Array [Vector3] = []
	last.resize(made.size())
	for tick in 300:
		await get_tree().physics_frame
		for i in made.size():
			if _is_mine(made [i], TAG_THROWN):
				last [i] = made [i].global_position

	var left:= 0
	var under_pile:= 0
	var in_the_open: PackedStringArray = PackedStringArray()
	for i in made.size():
		if _is_mine(made [i], TAG_THROWN):
			left += 1
			continue
		var p:= last [i]
		var over: float = world.field.height_at(p.x, p.z)
		if over >= OVERHANG:
			under_pile += 1
		else:
			in_the_open.append("%.2v, under %.2f m of pile" % [p, over])
	_log("  still lying where they landed: %d of %d" % [left, made.size()])
	_log("  folded back in under the crust: %d" % under_pile)
	for line in in_the_open:
		_log("  VANISHED IN THE OPEN: %s" % line)
	if not in_the_open.is_empty():
		_fails.append("%d strand(s) thrown at the pile vanished off open ground"
			% in_the_open.size())


func _case_belt() -> void:
	_log("\n=== on a running belt ===")
	var a:= Vector3(13.0, 0.75, -5.0)
	var b:= Vector3(13.0, 0.75, 5.0)
	world.builds.add_conveyor(a, b)
	await _settle(30)

	var made: Array [RigidBody3D] = []
	for i in 16:
		var p:= Vector3(13.0 + _rng.randf_range(-0.2, 0.2), 0.95,
			-4.4 + _rng.randf_range(-0.3, 0.3))
		var body: RigidBody3D = world.live.spawn(p,
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, TAG_BELT)
		if body != null:
			made.append(body)
	await _settle(45)
	var riding:= _alive(made, TAG_BELT)
	_log("  %d of %d landed on the deck" % [riding, made.size()])


	var live: LiveStrandManager = world.live
	var flood: int = Cfg.LIVE_SOFT_CAP + 200 - live.active_count()
	for i in maxi(flood, 0):
		live.spawn(Vector3(-6.0, 9.0, -6.0) + Vector3(_rng.randf(), 0, _rng.randf()),
			StrandFactory.random_strand_basis(_rng), Vector3.ZERO, Cfg.COL_HAY_DARK)
	_log("  flooded to %d live strands (soft cap %d)"
		% [live.active_count(), Cfg.LIVE_SOFT_CAP])
	await _settle(150)

	var left:= _alive(made, TAG_BELT)
	_log("  still on the belt after the drain: %d of %d" % [left, riding])
	if left < riding:
		_fails.append("the over-cap drain ate %d strands off a running belt"
			% (riding - left))


func _case_needle_on_ground() -> void:
	_log("\n=== a needle thrown at the floor ===")
	var before: int = world.live.needles.size()
	var made: Array [RigidBody3D] = []
	for i in 8:
		var n: RigidBody3D = world.live.reveal_needle(-1,
			Vector3(-13.0 + float(i) * 0.4, 1.6, 12.0))
		if n != null:

			n.linear_velocity = Vector3(_rng.randfn(0.0, 2.0), -7.0, _rng.randfn(0.0, 2.0))
			made.append(n)
	await _settle(180)

	var left:= 0
	var under:= 0
	for n in made:
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		left += 1
		if n.global_position.y < -0.05:
			under += 1
	_log("  thrown %d, still in the world %d, below the floor %d"
		% [made.size(), left, under])
	if left < made.size():
		_fails.append("%d needle(s) left the world" % (made.size() - left))
	if under > 0:
		_fails.append("%d needle(s) went through the floor" % under)
	var after: int = world.live.needles.size()
	if after != before + made.size():
		_fails.append("the needle register does not match what is in the world")


func _case_needle_under_floor() -> void:
	_log("\n=== a needle that got under the floor anyway ===")
	var n: RigidBody3D = world.live.reveal_needle(-1, Vector3(4.0, 1.0, 4.0))
	if n == null:
		_fails.append("could not make a needle to test the backstop")
		return
	n.global_position = Vector3(4.0, -6.0, 4.0)
	await _settle(20)
	if not is_instance_valid(n) or not n.is_inside_tree():
		_fails.append("the needle was freed instead of recovered")
		return
	var p: Vector3 = n.global_position
	var at_surf: float = world.field.height_at(p.x, p.z)
	_log("  recovered to %.2v (pile surface there is %.2f m)" % [p, at_surf])
	if p.y < 0.0:
		_fails.append("a needle under the floor was left there (y = %.2f)" % p.y)


func _case_buried_is_still_lost() -> void:
	_log("\n=== hay genuinely inside the pile ===")
	var surf: float = world.field.height_at(Cfg.PILE_CENTER.x, Cfg.PILE_CENTER.z)
	if surf < 3.0:
		_fails.append("no pile to bury anything in (%.2f m at the centre)" % surf)
		return
	var made: Array [RigidBody3D] = []
	for i in 8:
		var p:= Cfg.PILE_CENTER + Vector3(_rng.randf_range(-0.5, 0.5),
			surf * 0.5, _rng.randf_range(-0.5, 0.5))
		var b: RigidBody3D = world.live.spawn(p, StrandFactory.random_strand_basis(_rng),
			Vector3.ZERO, TAG_BURIED)
		if b != null:
			b.freeze = true
			made.append(b)
	_log("  held %d strands %.1f m inside a %.1f m pile"
		% [made.size(), surf * 0.5, surf])
	await _settle(20)
	var left:= _alive(made, TAG_BURIED)
	_log("  still simulated: %d of %d" % [left, made.size()])
	if left > 0:
		_fails.append("%d strand(s) buried in the pile were not reclaimed" % left)


func _is_mine(b: RigidBody3D, tint: Color) -> bool:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return false
	var c: Color = b.get_meta(LiveStrandManager.META_COLOR, Color.BLACK)
	return c.is_equal_approx(tint)


func _alive(bodies: Array [RigidBody3D], tint: Color) -> int:
	var n:= 0
	for b in bodies:
		if _is_mine(b, tint):
			n += 1
	return n


func _settle(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func _log(msg: String) -> void:
	print("[keep] %s" % msg)
	var f:= FileAccess.open(LOG, FileAccess.READ_WRITE if FileAccess.file_exists(LOG)
		else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(msg)
	f.close()
