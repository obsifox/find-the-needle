extends Node


static func dump(field: HayField) -> void:
	var missing:= 0
	var present:= 0
	for c in field.chunks:
		var center: Vector3 = field.cell_center(c.cx0 + c.cw / 2, c.cz0 + c.ch / 2)
		var maxh:= 0.0
		var nv:= Cfg.field_verts()
		for j in range(c.cz0, c.cz0 + c.ch + 1):
			for i in range(c.cx0, c.cx0 + c.cw + 1):
				maxh = maxf(maxh, field.heights [j * nv + i])
		var mi: MultiMeshInstance3D = c.get_node_or_null("Shell")
		var surfaces:= 0
		var verts:= 0


		var shell_mesh: ArrayMesh = null
		if mi != null and mi.multimesh != null:
			shell_mesh = mi.multimesh.mesh as ArrayMesh
		if shell_mesh != null:
			surfaces = shell_mesh.get_surface_count()
			if surfaces > 0:
				verts = shell_mesh.surface_get_array_len(0)
		if maxh > 0.05 and surfaces == 0:
			missing += 1
			print("MISSING shell  chunk(%d,%d) center=(%.1f, %.1f) max_h=%.2f has_node=%s"
				% [c.cx0, c.cz0, center.x, center.z, maxh, str(mi != null)])
		elif maxh > 0.05:
			present += 1
			if present <= 4:
				print("ok shell chunk(%d,%d) center=(%.1f, %.1f) max_h=%.2f verts=%d aabb=%s"
					% [c.cx0, c.cz0, center.x, center.z, maxh, verts, str(mi.get_aabb())])
	print("[diag] chunks with hay: %d ok, %d MISSING shell" % [present, missing])

	var allocated:= 0
	for c in field.chunks:
		var mmi: MultiMeshInstance3D = c.get_node_or_null("Crust")
		if mmi != null:
			allocated += mmi.multimesh.instance_count
	print("[diag] pile strands (the number): %d" % int(GameState.hay_total))
	print("[diag] crust instances allocated: %d" % allocated)
	print("[diag] crust instances drawn now:  %d" % field.drawn_instance_count())
	print("[diag] live rigid-body budget:     %d" % Cfg.live_strand_budget)
	print("[diag] height field: %d x %d verts, %d chunks, cell %.2f m"
		% [Cfg.field_verts(), Cfg.field_verts(), field.chunks.size(), Cfg.CELL])


	var shells_ok:= 0
	var shells_missing:= 0
	var shown:= 0
	for c in field.chunks:
		var mmi: MultiMeshInstance3D = c.get_node_or_null("Shell")
		if mmi == null:
			continue
		var mm:= mmi.multimesh
		var surfaces:= 0
		if mm != null and mm.mesh != null:
			surfaces = (mm.mesh as ArrayMesh).get_surface_count()
		if surfaces > 0 and mm.instance_count > 0:
			shells_ok += 1
			if shown < 2:
				shown += 1
				print("[diag] SHELL %s inst=%d vis=%d surf=%d verts=%d visible=%s mat=%s"
					% [c.name, mm.instance_count, mm.visible_instance_count, surfaces,
								(mm.mesh as ArrayMesh).surface_get_array_len(0),
								str(mmi.visible), str(mmi.material_override != null)])
				print("[diag]   aabb=%s  fmt_has_color=%s"
					% [str(mmi.custom_aabb),
								str(((mm.mesh as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0)])
		else:
			shells_missing += 1
	print("[diag] shell nodes: %d with geometry, %d empty" % [shells_ok, shells_missing])


static func dump_dig_bite(field: HayField) -> void:
	var nc:= Cfg.field_cells()
	var deep:= 0
	var bitten:= 0
	var halved:= 0
	var floored:= 0
	var worst:= 0.0
	var worst_at:= Vector3.ZERO
	for j in nc:
		for i in nc:
			var h:= field.cell_height(i, j)
			var avail: float = clampf(minf(Cfg.HAY_SHELL_DEPTH, h * 0.9), 0.02,
				Cfg.HAY_SHELL_DEPTH)
			if avail < Cfg.HAY_SHELL_DEPTH * 0.9:
				continue
			deep += 1
			var c:= field.cell_center(i, j)
			var kept: float = minf(1.0, field.shell_length_limit(c.x, c.z, field.normal_at(c.x, c.z)) / avail)
			if kept < 0.99:
				bitten += 1
			if kept < 0.5:
				halved += 1
			if kept <= Cfg.HAY_SHELL_DIG_FLOOR + 0.01:
				floored += 1
			if 1.0 - kept > worst:
				worst = 1.0 - kept
				worst_at = c
	if deep == 0:
		print("[diag] no cell has a full stack available")
		return
	print("[diag] dig crop on the %d cells with a full stack available:" % deep)
	print("[diag]   touched at all %d (%.1f%%), cut past half %d (%.1f%%), on the floor %d (%.1f%%)"
		% [bitten, 100.0 * bitten / deep, halved, 100.0 * halved / deep,
			floored, 100.0 * floored / deep])
	print("[diag]   worst cut %.0f%% at %.1v" % [100.0 * worst, worst_at])


static func dump_dig_probe(field: HayField) -> void:


	var at:= Vector3(6.2, 0.0, 0.0)
	at.y = field.height_at(at.x, at.z)
	var before:= _ring_means(field, at)


	for k in 14:
		var a:= TAU * float(k) / 14.0
		field.carve_sphere(at + Vector3(cos(a), 0.0, sin(a)) * 0.8, 1.1, 1.6)
	field.carve_sphere(at, 1.3, 1.8)
	var after:= _ring_means(field, at)
	print("[diag] dig probe: a %.1f m bowl cut into the flank at %.1v" % [2.6, at])
	print("[diag]   ring               hay before  after      dug  stack  kept")
	for i in 3:
		var label: String = ["crater (0-1.5 m)", "lip    (1.5-3 m)", "open   (6 m+)"] [i]
		print("[diag]   %s  %6.2f m %6.2f m  %6.2f %5.2f m  %3.0f%%"
			% [label, (before [1] as Array) [i], (after [1] as Array) [i],
				(after [2] as Array) [i], (after [0] as Array) [i],
				100.0 * float((after [0] as Array) [i])
					/ maxf(float((before [0] as Array) [i]), 0.0001)])


static func _ring_means(field: HayField, at: Vector3) -> Array:
	var sums:= [0.0, 0.0, 0.0]
	var heights:= [0.0, 0.0, 0.0]
	var sinks:= [0.0, 0.0, 0.0]
	var counts:= [0, 0, 0]
	var nc:= Cfg.field_cells()
	for j in nc:
		for i in nc:
			var c:= field.cell_center(i, j)
			var d:= Vector2(c.x - at.x, c.z - at.z).length()
			var ring:= -1
			if d <= 1.5:
				ring = 0
			elif d <= 2.6:
				ring = 1
			elif d >= 6.0:
				ring = 2
			if ring < 0:
				continue
			var h:= field.cell_height(i, j)
			if h < 0.05:
				continue
			var avail: float = clampf(minf(Cfg.HAY_SHELL_DEPTH, h * 0.9), 0.02,
				Cfg.HAY_SHELL_DEPTH)
			sums [ring] += minf(avail, field.shell_length_limit(c.x, c.z, field.normal_at(c.x, c.z)))
			heights [ring] += h
			sinks [ring] += field.dug_depth_at(c.x, c.z)
			counts [ring] += 1
	for i in 3:
		var n:= maxf(float(counts [i]), 1.0)
		sums [i] = sums [i] / n
		heights [i] = heights [i] / n
		sinks [i] = sinks [i] / n
	return [sums, heights, sinks]
