class_name Pitchfork
extends Shovel


const MODEL_PATH:= "res://assets/models/pitchfork.glb"


const MODEL_SCALE:= Vector3(0.0175, 0.0105, 0.0085)


const MODEL_CENTER:= Vector3(2.602352, 0.30916, 7.10301)
const MODEL_TIP_FROM_CENTER:= 66.64533


const FORK_W:= 0.404
const FORK_D:= 0.24
const FORK_HEAD_Z:= -0.4


const TINE_W:= 0.018
const TINE_H:= 0.035
const TINE_LEN:= 0.24
const HANDLE_LEN:= 1.05


const LOAD_Z:= FORK_HEAD_Z


const LOAD_Y:= 0.0


const BASIN_Y:= 0.09
const SCOOP_RADIUS:= Cfg.SCOOP_RADIUS * 1.25


const SCOOP_MAX:= Cfg.SCOOP_MAX + 8
const PITCH_REST_FORWARD:= 0.55
const PITCH_REST_DOWN:= 0.3


const HAND_PITCH:= 0.0


const PIVOT:= Vector3(0.0, 0.0, FORK_HEAD_Z)


const FORK_SWING_GRIP:= Vector3(0.06, -0.3, -0.72)


func _init() -> void:
	_swing = DigSwing.fork()


func swing_grip() -> Vector3:
	return FORK_SWING_GRIP


func _build_samples() -> void:
	for j in 3:
		for i in 4:
			var x:= lerpf(- FORK_W * 0.4, FORK_W * 0.4, float(i) / 3.0)
			var z:= lerpf(- FORK_D * 0.4, FORK_D * 0.4, float(j) / 2.0)
			_sample_offsets.append(Vector3(x, 0.0, z))


func _build_body() -> void:
	body = AnimatableBody3D.new()
	body.name = "PitchforkCollider"
	body.sync_to_physics = false
	body.collision_layer = Cfg.L_TOOL


	body.collision_mask = Cfg.L_WORLD | Cfg.L_STRAND | Cfg.L_BUILD


	for i in 6:
		var x:= lerpf(- FORK_W * 0.477, FORK_W * 0.477, float(i) / 5.0)
		_shape_box(Vector3(TINE_W, TINE_H, TINE_LEN),
			Vector3(x, 0.0, FORK_HEAD_Z))
	_shape_box(Vector3(FORK_W, TINE_H * 1.5, 0.055),
		Vector3(0.0, 0.0, FORK_HEAD_Z + TINE_LEN * 0.5))
	var handle_start:= FORK_HEAD_Z + TINE_LEN * 0.5 - 0.03
	_shape_box(Vector3(0.045, 0.045, HANDLE_LEN),
		Vector3(0.0, 0.0, handle_start + HANDLE_LEN * 0.5))

	basin = Area3D.new()
	basin.name = "TineBasin"
	basin.collision_layer = 0
	basin.collision_mask = Cfg.L_STRAND
	basin.monitorable = false


	_basin_shape = CollisionShape3D.new()
	var bshape:= BoxShape3D.new()


	bshape.size = Vector3(FORK_W * 1.08, 0.22, FORK_D * 1.08)
	_basin_shape.shape = bshape
	_basin_shape.position = Vector3(0.0, BASIN_Y, LOAD_Z)
	basin.add_child(_basin_shape)
	body.add_child(basin)

	world_root.add_child(body)
	_mount_pitchfork_mesh()
	body.global_transform = _held_transform()


func _mount_pitchfork_mesh() -> void:
	visual = Node3D.new()
	visual.name = "PitchforkVisual"
	player.camera.add_child(visual)

	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		push_error("Pitchfork: could not load %s" % MODEL_PATH)
		return
	var inst: Node3D = packed.instantiate()


	var b:= Basis(Vector3.UP, PI).scaled(MODEL_SCALE)

	var desired_tip_z:= FORK_HEAD_Z - TINE_LEN * 0.5
	var centred_tip_z:= - MODEL_TIP_FROM_CENTER * MODEL_SCALE.z
	var model_offset:= Vector3(0.0, 0.0, desired_tip_z - centred_tip_z)
	inst.transform = Transform3D(b, - (b * MODEL_CENTER) + model_offset)
	_ground_pitchfork_materials(inst)
	visual.add_child(inst)
	_update_visual_pose()


func _ground_pitchfork_materials(inst: Node3D) -> void:
	var meshes:= inst.find_children("*", "MeshInstance3D", true, false)
	if inst is MeshInstance3D:
		meshes.append(inst)
	for child in meshes:
		var mi:= child as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src:= mi.get_active_material(s)
			if not src is StandardMaterial3D:
				continue
			var m:= (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.metallic = minf(m.metallic, 0.65)
			m.roughness = maxf(m.roughness, 0.52)
			mi.set_surface_override_material(s, m)


func _shape_box(size: Vector3, pos: Vector3) -> void:
	var cs:= CollisionShape3D.new()
	var shape:= BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


func _local_pose() -> Transform3D:
	var basis:= Basis.from_euler(Vector3(_aim_pitch + HAND_PITCH, _aim_yaw, 0.0))
	var rest:= Vector3(0.0, - PITCH_REST_DOWN, - PITCH_REST_FORWARD)
	return Transform3D(basis, rest + PIVOT - basis * PIVOT)


func pan_geometry() -> Dictionary:
	var s:= blade_scale()
	return {
		"xf": body.global_transform.orthonormalized(),
		"origin": Vector3(0.0, LOAD_Y, LOAD_Z) * s,
		"w": FORK_W * s,
		"d": FORK_D * s,
		"max": Tech.scoop_max(SCOOP_MAX, s),
		"radius": SCOOP_RADIUS * s,
		"track": "",
	}


func blade_scale() -> float:
	return Tech.fork_scale()


func size_node() -> String:
	return "fork_size"
