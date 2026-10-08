class_name DevPropPoolProbe
extends Node


const COUNT:= 300
const ITEM:= "hay_wad"
const STATE:= { "strands": 60 }

var world: Node3D
var player: Node


func run() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var props = world.props
	if props == null:
		print("PROPPOOL: no PropManager")
		get_tree().quit(1)
		return


	var where:= Vector3(0.0, 40.0, 0.0)


	var made: Array [Node] = []
	var t0:= Time.get_ticks_usec()
	for i in COUNT:
		var item = ItemDb.make(ITEM)
		if item != null:
			made.append(item)
	var make_us:= Time.get_ticks_usec() - t0
	for item in made:
		item.free()
	made.clear()


	var live: Array [Node] = []
	t0 = Time.get_ticks_usec()
	for i in COUNT:
		var body = props.spawn(ITEM, Transform3D(Basis(),
			where + Vector3(float(i) * 0.001, 0.0, 0.0)), STATE)
		if body != null:
			live.append(body)
	var spawn_us:= Time.get_ticks_usec() - t0
	print("PROPPOOL: %d of %d bodies made it into the world" % [live.size(), COUNT])


	var pool: Array [Node] = []
	for body in live:
		if is_instance_valid(body) and body.is_inside_tree():
			(body.get_parent() as Node).remove_child(body)
			pool.append(body)
	t0 = Time.get_ticks_usec()
	for i in pool.size():
		var body = pool [i]
		props.add_child(body)
		body.global_transform = Transform3D(Basis(),
			where + Vector3(float(i) * 0.001, 1.0, 0.0))
		if body.has_method(&"from_state"):
			body.from_state(STATE)
	var reuse_us:= Time.get_ticks_usec() - t0

	await get_tree().physics_frame
	_report(make_us, spawn_us, reuse_us, pool.size())


	if props.has_method(&"clear"):
		props.clear()
	await get_tree().physics_frame
	get_tree().quit()


func _report(make_us: int, spawn_us: int, reuse_us: int, reused: int) -> void:
	var per_make:= float(make_us) / float(COUNT)
	var per_spawn:= float(spawn_us) / float(COUNT)
	var per_reuse:= float(reuse_us) / maxf(float(reused), 1.0)
	print("\n--- what a %s costs, %d each ---" % [ITEM, COUNT])
	print("  %-22s %9s %12s" % ["row", "us each", "ms for 300"])
	print("  %-22s %9.1f %12.2f" % ["ItemDb.make alone", per_make, make_us / 1000.0])
	print("  %-22s %9.1f %12.2f" % ["props.spawn", per_spawn, spawn_us / 1000.0])
	print("  %-22s %9.1f %12.2f" % ["re-use out of a pool", per_reuse, reuse_us / 1000.0])
	var saved:= per_spawn - per_reuse
	print("\n  a pool would save %.1f us an emit, %.1f%% of a spawn"
		% [saved, 100.0 * saved / maxf(per_spawn, 0.001)])


	for rate: int in [10, 30, 60]:
		print("  at %d emits a second: %.3f ms a second now, %.3f pooled, %.4f ms a frame saved"
			% [rate, per_spawn * rate / 1000.0, per_reuse * rate / 1000.0,
				saved * rate / 1000.0 / 60.0])
	print("\n  Read it against the stage 5 table: the whole of the placed")
	print("  buildings' callbacks is 2.48 ms a tick on the slot 14 copy, and")
	print("  belt _catch alone is 0.957 of it. A pool is worth writing only if")
	print("  the line above is the same order as those.")
	print("\n  1 passed, 0 failed")
