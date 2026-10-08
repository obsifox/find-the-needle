class_name ToolProp
extends Carryable


const SPECS:= {
	"spade": {
		"name": "Spade",
		"path": Shovel.SPADE_PATH,
		"scale": 1.0,


		"lie": Vector3(PI * 0.5, 0.0, 0.0),
		"impact": "tool_clang",
	},
	"pitchfork": {
		"name": "Pitchfork",
		"path": Pitchfork.MODEL_PATH,
		"scale": 0.011,


		"lie": Vector3.ZERO,
		"impact": "tool_clang",
	},
	"broom": {
		"name": "Broom",
		"path": Broom.MODEL_PATH,
		"scale": 1.0,
		"lie": Vector3(PI * 0.5, 0.0, 0.0),


		"impact": "item_clatter",
	},
	"yard_vac": {
		"name": "Yard Vac",
		"path": YardVac.MODEL_PATH,
		"scale": 1.0,


		"lie": Vector3(0.0, 0.0, PI * 0.5),


		"impact": "item_clatter",
	},
	"metal_detector": {
		"name": "Metal Detector",
		"path": MetalDetector.MODEL_PATH,
		"scale": 1.0,


		"lie": Vector3(0.0, 0.0, 0.757),


		"impact": "item_clatter",
	},
	"lighter": {
		"name": "Lighter",
		"path": Lighter.MODEL_PATH,
		"scale": 1.0,


		"lie": Vector3.ZERO,


		"thick": 0.03,


		"impact": "item_clatter",
	},
}


const PROP_THICK:= 0.1


const PROP_WIDTH:= 0.14


var _bounds:= AABB()


var tool_id:= "spade"


static func has_spec(id: String) -> bool:
	return SPECS.has(id)


static func display_name_of(id: String) -> String:

	var spec:= SPECS.get(id, { }) as Dictionary
	return Cfg.tr(str(spec ["name"])) if spec.has("name") else id


func _spec() -> Dictionary:
	return SPECS.get(tool_id, SPECS ["spade"])


func passes_through_barrows() -> bool:
	return true


func _build_model() -> void:
	var spec:= _spec()
	var packed: PackedScene = load(str(spec ["path"]))
	if packed == null:
		push_error("ToolProp: cannot load %s" % spec ["path"])
		return
	var inst: Node3D = packed.instantiate()
	inst.name = "Model"


	if tool_id == "yard_vac":
		YardVac.strip_intake_clumps(inst)
	var lie: Vector3 = spec ["lie"]
	var b:= Basis.from_euler(lie).scaled(Vector3.ONE * float(spec ["scale"]))
	inst.transform = Transform3D(b, Vector3.ZERO)
	add_child(inst)
	_model = inst


	if tool_id == "lighter":
		Lighter.prepare_prop(inst)
	_meshes.assign(inst.find_children("*", "MeshInstance3D", true, false))
	if inst is MeshInstance3D:
		_meshes.append(inst as MeshInstance3D)
	_centre_model(inst)


	if tool_id == "yard_vac":
		YardVac.skin(inst)


	if tool_id == "lighter":
		return


	for mi in _meshes:
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src:= mi.get_active_material(s)
			if src is not StandardMaterial3D:
				continue
			var m:= (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.metallic = minf(m.metallic, 0.2)
			m.roughness = maxf(m.roughness, 0.62)
			mi.set_surface_override_material(s, m)


func _centre_model(inst: Node3D) -> void:
	_bounds = _posed_bounds()
	if _bounds.size == Vector3.ZERO:
		return
	var c:= _bounds.get_center()

	inst.position = Vector3(- c.x, _thickness() * 0.5 - c.y, - c.z)
	_bounds.position += inst.position


func _posed_bounds() -> AABB:
	var out:= AABB()
	var first:= true
	for mi in _meshes:
		if mi.mesh == null:
			continue
		var t:= Transform3D.IDENTITY
		var cur: Node3D = mi
		while cur != null and cur != self:
			t = cur.transform * t
			cur = cur.get_parent() as Node3D
		var a:= t * mi.mesh.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


func _build_shapes() -> void:
	mass = 2.2
	var h:= _thickness()
	var length:= maxf(_bounds.size.z, PROP_WIDTH)
	_shape_box(Vector3(PROP_WIDTH, h, length), Vector3(0.0, h * 0.5, 0.0))


func _thickness() -> float:
	return maxf(_bounds.size.y, float(_spec().get("thick", PROP_THICK)))


func carry_mode() -> Mode:
	return Mode.HELD


func impact_sfx() -> String:
	return str(_spec().get("impact", ""))


func interact_verb() -> String:
	return tr("Pick up %s") % display_name_of(tool_id)


func interact_action() -> String:
	return "interact"


func interact_key() -> String:
	return InputSetup.hint(interact_action())


func claim(player: Player) -> bool:
	if not GameState.grant_tool(tool_id):
		return false
	Audio.play_3d("item_pick", global_position, -4.0)
	if player != null:
		player.equip_tool_id(tool_id)
	return true


func to_state() -> Dictionary:
	return { "tool": tool_id }


func from_state(state: Dictionary) -> void:
	var id:= str(state.get("tool", ""))
	if id != "" and id != tool_id and has_spec(id):
		tool_id = id


		for child in get_children():
			child.queue_free()
		_meshes.clear()
		_build()
