class_name Roof
extends StaticBody3D


enum Kind { FLAT, PITCHED, HATCH }


var placement_preview:= false


static var _keep_empty_mm:= "--keepemptymm" in OS.get_cmdline_user_args()

var kind: Kind = Kind.FLAT
var a:= Vector3.ZERO
var b:= Vector3.ZERO


var side:= 1
var length:= 0.0
var bays:= 0


var rows:= 1


var paid_cost:= -1.0

var _sheets: MultiMeshInstance3D
var _ends: MultiMeshInstance3D
var _rafters: MultiMeshInstance3D
var _purlins: MultiMeshInstance3D
var _ladder: Node3D
var _volume: Area3D


var shared_rafters:= PackedInt32Array()
var _built:= { "a": Vector3.INF, "b": Vector3.INF, "kind": Kind.FLAT,
	"side": 0, "rows": 0 }
var _ladder_origin:= Vector3(NAN, NAN, NAN)
var _ladder_drop:= 0.0
var _shapes: Array [CollisionShape3D] = []
var _preview_valid:= true


var deck_style:= false


static func bays_for(metres: float) -> int:
	return clampi(int(round(absf(metres) / Cfg.ROOF_BAY)),
		int(Cfg.ROOF_MIN_LENGTH / Cfg.ROOF_BAY),
		int(Cfg.ROOF_MAX_LENGTH / Cfg.ROOF_BAY))


static func end_for(from: Vector3, to: Vector3, of_kind: Kind = Kind.FLAT) -> Vector3:
	var flat:= Vector3(to.x - from.x, 0.0, to.z - from.z)
	var span:= flat.length()
	if span < 0.0001:
		return from
	var n:= 1 if of_kind == Kind.HATCH else bays_for(span)
	return from + flat / span * (float(n) * Cfg.ROOF_BAY)


static func cost_for(from: Vector3, to: Vector3, of_kind: Kind,
		deep: int = 1) -> float:
	var run:= from.distance_to(end_for(from, to, of_kind))
	var price:= run * Cfg.ROOF_COST_PER_M * float(maxi(1, deep))
	if of_kind == Kind.HATCH:
		price += Cfg.ROOF_HATCH_COST
	return price * Tech.build_cost_scale()


func build_cost() -> float:
	if paid_cost >= 0.0:
		return paid_cost
	return _price_now()


func _price_now() -> float:
	var price:= length * Cfg.ROOF_COST_PER_M * float(maxi(1, rows))
	if kind == Kind.HATCH:
		price += Cfg.ROOF_HATCH_COST
	return price * Tech.build_cost_scale()


func pitched() -> bool:
	return kind == Kind.PITCHED


func depth() -> float:
	return Cfg.ROOF_DEPTH * float(maxi(1, rows))


func rise() -> float:
	return Cfg.ROOF_RISE * float(maxi(1, rows)) if pitched() else 0.0


func setup(from: Vector3, to: Vector3, of_kind: Kind, to_side: int,
		deep: int = 1) -> void:
	a = from
	b = end_for(from, to, of_kind)
	length = a.distance_to(b)
	bays = maxi(1, int(round(length / Cfg.ROOF_BAY))) if length > 1e-06 else 0
	kind = of_kind
	side = -1 if to_side < 0 else 1


	rows = 1 if of_kind == Kind.HATCH else maxi(1, deep)


	paid_cost = _price_now()


func _ready() -> void:
	collision_layer = 0 if placement_preview else Cfg.L_BUILD
	collision_mask = 0
	_build_model()
	if placement_preview:
		set_preview_valid(true)


	call_deferred("refresh_ladder")


func set_shape(from: Vector3, to: Vector3) -> void:
	var end:= end_for(from, to, kind)
	if a.is_equal_approx(from) and b.is_equal_approx(end):
		return
	setup(from, to, kind, side)
	_build_model()
	if placement_preview:
		set_preview_valid(_preview_valid)


