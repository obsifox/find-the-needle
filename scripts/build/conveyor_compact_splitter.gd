class_name ConveyorCompactSplitter
extends ConveyorSplitter


const OUT_LEFT:= 0
const OUT_FORWARD:= 1
const OUT_RIGHT:= 2
const OUTPUTS:= [OUT_LEFT, OUT_FORWARD, OUT_RIGHT]

const RULE_ANY:= -1
const RULE_UNDEFINED:= -2
const RULE_OVERFLOW:= -3

const RULE_NONE:= -4


const DOOR_COLOURS:= [Color(0.95, 0.55, 0.12), Color(0.2, 0.62, 0.95),
	Color(0.35, 0.8, 0.3)]

const PORT_R:= 0.92

var smart:= false
var filters:= PackedInt32Array([RULE_ANY, RULE_ANY, RULE_ANY])
var _compact_model: Node3D

var _compact_stall:= [0.0, 0.0, 0.0]


var _compact_blocked_ago:= [STALL_SECONDS, STALL_SECONDS, STALL_SECONDS]


var _compact_hold:= [0.0, 0.0, 0.0]

var _compact_full:= [false, false, false]


static var fill_to_fork:= true
var _awaiting_choice:= true


func output_sides() -> Array:
	return OUTPUTS


func _build_model() -> void:
	var path:= "res://assets/models/compact_splitters/%s.glb" % (
		"SmartSplitter" if smart else "Splitter")
	var scene:= AssetFix.load_res(path) as PackedScene
	if scene == null:
		push_error("Compact splitter model is missing: %s" % path)
		return
	_compact_model = scene.instantiate() as Node3D
	_compact_model.name = "Model"
	add_child(_compact_model)
	var meshes:= _model_meshes()
	if not meshes.is_empty():
		_body = meshes [0]
	if placement_preview:
		for mesh in meshes:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func show_door_tags(on: bool) -> void:
	var old:= get_node_or_null("DoorTags")
	if old != null:
		old.queue_free()

		old.name = "DoorTagsGoing"
	if not on or not smart:
		return
	var box:= model_box()
	if box.size == Vector3.ZERO:
		return
	var tags:= DoorTags.new()
	tags.name = "DoorTags"
	add_child(tags)
	var centre:= box.get_center()
	for side in OUTPUTS:
		var out_dir:= [Vector3.LEFT, Vector3.FORWARD, Vector3.RIGHT] [side] as Vector3
		var half:= absf(out_dir.dot(box.size)) * 0.5
		var tag:= _door_number(side, 0.42)
		tag.position = Vector3(centre.x, box.end.y + 0.25, centre.z) + out_dir * (half + 0.15)
		tags.add(tag)
	refresh_door_tags()


func refresh_door_tags() -> void:
	var tags:= get_node_or_null("DoorTags")
	if tags == null:
		return
	for side in OUTPUTS:
		var tag:= tags.get_node_or_null("DoorNumber%d" % (side + 1)) as Label3D
		if tag != null:
			tag.text = str(side + 1) + ("\n×" if filters [side] == RULE_NONE else "")


class DoorTags extends Node3D:
	const BOB:= 0.06
	const FADE_IN:= 0.25
	var _t:= 0.0
	var _rest: Array [Vector3] = []

	func add(tag: Label3D) -> void:
		_rest.append(tag.position)
		tag.transparency = 1.0
		add_child(tag)

	func _process(delta: float) -> void:
		_t += delta
		var alpha:= clampf(_t / FADE_IN, 0.0, 1.0)
		for i in range(get_child_count()):
			var tag:= get_child(i) as Label3D
			tag.position = _rest [i] + Vector3.UP * sin(_t * 2.4 + i * 2.1) * BOB
			tag.transparency = 1.0 - alpha


