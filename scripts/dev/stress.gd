class_name DevStress
extends Node


var world: Node3D

const PHYS_TIERS:= [500, 2000, 5000, 10000, 20000]
const DRAW_TIERS:= [250000, 1000000, 3000000, 5000000]
const SETTLE_FRAMES:= 45
const MEASURE_FRAMES:= 60


func run() -> void:
	for i in 30:
		await get_tree().process_frame
	print("\n================ HAYSTACK SCALE TEST ================")
	await _physics_test()
	await _draw_test()
	print("====================================================\n")
	get_tree().quit()


func _physics_test() -> void:
	print("\n--- A: rigid bodies (real physics) ---")
	var holder:= Node3D.new()
	world.add_child(holder)
	var shape:= BoxShape3D.new()
	shape.size = Vector3(Cfg.STRAND_THICK, Cfg.STRAND_THICK, Cfg.STRAND_LENGTH)
	var mat:= StrandFactory.hay_physics_material()
	var rng:= RandomNumberGenerator.new()
	rng.seed = 99
	var made:= 0

	for tier: int in PHYS_TIERS:
		while made < tier:
			var b:= RigidBody3D.new()
			b.mass = Cfg.STRAND_MASS
			b.physics_material_override = mat
			b.collision_layer = Cfg.L_STRAND
			b.collision_mask = Cfg.L_WORLD | Cfg.L_STRAND
			b.can_sleep = false
			var cs:= CollisionShape3D.new()
			cs.shape = shape
			b.add_child(cs)
			holder.add_child(b)

			b.global_position = Vector3(
				10.0 + rng.randf_range(-2.0, 2.0),
				0.4 + rng.randf() * 6.0,
				8.0 + rng.randf_range(-2.0, 2.0))
			b.basis = StrandFactory.random_strand_basis(rng)
			made += 1
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var t:= 0.0
		for i in MEASURE_FRAMES:
			await get_tree().process_frame
			t += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		var ms:= t / MEASURE_FRAMES * 1000.0
		var budget_pct:= ms / 16.667 * 100.0
		print("  %7d bodies   physics %6.2f ms/frame   (%5.1f%% of a 60 fps frame)"
			% [tier, ms, budget_pct])
		if ms > 16.667:
			print("            ^ already over budget; higher tiers skipped")
			break
	holder.queue_free()
	await get_tree().process_frame


func _draw_test() -> void:
	print("\n--- B: drawn instances (MultiMesh, no physics) ---")
	var holder:= Node3D.new()
	world.add_child(holder)
	var rng:= RandomNumberGenerator.new()
	rng.seed = 7
	var mesh:= StrandFactory.strand_mesh()
	var per_mm:= 250000
	var made:= 0
	var mms: Array [MultiMeshInstance3D] = []

	for tier: int in DRAW_TIERS:
		while made < tier:
			var mm:= MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = per_mm


			var buf:= PackedFloat32Array()
			buf.resize(per_mm * 16)
			for k in per_mm:
				var a:= rng.randf() * TAU
				var r: float = sqrt(rng.randf()) * Cfg.PILE_RADIUS
				var x: float = cos(a) * r
				var z: float = sin(a) * r
				var y: float = world.field.height_at(x, z) - rng.randf() * Cfg.CRUST_DEPTH
				var b:= StrandFactory.random_strand_basis(rng)
				var c:= StrandFactory.random_tint(rng)
				var o:= k * 16
				buf [o] = b.x.x; buf [o + 1] = b.y.x; buf [o + 2] = b.z.x; buf [o + 3] = x
				buf [o + 4] = b.x.y; buf [o + 5] = b.y.y; buf [o + 6] = b.z.y; buf [o + 7] = y
				buf [o + 8] = b.x.z; buf [o + 9] = b.y.z; buf [o + 10] = b.z.z; buf [o + 11] = z
				buf [o + 12] = c.r; buf [o + 13] = c.g; buf [o + 14] = c.b; buf [o + 15] = 1.0
			mm.buffer = buf
			var mmi:= MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.custom_aabb = AABB(Vector3(- Cfg.PILE_RADIUS, -1, - Cfg.PILE_RADIUS),
				Vector3(Cfg.PILE_RADIUS * 2, Cfg.PILE_HEIGHT + 2, Cfg.PILE_RADIUS * 2))
			holder.add_child(mmi)
			mms.append(mmi)
			made += per_mm


		for i in 90:
			await get_tree().process_frame

		var total:= 0.0
		for i in MEASURE_FRAMES:
			await get_tree().process_frame
			total += get_process_delta_time()
		var ms:= total / MEASURE_FRAMES * 1000.0
		print("  %9d instances   %6.2f ms/frame  = %5.1f fps   (~%d M triangles)"
			% [tier, ms, 1000.0 / maxf(ms, 0.001), tier * 12 / 1000000])
	holder.queue_free()
