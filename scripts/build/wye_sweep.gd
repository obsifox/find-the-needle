class_name WyeSweep
extends RefCounted


const ACROSS:= 0.9


const ALONG:= 0.35


const HEIGHT:= 0.75


const MARGIN:= 0.15


const JUNCTION:= 0.45


const INFILL_DROP:= 0.003


const INFILL_THICK:= 0.05


static func infill(mouths: Array) -> MeshInstance3D:
	var verts:= PackedVector3Array()
	var normals:= PackedVector3Array()
	var uvs:= PackedVector2Array()
	for m: Vector3 in mouths:
		verts.append(Vector3(m.x, - INFILL_DROP, m.z))
		normals.append(Vector3.UP)

		uvs.append(Vector2(m.x, m.z))
	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = verts
	arrays [Mesh.ARRAY_NORMAL] = normals
	arrays [Mesh.ARRAY_TEX_UV] = uvs
	arrays [Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 1])
	var mesh:= ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


	mesh.surface_set_material(0, ConveyorKit.frame_material())
	var mi:= MeshInstance3D.new()
	mi.name = "Infill"
	mi.mesh = mesh
	return mi


static func infill_body(mouths: Array) -> StaticBody3D:
	var body:= StaticBody3D.new()
	body.name = "InfillFloor"
	body.collision_layer = Cfg.L_BUILD
	body.collision_mask = 0
	var points:= PackedVector3Array()
	for m: Vector3 in mouths:
		points.append(Vector3(m.x, - INFILL_DROP, m.z))
		points.append(Vector3(m.x, - INFILL_DROP - INFILL_THICK, m.z))
	var hull:= ConvexPolygonShape3D.new()
	hull.points = points
	var cs:= CollisionShape3D.new()
	cs.shape = hull
	body.add_child(cs)
	return body


static func infill_outline(outline: PackedVector2Array) -> MeshInstance3D:
	var verts:= PackedVector3Array()
	var normals:= PackedVector3Array()
	var uvs:= PackedVector2Array()
	for p: Vector2 in outline:
		verts.append(Vector3(p.x, - INFILL_DROP, p.y))
		normals.append(Vector3.UP)
		uvs.append(p)
	var tris:= Geometry2D.triangulate_polygon(outline)
	var index:= PackedInt32Array()


	for t in range(0, tris.size(), 3):
		index.append_array([tris [t], tris [t + 1], tris [t + 2],
			tris [t], tris [t + 2], tris [t + 1]])
	var mi:= MeshInstance3D.new()
	mi.name = "Infill"
	if index.is_empty():
		push_warning("WyeSweep: the infill outline did not triangulate")
		return mi
	var arrays:= []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays [Mesh.ARRAY_VERTEX] = verts
	arrays [Mesh.ARRAY_NORMAL] = normals
	arrays [Mesh.ARRAY_TEX_UV] = uvs
	arrays [Mesh.ARRAY_INDEX] = index
	var mesh:= ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, ConveyorKit.frame_material())
	mi.mesh = mesh
	return mi


static func infill_outline_body(outline: PackedVector2Array) -> StaticBody3D:
	var body:= StaticBody3D.new()
	body.name = "InfillFloor"
	body.collision_layer = Cfg.L_BUILD
	body.collision_mask = 0
	var pieces: Array = Geometry2D.decompose_polygon_in_convex(outline)
	if pieces.is_empty():


		var tris:= Geometry2D.triangulate_polygon(outline)
		for t in range(0, tris.size(), 3):
			pieces.append(PackedVector2Array([outline [tris [t]], outline [tris [t + 1]],
				outline [tris [t + 2]]]))
	for piece: PackedVector2Array in pieces:
		var points:= PackedVector3Array()
		for p: Vector2 in piece:
			points.append(Vector3(p.x, - INFILL_DROP, p.y))
			points.append(Vector3(p.x, - INFILL_DROP - INFILL_THICK, p.y))
		var hull:= ConvexPolygonShape3D.new()
		hull.points = points
		var cs:= CollisionShape3D.new()
		cs.shape = hull
		body.add_child(cs)
	return body


