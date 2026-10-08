extends RefCounted


var _bodies: Array [Dictionary] = []


func prepare(probe: Node, before_path: String) -> void:
	assert (probe.world.block_save)
	var absolute:= ProjectSettings.globalize_path(before_path).replace("\\", "/").simplify_path()
	var scratch:= ProjectSettings.globalize_path("res://.scratchpad/").replace("\\", "/")
	assert (absolute.to_lower().begins_with(scratch.to_lower()), "palette reference belongs in the scratchpad")
	var reference: Node = load(before_path).instantiate()
	var original:= reference.get_node("HayPulper/HayPulperBody") as MeshInstance3D
	var spec: Dictionary = HayPulper.spec_table()
	var shader: Shader = load(HayCompressor.SHADER)
	for pulper: HayPulper in probe.world.builds.pulpers:
		var body:= pulper._find("HayPulperBody") as MeshInstance3D
		assert (body != null and body.mesh.get_surface_count() == 10)
		var active: Dictionary = { }
		var after: Array [Material] = []
		for s in body.mesh.get_surface_count():
			active [body.mesh.surface_get_material(s).resource_name] = body.get_active_material(s)
			after.append(body.get_surface_override_material(s))
		var before: Array [Material] = []
		for s in original.mesh.get_surface_count():
			var key:= original.mesh.surface_get_material(s).resource_name
			before.append(active.get(key, null) if active.has(key) else pulper._material_for(key, spec, shader))
		_bodies.append({ "node": body, "before_mesh": original.mesh, "after_mesh": body.mesh,
			"before": before, "after": after })
	reference.free()
	assert (not _bodies.is_empty(), "palette comparison needs placed pulpers")
	print("YARDPERF: palette comparison prepared for %d pulpers, 27 versus 10 body surfaces" % _bodies.size())
	apply(false)


func apply(merged: bool) -> void:
	var key:= "after" if merged else "before"
	for row: Dictionary in _bodies:
		var node: MeshInstance3D = row ["node"]
		node.mesh = row [key + "_mesh"]
		for s in node.mesh.get_surface_count():
			node.set_surface_override_material(s, row [key] [s])
