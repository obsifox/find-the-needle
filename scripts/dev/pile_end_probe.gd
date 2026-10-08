class_name DevPileEndProbe
extends Node


const ARM_FLOOR:= RoboticArm.FIELD_FLOOR

const SWEEP_SLACK:= 0.1

var _fails:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func run() -> void:
	print("--- pile end probe ---")
	var was:= Cfg.pile_size_id
	var shares:= { }
	for spec: Dictionary in Cfg.PILE_SIZES:
		shares [str(spec.get("id", ""))] = await _measure(spec)
	Cfg.apply_pile_size(was)

	print("\nhand sweep against STANDARD's")
	var base: float = shares.get("standard", 0.0)
	for id: String in shares:
		_ok(float(shares [id]) <= base + SWEEP_SLACK,
			"%s: %.0f%% of the floor by hand, STANDARD %.0f%%"
				% [id, float(shares [id]) * 100.0, base * 100.0])
	print("\n[pileend] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _measure(spec: Dictionary) -> float:
	var id:= str(spec.get("id", ""))
	Cfg.apply_pile_size(id)
	var field:= HayField.new()
	add_child(field)
	field.generate(1234)
	await get_tree().process_frame

	var nv:= Cfg.field_verts()
	var nc:= Cfg.field_cells()
	var area: float = Cfg.CELL * Cfg.CELL
	var floor_m3:= 0.0
	var floor_cells:= 0
	for j in nc:
		for i in nc:
			var h00:= minf(field.heights [j * nv + i], ARM_FLOOR)
			var h10:= minf(field.heights [j * nv + i + 1], ARM_FLOOR)
			var h01:= minf(field.heights [(j + 1) * nv + i], ARM_FLOOR)
			var h11:= minf(field.heights [(j + 1) * nv + i + 1], ARM_FLOOR)
			var h:= (h00 + h10 + h01 + h11) * 0.25
			if h > 0.0:
				floor_cells += 1
			floor_m3 += h * area
	var tipped:= field.measure_strands()
	var left:= floor_m3 * Cfg.STRANDS_PER_M3
	var line:= Cfg.PILE_CLEAR_STRANDS
	var sweep:= maxf(0.0, left - line)
	var share:= sweep / maxf(left, 1.0)

	print("\n%s" % str(spec.get("name", "")))
	print("  tipped in %s strands" % Hud.fmt(tipped))
	print("  arms leave %s strands (%.1f m3 over %.0f m2)"
		% [Hud.fmt(left), floor_m3, floor_cells * area])
	print("  line %s   by hand %s (%.0f%%)"
		% [Hud.fmt(line), Hud.fmt(sweep), share * 100.0])
	_ok(line <= left, "%s: the line is under what the arms leave" % id)

	field.queue_free()
	await get_tree().process_frame
	return share
