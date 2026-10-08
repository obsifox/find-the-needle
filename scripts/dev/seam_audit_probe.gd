class_name DevSeamAuditProbe
extends Node


var world: Node3D
var player: Player

const WATCH_SECONDS:= 60.0

const FOLLOW_TICKS:= 180

const FALL_DROP:= 1.0

var _ticks:= 0

var _following:= { }
var _drops:= { }
var _fell:= 0
var _landed:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	player = world.player
	world.block_save = true
	BeltPath.debug_props = true
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--seamaudit")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		print("SEAMAUDIT: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	var f:= SaveManager.open_for_read(path)
	var d: Dictionary = f.get_var(true)
	f.close()
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)


	var saved_ranks: Dictionary = (d.get("tech", { }) as Dictionary).get("ranks", { })
	print("SEAMAUDIT: tree has belt_speed %s, max rank %d, saved rank %s" % [
		str(TechTree.has_id("belt_speed")), TechTree.max_rank("belt_speed"),
		str(saved_ranks.get("belt_speed"))])
	var heights: PackedFloat32Array = d.get("heights", PackedFloat32Array())
	if heights.size() > 0:
		world.field.generate(int(GameState.run_seed), heights)
		GameState.from_dict(d.get("state", { }))


	if int(saved_ranks.get("belt_speed", 0)) > 0:
		Tech.ranks ["belt_speed"] = int(saved_ranks ["belt_speed"])


	BeltRunBatch.draw_headless = true
	_batch = BeltRunBatch.new()
	_batch.name = "SeamAuditBatch"
	world.add_child(_batch)
	world.builds.from_array(d.get("buildings", []))
	world.props.from_array(d.get("props", []))
	if world.props.items.size() > Cfg.prop_cap:
		Cfg.prop_cap = world.props.items.size()
	var belts: Dictionary = d.get("belts", { })
	var back:= { }
	var before_restore: Array = world.props.items.duplicate()
	if not belts.is_empty():
		_missing_paths(belts.get("paths", []))
		back = BeltPath.belts_from_array(belts.get("paths", []), world.props)
	for it in world.props.items:
		if not before_restore.has(it) and is_instance_valid(it):
			_bodied [it.get_instance_id()] = it.global_position
	if player != null and d.has("player"):
		player.global_transform = d ["player"]
	print("SEAMAUDIT: %d buildings, %d props, records back %s, belt speed %.2f, save version %s"
		% [(d.get("buildings", []) as Array).size(), world.props.items.size(), str(back),
			Tech.belt_speed(), str(d.get("version", "?"))])
	var tech: Dictionary = d.get("tech", { })
	print("SEAMAUDIT: tech keys %s, belt_speed rank %s, saved ranks %s" % [str(tech.keys()),
		str(Tech.ranks.get("belt_speed")), str(tech.get("ranks", { })).substr(0, 300)])
	for it in world.props.items:
		if is_instance_valid(it):
			_in_save [it.get_instance_id()] = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	if "--oldwye" in ua:
		_unlink_like_before()
	_list_dead_ends()
	_list_open_outlets()
	if "--switchon" in ua:
		_switch_everything_on()
	for p in _paths() + _outlets():
		p.handed_on.connect(_let_go.bind(p))
	get_tree().physics_frame.connect(_sample)


	for p in _paths():
		var pb:= p as BeltPath
		if pb.records_props and pb._line.size() >= 2:
			_batch.adopt(pb.run)
			_path_of [pb.run] = pb
	get_tree().process_frame.connect(_audit_drawn)
	await get_tree().create_timer(3.0).timeout
	_judge_bodied()
	_plant_fault()


	for k in 2 * (_batch._runs.size() / BeltRunBatch.AUDIT_PER_FRAME) + 60:
		await get_tree().process_frame
	_judge_fault()
	await get_tree().create_timer(WATCH_SECONDS - 3.0).timeout
	_report()
	get_tree().quit(0)


var _fault_runs: Array [BeltRun] = []
var _reports_before:= 0


