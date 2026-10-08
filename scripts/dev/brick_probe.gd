class_name DevBrickProbe
extends Node


var world: Node3D
var player: Player

const SHOTS:= 24


const RANGE_TOL:= 0.3

var _pass:= 0
var _fail:= 0


func run() -> void:
	await get_tree().process_frame


	var mesh:= EcoBrick.shared_mesh()
	_check("brick mesh loads out of eco_brick.glb", mesh != null)
	var spec:= EcoBrick.spec_table()
	var surfaces: Dictionary = spec.get("surfaces", { })
	_check("surface table has M_EB_Brick", surfaces.has("M_EB_Brick"))
	_check("surface table has M_EB_Stamp", surfaces.has("M_EB_Stamp"))
	if mesh != null:
		var named:= 0
		for i in mesh.get_surface_count():
			var m:= mesh.surface_get_material(i)
			if m != null and surfaces.has(m.resource_name):
				named += 1
		_check("every brick surface names a slot in the table (%d/%d)"
			% [named, mesh.get_surface_count()], named == mesh.get_surface_count())


	var props: PropManager = world.props
	var brick:= props.spawn("eco_brick",
		Transform3D(Basis.IDENTITY, Vector3(0, 40, 0)),
		{ "strands": 45 }) as EcoBrick
	_check("ItemDb makes an eco_brick", brick != null)
	if brick != null:
		_check("brick mass is Cfg.ECO_BRICK_MASS",
			is_equal_approx(brick.mass, Cfg.ECO_BRICK_MASS))
		_check("brick has a collision shape", brick.get_child_count() > 0
			and _has_shape(brick))

		brick.strands = 37
		var st:= brick.to_state()
		var other:= ItemDb.make("eco_brick") as EcoBrick
		other.from_state(st)
		_check("strands survive a save round trip", other.strands == 37)
		other.free()
		props.remove(brick)


	var rig:= BrickLauncher.new()
	rig.ground_y = 0.0
	add_child(rig)
	rig.global_position = Vector3(0, 1.62, 0)
	await get_tree().process_frame

	var muzzle:= rig.get_node_or_null("MuzzleBurst") as GPUParticles3D
	var ring:= rig.get_node_or_null("MouthRing") as GPUParticles3D
	_check("muzzle burst exists", muzzle != null)
	_check("mouth ring exists", ring != null)
	if muzzle != null:
		_check("muzzle burst is a one-shot", muzzle.one_shot)
		_check("muzzle burst is fully explosive", is_equal_approx(muzzle.explosiveness, 1.0))
		_check("muzzle burst starts disarmed", not muzzle.emitting)
	if ring != null:
		_check("mouth ring is flattened", ring.process_material != null
			and (ring.process_material as ParticleProcessMaterial).flatness > 0.5)


	var dir:= Vector3(0.395, 0.695, 0.601).normalized()
	rig.aim_along(dir)


	rig.burst()
	_check("first burst arms", muzzle != null and muzzle.emitting)
	await get_tree().process_frame
	rig.burst()
	_check("re-fire while the last one is still alive re-arms",
		muzzle != null and muzzle.emitting)


	var g: float = absf(float(ProjectSettings.get_setting(
		"physics/3d/default_gravity", 9.8)))
	var worst:= 0.0
	var tumbling:= 0
	var thrown:= 0
	for i in SHOTS:
		var b:= rig.discharge(props, Cfg.PELLETIZER_BRICK_STRANDS)
		if b == null:
			continue
		thrown += 1
		var v:= b.linear_velocity
		var h:= rig.global_position.y - rig.ground_y
		var flat:= Vector2(v.x, v.z).length()

		var t:= (v.y + sqrt(maxf(v.y * v.y + 2.0 * g * h, 0.0))) / g
		var reach:= flat * t
		worst = maxf(worst, absf(reach - rig.throw_distance))
		if b.angular_velocity.length() > 0.3:
			tumbling += 1

		var want:= Vector2(dir.x, dir.z).normalized()
		var got:= Vector2(v.x, v.z).normalized()
		if want.dot(got) < 0.8:
			worst = 999.0
		props.remove(b)
		await get_tree().process_frame

	_check("all %d shots produced a brick" % SHOTS, thrown == SHOTS)
	_check("every brick tumbles", tumbling == thrown and thrown > 0)
	_check("landing within %.2f m of throw_distance (worst %.3f)" % [RANGE_TOL, worst],
		worst <= RANGE_TOL)


	rig.throw_distance = 5.0
	var far:= rig.discharge(props, 1)
	if far != null:
		var v:= far.linear_velocity
		var h:= rig.global_position.y - rig.ground_y
		var t:= (v.y + sqrt(maxf(v.y * v.y + 2.0 * g * h, 0.0))) / g
		var reach:= Vector2(v.x, v.z).length() * t
		_check("doubling throw_distance moves the landing (%.2f m)" % reach,
			absf(reach - 5.0) <= RANGE_TOL)
		props.remove(far)

	rig.queue_free()


	var builds: BuildManager = world.builds
	var mill:= builds.add_pelletizer(Vector3(14, 0, 14), 0.0)
	await get_tree().physics_frame
	_check("BuildManager places a pelletizer", mill != null and is_instance_valid(mill))
	if mill != null:

		var port:= mill.to_local(mill.port_in())
		_check("port sits 0.80 m back and 0.94 m up (%.2f, %.2f)" % [port.z, port.y],
			absf(port.z + 0.8) < 0.06 and absf(port.y - 0.94) < 0.06)
		_check("machine has a collider", _has_static_body(mill))


		_check("X can target it: owner_of resolves the machine from its collider",
			builds.owner_of(mill.get_node_or_null("Body")) == mill)
		_check("it lays its own metre of belt", mill.deck() != null)
		var stub:= mill.intake_port().distance_to(mill.port_in())
		_check("the attach point is a stub out from the throat (%.2f m)" % stub,
			absf(stub - mill.stub()) < 0.02)
		_check("a run ending at the stub feeds the machine's deck",
			builds.owner_of(mill.deck()) == mill)
		_check("every model surface resolves to a slot in the table",
			_all_surfaces_skinned(mill))
		_check("it has its own tech icon", TechPanel.icon_for("pelletizer") != null)


		var near:= mill.intake_port() + Vector3(0.35, 0.0, 0.4)
		var snapped: Vector3 = builds.snap_endpoint(near)
		_check("a belt end near the intake snaps onto it (off by %.3f m)"
			% snapped.distance_to(mill.intake_port()),
			snapped.is_equal_approx(mill.intake_port()))
		var away:= mill.intake_port() + Vector3(5.0, 0.0, 0.0)
		_check("a belt end well clear is left alone",
			builds.snap_endpoint(away).is_equal_approx(away))
		_check("a second mill on the same spot is refused",
			builds.pelletizer_overlap(mill.global_position))


		var feed_a:= mill.intake_port() - mill.forward() * 4.0
		var run: Conveyor = builds.add_conveyor(feed_a, mill.intake_port())
		_check("a run lays into the intake", run != null)
		await get_tree().physics_frame
		_check("the run hands off to the mill's deck",
			builds.owner_of(mill.deck()) == mill)
		var wad:= props.spawn("hay_wad",
			Transform3D(Basis.IDENTITY, feed_a + mill.forward() * 0.5 + Vector3.UP * 0.25),
			{ "strands": 12 })
		var travelled:= 0.0
		if wad != null:
			var start_s:= wad.global_position
			var carried:= 0
			for i2 in 900:
				await get_tree().physics_frame
				if mill.stored > 0:
					carried = 1
					break


			if carried == 1:
				_check("a wad rides the run across the joint and is eaten", true)
			else:
				travelled = start_s.distance_to(wad.global_position) if is_instance_valid(wad) else -1.0
				_check("a wad rides the run across the joint and is eaten"
					+ " (stalled after %.2f m)" % travelled, false)
			if is_instance_valid(wad):
				props.remove(wad)


		var deck:= mill.deck()


		var thrown_here: Array [EcoBrick] = []
		var keep:= func(b: EcoBrick) -> void: thrown_here.append(b)
		mill.bricked.connect(keep)


		var tipped:= [0]
		deck.handed_on.connect(func(_b: RigidBody3D) -> void: tipped [0] += 1)
		var head:= feed_a + mill.forward() * 0.5 + Vector3.UP * 0.25
		var queued: Array [Carryable] = []
		for i3 in 1200:
			mill.stored = maxi(mill.stored, mill.buffer_capacity())
			if queued.size() < 5 and run != null and run.has_room_near(head):
				var w:= props.spawn("hay_wad",
					Transform3D(Basis.IDENTITY, head), { "strands": 60 })
				if w != null:
					queued.append(w)
			await get_tree().physics_frame


		var head_at:= - INF
		var riding:= 0
		for w in queued:
			if is_instance_valid(w) and w.is_inside_tree():
				head_at = maxf(head_at,
					mill.forward().dot(w.global_position - mill.port_in()))
		for path in BeltPath._live:
			if not is_instance_valid(path) or not path.is_inside_tree():
				continue
			var prun: BeltRun = path.run
			for i in range(prun.first(), prun.first() + prun.count()):
				if prun.kind_of(i) != BeltRun.Kind.WAD:
					continue
				head_at = maxf(head_at,
					mill.forward().dot(prun.pose_of(i).origin - mill.port_in()))
				if path == run:
					riding += 1
		_check("a full mill shuts its mouth", deck != null and deck.is_blocked())
		_check("%d wads fed at a full mill, none let go at the throat (%d tipped,"
			% [queued.size(), tipped [0]] + " head standing %+.2f m off it)" % head_at,
			queued.size() > 0 and tipped [0] == 0)
		_check("the queue stands back along the run rather than in the throat",
			run != null and (riding > 0 or not run.riders().is_empty()))
		for w in queued:
			if is_instance_valid(w):
				props.remove(w)
		for path in BeltPath._live:
			if not is_instance_valid(path) or not path.is_inside_tree():
				continue
			var prun: BeltRun = path.run
			var i:= prun.first() + prun.count() - 1
			while i >= prun.first():
				if prun.kind_of(i) == BeltRun.Kind.WAD:


					var was_head:= i == prun.first()
					prun.remove_at(i)
					if was_head:
						break
				i -= 1


		mill.stored = 0
		var winding_down:= 600
		while mill.is_running() and winding_down > 0:
			winding_down -= 1
			mill.stored = 0
			await get_tree().physics_frame
		mill.bricked.disconnect(keep)
		for b in thrown_here:
			if is_instance_valid(b):
				props.remove(b)


		await get_tree().physics_frame


		var made: Array [EcoBrick] = []
		mill.bricked.connect(func(b: EcoBrick) -> void: made.append(b))
		var loads:= 2


		var batch:= Tech.pellet_brick_strands()
		mill.stored = batch * loads
		var budget:= int((Tech.pellet_cycle_seconds() * (loads + 2)) * 70.0)
		while made.size() < loads and budget > 0:
			budget -= 1
			await get_tree().physics_frame
		_check("%d brick-loads make exactly %d bricks (made %d)"
			% [loads, loads, made.size()], made.size() == loads)
		_check("buffer is spent, not duplicated (%d left)" % mill.stored, mill.stored == 0)
		var strands_ok:= true
		for b in made:
			if not is_instance_valid(b) or b.strands != batch:
				strands_ok = false
		_check("each brick carries its strand count (%d)" % batch, strands_ok)
		_check("a brick is worth x%.1f at the till" % Cfg.PELLETIZER_BRICK_RATIO,
			made.size() > 0 and is_equal_approx(made [0].sale_strands(),
				batch * Cfg.PELLETIZER_BRICK_RATIO))


		mill.stored = batch
		var spin:= 120
		while not mill.is_running() and spin > 0:
			spin -= 1
			await get_tree().physics_frame
		_check("the mill starts a grind once it holds a full die", mill.is_running())
		var before:= made.size()
		Tech.grant("pelletizer", 1)
		Tech.grant("pellet_batch", 8)
		var mid_budget:= int(Tech.pellet_cycle_seconds() * 200.0)
		while made.size() == before and mid_budget > 0:
			mid_budget -= 1
			await get_tree().physics_frame
		_check("a rank bought mid-grind lands on the NEXT brick, not this one",
			made.size() > before and is_instance_valid(made [-1])
				and made [-1].strands == batch)
		_check("mid-grind purchase invents no hay (%d left)" % mill.stored,
			mill.stored == 0)
		Tech.reset()


		mill.stored = 0
		for b in made:
			if is_instance_valid(b):
				b.global_position = mill.port_in()
		for i in 12:
			await get_tree().physics_frame
		_check("the mill does not swallow its own bricks", mill.stored == 0)
		for b in made:
			if is_instance_valid(b):
				props.remove(b)


		mill.stored = 61
		var d:= mill.to_dict()
		_check("save names the type", String(d.get("type", "")) == "hay_pelletizer")
		_check("save carries the buffer", int(d.get("stored", -1)) == 61)
		var found:= false
		for e in builds.to_array():
			if typeof(e) == TYPE_DICTIONARY and String((e as Dictionary).get("type", "")) == "hay_pelletizer":
				found = true
		_check("BuildManager writes it into the world save", found)
		_check("demolishing refunds its cost",
			is_equal_approx(builds.demolish(mill), Cfg.PELLETIZER_COST))


	var tool: BuildTool = player.build
	_check("the player has a build tool", tool != null)
	if tool != null:
		tool.set_mode(BuildTool.Mode.PELLETIZER)
		tool.set_active(true)
		await get_tree().process_frame
		var ghost:= tool.get_node_or_null("PelletizerGhost") as HayPelletizer
		_check("the tool carries a pelletizer hologram", ghost != null)
		if ghost != null:
			_check("the hologram is a preview and not a live machine",
				ghost.placement_preview)
			var arc:= ghost.get_node_or_null("ThrowArc") as LaunchArc
			_check("the hologram draws a throw arc", arc != null)
			_check("the arc is up while the hologram is",
				arc != null and arc.visible)
			_check("the arc has geometry in it, not just a tint",
				arc != null and arc.drawn())
			if arc != null:


				var mark:= arc.landing_mark()
				var want:= ghost.throw_target()
				var off:= Vector2(mark.x - want.x, mark.z - want.z).length()
				_check("the ring sits on the pad the mill throws at (off by %.3f m)"
					% off, off < 0.05)
				var reach:= Vector2(want.x - ghost.global_position.x,
					want.z - ghost.global_position.z).length()
				_check("the pad is out in front of the machine (%.2f m)" % reach,
					reach > 1.0)
		tool.set_active(false)

	print("\n%d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _all_surfaces_skinned(node: Node3D) -> bool:
	var spec:= HayPelletizer.spec_table()
	var surfaces: Dictionary = spec.get("surfaces", { })
	var flats: Dictionary = spec.get("flats", { })
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m:= mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src:= m.mesh.surface_get_material(i)
			if src == null or src.resource_name.is_empty():
				continue
			if src.get_meta("immutable_palette", false):
				for key: String in src.get_meta("palette_entries", []):
					if not flats.has(key):
						push_warning("unskinned palette slot: %s" % key)
						return false
				continue
			if not (surfaces.has(src.resource_name) or flats.has(src.resource_name)):
				push_warning("unskinned slot: %s" % src.resource_name)
				return false
	return true


func _has_static_body(node: Node) -> bool:
	for c in node.get_children():
		if c is StaticBody3D and (c as StaticBody3D).get_child_count() > 0:
			return true
	return false


func _has_shape(node: Node) -> bool:
	for c in node.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
			return true
	return false


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  ok    %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)
