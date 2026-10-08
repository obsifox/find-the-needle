class_name DevPipeHitchProbe
extends Node


var world: Node3D
var player: Player

const SIZES:= [100, 300, 600]
const AFTER:= 8
const ORIGIN:= Vector3(-40.0, 0.4, -40.0)


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var builds: BuildManager = world.builds
	for _k in 30:
		await get_tree().physics_frame
	var laid:= 0
	for size: int in SIZES:
		while laid < size:
			var p:= _point(laid)
			var q:= _point(laid + 1)
			var run:= WaterMain.new()
			run.name = "WaterMain%d" % laid
			run.setup(p, q)
			builds.water_mains.append(run)
			builds.add_child(run)
			laid += 1
		builds.rebuild_water_joints()
		for _k in 10:
			await get_tree().physics_frame
		print("PIPEHITCH ---- %d runs ----" % laid)
		var t:= Time.get_ticks_usec()
		builds.rebuild_water_joints()
		print("  rebuild_water_joints   %8.2f ms" % _ms(t))
		t = Time.get_ticks_usec()
		builds.water.rebuild()
		print("  WaterGrid.rebuild      %8.2f ms" % _ms(t))
		t = Time.get_ticks_usec()
		builds.grid.rebuild()
		print("  PowerGrid.rebuild      %8.2f ms" % _ms(t))
		t = Time.get_ticks_usec()
		builds.snap_water_endpoint(_point(laid))
		builds.water_port_taken(_point(laid))
		builds.nearest_water_run_end(_point(laid))
		print("  ghost lookups          %8.2f ms" % _ms(t))


		t = Time.get_ticks_usec()
		builds.add_water_main(_point(laid), _point(laid + 1))
		laid += 1
		print("  add_water_main         %8.2f ms" % _ms(t))
		var frames:= PackedFloat32Array()
		for _k in AFTER:
			var f:= Time.get_ticks_usec()
			await get_tree().process_frame
			frames.append(_ms(f))
		print("  frames after           %s" % str(frames))
	print("PIPEHITCH done")
	get_tree().quit()


func _point(i: int) -> Vector3:
	var row:= i / 20
	var col:= i % 20
	var x:= float(col) if row % 2 == 0 else float(20 - col)
	return ORIGIN + Vector3(x, 0.0, float(row) * 1.5)


static func _ms(since: int) -> float:
	return (Time.get_ticks_usec() - since) / 1000.0
