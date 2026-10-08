class_name DevCableDeckProbe
extends Node


var world: Node3D

var _failures:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	for i in 10:
		await get_tree().physics_frame
	var builds: BuildManager = world.builds
	var tier:= Cfg.ROBOT_ARM_DEFAULT_TIER
	var scale:= float(Cfg.ROBOT_ARM_TIERS [tier] ["scale"])
	var h:= RoboticArm.AIM_HEIGHT * scale + Cfg.PLATFORM_THICK + 0.3
	var span:= Vector2(Cfg.PLATFORM_TILE, Cfg.PLATFORM_TILE) * 4.0
	print("deck top %.2f, span %s" % [h, span])
	var cases:= [
		["pole on the deck", Vector3(0.0, h, 0.0)],
		["pole under the deck", Vector3(1.5, 0.0, 0.0)],
		["pole beside the deck", Vector3(span.x * 0.5 + 1.5, 0.0, 0.0)],
		["pole on the deck strung to one under it", Vector3(-1.0, h, 1.0),
			Vector3(2.0, 0.0, -1.0)],
		["pole on the deck strung to one beside it", Vector3(0.0, h, 0.0),
			Vector3(span.x * 0.5 + 2.0, 0.0, 0.0), "joined"],
		["deck laid under a span already hung", Vector3(-1.0, h, 1.0),
			Vector3(2.0, 0.0, -1.0), "deck last"],
	]
	var ox:= 40.0
	for c: Array in cases:
		var o:= Vector3(ox, 0.0, 40.0)
		ox += 40.0
		var note: String = c [3] if c.size() > 3 else ""
		print("\n=== %s ===" % c [0])
		if note != "deck last":
			builds.add_platform(o + Vector3(0.0, h, 0.0), span)
			builds.add_robotic_arm(o + Vector3(-2.5, h, 0.0), 0.0, tier)
			builds.add_robotic_arm(o + Vector3(-2.5, 0.0, 2.0), 0.0, tier)
			builds.add_robotic_arm(o + Vector3(span.x * 0.5 - 1.0, 0.0, -2.0), 0.0, tier)
		var p0:= builds.add_power_pole(o + (c [1] as Vector3), 0.0)
		var p1: PowerPole = null
		if c.size() > 2:
			for i in 10:
				await get_tree().physics_frame
			p1 = builds.add_power_pole(o + (c [2] as Vector3), 0.0)
		for i in 20:
			await get_tree().physics_frame
		if note == "deck last":
			_check("the two poles are strung while nothing is between them",
				builds.grid.network_of(p0) == builds.grid.network_of(p1))
			builds.add_platform(o + Vector3(0.0, h, 0.0), span)
			for i in 20:
				await get_tree().physics_frame
			_check("...and come apart once a deck is laid between them",
				builds.grid.network_of(p0) != builds.grid.network_of(p1))
		if note == "joined":
			_check("a clear span from a deck is still strung",
				builds.grid.network_of(p0) == builds.grid.network_of(p1))
		_audit(builds, o)
	print("\n[cable-deck] %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _audit(builds: BuildManager, o: Vector3) -> void:
	for arm in builds.robotic_arms:
		if absf(arm.global_position.x - o.x) > 15.0:
			continue
		var pole: PowerPole = builds.grid.pole_for(arm)
		print("  arm at %s: %s" % [arm.global_position.snapped(Vector3.ONE * 0.01),
			"no cable" if pole == null else "cable from pole at %s" % pole.global_position])
	for line in _lines(builds):
		for w in mini(line.from_anchors.size(), line.to_anchors.size()):
			var a:= line.from_anchors [w].global_position
			var b:= line.to_anchors [w].global_position
			if absf(a.x - o.x) > 15.0:
				continue
			print("  wire %s -> %s" % [a.snapped(Vector3.ONE * 0.01), b.snapped(Vector3.ONE * 0.01)])
			for deck in builds.platforms:
				var hit:= _through(deck, PowerLine.curve(a, b, 60))
				if hit != Vector3.INF:
					_failures += 1
					print("  FAIL: wire %s -> %s passes through the deck at %s" % [
						a.snapped(Vector3.ONE * 0.01), b.snapped(Vector3.ONE * 0.01),
						hit.snapped(Vector3.ONE * 0.01)])


func _check(what: String, ok: bool) -> void:
	print("  %s: %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _lines(root: Node) -> Array [PowerLine]:
	var out: Array [PowerLine] = []
	for n in root.find_children("*", "", true, false):
		if n is PowerLine:
			out.append(n as PowerLine)
	return out


func _through(deck: Platform, pts: PackedVector3Array) -> Vector3:
	var rect:= deck.footprint()
	var top:= deck.top_y()
	for p in pts:
		if p.y < top and p.y > top - Cfg.PLATFORM_THICK and rect.has_point(Vector2(p.x, p.z)):
			return p
	for i in pts.size() - 1:
		var a:= pts [i]
		var b:= pts [i + 1]
		if (a.y - top) * (b.y - top) < 0.0:
			var t:= (top - a.y) / (b.y - a.y)
			var q:= a.lerp(b, t)
			if rect.has_point(Vector2(q.x, q.z)):
				return q
	return Vector3.INF
