class_name DevPlazaAuditProbe
extends Node


const BIG:= 5.0

var world: Node3D

var _solid: Array [Dictionary] = []


func run() -> void:
	print("--- plaza audit ---")
	print("site: %s" % ("the plaza" if world.get("plaza") != null else "NOT BUILT"))

	await get_tree().process_frame
	await get_tree().process_frame

	_collect(world)
	_report()
	_ground()
	_fixtures()
	_bore()
	get_tree().quit(0)


func _collect(root: Node) -> void:
	var stack: Array [Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for kid: Node in node.get_children():
			stack.append(kid)
		var body:= node as CollisionObject3D
		if body == null:
			continue
		if body.collision_layer == 0:
			continue
		_solid.append({
			"path": String(world.get_path_to(body)),
			"layer": body.collision_layer,
			"seen": body.is_visible_in_tree(),
			"box": _box_of(body),
			"top": _top_name(body),
		})


func _top_name(body: Node) -> String:
	var at:= body
	while at.get_parent() != null and at.get_parent() != world:
		at = at.get_parent()
	return String(at.name)


func _box_of(body: CollisionObject3D) -> AABB:
	var out:= AABB()
	var first:= true
	for kid: Node in body.get_children():
		var cs:= kid as CollisionShape3D
		if cs == null or cs.shape == null or cs.disabled:
			continue
		var local: AABB = cs.shape.get_debug_mesh().get_aabb()
		var box: AABB = cs.global_transform * local
		out = box if first else out.merge(box)
		first = false
	return out


func _report() -> void:
	var by_top: Dictionary = { }
	for row: Dictionary in _solid:
		var top:= str(row ["top"])
		if not by_top.has(top):
			by_top [top] = []
		(by_top [top] as Array).append(row)

	print("\n%d solid bodies under the world" % _solid.size())
	for top: String in by_top.keys():
		var rows: Array = by_top [top]
		var unseen:= 0
		for row: Dictionary in rows:
			if not bool(row ["seen"]):
				unseen += 1
		print("\n%-22s %3d bodies, %d of them invisible" % [top, rows.size(), unseen])
		for row: Dictionary in rows:
			if bool(row ["seen"]):
				continue
			var box: AABB = row ["box"]
			if maxf(box.size.x, box.size.z) < BIG:
				continue
			print("  INVISIBLE AND SOLID  %-46s layer %-5d %.0f x %.0f x %.0f m at (%.0f, %.0f, %.0f)"
				% [row ["path"], row ["layer"],
					box.size.x, box.size.y, box.size.z,
					box.position.x + box.size.x * 0.5,
					box.position.y,
					box.position.z + box.size.z * 0.5])


func _ground() -> void:
	var terrain: Node = world.get("terrain")
	var t3d: Node = terrain.get_child(0).get_node_or_null(NodePath("Terrain3D")) if terrain != null and terrain.get_child_count() > 0 else null
	print("\nterrain: %s, collision_mode %s, layer %s"
		% ["hidden" if terrain != null and not terrain.visible else "visible",
			str(t3d.get("collision_mode")) if t3d != null else "no node",
			str(t3d.get("collision_layer")) if t3d != null else "-"])

	var space:= world.get_world_3d().direct_space_state
	print("\nwhat is under a walk out from the pile:")
	for metres: int in [0, 20, 40, 60, 90, 140, 200]:
		var from:= Vector3(float(metres), 120.0, 0.0)
		var q:= PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 400.0)
		q.collision_mask = 4294967295
		var hit:= space.intersect_ray(q)
		if hit.is_empty():
			print("  %4d m   nothing at all" % metres)
			continue
		var body: Object = hit.get("collider")
		var name:= "(no node)" if body == null else String(world.get_path_to(body as Node)) if body is Node and (body as Node).is_inside_tree() else "OFF THE TREE (the terrain)"
		print("  %4d m   y %6.2f   %s" % [metres, (hit ["position"] as Vector3).y, name])


func _fixtures() -> void:
	print("\nyard nodes still visible on the site:")
	for child: Node in world.get_children():
		var n3:= child as Node3D
		if n3 == null or not n3.visible:
			continue
		if child == world.get("plaza") or child == world.get("player"):
			continue
		if child is Light3D or child is WorldEnvironment or child is Camera3D:
			continue
		print("  %-24s at (%.0f, %.0f, %.0f)"
			% [child.name, n3.global_position.x, n3.global_position.y,
				n3.global_position.z])


func _bore() -> void:
	var plaza: Node3D = world.get("plaza")
	var door: Node3D = world.get("bay_door")
	if plaza == null or door == null:
		print("\nno bore to check")
		return
	print("\nthe bore:")
	var cases:= {
		"7 m outboard, the opening pose": door.inboard_point(-7.0),
		"just outboard of the doorway": door.inboard_point(-0.5),
		"in the doorway": door.inboard_point(0.5),
		"the middle of the room": Vector3.ZERO,
		"past the back of the bore": door.inboard_point(-40.0),
		"beside the bore, on open apron": door.inboard_point(-7.0)
			+ door.global_basis.x * 12.0,
	}
	for what: String in cases.keys():
		print("  %-34s %s" % [what,
			"IN THE BORE" if plaza.call("in_the_bore", cases [what]) else "in the open"])

	var blocker: Node = plaza.get_node_or_null(
		NodePath("Tunnel/Blocker/Blocker_body"))
	if blocker == null:
		print("  no blocker body")
		return
	plaza.call("hold_the_doorway", false)
	var down: int = blocker.get("collision_layer")
	plaza.call("hold_the_doorway", true)
	var up: int = blocker.get("collision_layer")
	print("  doorway: %d held, %d stood down (0 and %d wanted)"
		% [up, down, Cfg.L_PEN])