func _plant_fault() -> void:
	BeltRunBatch.audit_always = true
	_reports_before = _batch.reports
	for rd in _batch._runs:


		if rd.straight and rd.slots.size() >= 2 and not rd.jam_bins.is_empty() and not rd.run.awake and rd.run.groups().x == rd.slots.size():
			for b in rd.jam_bins:
				b.node.position -= rd.basis.z * 2.0
			if _batch._audit(rd) == "":
				print("DRAWER SELFCHECK: FAIL, the check does not see a queue shoved 2 m")
				return
			_fault_runs.append(rd.run)
	print("DRAWER SELFCHECK: shoved %d parked queues back 2 m" % _fault_runs.size())


func _judge_fault() -> void:
	if _fault_runs.is_empty():
		return


	_batch._apply_events()
	var still:= 0
	for run in _fault_runs:
		var rd = _batch._by_run.get(run)
		if rd != null and rd.dirty:
			continue
		var why: String = _batch._audit(rd) if rd != null else "not drawn"
		if why != "":
			still += 1
			print("DRAWER SELFCHECK:   still off, reported %s dirty %s awake %s: %s"
				% [_batch._reported.has(run), rd.dirty if rd != null else false, run.awake, why])
	var caught:= _batch.reports - _reports_before
	print("DRAWER SELFCHECK: %s: %d reported and drawn again by the check, %d still off, %d runs checked of %d"
		% ["PASS" if still == 0 and caught > 0 else "FAIL", caught, still, _batch.checks, _batch._runs.size()])


var _batch: BeltRunBatch = null
var _path_of:= { }
var _drawn_checked:= 0
var _drawn_off:= 0
var _drawn_off_by:= { }
var _drawn_shouts:= 0
var _run_off:= 0
var _run_off_by:= { }
var _run_shouts:= 0


const DRAWN_SIDE:= 0.5
const DRAWN_LIFT:= 0.8
const DRAWN_PAST_END:= 0.3


var _draw_us_sum:= 0
var _draw_us_max:= 0
var _draw_frames:= 0
var _rows_sum:= 0


func _audit_drawn() -> void:
	if _batch == null:
		return


	if _ticks > 300:
		_draw_frames += 1
		_draw_us_sum += _batch.last_us
		_draw_us_max = maxi(_draw_us_max, _batch.last_us)
		_rows_sum += _batch.rows_written
	for rd in _batch._runs:
		var pb: BeltPath = _path_of.get(rd.run)
		if pb == null or not is_instance_valid(pb):
			continue
		var length: float = pb.path_length()
		var f: int = rd.run.first()
		var n: int = rd.run.count()
		for row in range(f, f + n):
			var sl = rd.slots.get(rd.run.seq_of(row))
			if sl == null:
				continue


			var truth: float = rd.run.s_of(row)
			if truth < - DRAWN_PAST_END or truth > length + DRAWN_PAST_END:
				_run_off += 1
				_run_off_by [pb.name] = int(_run_off_by.get(pb.name, 0)) + 1
				if _run_shouts < 20:
					_run_shouts += 1
					print("  RUN OFF: t=%.2f %s row %d s %.2f of %.2f groups %s jam_offset %.3f free_offset %.3f awake %s"
						% [_ticks / 60.0, pb.name, row, truth, length, str(rd.run.groups()),
							rd.run.jam_offset(), rd.run.free_offset(), rd.run.awake])


			var s: float
			if rd.straight and sl.group != BeltRun.Group.BACK and not sl.bins.is_empty():
				s = sl.rel + (sl.bins [0].node.position as Vector3).dot(rd.basis.z)
			else:
				s = sl.drawn_s
			if s == - INF:
				continue
			_drawn_checked += 1
			if s >= - DRAWN_PAST_END and s <= length + DRAWN_PAST_END:
				continue
			_drawn_off += 1
			_drawn_off_by [pb.name] = int(_drawn_off_by.get(pb.name, 0)) + 1
			if _drawn_shouts < 40:
				_drawn_shouts += 1
				print("  DRAWN OFF: t=%.2f %s row %d (run s %.2f of %.2f, group %d) drawn at s %.2f"
					% [_ticks / 60.0, pb.name, row, rd.run.s_of(row), length, sl.group, s])
				print("      rel %.3f run rel %.3f drawn_free %.3f free_offset %.3f drawn_jam %.3f jam_offset %.3f run group %d awake %s dirty %s groups %s straight %s"
					% [sl.rel, rd.run.rel_of(row), rd.drawn_free, rd.run.free_offset(), rd.drawn_jam,
						rd.run.jam_offset(), rd.run.row_group(row), rd.run.awake, rd.dirty,
						str(rd.run.groups()), rd.straight])


