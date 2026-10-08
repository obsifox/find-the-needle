class_name DevHeapProbe
extends Node


const SETTLE:= 20


const KINDS:= ["bucket", "wheelbarrow"]

var world: Node3D
var player: Player

var _pass:= 0
var _fail:= 0


func run() -> void:
	call_deferred("_run")


func _check(label: String, ok: bool, note: String = "") -> void:
	if ok:
		_pass += 1
		print("  ok    %s%s" % [label, "" if note.is_empty() else "   " + note])
	else:
		_fail += 1
		print("  FAIL  %s%s" % [label, "" if note.is_empty() else "   " + note])


func _run() -> void:
	for i in SETTLE:
		await get_tree().process_frame
	Tech.grant_legacy()
	for i in SETTLE:
		await get_tree().physics_frame

	print("\n=== the heap over a full container ===")
	for id: String in KINDS:
		await _measure(id)

	print("\n=== the badge ===")
	_timing()
	await _placement()
	await _infall()

	print("\n%d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _measure(id: String) -> void:
	var box:= _make(id, Vector3(13.0, 1.4, 0.0))
	if box == null:
		return
	print("\n=== %s ===" % box.display_name)
	var mm: MultiMesh = (box.get_node("Load") as MultiMeshInstance3D).multimesh
	var n:= mm.instance_count
	var crown:= box._crown
	var lip: float = box._mouth_centre.y
	var rise: float = box.crown_rise()

	_check("%s: the load has a heap on it" % id, crown > 0, "%d of %d instances" % [crown, n])


	_check("%s: the heap is a slice, not the load" % id,
		crown > 0 and float(crown) / float(n) <= 0.34,
		"%.1f%%" % (100.0 * float(crown) / float(n)))


	var rng:= RandomNumberGenerator.new()
	rng.seed = hash(id)
	var body_top:= - INF
	for i in 400:
		var u:= float(i) / 399.0
		body_top = maxf(body_top, box._load_point(u, rng).y)
	var crown_top:= - INF
	var below:= 0
	var wide:= 0
	for i in 400:
		var h:= float(i) / 399.0
		var p:= box._crown_point(h, rng)
		crown_top = maxf(crown_top, p.y)
		if p.y < lip - 0.0001:
			below += 1


		var flat:= Vector3(p.x - box._mouth_centre.x, 0.0, p.z - box._mouth_centre.z)
		if flat.length() > 1e-05:
			var edge: Vector3 = box._lip_point(flat.normalized()) - box._mouth_centre
			if flat.length() > edge.length() + 0.0001:
				wide += 1
	_check("%s: the straw inside stops at the lip" % id, body_top <= lip + 0.001,
		"top %.3f, lip %.3f" % [body_top, lip])
	_check("%s: no heap strand sits below the lip" % id, below == 0,
		"%d of 400 below" % below)
	_check("%s: nor outside the mouth" % id, wide == 0, "%d of 400 outside" % wide)
	_check("%s: the heap stands proud of it" % id, crown_top > lip + rise * 0.9,
		"peak %.3f, lip + rise %.3f" % [crown_top, lip + rise])


	print("     heap stands %.1f cm over the lip"
		% ((crown_top - lip) * box.size_scale() * 100.0))


	box.stored = int(round(float(box.capacity()) * 0.5))
	box._refresh_fill()
	_check("%s: half full draws no heap" % id,
		mm.visible_instance_count <= n - crown,
		"%d visible, body is %d" % [mm.visible_instance_count, n - crown])
	box.stored = box.capacity()
	box._refresh_fill()
	_check("%s: full draws all of it" % id, mm.visible_instance_count == n,
		"%d of %d" % [mm.visible_instance_count, n])


	var bounds: AABB = (box.get_node("Load") as MultiMeshInstance3D).custom_aabb
	var s:= box.size_scale()
	var outside:= 0
	for i in 400:
		var h:= float(i) / 399.0
		if not bounds.has_point(box._crown_point(h, rng) * s):
			outside += 1
	_check("%s: the bounds hold the heap as well" % id, outside == 0,
		"%d of 400 outside" % outside)
	_check("%s: and are not merely enormous" % id,
		bounds.size.y < (rise + box._load_bounds().size.y) * s * 2.0,
		"%.2f m tall" % bounds.size.y)

	_drop(box)
	await get_tree().physics_frame


func _timing() -> void:
	_check("badge: about a second and a half",
		absf(FullBadge.LIFE - 1.5) < 0.15, "%.2f s" % FullBadge.LIFE)
	_check("badge: dark at both ends",
		FullBadge.alpha_at(0.0) <= 0.0 and FullBadge.alpha_at(FullBadge.LIFE) <= 0.0)
	_check("badge: lit through the hold",
		FullBadge.alpha_at(FullBadge.RISE + FullBadge.HOLD * 0.5) > 0.99)
	_check("badge: on its way up at half the rise",
		FullBadge.alpha_at(FullBadge.RISE * 0.5) > 0.0
		and FullBadge.alpha_at(FullBadge.RISE * 0.5) < 1.0)
	_check("badge: on its way down at half the fall",
		FullBadge.alpha_at(FullBadge.RISE + FullBadge.HOLD + FullBadge.FALL * 0.5) > 0.0
		and FullBadge.alpha_at(FullBadge.RISE + FullBadge.HOLD + FullBadge.FALL * 0.5) < 1.0)
	_check("badge: gone past the cut range",
		FullBadge.range_scale(FullBadge.CUT_RANGE) == 0.0)
	_check("badge: full size in front of you",
		is_equal_approx(FullBadge.range_scale(1.0), 1.0))


	_check("badge: it says FULL", FullBadge.WORD == "FULL", FullBadge.WORD)


func _placement() -> void:
	for id: String in KINDS:
		var box:= _make(id, Vector3(13.0, 1.4, 0.0))
		if box == null:
			continue
		var at:= box.badge_point()
		var mouth: Vector3 = box._mouth_centre * box.size_scale()
		_check("%s: the badge is over the mouth" % id,
			Vector2(at.x - mouth.x, at.z - mouth.z).length() < 0.02,
			"%.3f m off centre" % Vector2(at.x - mouth.x, at.z - mouth.z).length())
		_check("%s: and clear of the heap" % id,
			at.y > mouth.y + box.crown_rise() * box.size_scale(),
			"badge %.3f, heap top %.3f" % [at.y,
				mouth.y + box.crown_rise() * box.size_scale()])

		box.flash_full()
		var badge:= box.get_node_or_null("FullBadge") as FullBadge
		_check("%s: filling puts one up" % id, badge != null)
		if badge == null:
			_drop(box)
			continue
		var mark:= badge.get_node_or_null("Mark") as Label3D
		_check("%s: and it is drawn" % id, mark != null and mark.visible,
			"" if mark == null else "\"%s\"" % mark.text)


		var before:= badge.get_index()
		box.flash_full()
		_check("%s: a second ask inside the gap is ignored" % id,
			box.get_node_or_null("FullBadge") == badge
			and badge.get_index() == before)


		for i in int(ceil(FullBadge.LIFE / 0.05)) + 2:
			badge._process(0.05)
		_check("%s: and then it goes away" % id, mark != null and not mark.visible)
		_drop(box)
		await get_tree().physics_frame


func _infall() -> void:
	var box:= _make("bucket", Vector3(13.0, 0.35, 0.0))
	if box == null:
		return
	print("\n=== hay falling into a bucket ===")
	var live: LiveStrandManager = world.live
	var rng:= RandomNumberGenerator.new()
	rng.seed = 7


	box.stored = box.capacity() - 3
	box._refresh_fill()
	var mouth: Vector3 = box.global_position + Vector3.UP * (box._mouth_centre.y + 0.25)

	var filled:= false
	for tick in 300:


		if live.has_headroom():
			for i in 2:
				var jitter:= Vector3(rng.randf_range(-0.03, 0.03), 0.0,
					rng.randf_range(-0.03, 0.03))
				live.spawn(mouth + jitter, StrandFactory.random_strand_basis(rng),
					Vector3.DOWN * 1.5, StrandFactory.random_tint(rng))
		await get_tree().physics_frame
		if box.stored >= box.capacity():
			filled = true
			break
	_check("hay falling in fills it", filled, "%d / %d" % [box.stored, box.capacity()])


	_check("and not one strand past capacity", box.stored <= box.capacity(),
		"%d / %d" % [box.stored, box.capacity()])

	var badge:= box.get_node_or_null("FullBadge") as FullBadge
	var mark: Label3D = null
	if badge != null:
		mark = badge.get_node_or_null("Mark") as Label3D
	_check("filling it raises the badge by itself", mark != null and mark.visible)


	var lit:= 0
	var was:= mark != null and mark.visible
	for tick in int((FullBadge.LIFE + HayContainer.FULL_BADGE_GAP + 0.4)
			/ maxf(get_physics_process_delta_time(), 1e-06)):
		if live.has_headroom():
			live.spawn(mouth, StrandFactory.random_strand_basis(rng),
				Vector3.DOWN * 1.5, StrandFactory.random_tint(rng))
		await get_tree().physics_frame
		var now: bool = mark != null and mark.visible
		if now and not was:
			lit += 1
		was = now
	_check("hay with nowhere to go says so again, once", lit == 1,
		"%d times over %.1f s" % [lit, FullBadge.LIFE + HayContainer.FULL_BADGE_GAP + 0.4])

	_drop(box)
	await get_tree().physics_frame


func _make(id: String, at: Vector3) -> HayContainer:
	var props: PropManager = world.props
	var thing: Carryable = props.spawn(id, Transform3D(Basis.IDENTITY, at))
	var box:= thing as HayContainer
	if box == null:
		_check("could place a %s" % id, false)
		if thing != null:
			thing.queue_free()
		return null


	box.freeze = true
	return box


func _drop(box: HayContainer) -> void:
	var props: PropManager = world.props
	props.remove(box)
