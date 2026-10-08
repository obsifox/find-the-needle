class_name DevBarrowPileProbe
extends Node


var world: Node3D

const SETTLE:= 40
const WALK_TICKS:= 420


const SINK_SLACK:= 0.15

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().physics_frame
	var field: HayField = world.field
	var player: Player = world.player
	for bearing: float in [0.0, 100.0, 215.0]:
		var out:= Vector3(sin(deg_to_rad(bearing)), 0.0, cos(deg_to_rad(bearing)))
		var centre:= Vector3(Cfg.PILE_CENTER.x, 0.0, Cfg.PILE_CENTER.z)


		var r:= 0.0
		while r < 40.0 and field.height_at(centre.x + out.x * r, centre.z + out.z * r) > 0.05:
			r += 0.1
		var start:= centre + out * (r + 4.0) + Vector3.UP * 0.2
		player.global_position = start
		player.velocity = Vector3.ZERO
		player.rotation.y = atan2(out.x, out.z)
		var barrow:= world.props.spawn("wheelbarrow",
			Transform3D(Basis.IDENTITY, start - out * 1.2)) as Wheelbarrow
		for i in 10:
			await get_tree().physics_frame
		_check("%.0f deg: the player takes the barrow" % bearing, player.carry.take(barrow))

		player.scripted = true
		player.scripted_move = - out
		player.scripted_speed = Player.SPEED
		var deepest:= - INF
		var rise:= - INF
		var was:= player.global_position
		var moved_late:= 0.0
		for tick in WALK_TICKS:
			await get_tree().physics_frame
			deepest = maxf(deepest, _sink(barrow, field))
			rise = maxf(rise, barrow.global_position.y - player.global_position.y)
			if tick >= WALK_TICKS - 60:
				moved_late += player.global_position.distance_to(was)
			was = player.global_position
		var face:= - INF
		for k in 41:
			var p:= player.global_position - out * (k * 0.1)
			face = maxf(face, field.height_at(p.x, p.z) - player.global_position.y)
		print("  %.0f deg: walked %.2f m, wheel %.2f m into the hay at worst, %.2f m up, face %.2f m over the feet within 4 m"
			% [bearing, Vector2(start.x - player.global_position.x, start.z - player.global_position.z).length(),
			deepest, rise, face])
		_check("%.0f deg: the face is tall enough to have been the bug (%.2f m)" % [bearing, face],
			face > 1.6)
		_check("%.0f deg: the wheel stays out of the hay (%.2f m in)" % [bearing, deepest],
			deepest <= SINK_SLACK)
		_check("%.0f deg: the barrow does not climb the face (%.2f m up)" % [bearing, rise],
			rise <= Cfg.PUSH_PILE_STEP + 0.05)
		_check("%.0f deg: the player stops at the pile (%.2f m in the last second)"
			% [bearing, moved_late], moved_late < 0.05)

		var stopped:= player.global_position
		player.scripted_move = out
		for tick in 60:
			await get_tree().physics_frame
		var back:= Vector2(player.global_position.x - stopped.x,
			player.global_position.z - stopped.z).length()
		_check("%.0f deg: walking away still works (%.2f m)" % [bearing, back], back > 1.5)

		player.scripted = false
		player.scripted_move = Vector3.ZERO
		player.carry.drop_all()
		for i in 10:
			await get_tree().physics_frame
		if is_instance_valid(barrow):
			barrow.queue_free()
	_finish()


func _sink(barrow: Wheelbarrow, field: HayField) -> float:
	var s:= barrow.size_scale()
	var axle:= barrow.global_transform * (Wheelbarrow.AXLE * s)
	var bottom:= axle.y - Wheelbarrow.WHEEL_R * s
	return field.height_at(axle.x, axle.z) - bottom


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _finish() -> void:
	print("\n[barrowpile] %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