var _bodied:= { }


func _missing_paths(entries: Array) -> void:
	var standing:= []
	for item in BeltPath._live:
		if not is_instance_valid(item) or not (item as Node).is_inside_tree():
			continue
		var ends: PackedVector3Array = (item as BeltPath).save_ends()
		if ends.size() >= 2:
			standing.append([item, ends])
	var missing:= 0
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var a: Vector3 = entry.get("a", Vector3.INF)
		var b: Vector3 = entry.get("b", Vector3.INF)
		var found:= false
		for st in standing:
			if (st [1] [0] as Vector3).distance_to(a) <= BeltPath.SAVE_END_SLACK and (st [1] [1] as Vector3).distance_to(b) <= BeltPath.SAVE_END_SLACK:
				found = true
				break
		if found:
			continue
		missing += 1
		var rows: Array = entry.get("records", [])
		if missing <= 12:
			var nearest:= INF
			var near_name:= "none"
			for st in standing:
				var dd:= (st [1] [0] as Vector3).distance_to(a) + (st [1] [1] as Vector3).distance_to(b)
				if dd < nearest:
					nearest = dd
					near_name = (st [0] as Node).name
			print("  saved run %s to %s (%d records) matches no standing path; nearest %s, ends off by %.2f m in all"
				% [_v(a), _v(b), rows.size(), near_name, nearest])
	print("  %d saved runs of %d match no standing path" % [missing, entries.size()])


func _judge_bodied() -> void:
	var riding:= 0
	var on_deck:= 0
	var fell:= 0
	var gone:= 0
	var shown:= 0
	for id in _bodied:
		var body:= instance_from_id(id) as RigidBody3D
		if body == null or not is_instance_valid(body) or not body.is_inside_tree():
			gone += 1
			continue
		var from: Vector3 = _bodied [id]
		var at: Vector3 = body.global_position
		if BeltPath.is_rider(body):
			riding += 1
		elif at.y < from.y - FALL_DROP:
			fell += 1
			if shown < 12:
				shown += 1
				print("  bodied at load: %s made at %s FELL to %s" % [body.get("item_id"), _v(from), _v(at)])
		else:
			on_deck += 1
	print("  bodies made by the restore: %d, after 3 s riding %d, still up %d, fell %d, gone %d"
		% [_bodied.size(), riding, on_deck, fell, gone])


func _paths() -> Array:
	var out:= []
	for c in world.builds.conveyors:
		if is_instance_valid(c):
			out.append(c)
	for c in world.builds.corners:
		if is_instance_valid(c):
			out.append(c)
	return out


func _end_of(p: BeltPath) -> Vector3:
	if p is Conveyor:
		return (p as Conveyor).laid_end()
	if p is ConveyorCorner:
		return (p as ConveyorCorner).to_point
	return p.run.pose_at(p.path_length(), 0.0, 0.0).origin


func _start_of(p: BeltPath) -> Vector3:
	if p is Conveyor:
		return (p as Conveyor).laid_start()
	if p is ConveyorCorner:
		return (p as ConveyorCorner).from_point
	return p.run.pose_at(0.0, 0.0, 0.0).origin


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