func set_kind(to_kind: Kind) -> void:
	if kind == to_kind:
		return
	kind = to_kind


	b = end_for(a, b, kind)
	length = a.distance_to(b)
	bays = maxi(1, int(round(length / Cfg.ROOF_BAY))) if length > 1e-06 else 0
	_built ["a"] = Vector3.INF
	_build_model()
	if placement_preview:
		set_preview_valid(_preview_valid)


func set_rows(deep: int) -> void:
	var want:= 1 if kind == Kind.HATCH else maxi(1, deep)
	if rows == want:
		return
	rows = want
	_built ["a"] = Vector3.INF
	_build_model()
	if placement_preview:
		set_preview_valid(_preview_valid)


func set_side(to_side: int) -> void:
	var want:= -1 if to_side < 0 else 1
	if side == want:
		return
	side = want
	_built ["a"] = Vector3.INF
	_build_model()
	if placement_preview:
		set_preview_valid(_preview_valid)


func covers(point: Vector3) -> bool:
	if absf(point.y - a.y) > 0.05 or length < 1e-06:
		return false
	var along:= (b - a) / length
	var t:= (point - a).dot(along)
	if t < - Cfg.ROOF_BAY * 0.5 or t > length + Cfg.ROOF_BAY * 0.5:
		return false
	return (point - (a + along * clampf(t, 0.0, length))).length() < 0.4


func supports_point(point: Vector3) -> bool:
	if length < 1e-06:
		return false
	var local:= global_transform.affine_inverse() * point
	var out:= local.x * float(side)
	if out < -0.05 or out > depth() + 0.05:
		return false
	if absf(local.z) > length * 0.5 + 0.05:
		return false
	var surface:= out * rise() / depth()
	var above:= local.y - surface
	return above >= -0.1 and above <= Cfg.PLATFORM_RAIL_H


func rafter_keys() -> PackedStringArray:
	var out:= PackedStringArray()
	if length < 1e-06:
		return out
	var dir:= (b - a) / length
	var reach:= Vector3(dir.z, 0.0, - dir.x) * float(side)
	var way:= Vector3i((reach * 100.0).round())
	var joints:= joint_points()
	for joint in joints:
		var at:= Vector3i((joint * 100.0).round())
		for row in rows:
			out.append("%s|%s|%d|%d" % [at, way, row, int(pitched())])
	return out


func set_shared_rafters(skip: PackedInt32Array) -> void:
	if skip == shared_rafters:
		return
	shared_rafters = skip
	_built ["a"] = Vector3.INF
	_build_model()


func joint_points() -> Array [Vector3]:
	var out: Array [Vector3] = []
	if length < 1e-06:
		out.append(a)
		return out
	var n:= maxi(1, bays)
	for i in n + 1:
		out.append(a.lerp(b, float(i) / float(n)))
	return out


func _tilt() -> Basis:
	if not pitched():
		return Basis()
	return Basis(Vector3.BACK, StructureKit.roof_pitch() * float(side))


func _sheet_centre(along: float, row: int = 0) -> Vector3:
	var out:= Cfg.ROOF_DEPTH * (float(row) + 0.5)
	var up:= Cfg.ROOF_RISE * (float(row) + 0.5) if pitched() else 0.0
	return Vector3(float(side) * out, up, along)


func _hatch_strips() -> Array:
	var d:= Cfg.ROOF_DEPTH
	var hole:= Cfg.ROOF_HATCH
	var margin:= StructureKit.roof_hatch_margin()
	var s:= float(side)
	var out: Array = []
	for across: float in [margin * 0.5, d - margin * 0.5]:
		out.append({
			"across": margin,
			"along": Cfg.ROOF_BAY,
			"at": Vector3(s * across, 0.0, 0.0),
		})
	for along: float in [-1.0, 1.0]:
		out.append({
			"across": hole,
			"along": margin,
			"at": Vector3(s * d * 0.5, 0.0,
				along * (Cfg.ROOF_BAY - margin) * 0.5),
		})
	return out


