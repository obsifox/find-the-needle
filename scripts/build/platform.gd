class_name Platform
extends StaticBody3D


var placement_preview:= false


static var _keep_empty_mm:= "--keepemptymm" in OS.get_cmdline_user_args()

var span:= Vector2(Cfg.PLATFORM_TILE, Cfg.PLATFORM_TILE)


var paid_cost:= -1.0

var _deck_mm: MultiMeshInstance3D
var _beam_mm: MultiMeshInstance3D
var _supports: Node3D
var _collision: CollisionShape3D
var _shape: BoxShape3D
var _built_span:= Vector2.ZERO
var _support_origin:= Vector3(NAN, NAN, NAN)
var _preview_valid:= true


var _leg_points:= PackedVector2Array()
var _legs_assigned:= false


static func tiles_across(metres: float) -> int:
	return maxi(1, int(round(metres / Cfg.PLATFORM_TILE)))


static func quantise(metres: float) -> float:
	var tiles:= tiles_across(clampf(absf(metres),
		Cfg.PLATFORM_MIN_SPAN, Cfg.PLATFORM_MAX_SPAN))
	return float(tiles) * Cfg.PLATFORM_TILE


static func cost_for(deck_span: Vector2) -> float:
	return deck_span.x * deck_span.y * Cfg.PLATFORM_COST_PER_M2 * Tech.build_cost_scale()


func build_cost() -> float:
	if paid_cost >= 0.0:
		return paid_cost
	return cost_for(span)


func setup(top_centre: Vector3, deck_span: Vector2) -> void:
	position = top_centre
	span = deck_span


	paid_cost = cost_for(span)


func _ready() -> void:
	collision_layer = 0 if placement_preview else Cfg.L_BUILD
	collision_mask = 0
	_build_model()
	if placement_preview:
		set_preview_valid(true)


	call_deferred("refresh_supports")


func set_shape(top_centre: Vector3, deck_span: Vector2) -> void:
	var moved:= not position.is_equal_approx(top_centre)
	var resized:= not span.is_equal_approx(deck_span)
	if not moved and not resized:
		return
	position = top_centre
	span = deck_span
	if resized:
		_build_model()
		if placement_preview:
			set_preview_valid(_preview_valid)
	if is_inside_tree():
		refresh_supports()


func top_y() -> float:
	return global_position.y


func footprint() -> Rect2:
	return Rect2(Vector2(global_position.x - span.x * 0.5,
		global_position.z - span.y * 0.5), span)


func supports_point(point: Vector3) -> bool:
	var rise:= point.y - top_y()
	if rise < -0.05 or rise > Cfg.PLATFORM_RAIL_H:
		return false
	return footprint().has_point(Vector2(point.x, point.z))


func nearest_edge(from: Vector3) -> Dictionary:
	var rect:= footprint()
	var here:= Vector2(from.x, from.z)
	var best:= INF
	var point:= Vector2.ZERO
	var outward:= Vector3.BACK

	for edge in 4:
		var along_z:= edge < 2
		var candidate: Vector2
		var away: Vector3
		if along_z:
			var at: float = rect.position.x if edge == 0 else rect.end.x
			candidate = Vector2(at, clampf(here.y, rect.position.y, rect.end.y))
			away = Vector3(-1.0 if edge == 0 else 1.0, 0.0, 0.0)
		else:
			var at: float = rect.position.y if edge == 2 else rect.end.y
			candidate = Vector2(clampf(here.x, rect.position.x, rect.end.x), at)
			away = Vector3(0.0, 0.0, -1.0 if edge == 2 else 1.0)
		var d:= here.distance_squared_to(candidate)
		if d >= best:
			continue
		best = d
		point = candidate
		outward = away
	return {
		"point": Vector3(point.x, top_y(), point.y),
		"outward": outward,
	}


func _build_model() -> void:
	if is_equal_approx(_built_span.x, span.x) and is_equal_approx(_built_span.y, span.y) and _deck_mm != null:
		return
	_built_span = span
	var nx:= tiles_across(span.x)
	var nz:= tiles_across(span.y)
	var half:= Vector2(span.x, span.y) * 0.5

	var decks: Array [Transform3D] = []
	for i in nx:
		for j in nz:
			decks.append(Transform3D(Basis(), Vector3(
				- half.x + Cfg.PLATFORM_TILE * (i + 0.5), 0.0,
				- half.y + Cfg.PLATFORM_TILE * (j + 0.5))))


	var beams: Array [Transform3D] = []
	var inset:= StructureKit.BEAM_WIDTH * 0.5


	var across:= Basis(Vector3.UP, PI * 0.5)
	for side: float in [-1.0, 1.0]:
		for j in nz:
			beams.append(Transform3D(Basis(), Vector3(
				(half.x - inset) * side, 0.0,
				- half.y + Cfg.PLATFORM_TILE * (j + 0.5))))
		for i in nx:
			beams.append(Transform3D(across, Vector3(
				- half.x + Cfg.PLATFORM_TILE * (i + 0.5), 0.0,
				(half.y - inset) * side)))

	_deck_mm = _replace_mm(_deck_mm, "Deck", StructureKit.deck_mesh(), decks)
	_beam_mm = _replace_mm(_beam_mm, "Beams", StructureKit.beam_mesh(), beams)

	if placement_preview:
		return


	if _shape == null:
		_shape = BoxShape3D.new()
		_collision = CollisionShape3D.new()
		_collision.name = "DeckCollision"
		_collision.shape = _shape
		add_child(_collision)
	_shape.size = Vector3(span.x, Cfg.PLATFORM_THICK, span.y)
	_collision.position.y = - Cfg.PLATFORM_THICK * 0.5