func _list_dead_ends() -> void:
	var paths:= _paths()
	var dead:= 0
	print("\n== dead ends: paths whose records are given bodies at the end ==")
	for p in paths:
		var pb:= p as BeltPath
		if pb.downstream != null:
			continue
		dead += 1
		var end:= _end_of(pb)
		var nearest:= INF
		var near_name:= "none"
		var on_deck:= ""
		for q in paths:
			if q == p:
				continue
			var qb:= q as BeltPath
			var dist:= end.distance_to(_start_of(qb))
			if dist < nearest:
				nearest = dist
				near_name = qb.name
			var at: Dictionary = qb._nearest(end)
			var s:= float(at ["s"])
			if s > 0.3 and s < qb.path_length() - 0.3 and absf(float(at ["side"])) < 0.5 and absf(float(at ["lift"])) < 0.4:
				on_deck += " ON THE DECK OF %s at s %.2f side %.2f lift %.2f" % [
					qb.name, s, float(at ["side"]), float(at ["lift"])]
		var slope:= ""
		if pb.path_length() > 0.1:
			var dir: Vector3 = pb._basis_at(pb.path_length() - 0.05).z
			slope = " slope %.1f deg" % rad_to_deg(asin(clampf(dir.y, -1.0, 1.0)))
		print("  %s end %s len %.2f records %d riders %d%s, nearest other start %s at %.2f m%s"
			% [pb.name, _v(end), pb.path_length(), pb.run.count(), pb.riders().size(),
				slope, near_name, nearest, on_deck])
		if pb is Conveyor:
			var c:= pb as Conveyor
			print("      a %s b %s trim %.2f/%.2f line_id %d, upstream: %s"
				% [_v(c.a), _v(c.b), c.trim_start, c.trim_end, c.line_id, _feeders(pb)])
		_near_buildings((pb as Conveyor).b if pb is Conveyor else end)


		for q in paths:
			if q == p:
				continue
			var qe:= _end_of(q as BeltPath)
			if qe.distance_to(end) < 1.5:
				print("      another END within 1.5 m: %s at %s (%.2f m), len %.2f, downstream %s"
					% [q.name, _v(qe), qe.distance_to(end), (q as BeltPath).path_length(),
						(q as BeltPath).downstream.name if (q as BeltPath).downstream != null else "none"])
		if pb is Conveyor and (pb as Conveyor).line_id != 0:
			for q in world.builds.conveyors:
				if is_instance_valid(q) and q != pb and q.line_id == (pb as Conveyor).line_id:
					print("      same line: %s a %s b %s downstream %s" % [q.name, _v(q.a), _v(q.b),
						q.downstream.name if q.downstream != null else "none"])
	print("  %d dead ends of %d paths" % [dead, paths.size()])


func _outlets() -> Array:
	var out:= []
	for sp in world.builds.splitters:
		if not is_instance_valid(sp):
			continue
		for side: int in sp.output_sides():
			var r: BeltPath = sp.route(side)
			if r != null:
				out.append(r)
	for j in world.builds.joiners:
		if is_instance_valid(j) and j.out_path() != null:
			out.append(j.out_path())
	return out


func _list_open_outlets() -> void:
	var outlets:= _outlets()
	var open:= 0
	print("\n== wye outlets with nothing in front of them ==")
	for r: BeltPath in outlets:
		if r.downstream != null:
			continue
		open += 1
		print("  %s/%s end %s" % [r.get_parent().name, r.name, _v(_end_of(r))])
	print("  %d open of %d wye outlets" % [open, outlets.size()])
	_list_open_machine_outfeeds()


func _list_open_machine_outfeeds() -> void:
	var b = world.builds
	var decks:= []
	for list: Array in [b.scanners, b.compressors, b.wrappers, b.silos]:
		for m in list:
			if is_instance_valid(m):
				decks.append([m, m.deck(), m.port_out()])
	for list: Array in [b.pulpers, b.papers, b.briquette_presses, b.hay_lifts]:
		for m in list:
			if is_instance_valid(m):
				decks.append([m, m.outfeed_deck(), m.port_out()])
	for m in b.hay_stairs:
		if is_instance_valid(m):
			decks.append([m, m.deck(), m.outfeed_port()])
	var index: Array = b._successor_index()
	var open:= 0
	var bolted:= 0
	print("\n== machine outfeeds with nothing linked in front of them ==")
	for row: Array in decks:
		var deck: BeltPath = row [1]
		if deck == null or deck.downstream != null:
			continue
		open += 1
		var port: Vector3 = row [2]
		var there: BeltPath = b._wye_inlet_at(port)
		if there == null:
			there = b._successor_at(index, port, port)
		if there != null and there != deck:
			bolted += 1
		print("  %s outfeed at %s: %s" % [(row [0] as Node).name, _v(port),
			"BOLTED ONTO %s/%s, NOT LINKED" % [there.get_parent().name, there.name]
				if there != null and there != deck else "nothing there"])
	print("  %d open of %d machine outfeeds, %d of them bolted onto something"
		% [open, decks.size(), bolted])