func surround_points() -> Array [Vector3]:
	var out: Array [Vector3] = []
	var centre:= Vector3(float(side) * Cfg.ROOF_DEPTH * 0.5, 0.0, 0.0)
	var reach_x:= Cfg.ROOF_DEPTH * 0.5 + 0.5
	var reach_z:= Cfg.ROOF_BAY * 0.5 + 0.5
	for step: Vector3 in [Vector3(reach_x, 0.0, 0.0), Vector3(- reach_x, 0.0, 0.0),
			Vector3(0.0, 0.0, reach_z), Vector3(0.0, 0.0, - reach_z)]:
		out.append(to_global(centre + step))
	return out


func covers_point(point: Vector3) -> bool:
	var p:= to_local(point)
	var half:= maxf(length, Cfg.ROOF_BAY) * 0.5
	if absf(p.z) > half:
		return false
	var out:= p.x * float(side)
	if out < 0.0 or out > Cfg.ROOF_DEPTH * float(rows):
		return false
	var surface:= out * Cfg.ROOF_RISE / Cfg.ROOF_DEPTH if pitched() else 0.0
	return absf(p.y - surface) < 0.25


func set_deck_style(on: bool) -> void:
	if deck_style == on:
		return
	deck_style = on
	if kind == Kind.HATCH:
		_build_model()


func _build_model() -> void:
	if a.is_equal_approx(_built ["a"]) and b.is_equal_approx(_built ["b"]) and _built ["kind"] == kind and int(_built ["side"]) == side and _built.get("deck", false) == deck_style and _sheets != null:
		return
	_built = { "a": a, "b": b, "kind": kind, "side": side, "deck": deck_style }


	global_position = (a + b) * 0.5
	global_rotation = Vector3(0.0, _yaw(), 0.0)


	var n:= maxi(1, bays)
	var half:= maxf(length, Cfg.ROOF_BAY) * 0.5
	var tilt:= _tilt()

	var sheets: Array [Transform3D] = []
	var ends: Array [Transform3D] = []
	if kind == Kind.HATCH:


		var strips:= _hatch_strips()
		for i in 4:
			var strip: Dictionary = strips [i]
			var at:= Transform3D(Basis(), strip ["at"] as Vector3)
			if i < 2:
				sheets.append(at)
			else:
				ends.append(at)
	else:


		for i in n:
			for row in rows:
				sheets.append(Transform3D(tilt,
					_sheet_centre(- half + Cfg.ROOF_BAY * (float(i) + 0.5), row)))


	var rafters: Array [Transform3D] = []
	for i in n + 1:
		for row in rows:
			if shared_rafters.has(i * rows + row):
				continue
			rafters.append(Transform3D(tilt,
				_sheet_centre(- half + Cfg.ROOF_BAY * float(i), row)))


	var purlins: Array [Transform3D] = []
	var inset:= StructureKit.BEAM_WIDTH * 0.5
	for i in n:
		var along:= - half + Cfg.ROOF_BAY * (float(i) + 0.5)
		purlins.append(Transform3D(Basis(),
			Vector3(float(side) * inset, 0.0, along)))
		for row in rows:
			var out:= Cfg.ROOF_DEPTH * float(row + 1)
			var up:= Cfg.ROOF_RISE * float(row + 1) if pitched() else 0.0
			purlins.append(Transform3D(Basis(), Vector3(
				float(side) * (out - inset), up, along)))

	var plate:= deck_style and kind == Kind.HATCH
	var sheet_mesh:= StructureKit.roof_hatch_side_mesh(plate) if kind == Kind.HATCH else StructureKit.roof_sheet_mesh(pitched())
	_sheets = _fit(_sheets, "Sheets", sheet_mesh, sheets)
	_ends = _fit(_ends, "HatchEnds", StructureKit.roof_hatch_end_mesh(plate), ends)
	_rafters = _fit(_rafters, "Rafters", StructureKit.roof_rafter_mesh(pitched()), rafters)
	_purlins = _fit(_purlins, "Purlins", StructureKit.beam_mesh(), purlins)

	if placement_preview:
		for node in [_sheets, _ends, _rafters, _purlins]:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		_build_collision(n, half)


	_ladder_origin = Vector3(NAN, NAN, NAN)
	if is_inside_tree():
		refresh_ladder()