func _relative_to_self(node: Node3D) -> Transform3D:
	var t:= Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != self:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _door_number(side: int, height: float) -> Label3D:
	var label:= Label3D.new()
	label.name = "DoorNumber%d" % (side + 1)
	label.text = str(side + 1)
	label.pixel_size = height / 96.0
	label.font_size = 96
	label.font = UiFont.bold()
	label.outline_size = 22
	label.modulate = DOOR_COLOURS [side]
	label.outline_modulate = Color(0.05, 0.05, 0.05)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED


	label.no_depth_test = true
	label.render_priority = 2
	label.shaded = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return label


func _model_meshes() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if _compact_model == null:
		return out
	for node in _compact_model.find_children("*", "MeshInstance3D", true, false):
		var mesh:= node as MeshInstance3D
		if mesh != null:
			out.append(mesh)
	return out


func _make_infill() -> MeshInstance3D:
	var hidden:= MeshInstance3D.new()
	hidden.name = "ModelOwnsDeck"
	return hidden


func _make_infill_body() -> StaticBody3D:
	var box:= model_box()
	if box.size == Vector3.ZERO:


		return WyeSweep.infill_body(_mouths())
	var body:= StaticBody3D.new()
	body.name = "Shell"
	body.collision_layer = Cfg.L_BUILD
	body.collision_mask = 0
	var shape:= BoxShape3D.new()
	shape.size = box.size
	var cs:= CollisionShape3D.new()
	cs.shape = shape
	cs.position = box.get_center()
	body.add_child(cs)
	return body


func model_box() -> AABB:
	var box:= AABB()
	var first:= true
	for mesh in _model_meshes():
		var part:= _relative_to_self(mesh) * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


func _make_sweep() -> Area3D:
	return WyeSweep.make_area(PORT_R)


func port_in() -> Vector3:
	return to_global(Vector3(0.0, 0.0, PORT_R))


func port_left() -> Vector3:
	return port(OUT_LEFT)


func port_right() -> Vector3:
	return port(OUT_RIGHT)


func port(side: int) -> Vector3:
	match side:
		OUT_LEFT:
			return to_global(Vector3(- PORT_R, 0.0, 0.0))
		OUT_RIGHT:
			return to_global(Vector3(PORT_R, 0.0, 0.0))
		_:
			return to_global(Vector3(0.0, 0.0, - PORT_R))


func ports() -> Array [Vector3]:
	return [port_in(), port(OUT_LEFT), port(OUT_FORWARD), port(OUT_RIGHT)]


func forward() -> Vector3:
	return (- global_basis.z).normalized()


func arm_travel(side: int) -> Vector3:
	return (port(side) - global_position).normalized()


func footprint() -> Array [Vector4]:
	var c:= global_position
	return [Vector4(c.x, c.y, c.z, PORT_R)]


func _mouths() -> Array:
	return [Vector3(0.0, 0.0, PORT_R), Vector3(- PORT_R, 0.0, 0.0),
		Vector3(0.0, 0.0, - PORT_R), Vector3(PORT_R, 0.0, 0.0)]


func _lanes() -> Array:
	return [
		{ "mouth": Vector3(0.0, 0.0, PORT_R), "travel": Vector3(0.0, 0.0, -1.0) },
		{ "mouth": Vector3(- PORT_R, 0.0, 0.0), "travel": Vector3(-1.0, 0.0, 0.0) },
		{ "mouth": Vector3(0.0, 0.0, - PORT_R), "travel": Vector3(0.0, 0.0, -1.0) },
		{ "mouth": Vector3(PORT_R, 0.0, 0.0), "travel": Vector3(1.0, 0.0, 0.0) },
	]


func _sweep_lanes() -> Array:
	return _lanes()


func _route_points(side: int) -> PackedVector3Array:
	return PackedVector3Array([port_in(), global_position, port(side)])