static func make_lane_area(lanes: Array, hub_r: float) -> Area3D:
	var area:= Area3D.new()
	area.name = "Sweep"
	area.collision_layer = 0
	area.collision_mask = Cfg.L_STRAND | (Cfg.L_BELT_CATCH
		if BeltPath.cargo_physics_enabled else Cfg.L_PROP)
	area.monitorable = false
	var cyl:= CylinderShape3D.new()
	cyl.radius = hub_r + MARGIN
	cyl.height = HEIGHT
	var hub:= CollisionShape3D.new()
	hub.shape = cyl
	hub.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	area.add_child(hub)
	for lane: Dictionary in lanes:
		var from: Vector3 = lane.get("from", Vector3.ZERO)
		var mouth: Vector3 = lane ["mouth"]
		var seg:= Vector3(mouth.x - from.x, 0.0, mouth.z - from.z)
		if seg.length_squared() < 1e-08:
			continue
		var box:= BoxShape3D.new()
		box.size = Vector3(Cfg.BELT_WIDTH + MARGIN * 2.0, HEIGHT, seg.length() + MARGIN * 2.0)
		var cs:= CollisionShape3D.new()
		cs.shape = box
		cs.transform = Transform3D(BeltPath.run_basis(from, from + seg),
			(from + mouth) * 0.5 + Vector3(0.0, HEIGHT * 0.5, 0.0))
		area.add_child(cs)
	return area


static func make_area(port_r: float) -> Area3D:
	var area:= Area3D.new()
	area.name = "Sweep"
	area.collision_layer = 0


	area.collision_mask = Cfg.L_STRAND | (Cfg.L_BELT_CATCH
		if BeltPath.cargo_physics_enabled else Cfg.L_PROP)
	area.monitorable = false
	var cyl:= CylinderShape3D.new()
	cyl.radius = port_r + MARGIN
	cyl.height = HEIGHT
	var cs:= CollisionShape3D.new()
	cs.shape = cyl
	cs.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	area.add_child(cs)
	return area


static func run(area: Area3D, module: Node3D, lanes: Array, drive: float,
		exit: Vector3 = Vector3.ZERO) -> Array:
	var moved: Array = []
	if area == null or not area.has_overlapping_bodies():
		return moved
	var to_local:= module.global_transform.affine_inverse()
	var basis:= module.global_basis
	for node in area.get_overlapping_bodies():
		var rb:= node as RigidBody3D


		if rb == null or rb.freeze or BeltPath.is_rider(rb):
			continue


		if float(rb.get_meta(BeltPath.META_QUEUE_BOUNCE, 0.0)) > Time.get_ticks_msec() * 0.001:
			continue


		if not rb.is_inside_tree():
			continue
		var prop:= bool(rb.collision_layer & Cfg.L_PROP)
		if not prop and not (rb.collision_layer & Cfg.L_STRAND):
			continue
		var p: Vector3 = to_local * rb.global_position
		p.y = 0.0
		var push:= Vector3.ZERO
		if prop and p.length() < JUNCTION and exit.length_squared() > 1e-06:


			push = exit.normalized() * drive
			moved.append(rb)
		else:
			var lane:= _nearest_lane(p, lanes)
			if lane.is_empty():
				continue
			var off: float = lane ["off"]
			var travel: Vector3 = lane ["travel"]
			if prop:


				push = travel * drive
				moved.append(rb)
			elif off > Cfg.BELT_RIDE_HALF_W:


				push = lane ["toward"] * ACROSS + travel * drive * ALONG
		if push == Vector3.ZERO:
			continue


		rb.sleeping = false


		var item:= rb as Carryable
		if item != null:
			item.unplant()
		var world_push: Vector3 = basis * push
		rb.linear_velocity = Vector3(world_push.x, rb.linear_velocity.y, world_push.z)
	return moved


static func _nearest_lane(p: Vector3, lanes: Array) -> Dictionary:
	var out:= { }
	var best:= INF
	for lane: Dictionary in lanes:
		var mouth: Vector3 = lane ["mouth"]
		var from: Vector3 = lane.get("from", Vector3.ZERO)
		var seg:= Vector3(mouth.x - from.x, 0.0, mouth.z - from.z)
		var dir:= seg.normalized()
		var q:= p - Vector3(from.x, 0.0, from.z)
		var along:= q.dot(dir)


		if along < 0.0 or along > seg.length():
			continue
		var across:= q - dir * along
		var off:= across.length()
		if off >= best:
			continue
		best = off
		out = {
			"off": off,
			"travel": (lane ["travel"] as Vector3).normalized(),
			"toward": - across.normalized() if off > 0.0001 else Vector3.ZERO,
		}
	return out