func _fit(node: MultiMeshInstance3D, node_name: String, mesh: Mesh,
		instances: Array [Transform3D]) -> MultiMeshInstance3D:
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = instances.size()
	for i in instances.size():
		mm.set_instance_transform(i, instances [i])


	var shown:= _keep_empty_mm or not instances.is_empty()
	if node != null:
		node.multimesh = mm
		node.visible = shown
		return node
	var made:= MultiMeshInstance3D.new()
	made.name = node_name
	made.multimesh = mm
	made.visible = shown
	add_child(made)
	return made


func _build_collision(n: int, half: float) -> void:
	for shape in _shapes:
		remove_child(shape)
		shape.queue_free()
	_shapes.clear()
	if n <= 0:
		return
	var thick:= Cfg.ROOF_COLLIDER_THICK
	var tilt:= _tilt()
	if kind != Kind.HATCH:


		var mid:= (float(rows) - 1.0) * 0.5
		var centre:= _sheet_centre(0.0, 0) + tilt.x * (StructureKit.roof_run(pitched()) * mid * float(side)) - tilt.y * (thick * 0.5)
		_add_shape(Vector3(StructureKit.roof_run(pitched()) * float(rows),
			thick, half * 2.0), Transform3D(tilt, centre))
		return


	for strip: Dictionary in _hatch_strips():
		_add_shape(Vector3(strip ["across"], thick, strip ["along"]),
			Transform3D(Basis(), (strip ["at"] as Vector3)
				- Vector3(0.0, thick * 0.5, 0.0)))


func _add_shape(size: Vector3, at: Transform3D) -> void:
	var box:= BoxShape3D.new()
	box.size = size
	var shape:= CollisionShape3D.new()
	shape.name = "RoofCollision%d" % _shapes.size()
	shape.shape = box
	shape.transform = at
	add_child(shape)
	_shapes.append(shape)


func _yaw() -> float:
	var dir:= b - a
	if absf(dir.x) < 1e-06 and absf(dir.z) < 1e-06:
		return 0.0
	return atan2(dir.x, dir.z)


func _ladder_x() -> float:
	return _ladder_x_for(side)


static func _ladder_x_for(to_side: int) -> float:
	return float(to_side) * (Cfg.ROOF_DEPTH - (Cfg.ROOF_DEPTH - Cfg.ROOF_HATCH) * 0.5)


static func hatch_drop_points(from: Vector3, to: Vector3, to_side: int) -> Array [Vector3]:
	var end:= end_for(from, to, Kind.HATCH)
	var dir:= end - from
	dir.y = 0.0
	var out: Array [Vector3] = []
	if dir.length_squared() < 1e-06:
		return out
	dir = dir.normalized()
	var right:= Vector3(dir.z, 0.0, - dir.x)
	var mid:= (from + end) * 0.5
	var s:= -1 if to_side < 0 else 1
	out.append(mid + right * _ladder_x_for(s))
	out.append(mid + right * (float(s) * Cfg.ROOF_DEPTH * 0.5))
	return out


func ladder_face() -> Vector3:
	return - global_transform.basis.x.normalized() * float(side)


func ladder_stand_point() -> Vector3:
	return to_global(Vector3(_ladder_x(), 0.0, 0.0)) + ladder_face() * 0.4


func ladder_exit_point() -> Vector3:
	var margin:= (Cfg.ROOF_DEPTH - Cfg.ROOF_HATCH) * 0.5
	return to_global(Vector3(float(side) * (Cfg.ROOF_DEPTH - margin * 0.5),
		0.0, 0.0))


func ladder_top_y() -> float:
	return global_position.y


func has_ladder() -> bool:
	return kind == Kind.HATCH and _ladder_drop > 0.1


func ladder_foot_y() -> float:
	return ladder_top_y() - _ladder_drop


func ladder_catches_a_fall() -> bool:
	return false


