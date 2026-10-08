class_name DevStrandCullProbe
extends Node


const SETTLE:= 20

const OFF_WALL:= 1.0

var world: Node3D
var player: Player

var _pass:= 0
var _fail:= 0
var _live: LiveStrandManager
var _mmi: MultiMeshInstance3D


func run() -> void:
	call_deferred("_run")


func _check(label: String, ok: bool, note: String = "") -> void:
	if ok:
		_pass += 1
		print("  ok    %s%s" % [label, "" if note.is_empty() else "   " + note])
	else:
		_fail += 1
		print("  FAIL  %s%s" % [label, "" if note.is_empty() else "   " + note])


func _box() -> AABB:
	var b: AABB = _mmi.custom_aabb
	var xf: Transform3D = _mmi.global_transform
	var out:= AABB(xf * b.position, Vector3.ZERO)
	return out.expand(xf * (b.position + b.size))


func _park(at: Vector3) -> RigidBody3D:
	var b:= _live.spawn(at, Basis.IDENTITY, Vector3.ZERO, Color.WHITE)
	if b == null:
		return null
	_live.set_protected(b, true)
	b.freeze = true
	b.global_position = at
	return b


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	_live = world.live
	_mmi = _live.get_node("LiveCrust") as MultiMeshInstance3D

	var wall: float = float(world.warehouse.inner) - OFF_WALL
	print("\n=== the yard is wider than the field ===")
	print("  field reaches %.1f m, the shed wall is at %.1f m"
		% [Cfg.FIELD_EXTENT, float(world.warehouse.inner)])
	_check("there is floor outside the field to stand on", wall > Cfg.FIELD_EXTENT)

	print("\n=== a load carried out to the wall ===")
	var far:= Vector3(wall, 1.5, 0.0)
	var held:= _park(far)
	_check("the strand spawned", held != null)
	if held == null:
		_report()
		return
	for i in 4:
		await get_tree().process_frame
	var box:= _box()
	_check("the cull box reaches the load", box.has_point(far),
		"box %s, load at %s" % [str(box.abs()), str(far)])

	print("\n=== and back into the middle ===")
	held.global_position = Vector3(0.0, 1.5, 0.0)
	for i in 4:
		await get_tree().process_frame
	box = _box()
	_check("the box came back in with it", box.end.x < Cfg.FIELD_EXTENT,
		"box ends at x %.2f" % box.end.x)

	print("\n=== a settled strand still gets a corner ===")


	held.global_position = far
	for i in 3:
		await get_tree().process_frame
	held.collision_layer = Cfg.L_SETTLED
	var near:= _park(Vector3(0.0, 1.5, 0.0))
	_check("a second strand spawned", near != null)
	for i in 4:
		await get_tree().process_frame
	box = _box()
	_check("the box still reaches the settled one", box.has_point(far),
		"box %s, settled strand at %s" % [str(box.abs()), str(far)])
	_report()


func _report() -> void:
	print("\n%d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
