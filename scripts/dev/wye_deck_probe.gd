class_name DevWyeDeckProbe
extends Node


var world: Node3D
var player: Player


const OPEN:= Vector3(41.0, 0.0, 39.0)


const AIM_STEP:= 0.25

const PIECES: Array [String] = ["u_splitter", "splitter", "t_splitter",
	"compact_splitter", "joiner", "u_joiner"]

var _pass:= 0
var _fail:= 0
var _steep_text:= ""


func run() -> void:
	await get_tree().process_frame
	var tool: BuildTool = player.build
	if tool == null:
		_check("the player has a build tool", false)
		_finish()
		return
	_steep_text = tool.tr("surface too steep")
	for node: String in ["splitter", "t_splitter", "compact_splitter", "joiner"]:
		Tech.grant(node, 1)
	GameState.add_money(100000.0)

	var builds: BuildManager = world.builds
	var floor_open:= _floor_y(OPEN)


	var decks: Array [Platform] = []
	var names: Array [String] = []
	decks.append(builds.add_platform(
		Vector3(OPEN.x, floor_open + 0.25, OPEN.z), Vector2(8.0, 8.0)))
	names.append("deck on the ground")
	decks.append(builds.add_platform(
		Vector3(OPEN.x + 20.0, floor_open + 1.79, OPEN.z), Vector2(8.0, 8.0)))
	names.append("deck at the first storey")
	decks.append(builds.add_platform(
		Vector3(OPEN.x, floor_open + 0.25, OPEN.z + 20.0), Vector2(8.0, 8.0)))
	names.append("lower deck of a step")
	decks.append(builds.add_platform(
		Vector3(OPEN.x + 8.0, floor_open + 0.55, OPEN.z + 20.0), Vector2(8.0, 8.0)))
	names.append("upper deck of a step")


	var field: HayField = world.field
	var edge_x:= 0.0
	var x:= 2.0
	while x < 40.0:
		if field.height_at(x, 0.0) < 0.4:
			edge_x = x
			break
		x += 0.25
	var pile_floor:= _floor_y(Vector3(edge_x + 6.0, 0.0, 0.0))
	decks.append(builds.add_platform(
		Vector3(roundf(edge_x) + 2.0, pile_floor + 0.3, 0.0), Vector2(8.0, 8.0)))
	names.append("deck over the pile edge (x %.2f)" % edge_x)


	var wall_q:= PhysicsRayQueryParameters3D.create(
		Vector3(0.0, 1.2, - edge_x), Vector3(0.0, 1.2, -80.0))
	wall_q.collision_mask = Cfg.L_WORLD
	var wall:= player.get_world_3d().direct_space_state.intersect_ray(wall_q)
	if not wall.is_empty():
		var wz:= roundf((wall ["position"] as Vector3).z) + 4.0
		var shed_floor:= _floor_y(Vector3(0.0, 0.0, wz))
		decks.append(builds.add_platform(
			Vector3(0.0, shed_floor + 0.25, wz), Vector2(8.0, 8.0)))
		names.append("deck against the shed wall (z %.2f)" % wz)

	for _i in 4:
		await get_tree().physics_frame

	for id: String in PIECES:
		player.equip_build(id)
		for _f in 6:
			await get_tree().process_frame
		_check("the tool comes up holding %s" % id, player.build_id == id)
		if player.build_id != id:
			continue
		for grid: bool in [true, false]:
			tool._grid_on = grid
			for i in decks.size():
				await _sweep(tool, decks [i], "%s, %s, %s"
					% [id, names [i], "grid on" if grid else "grid off"])
	tool._grid_on = false
	_finish()