func refresh_ladder(force:= false) -> void:
	if not is_inside_tree():
		return
	if not force and global_position.is_equal_approx(_ladder_origin) and _ladder != null:
		return
	_ladder_origin = global_position


	if _ladder != null:
		remove_child(_ladder)
		_ladder.queue_free()
		_ladder = null
	_volume = null
	_ladder_drop = 0.0
	if kind != Kind.HATCH:
		return

	var top:= to_global(Vector3(_ladder_x(), 0.0, 0.0))
	var drop:= Cfg.LADDER_MAX_DROP
	var space:= get_world_3d().direct_space_state
	var q:= PhysicsRayQueryParameters3D.create(top,
		top - Vector3(0.0, Cfg.LADDER_MAX_DROP, 0.0))
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD


	q.exclude = [get_rid()]
	var hit:= space.intersect_ray(q)
	if not hit.is_empty():
		drop = maxf(0.0, top.y - (hit ["position"] as Vector3).y)
	_ladder_drop = drop

	_ladder = Node3D.new()
	_ladder.name = "Ladder"
	add_child(_ladder)
	if drop < 0.1:
		return

	var stiles: Array [Transform3D] = []
	var half_w:= (Cfg.LADDER_WIDTH - Cfg.LADDER_STILE) * 0.5
	for z: float in [- half_w, half_w]:


		stiles.append(Transform3D(Basis().scaled(Vector3(1.0, drop, 1.0)),
			Vector3(_ladder_x(), 0.0, z)))
		stiles.append(Transform3D(Basis().scaled(Vector3(1.0, Cfg.LADDER_GRAB_H, 1.0)),
			Vector3(_ladder_x(), Cfg.LADDER_GRAB_H, z)))
	var rungs: Array [Transform3D] = []


	var across:= Basis(Vector3.UP, PI * 0.5)
	var count:= int(drop / Cfg.LADDER_RUNG_SPACING)
	for i in count:
		rungs.append(Transform3D(across, Vector3(_ladder_x(),
			- Cfg.LADDER_RUNG_SPACING * (float(i) + 0.5), 0.0)))
	_ladder.add_child(_mm("Stiles", StructureKit.ladder_stile_mesh(), stiles))
	_ladder.add_child(_mm("Rungs", StructureKit.ladder_rung_mesh(), rungs))
	if placement_preview:
		return


	_volume = Area3D.new()
	_volume.name = "LadderVolume"
	_volume.collision_layer = 0
	_volume.collision_mask = Cfg.L_PLAYER
	_volume.monitoring = true
	var box:= BoxShape3D.new()
	box.size = Vector3(0.7, drop + Cfg.LADDER_GRAB_H, Cfg.LADDER_WIDTH + 0.2)
	var shape:= CollisionShape3D.new()
	shape.name = "LadderReach"
	shape.shape = box
	shape.position = Vector3(_ladder_x() - float(side) * 0.35,
		(Cfg.LADDER_GRAB_H - drop) * 0.5, 0.0)
	_volume.add_child(shape)
	_ladder.add_child(_volume)
	_volume.body_entered.connect(_on_climber_entered)
	_volume.body_exited.connect(_on_climber_exited)


func _on_climber_entered(body: Node3D) -> void:
	if body.has_method("enter_ladder"):
		body.enter_ladder(self)


func _on_climber_exited(body: Node3D) -> void:
	if body.has_method("exit_ladder"):
		body.exit_ladder(self)


func _mm(mm_name: String, mesh: Mesh,
		instances: Array [Transform3D]) -> MultiMeshInstance3D:
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = instances.size()
	for i in instances.size():
		mm.set_instance_transform(i, instances [i])
	var made:= MultiMeshInstance3D.new()
	made.name = mm_name
	made.multimesh = mm
	if placement_preview:
		made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		made.material_override = ConveyorKit.ghost_material(_preview_valid)
	return made


func set_preview_valid(valid: bool) -> void:
	if not placement_preview:
		return
	_preview_valid = valid
	var material:= ConveyorKit.ghost_material(valid)
	for node in [_sheets, _ends, _rafters, _purlins]:
		if node != null:
			node.material_override = material
	if _ladder == null:
		return
	for child in _ladder.get_children():
		var mmi:= child as MultiMeshInstance3D
		if mmi != null:
			mmi.material_override = material


func to_dict() -> Dictionary:
	return {
		"type": "roof",
		"a": a,
		"b": b,
		"kind": int(kind),
		"side": side,
		"rows": rows,
		"paid": build_cost(),
	}
