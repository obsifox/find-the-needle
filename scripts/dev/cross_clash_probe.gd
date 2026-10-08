class_name DevCrossClashProbe
extends Node


var world: Node3D
var player: Player

const AT:= Vector3(30.0, 0.0, 30.0)

const FWD:= Vector3(0.0, 0.0, 1.0)

const U_YAW:= PI * 0.5

const INSIDE:= 0.5
const AWAY:= Vector3(8.0, 0.0, 0.0)
const KINDS:= ["generator", "gas_plant", "pelletizer", "launcher", "lift", "stairs"]

var _pass:= 0
var _fail:= 0
var builds: BuildManager


func run() -> void:
	for i in 40:
		await get_tree().process_frame
	builds = world.builds
	GameState.add_money(500000.0)
	for kind: String in KINDS:
		print("\n=== %s ===" % kind)
		await _kind(kind)
	print("\n[crossclash] %s  %d passed, %d failed"
		% ["PASS" if _fail == 0 else "FAIL", _pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _kind(kind: String) -> void:
	var deck_y:= Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR
	var back:= _port_back(kind)

	var spot:= AT - FWD * (back - INSIDE) if kind != "stairs" else AT + Vector3(1.2, 0.0, 0.0)
	spot.y = deck_y


	var m:= _add(kind, AT)
	await _settle()
	if kind != "stairs":
		var port: Vector3 = m.call("intake_port") if kind != "lift" else m.call("port_in")
		var measured:= (AT - port).dot(FWD)
		_check("the port stands where the check thinks (%.3f m against %.3f m)"
			% [measured, back], absf(measured - back) < 0.05)
	_check("a U splitter's arm on it is refused", builds.wye_overlap(_u_discs(spot)))
	_check("...and eight metres over is not", not builds.wye_overlap(_u_discs(spot + AWAY)))
	_check("a scanner on it is refused", builds.scanner_overlap(spot, Vector3.RIGHT))
	_check("...and eight metres over is not",
		not builds.scanner_overlap(spot + AWAY, Vector3.RIGHT))
	if kind != "stairs":


		var port: Vector3 = m.call("intake_port") if kind != "lift" else m.call("port_in")
		var centre:= port - ConveyorUSplitter.mouth_local(1.0)
		centre.y = deck_y
		_check("a U outlet on its port, port on port, is not a clash",
			not builds.wye_overlap(_u_discs_at(centre, 0.0)))
	builds.demolish(m)
	await _settle()


	var u_centre:= _u_centre_for(spot)
	var u: ConveyorUSplitter = builds.add_u_splitter(u_centre, U_YAW)
	await _settle()
	var arm_disc:= _disc_centre(u.footprint() [2])
	var at:= arm_disc + FWD * (back - INSIDE) if kind != "stairs" else arm_disc - Vector3(1.2, 0.0, 0.0)
	at.y = 0.0
	_check("set down with its belt on a U splitter's arm, refused", _overlap(kind, at))
	_check("...and eight metres over is not", not _overlap(kind, at - AWAY))
	builds.demolish(u)
	await _settle()


	var s:= builds.add_scanner(spot, atan2(1.0, 0.0))
	await _settle()
	var at2:= spot + FWD * (back - INSIDE) if kind != "stairs" else spot - Vector3(1.2, 0.0, 0.0)
	at2.y = 0.0
	_check("set down with its belt through a scanner, refused", _overlap(kind, at2))
	_check("...and eight metres over is not", not _overlap(kind, at2 - AWAY))
	builds.demolish(s)
	await _settle()


func _port_back(kind: String) -> float:
	match kind:
		"generator", "gas_plant":
			return HayGenerator.PORT_BACK
		"pelletizer":
			return HayPelletizer.PORT_BACK + HayPelletizer.STUB + HayPelletizer.STUB_REACH
		"launcher":
			return TubeLauncher.PORT_BACK + TubeLauncher.STUB + TubeLauncher.STUB_REACH
		"lift":
			return - HayLift.PLAN_Z.x + float(HayLift.PORT_REACH [0])
	return 0.0


func _add(kind: String, at: Vector3) -> Node3D:
	match kind:
		"generator":
			return builds.add_generator(at, 0.0)
		"gas_plant":
			return builds.add_gas_plant(at, 0.0)
		"pelletizer":
			return builds.add_pelletizer(at, 0.0)
		"launcher":
			return builds.add_tube_launcher(at, 0.0)
		"lift":
			return builds.add_hay_lift(at, 0.0, 1)
	return builds.add_hay_stairs(at, 0.0)


func _overlap(kind: String, at: Vector3) -> bool:
	match kind:
		"generator":
			return builds.generator_overlap(at, FWD)
		"gas_plant":
			return builds.generator_overlap(at, FWD, null, true)
		"pelletizer":
			return builds.pelletizer_overlap(at, FWD)
		"launcher":
			return builds.launcher_overlap(at, FWD)
		"lift":
			return builds.lift_overlap(at, null, FWD)
	return builds.stairs_overlap(at)


func _u_centre_for(spot: Vector3) -> Vector3:
	var local: Vector4 = ConveyorUSplitter.footprint_local() [2]
	return spot - Basis(Vector3.UP, U_YAW) * Vector3(local.x, local.y, local.z)


func _u_discs(spot: Vector3) -> Array [Vector4]:
	return _u_discs_at(_u_centre_for(spot), U_YAW)


func _u_discs_at(centre: Vector3, yaw: float) -> Array [Vector4]:
	var out: Array [Vector4] = []
	for d: Vector4 in ConveyorUSplitter.footprint_local():
		var c:= centre + Basis(Vector3.UP, yaw) * Vector3(d.x, d.y, d.z)
		out.append(Vector4(c.x, c.y, c.z, d.w))
	return out


func _disc_centre(d: Vector4) -> Vector3:
	return Vector3(d.x, d.y, d.z)


func _settle() -> void:
	for i in 6:
		await get_tree().physics_frame


func _check(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