func _unlink_like_before() -> void:
	var n:= 0
	for sp in world.builds.splitters:
		if not is_instance_valid(sp):
			continue
		for side: int in sp.output_sides():
			var r: BeltPath = sp.route(side)
			if r != null and r.downstream != null and _old_onward(sp.port(side)) == null:
				r.downstream = null
				n += 1
	for j in world.builds.joiners:
		if not is_instance_valid(j) or j.out_path() == null:
			continue
		if j.out_path().downstream != null and _old_onward(j.port_out()) == null:
			j.out_path().downstream = null
			n += 1
	print("SEAMAUDIT: --oldwye unlinked %d outlets" % n)


func _old_onward(mouth: Vector3) -> BeltPath:
	var run: BeltPath = world.builds.run_out_of(mouth)
	if run != null:
		return run
	var inlet: BeltPath = world.builds._wye_inlet_at(mouth)
	if inlet != null:
		return inlet
	var gen: HayGenerator = world.builds.generator_at_port(mouth)
	return gen.deck() if gen != null else null


func _switch_everything_on() -> void:
	var n:= 0
	for node in world.builds.find_children("*", "Node3D", true, false):
		if node.has_method("set_switched_off") and node.has_method("is_switched_off") and bool(node.call("is_switched_off")):
			node.call("set_switched_off", false)
			n += 1
	print("SEAMAUDIT: switched %d machines on" % n)


func _collect(n: Node, into: Array) -> void:
	for c in n.get_children():
		if c is Node3D and not (c is BeltPath):
			for m in ["port_in", "port_out", "intake_port", "outfeed_port", "belt_entry_point", "port"]:
				if c.has_method(m):
					into.append(c)
					break
		_collect(c, into)


func _feeders(p: BeltPath) -> String:
	var out:= ""
	for q in _paths():
		if (q as BeltPath).downstream == p:
			out += " %s(len %.2f, %d rec)" % [q.name, (q as BeltPath).path_length(), (q as BeltPath).run.count()]
	return out if out != "" else " none"


func _near_buildings(at: Vector3) -> void:
	var nodes: Array = []
	_collect(world, nodes)
	for n in nodes:
		var node:= n as Node3D
		var dist:= node.global_position.distance_to(at)
		var ports:= ""
		for m in ["port_in", "port_out", "intake_port", "outfeed_port", "belt_entry_point"]:
			if node.has_method(m):
				var pt: Vector3 = node.call(m)
				ports += " %s %s (%.7f m, equal %s)" % [m, _v(pt), pt.distance_to(at), pt.is_equal_approx(at)]
				dist = minf(dist, pt.distance_to(at))
		if node.has_method("port"):
			for side in 3:
				var pt: Vector3 = node.call("port", side)
				ports += " port(%d) %s (%.2f m)" % [side, _v(pt), pt.distance_to(at)]
				dist = minf(dist, pt.distance_to(at))
		if dist <= 2.5:
			print("      near: %s %s at %s%s" % [node.get_class(), node.name, _v(node.global_position), ports])


func _let_go(body: RigidBody3D, p: BeltPath) -> void:
	if not is_instance_valid(body):
		return


	if BeltPath.is_rider(body):
		return
	var seam:= "dead end"
	if p.downstream != null and is_instance_valid(p.downstream):
		seam = "refused by %s" % p.downstream.name
	var id:= body.get_instance_id()
	_following [id] = { "path": p.name, "from": body.global_position, "tick": _ticks,
		"end": _end_of(p) }
	var key:= "%s (%s)" % [p.name, seam]
	_drops [key] = int(_drops.get(key, 0)) + 1
	if _drops [key] <= 3:
		print("  t=%.1f %s let go %s at %s vel %s, %s" % [_ticks / 60.0, p.name,
			body.get("item_id") if body.get("item_id") != null else body.get_class(),
			_v(body.global_position), _v(body.linear_velocity), seam])