func _build_routes() -> void:
	for side in OUTPUTS:
		var route:= BeltPath.new()
		route.name = ["RouteLeft", "RouteForward", "RouteRight"] [side]
		route.records_props = true
		route.record_boost = route_boost
		add_child(route)
		route.build_path(_route_points(side), Cfg.BELT_JOINT_OVERLAP)
		route.set_belt_drawn(false)
		route.gathers_straw = true
		route.caught.connect(_on_caught.bind(side))
		route.caught_record.connect(_on_caught_record.bind(side))
		_routes [side] = route
	for side in OUTPUTS:
		var siblings: Array [BeltPath] = []
		for other in OUTPUTS:
			if other != side:
				siblings.append(_routes [other] as BeltPath)
		(_routes [side] as BeltPath).share_deck(siblings)
	_apply_catching()


func route(side: int) -> BeltPath:
	return _routes.get(side) as BeltPath


func routes() -> Array [BeltPath]:
	var out: Array [BeltPath] = []
	for side in OUTPUTS:
		var path:= route(side)
		if path != null:
			out.append(path)
	return out


func set_filter(side: int, rule: int) -> void:
	if side not in OUTPUTS:
		return
	filters [side] = rule
	refresh_door_tags()
	_awaiting_choice = true
	if _feeder != null:
		_feeder.set_outlet_held(true)


func filter_for(side: int) -> int:
	return filters [side] if side in OUTPUTS else RULE_ANY


func stuck_kind() -> int:
	if not smart or _feeder == null or not is_instance_valid(_feeder):
		return -1
	var kind:= _waiting_kind()
	if kind < 0 or not _feeder.has_load_waiting():
		return -1
	for side in OUTPUTS:
		if _door_takes(side, kind):
			return -1
	return kind


func _on_caught(_rb: RigidBody3D, side: int) -> void:
	_complete_turn(side)


func _on_caught_record(_seq: int, _kind: int, _strands: int, side: int) -> void:
	_complete_turn(side)


func _complete_turn(side: int) -> void:
	next_side = (side + 1) % OUTPUTS.size()
	_awaiting_choice = true
	if _feeder != null and is_instance_valid(_feeder):
		_feeder.set_outlet_held(true)
	_share_now()


func _share_now() -> void:
	_share_throat()


func _apply_catching() -> void:
	var chosen:= _choose_output(_waiting_kind())
	for side in OUTPUTS:
		var path:= route(side)
		if path != null:
			path.set_catching(side == chosen)
	_sync_feeder(chosen)


func _waiting_kind() -> int:
	if _feeder == null or not is_instance_valid(_feeder):
		return -1
	return _feeder.front_kind()


static func _is_loose(kind: int) -> bool:
	return kind < 0 or kind == BeltRun.Kind.TUFT


func _choose_output(kind: int) -> int:
	var exact: Array [int] = []
	var any: Array [int] = []
	var undefined: Array [int] = []
	var overflow: Array [int] = []


	var loose: Array [int] = []
	var explicitly_defined:= false
	for side in OUTPUTS:
		if filters [side] == kind and kind >= 0:
			explicitly_defined = true
	for side in OUTPUTS:
		var rule:= filters [side]
		if not smart:
			any.append(side)
		elif rule == kind and kind >= 0:
			exact.append(side)
		elif rule == RULE_ANY:
			any.append(side)
		elif rule == RULE_UNDEFINED and not explicitly_defined:
			undefined.append(side)
		elif rule == RULE_OVERFLOW:
			overflow.append(side)
		if smart and rule != RULE_NONE and _is_loose(kind):
			loose.append(side)
	var chosen:= _first_available(exact)
	if chosen < 0:
		chosen = _first_available(any)
	if chosen < 0:
		chosen = _first_available(undefined)
	if chosen < 0:
		chosen = _first_available(overflow)
	if chosen < 0:
		chosen = _first_available(loose)


	return chosen


func _first_available(candidates: Array [int]) -> int:
	for step in range(OUTPUTS.size()):
		var side:= (next_side + step) % OUTPUTS.size()
		if side in candidates and not _compact_stalled(side):
			return side
	return -1


