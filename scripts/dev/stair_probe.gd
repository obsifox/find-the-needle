class_name DevStairProbe
extends Node


var world: Node3D
var player: Player

const SETTLE:= 30


const TOLERANCE:= 0.05

var _fails:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame

	GameState.add_money(50000.0)
	var builds: BuildManager = world.builds
	var tool: BuildTool = player.build


	var lower:= builds.add_platform(Vector3(13.0, 0.35, -5.0), Vector2(12.0, 8.0))
	var upper:= builds.add_platform(Vector3(9.0, 3.0, -5.0), Vector2(4.0, 4.0))
	for i in 10:
		await get_tree().process_frame
		await get_tree().physics_frame

	var top:= upper.top_y()
	var floor_y:= lower.top_y()
	var rise:= top - floor_y


	tool._reach = 14.0
	player.global_position = Vector3(9.0, top + 0.1, -5.0)
	for i in 4:
		await get_tree().process_frame

	print("\nupper deck top %.2f, floor %.2f, rise %.2f" % [top, floor_y, rise])


	_aim(Vector3(10.5, top, -5.0))
	tool._mode = BuildTool.Mode.STAIR
	tool._update_stair_ghost()
	_ok("pointing at a deck is a valid first click", tool._eval ["ok"], true)
	_ok("the head lands on the edge nearest the crosshair",
		"%.2f" % tool._stair_ghost.global_position.x, "%.2f" % 11.0)
	_ok("and sits on the walking surface",
		"%.2f" % tool._stair_ghost.global_position.y, "%.2f" % top)
	_ok("the stub faces off the deck",
		"%.2f" % (- tool._stair_ghost.global_transform.basis.z).x, "%.2f" % 1.0)
	_ok("and is one step long, not a measured flight",
		"%.2f" % tool._stair_ghost.rise, "%.2f" % Cfg.STAIR_RISER)

	tool._stair_primary()
	_ok("the first click starts a run instead of building",
		tool._state == BuildTool.State.RUNNING, true)
	_ok("and builds nothing yet", builds.stairs.size(), 0)


	var want:= 0.5
	var target:= Vector3(11.0 + rise / want, floor_y, -5.0)
	_aim(target)
	tool._update_stair_ghost()
	_ok("a landing inside the band is buildable", tool._eval ["ok"], true)
	_ok("and reads out the angle it was drawn at",
		"%.1f" % tool._eval ["angle"], "%.1f" % rad_to_deg(atan(want)))
	_ok("the ghost takes the derived pitch",
		"%.3f" % tool._stair_ghost.pitch, "%.3f" % want)


	var hud: Hud = world.hud


	tool.set_active(true)
	tool._reach = 14.0
	tool._mode = BuildTool.Mode.STAIR
	tool._state = BuildTool.State.RUNNING
	_aim(target)
	tool._update_stair_ghost()
	hud._update_build_readout()
	_ok("the readout prints the rise and the angle",
		hud._build.text.contains("m rise") and hud._build.text.contains("°"), true)


	tool._state = BuildTool.State.AIMING
	_aim(Vector3(10.5, top, -5.0))
	tool._update_stair_ghost()
	hud._update_build_readout()
	_ok("and before the head is pinned it says what the click does",
		hud._build.text, "click the deck edge to start")
	tool._state = BuildTool.State.RUNNING
	_aim(target)
	tool._update_stair_ghost()

	tool._stair_primary()
	_ok("the second click builds the flight", builds.stairs.size(), 1)
	var flight: Stair = builds.stairs [0]
	var landed: Vector3 = flight.foot()
	print("  aimed at %s, landed at %s" % [target.snappedf(0.01), landed.snappedf(0.01)])
	_ok("the flight lands where it was aimed",
		landed.distance_to(target) < TOLERANCE, true)
	_ok("and its head is still on the deck edge",
		"%.2f" % flight.global_position.y, "%.2f" % top)
	_ok("a placed flight leaves the tool ready for the next one",
		tool._state == BuildTool.State.AIMING, true)


	var ramp: CollisionShape3D = flight.get_node("RampCollision")
	var box:= ramp.shape as BoxShape3D


	var head_edge: Vector3 = ramp.global_transform * Vector3(0.0, box.size.y * 0.5, box.size.z * 0.5)
	_ok("the ramp's top edge arrives at the deck's walking surface",
		"%.3f" % head_edge.y, "%.3f" % top)
	_ok("and reaches the deck's edge rather than stopping short of it",
		"%.3f" % head_edge.x, "%.3f" % 11.0)


	var crest:= _crest_angle(flight.pitch, top - head_edge.y)
	print("  the capsule meets the deck edge at %.0f°, and walks anything under %.0f°"
		% [crest, rad_to_deg(player.floor_max_angle)])
	_ok("and the deck's top edge is something the player can walk over",
		crest <= rad_to_deg(player.floor_max_angle), true)


	builds.demolish(flight)
	await get_tree().physics_frame
	tool._anchor = Vector3(11.0, top, -5.0)
	tool._stair_outward = Vector3.RIGHT


	var band_rise:= 1.2
	_reason(tool, "a flight steeper than the band", band_rise, Cfg.STAIR_PITCH_MAX + 0.2,
		Vector3.RIGHT, false)
	_reason(tool, "a flight shallower than the band", band_rise,
		Cfg.STAIR_PITCH_MIN - 0.1, Vector3.RIGHT, false)
	_reason(tool, "a flight at the steep limit", band_rise, Cfg.STAIR_PITCH_MAX,
		Vector3.RIGHT, true)
	_reason(tool, "a flight at the shallow limit", band_rise, Cfg.STAIR_PITCH_MIN,
		Vector3.RIGHT, true)


	_reason(tool, "a flight aimed back across the deck", band_rise, want,
		Vector3.LEFT, false)
	_reason(tool, "a flight aimed along the edge", band_rise, want,
		Vector3.FORWARD, false)
	_reason(tool, "a flight with nothing to descend to", 0.0, want,
		Vector3.RIGHT, false)
	_reason(tool, "a flight past the maximum rise", Cfg.STAIR_MAX_RISE + 1.0,
		want, Vector3.RIGHT, false)


	_reason(tool, "a flight run out through the shed wall", rise,
		Cfg.STAIR_PITCH_MIN, Vector3.RIGHT, false)

	print("\n%s (%d failed)" % ["FAIL" if _fails > 0 else "PASS", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _crest_angle(pitch: float, gap: float) -> float:
	var r:= Player.CAP_RADIUS
	var c:= r * sqrt(1.0 + pitch * pitch) - gap
	var a:= 1.0 + pitch * pitch
	var b:= -2.0 * pitch * c
	var disc:= b * b - 4.0 * a * (c * c - r * r)
	if disc <= 0.0:
		return 0.0
	var d:= (- b + sqrt(disc)) / (2.0 * a)


	var h:= c - pitch * d
	return rad_to_deg(acos(clampf(h / r, -1.0, 1.0)))


func _aim(at: Vector3) -> void:
	var to:= at - player.eye_position()
	player.rotation.y = atan2(- to.x, - to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	player.force_update_transform()
	player.head.force_update_transform()


func _reason(tool: BuildTool, label: String, rise: float, pitch: float,
		heading: Vector3, want: bool) -> void:


	tool._stair_ghost.set_shape(tool._anchor, atan2(- heading.x, - heading.z),
		maxf(rise, Cfg.STAIR_RISER), pitch)
	var r: Dictionary = tool._evaluate_stair(rise, pitch, heading)
	var got: bool = r ["ok"]
	if got == want:
		_fails += 0
		print("  ok   %s -> %s" % [label, "buildable" if got else str(r ["reason"])])
		return
	_fails += 1
	print("  FAIL %s -> %s (wanted %s)"
		% [label, "buildable" if got else str(r ["reason"]),
			"buildable" if want else "refused"])


func _ok(label: String, got: Variant, want: Variant) -> void:
	if str(got) == str(want):
		print("  ok   %s" % label)
		return
	_fails += 1
	print("  FAIL %s: got %s, wanted %s" % [label, got, want])