func _sample() -> void:
	_ticks += 1
	if _ticks % 6 == 0:
		_count_sliders()
	for id in _following.keys():
		var rec: Dictionary = _following [id]
		if _ticks - int(rec ["tick"]) < FOLLOW_TICKS:
			continue
		_following.erase(id)
		var body:= instance_from_id(id) as RigidBody3D
		if body == null or not is_instance_valid(body) or not body.is_inside_tree():
			print("  ... from %s: body gone (folded away or freed)" % rec ["path"])
			continue
		var at: Vector3 = body.global_position
		var end: Vector3 = rec ["end"]
		var owner:= ""
		if BeltPath.is_rider(body):
			var o: Object = body.get_meta(LiveStrandManager.META_RIDER)
			owner = " riding %s" % (o as Node).name if o is Node else " riding"
		if at.y < end.y - FALL_DROP and owner == "":
			_fell += 1
			print("  ... from %s: FELL to %s, %.1f m below the end" % [rec ["path"], _v(at), end.y - at.y])
		else:
			_landed += 1
			print("  ... from %s: landed at %s%s" % [rec ["path"], _v(at), owner])


var _slide_samples:= 0
var _sliders:= { }
var _bounced:= { }


var _in_save:= { }


func _count_sliders() -> void:
	for it in world.props.items:
		var rb:= it as RigidBody3D
		if rb == null or not is_instance_valid(rb) or not rb.is_inside_tree() or rb.freeze:
			continue
		if rb.has_meta(&"belt_queue_bounce_until") and not _bounced.has(rb.get_instance_id()):
			_bounced [rb.get_instance_id()] = "%s at %s, t=%.1f" % [
				(it as Carryable).item_id, _v(rb.global_position), _ticks / 60.0]
		if BeltPath.is_rider(rb):
			continue
		var why: String = BeltPath.debug_last_refusal.get(rb.get_instance_id(), "")
		if not (why.begins_with("occupied") or why.begins_with("lane_full")):
			continue
		var v:= rb.linear_velocity


		var bouncing:= float(rb.get_meta(&"belt_queue_bounce_until", 0.0)) > Time.get_ticks_msec() * 0.001
		if v.length() > 2.0 and absf(v.y) < 1.8 and not bouncing:
			_slide_samples += 1
			_sliders [rb.get_instance_id()] = int(_sliders.get(rb.get_instance_id(), 0)) + 1


func _report() -> void:
	print("\n== seam audit, %.0f s watched ==" % (_ticks / 60.0))
	for nm in _drops:
		print("  %s let go %d" % [nm, int(_drops [nm])])
	print("  %d landed, %d fell" % [_landed, _fell])
	if _draw_frames > 0:
		print("  drawer frame cost: mean %.0f us, worst %d us, %.1f rows written a frame, over %d frames"
			% [float(_draw_us_sum) / _draw_frames, _draw_us_max, float(_rows_sum) / _draw_frames,
				_draw_frames])
	print("  drawn records checked %d, drawn off the belt %d" % [_drawn_checked, _drawn_off])
	for nm in _drawn_off_by:
		print("    %s: %d" % [nm, int(_drawn_off_by [nm])])
	print("  records the RUN itself stands off its belt %d" % _run_off)
	var long_sliders:= 0
	for id in _sliders:
		if int(_sliders [id]) >= 5:
			long_sliders += 1
	print("  refused props sliding at belt speed: %d samples, %d bodies, %d for half a second or more; bounced off a queue %d"
		% [_slide_samples, _sliders.size(), long_sliders, _bounced.size()])
	var new_bounced:= 0
	for id in _bounced:
		if not _in_save.has(id):
			new_bounced += 1
		print("    bounced %s%s" % [_bounced [id], "" if not _in_save.has(id) else ", in the save"])
	print("  ...of those bounced, %d were loads made during the watch and %d lay in the save"
		% [new_bounced, _bounced.size() - new_bounced])
	for nm in _run_off_by:
		print("    %s: %d" % [nm, int(_run_off_by [nm])])