func _compact_stalled(side: int) -> bool:
	var path:= route(side)
	if path == null:
		return true
	if not is_instance_valid(path.downstream):
		return true
	return _compact_stall [side] >= STALL_SECONDS or _compact_full [side]


func _compact_stuck(side: int) -> bool:
	var path:= route(side)
	if path == null or not is_instance_valid(path.downstream):
		return true
	return _compact_stall [side] >= STALL_SECONDS


func _tick_stalls(delta: float) -> void:
	_note_handed()
	for side in OUTPUTS:
		var backed:= _backed_up(side)
		_compact_stall [side] = minf(_compact_stall [side] + delta, STALL_SECONDS) if backed else 0.0
		if backed and _door_blocked(side):
			_compact_blocked_ago [side] = 0.0
			_compact_hold [side] = _front_edge(route(side))
		else:
			_compact_blocked_ago [side] = minf(_compact_blocked_ago [side] + delta, STALL_SECONDS)
		_compact_full [side] = _arm_full(side)


func _door_blocked(side: int) -> bool:
	var path:= route(side)
	if path == null or not is_instance_valid(path.downstream):
		return false
	var r:= path.downstream.run
	if r.count() == 0:
		return false
	var rear:= r.first() + r.count() - 1
	return r.speed_of(rear) < 0.05 and not r._room_at_start()


func _front_edge(path: BeltPath) -> float:
	var edge:= 0.0
	var loads:= path.lane_loads_before(INF)
	for k in range(0, loads.size(), 3):
		edge = maxf(edge, loads [k] + loads [k + 1])
	return edge


func _arm_full(side: int) -> bool:
	if not fill_to_fork or _compact_blocked_ago [side] >= STALL_SECONDS:
		return false
	var path:= route(side)
	if path == null:
		return false
	var edge: float = _compact_hold [side]
	var length:= 0.0
	var loads:= path.lane_loads_before(INF)
	for k in range(0, loads.size(), 3):
		edge = maxf(edge, loads [k] + loads [k + 1])
		length += 2.0 * loads [k + 1]
	return edge - length - 2.0 * _waiting_reach() < _throat_s()


func _waiting_reach() -> float:
	if _feeder == null or not is_instance_valid(_feeder) or _feeder.run.count() == 0:
		return 0.0
	return _feeder.run.reach_of(_feeder.run.first())


func _open_side() -> int:
	return _choose_output(_waiting_kind())


func _throat_s() -> float:
	if has_meta(&"_throat_s"):
		return float(get_meta(&"_throat_s"))
	var a:= route(OUT_LEFT)
	var b:= route(OUT_RIGHT)
	var fork:= 0.0
	if a != null and b != null:
		var s:= 0.0
		var total:= a.path_length()
		while s <= total:
			var p:= a._point_at(s)
			var q:= b._point_at(float(b._nearest(p) ["s"]))
			if p.distance_to(q) > 0.02:
				break
			fork = s
			s += 0.02
	set_meta(&"_throat_s", fork)
	return fork


func _share_throat() -> void:
	var fork:= _throat_s()
	if fork <= 0.0:
		return
	var on: Array [PackedFloat64Array] = []
	for side in OUTPUTS:
		var path:= route(side)
		on.append(path.lane_loads_before(fork) if path != null else PackedFloat64Array())
	for side in OUTPUTS:
		var path:= route(side)
		if path == null:
			continue
		var others:= PackedFloat64Array()
		for other in OUTPUTS:
			if other != side:
				others.append_array(on [other])
		path.set_foreign_loads(others)


func _door_takes(side: int, kind: int) -> bool:
	if not smart:
		return true
	var rule:= filters [side]
	if rule == RULE_ANY or rule == RULE_OVERFLOW:
		return true
	if rule == kind and kind >= 0:
		return true
	if rule == RULE_UNDEFINED:

		for other in OUTPUTS:
			if filters [other] == kind and kind >= 0:
				return false
		return true


	if _is_loose(kind):
		return rule != RULE_NONE
	return false