func _sweep(tool: BuildTool, deck: Platform, what: String) -> void:
	print("\n=== %s ===" % what)
	var c:= deck.global_position
	var half:= deck.span * 0.5
	var top:= deck.top_y()
	var stands: Array [Vector3] = [
		Vector3(c.x, top, c.z),
		Vector3(c.x - half.x + 0.6, top, c.z - half.y + 0.6),
		Vector3(c.x + half.x - 0.6, top, c.z + half.y - 0.6),
		Vector3(c.x - half.x - 2.5, _floor_y(Vector3(c.x - half.x - 2.5, 0.0, c.z)), c.z),
	]
	var aimed:= 0
	var steep:= 0
	var other:= 0
	var seen:= { }
	for stand in stands:
		player.global_position = stand
		player.velocity = Vector3.ZERO
		var u:= - half.x
		while u <= half.x + 0.0001:
			var v:= - half.y
			while v <= half.y + 0.0001:
				var target:= Vector3(c.x + u, top, c.z + v)
				v += AIM_STEP
				_aim_at(target)
				var eye:= player.eye_position()
				if eye.distance_to(target) > tool._reach - 0.3:
					continue
				var raw:= tool._raw_surface_hit()
				if raw.is_empty():
					continue


				var at: Vector3 = raw ["position"]
				var place:= "TOP"
				if at.y < top - 0.01:
					place = "SIDE"
				elif at.y > top + 0.02:
					place = "ABOVE"
				elif absf(at.x - c.x) > half.x - 0.02 or absf(at.z - c.z) > half.y - 0.02:
					place = "RIM"
				var over_plate:= place == "TOP"
				tool._update_ghost(0.0)
				aimed += 1
				if String(tool._eval ["reason"]) != _steep_text:
					continue
				var hit:= tool._surface_hit()
				var key:= "%s | raw %s n=%s | used %s n=%s" % [
					place,
					_body(raw), _vec(raw ["normal"]),
					_body(hit), _vec(hit.get("normal", Vector3.ZERO))]
				if over_plate:
					steep += 1
				else:
					other += 1
				if over_plate and not seen.has(key):

					var stood: Vector3 = hit ["position"]
					var fq:= PhysicsRayQueryParameters3D.create(
						stood + Vector3.UP * 1.5, stood + Vector3.DOWN * 1.0)
					fq.collision_mask = Cfg.BUILD_SURFACE_MASK
					var under:= player.get_world_3d().direct_space_state.intersect_ray(fq)
					print("    TOP refusal: aim %s, stands at %s, floor ray finds %s n=%s at %s"
						% [_vec(target), _vec(stood), _body(under),
						_vec(under.get("normal", Vector3.ZERO)),
						_vec(under.get("position", Vector3.ZERO))])
				if seen.has(key):
					seen [key] += 1
				else:
					seen [key] = 1
					print("  steep at %s from %s: %s" % [_vec(target), _vec(stand), key])
			u += AIM_STEP
	print("  %d aims, %d steep on top of the plate, %d steep on a side, rim or something above it"
		% [aimed, steep, other])
	for key: String in seen:
		print("    x%d  %s" % [seen [key], key])
	_check("%s: no aim at the plate reads \"surface too steep\" (%d of %d)"
		% [what, steep, aimed], steep == 0 and aimed > 0)
	await get_tree().process_frame


func builds_owner(hit: Dictionary) -> Node:
	var builds: BuildManager = world.builds
	return builds.owner_of(hit.get("collider") as Node)


func _aim_at(target: Vector3) -> void:
	for _pass_i in 2:
		var d:= target - player.eye_position()
		var flat:= Vector2(d.x, d.z).length()
		player.set_look(atan2(- d.x, - d.z), atan2(d.y, flat))


func _floor_y(at: Vector3) -> float:
	var q:= PhysicsRayQueryParameters3D.create(
		Vector3(at.x, 60.0, at.z), Vector3(at.x, -60.0, at.z))
	q.collision_mask = Cfg.L_WORLD
	var hit:= player.get_world_3d().direct_space_state.intersect_ray(q)
	return 0.0 if hit.is_empty() else (hit ["position"] as Vector3).y


func _body(hit: Dictionary) -> String:
	var body:= hit.get("collider") as CollisionObject3D
	if body == null:
		return "nothing"
	var cls: String = body.get_class()
	if body.get_script() != null and body.get_script().get_global_name() != &"":
		cls = body.get_script().get_global_name()
	return "%s %s (layer %d, owner %s)" % [cls, body.name, body.collision_layer,
		builds_owner(hit).name if builds_owner(hit) != null else "-"]


func _vec(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


func _check(what: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _finish() -> void:
	print("[wyedeck] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