func _replace_mm(existing: MultiMeshInstance3D, mm_name: String, mesh: Mesh,
		xforms: Array [Transform3D]) -> MultiMeshInstance3D:
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms [i])
	var mmi:= MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	if placement_preview:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func refresh_supports(force:= false) -> void:
	if not is_inside_tree():
		return


	if not force and global_position.is_equal_approx(_support_origin) and _supports != null:
		return
	_support_origin = global_position
	if _supports != null:
		remove_child(_supports)
		_supports.queue_free()
		_supports = null

	var space:= get_world_3d().direct_space_state
	var legs: Array [Transform3D] = []
	var feet: Array [Transform3D] = []
	var under:= - Cfg.PLATFORM_THICK
	for top in _leg_tops():
		var from:= global_position + top + Vector3(0.0, under, 0.0)
		var q:= PhysicsRayQueryParameters3D.create(from,
			from - Vector3(0.0, Cfg.PLATFORM_LEG_MAX_DROP, 0.0))
		q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD


		q.exclude = [get_rid()]
		var hit:= space.intersect_ray(q)
		if hit.is_empty():
			continue
		var ground: Vector3 = hit ["position"]
		var drop: float = from.y - ground.y
		if drop < 0.05:
			continue


		legs.append(Transform3D(Basis().scaled(Vector3(1.0, drop, 1.0)), from))
		feet.append(Transform3D(Basis(), ground))

	_supports = Node3D.new()
	_supports.name = "Supports"


	_supports.top_level = true
	add_child(_supports)


	if legs.is_empty() and not _keep_empty_mm:
		return
	_supports.add_child(_leg_mm("Legs", StructureKit.leg_mesh(), legs))
	_supports.add_child(_leg_mm("Feet", StructureKit.foot_mesh(), feet))


func set_leg_points(points: PackedVector2Array) -> bool:
	if _legs_assigned and points == _leg_points:
		return false
	_leg_points = points
	_legs_assigned = true
	return true


func _leg_tops() -> Array [Vector3]:
	var out: Array [Vector3] = []
	if _legs_assigned:
		for p in _leg_points:
			out.append(Vector3(p.x - global_position.x, 0.0, p.y - global_position.z))
		return out
	for x in _leg_axis(span.x):
		for z in _leg_axis(span.y):
			out.append(Vector3(x, 0.0, z))
	return out


static func leg_grid(rect: Rect2) -> PackedVector2Array:
	var out:= PackedVector2Array()
	var centre:= rect.get_center()
	for x in _leg_axis(rect.size.x):
		for z in _leg_axis(rect.size.y):
			out.append(centre + Vector2(x, z))
	return out


static func _leg_axis(extent: float) -> PackedFloat32Array:
	var usable:= maxf(0.0, extent - Cfg.PLATFORM_LEG_INSET * 2.0)
	var n:= maxi(1, int(round(usable / Cfg.PLATFORM_LEG_SPACING)))
	var out:= PackedFloat32Array()
	for i in n + 1:
		out.append(- usable * 0.5 + usable * (float(i) / float(n)))
	return out


func _leg_mm(mm_name: String, mesh: Mesh,
		xforms: Array [Transform3D]) -> MultiMeshInstance3D:
	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms [i])
	var mmi:= MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	if placement_preview:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.material_override = ConveyorKit.ghost_material(_preview_valid)
	return mmi


func set_preview_valid(valid: bool) -> void:
	if not placement_preview:
		return
	_preview_valid = valid
	var material:= ConveyorKit.ghost_material(valid)
	for node in [_deck_mm, _beam_mm]:
		if node != null:
			node.material_override = material
	if _supports == null:
		return
	for child in _supports.get_children():
		var mmi:= child as MultiMeshInstance3D
		if mmi != null:
			mmi.material_override = material


func to_dict() -> Dictionary:
	return {
		"type": "platform",
		"position": position,
		"span": span,
		"paid": build_cost(),
	}