func _unjam_throat() -> void:
	var open:= _open_side()
	if open < 0:
		return
	var onto:= route(open)
	if onto == null or not onto._catching:
		return
	var fork:= _throat_s()
	for shut in OUTPUTS:
		if shut == open:
			continue
		var from:= route(shut)
		if from == null or from._catching or not from.has_load_waiting():
			continue


		var stuck:= _compact_stuck(shut)
		if not stuck and not _compact_full [shut]:
			continue
		var r:= from.run
		while r.count() > 1:
			var rear:= r.first() + r.count() - 1
			var s:= r.s_of(rear)


			if not stuck and r.speed_of(rear) > 0.05:
				break


			if s - r.reach_of(rear) >= fork:
				break
			if not _door_takes(open, r.kind_of(rear)):
				break
			var at:= float(onto._nearest(from._point_at(s)) ["s"])
			var rec:= r.remove_at(rear)
			if _board_across(onto.run, rec, at):
				onto.wake()
				continue


			r.catching = true
			var put:= r.board_record(rec, s, 0.0, false)
			r.catching = false
			if not put:

				push_warning("%s: unjam could not put seq %d back" % [name, int(rec.get("seq", -1))])
				from._spawn_record(rec, s)
			break
		_share_now()


func _board_across(onto: BeltRun, rec: Dictionary, at: float) -> bool:
	if onto.board_record(rec, at, 0.0, false):
		return true
	var reach:= float(rec ["reach"])
	var k:= onto._row_behind(at)
	if k >= onto.first() + onto.count():
		return false
	var clear:= onto.s_of(k) + maxf(onto.gap_of(k), reach + onto.reach_of(k))
	if clear <= at or clear - at > reach:
		return false
	return onto.board_record(rec, clear + 0.001, 0.0, false)


func _sync_feeder(open: int = -2) -> void:
	if _feeder == null or not is_instance_valid(_feeder):
		return
	var side:= _choose_output(_waiting_kind()) if open == -2 else open


	_feeder.downstream = route(side if side >= 0 else next_side)


func set_feeder(run: BeltPath) -> void:
	_feeder = run
	_awaiting_choice = true
	if _feeder != null:
		_feeder.set_outlet_held(true)
	_sync_feeder()


func factory_tick(delta: float) -> void:
	_tick_stalls(delta)
	_apply_catching()
	_unjam_throat()
	_share_throat()
	_refresh_held()
	var side:= _open_side()

	if _sweep != null and _sweep.has_overlapping_bodies():
		WyeSweep.run(_sweep, self, _sweep_lanes(), Cfg.BELT_SPEED,
			arm_travel(side) if side >= 0 else forward())
	if _feeder != null and is_instance_valid(_feeder):
		_feeder.set_outlet_held(side < 0)
	_awaiting_choice = false


func _show_held() -> void:
	pass


func refresh_supports() -> void:
	pass


func set_preview_valid(valid: bool) -> void:
	if not placement_preview:
		return
	var material:= ConveyorKit.ghost_material(valid)
	for mesh in _model_meshes():
		mesh.material_overlay = material


func has_panel() -> bool:
	return smart


func mode_label() -> String:
	if not smart:
		return tr("all three doors, taking turns")
	return tr("each door by its own rule")


func build_cost() -> float:
	return Cfg.SMART_SPLITTER_COST if smart else Cfg.COMPACT_SPLITTER_COST


func to_dict() -> Dictionary:
	return {
		"type": "conveyor_smart_splitter" if smart else "conveyor_compact_splitter",
		"position": global_position,
		"yaw": global_rotation.y,
		"next_side": int(next_side),
		"filters": Array(filters),
	}
