class_name DevStubbleProbe
extends Node


var world: Node3D
var player: Player
var field: HayField

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in 10:
		await get_tree().process_frame
	var tool: BuildTool = player.build
	GameState.add_money(5000.0)
	Tech.reset()
	Tech.grant("spade", 1)
	GameState.grant_tool("spade")
	player._set_tool(Player.Tool.SHOVEL)
	player.shovel.reset_aim()
	for i in 10:
		await get_tree().physics_frame

	print("\n=== the fork and a lone tuft ===")

	_check("the floor at (13, -3) is bare", field.height_at(13.0, -3.0) <= 0.0)
	await _scoop_case("10 cm, the old dead band", Vector3(13.0, 0.0, -3.0), 0.1, 2)
	await _scoop_case("12 cm, the top of the band", Vector3(13.0, 0.0, -1.0), 0.12, 2)
	await _scoop_case("20 cm, more than one pan", Vector3(13.0, 0.0, 1.0), 0.2, 6)

	print("\n=== placing over a tuft ===")
	var lift:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var ridge:= Vector3(13.0, 0.0, 4.25)
	_plant(ridge + Vector3(0.0, 0.0, -0.25), 0.2)
	_plant(ridge, 0.2)
	_plant(ridge + Vector3(0.0, 0.0, 0.25), 0.2)
	var mound:= Vector3(13.0, 0.0, 8.0)
	for dx in [-0.25, 0.0, 0.25]:
		for dz in [-0.25, 0.0, 0.25]:
			_plant(mound + Vector3(dx, 0.0, dz), 0.4)
	await _rebuild()
	var over_ridge:= tool._evaluate_compressor(ridge + Vector3.UP * lift, Vector3(0.0, 0.0, 1.0), Vector3.UP, false)
	_check("a compressor goes down over a 20 cm ridge (%s)" % over_ridge ["reason"],
		bool(over_ridge ["ok"]))
	if not bool(over_ridge ["ok"]):


		var what:= tool._probe_obstruction(tool._compressor_probe_query)
		print("       in the way: %s, hay under the probe %.3f m"
			% [str(what), tool._hay_under_probe(tool._compressor_probe_query)])
	var belt_over:= tool._evaluate(Vector3(11.0, lift, 4.25), Vector3(15.0, lift, 4.25), true)
	_check("a run of belt crosses it (%s)" % belt_over ["reason"], bool(belt_over ["ok"]))
	var over_mound:= tool._evaluate_compressor(mound + Vector3.UP * lift, Vector3(0.0, 0.0, 1.0), Vector3.UP, false)
	_check("a 40 cm mound still refuses the compressor (%s)" % over_mound ["reason"],
		not bool(over_mound ["ok"]))
	var belt_mound:= tool._evaluate(Vector3(11.0, lift, 8.0), Vector3(15.0, lift, 8.0), true)
	_check("and the belt (%s)" % belt_mound ["reason"], not bool(belt_mound ["ok"]))


	var flank_x:= 9.0
	while flank_x > 0.0 and field.height_at(flank_x, 0.0) < 1.0:
		flank_x -= 0.25
	var flank:= Vector3(flank_x, field.height_at(flank_x, 0.0), 0.0)
	var on_pile:= tool._evaluate_compressor(flank + Vector3.UP * lift, Vector3(0.0, 0.0, 1.0), Vector3.UP, false)
	_check("the pile's flank at x %.2f, %.2f m of hay, still refuses it (%s)"
		% [flank_x, flank.y, on_pile ["reason"]], not bool(on_pile ["ok"]))
	var through:= tool._evaluate(Vector3(-11.0, lift, 0.0), Vector3(11.0, lift, 0.0), true)
	_check("and a run through the pile (%s)" % through ["reason"], not bool(through ["ok"]))

	print("\n=== sweeping the islands off a loaded field ===")
	var lone:= Vector3(-13.0, 0.0, 6.0)
	_plant(lone, 0.1)
	var pair:= Vector3(-13.0, 0.0, 8.0)
	_plant(pair, 0.22)
	_plant(pair + Vector3(0.25, 0.0, 0.0), 0.22)
	var before:= field.measure_strands()
	var crown_h:= field.height_at(0.0, 0.0)
	var planted:= _worth(0.1) + _worth(0.22) * 2.0 + _worth(0.2) * 3.0
	var gone:= field.sweep_islands(Cfg.THIN_HAY)
	_check("the sweep took %.0f strands for %.0f planted" % [gone, planted],
		absf(gone - planted) < 1.0)
	_check("the lone tuft is gone", field.height_at(lone.x, lone.z) <= 0.0)
	_check("the pair is gone", field.height_at(pair.x, pair.z) <= 0.0)
	_check("the ridge under the compressor is gone", field.height_at(ridge.x, ridge.z) <= 0.0)
	_check("the 40 cm mound stands", field.height_at(mound.x, mound.z) > 0.39)
	_check("the crown is untouched", is_equal_approx(field.height_at(0.0, 0.0), crown_h))
	var after:= field.measure_strands()
	_check("the field lost exactly what the sweep returned (%.0f vs %.0f)"
		% [before - after, gone], absf((before - after) - gone) < 1.0)

	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _scoop_case(label: String, at: Vector3, h: float, scoops: int) -> void:
	_plant(at, h)
	await _rebuild()
	var ledger:= GameState.hay_total
	var scale:= Tech.spade_scale()
	var max_count:= Tech.scoop_max(Cfg.SCOOP_MAX, scale)
	var radius:= Cfg.SCOOP_RADIUS * scale
	var used:= 0
	var took:= 0
	for i in scoops:
		var p:= Vector3(at.x, field.height_at(at.x, at.z) - 0.02, at.z)
		var n:= player.shovel.scoop_at(p, max_count, radius,
			Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.5))
		took += n
		used += 1
		await get_tree().physics_frame
		if field.height_at(at.x, at.z) <= 0.0:
			break
	var left:= field.height_at(at.x, at.z)
	_check("%s: gone after %d scoop(s), %d strands on the pan" % [label, used, took],
		left <= 0.0 and took > 0)
	var debited:= ledger - GameState.hay_total
	_check("   ledger down by %.0f for %.0f planted" % [debited, _worth(h)],
		absf(debited - _worth(h)) < 1.5)


func _plant(at: Vector3, h: float) -> void:
	var i:= int(round((at.x + Cfg.FIELD_EXTENT) / Cfg.CELL))
	var j:= int(round((at.z + Cfg.FIELD_EXTENT) / Cfg.CELL))
	field.heights [j * Cfg.field_verts() + i] = h


func _rebuild() -> void:
	field.rebuild_everything()
	for i in 3:
		await get_tree().physics_frame


func _worth(h: float) -> float:
	return h * Cfg.CELL * Cfg.CELL * Cfg.PACKING / Cfg.STRAND_VOLUME


func _check(label: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		_fails += 1
