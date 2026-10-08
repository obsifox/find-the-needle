class_name Carryable
extends RigidBody3D


enum Mode { HELD, PUSHED }


var item_id:= ""
var display_name:= "Item"


var needle_index:= -1


const HAY_LAYER:= 1 << 19

var _held:= false
var _model: Node3D


var _meshes: Array [MeshInstance3D] = []
var _highlighted:= false


var _mounted:= Transform3D.IDENTITY


var _ride_scale:= 1.0


static var _shared_materials: Dictionary = { }


static func shared_material(id: String, maker: Callable) -> Material:
	if not _shared_materials.has(id):
		_shared_materials [id] = maker.call()
	return _shared_materials [id]


func _ready() -> void:
	collision_layer = Cfg.L_PROP | Cfg.L_BELT_CATCH


	collision_mask = (Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_STRAND | Cfg.L_TOOL
		| Cfg.L_BUILD | Cfg.L_PROP)

	if not shoved_by_tools():
		collision_mask &= ~ Cfg.L_TOOL
	can_sleep = true
	continuous_cd = false
	_build()
	_arm_impact()
	if passes_through_barrows():
		add_to_group(Wheelbarrow.GEAR_GROUP)
		Wheelbarrow.keep_apart(self)
	if stays_upright():
		sync_upright_lock()
		sleeping_state_changed.connect(_on_sleeping_changed)


func _build() -> void:
	_build_model()
	_build_shapes()


func _build_model() -> void:
	pass


func _build_shapes() -> void:
	pass


func _mount_model(path: String, xform: Transform3D) -> Node3D:
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("%s: cannot load %s" % [get_script().resource_path.get_file(), path])
		return null
	var inst: Node3D = packed.instantiate()
	inst.name = "Model"


	inst.transform = Transform3D(xform.basis * size_scale(), xform.origin * size_scale())
	add_child(inst)
	_model = inst


	_mounted = xform
	_meshes.assign(inst.find_children("*", "MeshInstance3D", true, false))


	if inst is MeshInstance3D:
		_meshes.append(inst as MeshInstance3D)
	return inst


func _ground_materials(table: Dictionary) -> void:
	for mi in _meshes:
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src:= mi.get_active_material(i)
			if src is not StandardMaterial3D:
				continue
			var tweak: Dictionary = table.get(src.resource_name, { })
			if tweak.is_empty():
				continue
			var m:= (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			if tweak.has("metallic"):
				m.metallic = tweak ["metallic"]
			if tweak.has("roughness"):
				m.roughness = tweak ["roughness"]
			if tweak.has("color"):
				m.albedo_color = tweak ["color"]
			elif tweak.has("albedo"):
				var k: float = tweak ["albedo"]
				m.albedo_color = Color(m.albedo_color.r * k, m.albedo_color.g * k,
					m.albedo_color.b * k, m.albedo_color.a)
			mi.set_surface_override_material(i, m)


func size_scale() -> float:
	return 1.0


func _shape_box(size: Vector3, pos: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var s:= size_scale()
	var cs:= CollisionShape3D.new()
	var sh:= BoxShape3D.new()
	sh.size = size * s
	cs.shape = sh
	cs.transform = Transform3D(basis, pos * s)
	add_child(cs)


func _shape_cylinder(radius: float, height: float, pos: Vector3,
		basis: Basis = Basis.IDENTITY) -> void:
	var s:= size_scale()
	var cs:= CollisionShape3D.new()
	var sh:= CylinderShape3D.new()
	sh.radius = radius * s
	sh.height = height * s
	cs.shape = sh
	cs.transform = Transform3D(basis, pos * s)
	add_child(cs)


static var _hover_mat: StandardMaterial3D


static func hover_material() -> StandardMaterial3D:
	if _hover_mat == null:
		var m:= StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0.3)


		m.no_depth_test = false
		m.render_priority = 1
		_hover_mat = m
	return _hover_mat


func set_highlighted(on: bool) -> void:
	if on == _highlighted:
		return
	_highlighted = on
	var m:= hover_material() if on else null
	for mi in _meshes:
		mi.material_overlay = m


func detach_model() -> Node3D:
	if _model == null or not is_instance_valid(_model):
		return null
	set_highlighted(false)
	var m:= _model
	_model = null
	_meshes.clear()
	remove_child(m)
	return m


func ride_box() -> AABB:
	var out:= AABB()
	if not is_inside_tree():
		return out
	var inv:= global_transform.affine_inverse()
	var have:= false
	for mi in _meshes:
		if mi.mesh == null or not mi.is_inside_tree():
			continue
		var box: AABB = (inv * mi.global_transform) * mi.mesh.get_aabb()
		out = box if not have else out.merge(box)
		have = true
	return out


func set_ride_scale(f: float) -> void:
	_ride_scale = maxf(f, 0.01)
	if _model == null or not is_instance_valid(_model):
		return
	var s:= size_scale() * _ride_scale
	_model.transform = Transform3D(_mounted.basis * s, _mounted.origin * s)


func ride_scale() -> float:
	return _ride_scale


func is_held() -> bool:
	return _held


func carry_pivot() -> Vector3:
	return Vector3.ZERO


func carry_mode() -> Mode:
	return Mode.HELD


func tilt_pivot() -> Vector3:
	return carry_pivot()


func tilt_limits() -> Vector3:
	return Vector3.ONE * Cfg.CARRY_TILT_LIMIT


func push_reach() -> float:
	return 0.0


func interact_verb() -> String:
	return tr("Pick up")


func interact_action() -> String:
	return "primary" if carry_mode() == Mode.HELD else "interact"


func interact_key() -> String:
	return InputSetup.hint(interact_action())


func carry_yaw() -> float:
	return 0.0


func carry_aim() -> Basis:
	return Basis.IDENTITY


func carry_pitches() -> bool:
	return false


func stays_upright() -> bool:
	return false


func shoved_by_tools() -> bool:
	return true


func passes_through_barrows() -> bool:
	return false


func stacks_in_arms() -> bool:
	return hay_strands() > 0 and carry_mode() == Mode.HELD


var carrier: Player = null


func pick_up() -> void:
	if _held:
		return


	BeltPath.release(self)
	_held = true


	_tumbling = false
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true


	sync_upright_lock()
	sleeping = false


	Audio.play_3d("item_pick", global_position, -5.0)


func warp(xform: Transform3D) -> void:
	_wake_sleepers()
	var was:= freeze_mode
	if freeze:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xform)
	global_transform = xform
	freeze_mode = was


func _wake_sleepers() -> void:
	var box:= ride_box()
	if box.size == Vector3.ZERO:
		return
	box = box.grow(0.05)
	var shape:= BoxShape3D.new()
	shape.size = box.size
	var query:= PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = global_transform * Transform3D(Basis(), box.get_center())
	query.collision_mask = Cfg.L_PROP | Cfg.L_STRAND
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var rb:= hit.get("collider") as RigidBody3D
		if rb != null:
			lost_floor(rb)


func release(velocity: Vector3, angular: Vector3 = Vector3.ZERO) -> void:
	if not _held:
		return
	_held = false
	carrier = null
	freeze = false


	sync_upright_lock()
	linear_velocity = velocity
	angular_velocity = angular
	sleeping = false
	arm_flight()


	Audio.play_3d("item_drop", global_position, -7.0)


static func skip_speed() -> float:
	return Cfg.BELT_DECK_THICK * float(maxi(Engine.physics_ticks_per_second, 1))


func _thinnest() -> float:
	if _thin > 0.0:
		return _thin
	var thin:= INF
	for child in get_children():
		var cs:= child as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var shape:= cs.shape
		if shape is BoxShape3D:
			var b:= (shape as BoxShape3D).size
			thin = minf(thin, minf(b.x, minf(b.y, b.z)))
		elif shape is CylinderShape3D:
			var cy:= shape as CylinderShape3D
			thin = minf(thin, minf(cy.height, cy.radius * 2.0))
		elif shape is SphereShape3D:
			thin = minf(thin, (shape as SphereShape3D).radius * 2.0)
		elif shape is CapsuleShape3D:
			thin = minf(thin, (shape as CapsuleShape3D).radius * 2.0)
	_thin = thin if thin < INF else 0.0
	return _thin

var _thin:= 0.0


const ARM_MARGIN:= 0.5


func flight_arm_speed() -> float:
	return (_thinnest() + Cfg.BELT_DECK_THICK) * float(maxi(Engine.physics_ticks_per_second, 1)) * ARM_MARGIN


func arm_flight() -> void:


	if linear_velocity.length() < flight_arm_speed():


		_arm_by = Time.get_ticks_msec() + ARM_WATCH_MS
		return
	_arm_by = 0
	_flight_still = 0.0
	if not continuous_cd:
		continuous_cd = true


var _arm_by:= 0


const ARM_WATCH_MS:= 4000


func _watch_arm(state: PhysicsDirectBodyState3D) -> void:
	var at:= flight_arm_speed() - 2.0 * state.total_gravity.length() * state.step
	if state.linear_velocity.length_squared() >= at * at:
		_arm_by = 0
		_flight_still = 0.0
		set_deferred(&"continuous_cd", true)
	elif Time.get_ticks_msec() > _arm_by:
		_arm_by = 0


var _flight_still:= 0.0


func _watch_flight(state: PhysicsDirectBodyState3D) -> void:
	if state.linear_velocity.length_squared() > SETTLE_LINEAR * SETTLE_LINEAR:
		_flight_still = 0.0
		return
	_flight_still += state.step
	if _flight_still >= SETTLE_SECONDS:
		set_deferred(&"continuous_cd", false)


const SETTLE_LINEAR:= 0.15
const SETTLE_ANGULAR:= 0.5
const SETTLE_SECONDS:= 0.3


var _tumbling:= false
var _still_for:= 0.0


var _planted:= false

var _pinned:= false

static var pin_enabled: bool = not ("--nopin" in OS.get_cmdline_user_args())


var _was_frozen:= false


func sync_upright_lock() -> void:


	if _was_frozen and not freeze:
		_planted = false
		_still_for = 0.0
	_was_frozen = freeze
	var want:= stays_upright() and not freeze and not _tumbling
	if axis_lock_angular_x != want or axis_lock_angular_y != want or axis_lock_angular_z != want:
		axis_lock_angular_x = want
		axis_lock_angular_y = want
		axis_lock_angular_z = want
	var put:= want and _planted
	if axis_lock_linear_x != put or axis_lock_linear_z != put:
		axis_lock_linear_x = put
		axis_lock_linear_z = put
	_pin(put)


func _pin(on: bool) -> void:
	if on == _pinned or not pin_enabled:
		return
	_pinned = on
	if on:
		PhysicsServer3D.body_set_mode(get_rid(), PhysicsServer3D.BODY_MODE_STATIC)
	elif not freeze:
		PhysicsServer3D.body_set_mode(get_rid(), PhysicsServer3D.BODY_MODE_RIGID)
		sleeping = false


func is_pinned() -> bool:
	return _pinned


func tumble() -> void:
	if not stays_upright():
		return
	_tumbling = true
	_planted = false
	_still_for = 0.0
	sync_upright_lock()


func unplant() -> void:
	if not stays_upright() or not _planted:
		return
	_planted = false
	_still_for = 0.0
	sleeping = false
	sync_upright_lock()


func floor_gone() -> void:
	unplant()


static func lost_floor(rb: RigidBody3D) -> void:
	var item:= rb as Carryable
	if item != null:
		item.floor_gone()
	if rb.sleeping:
		rb.sleeping = false


func is_tumbling() -> bool:
	return _tumbling


func level_in_hand() -> void:
	var xf:= global_transform
	var up:= xf.basis.y.normalized()
	if up.dot(Vector3.UP) > 0.9999:
		return
	var level:= Basis(Quaternion(up, Vector3.UP)) * xf.basis
	var tp:= tilt_pivot()
	warp(Transform3D(level, xf * tp - level * tp))


func _watch_settle(state: PhysicsDirectBodyState3D) -> void:
	if state.linear_velocity.length() > SETTLE_LINEAR or state.angular_velocity.length() > SETTLE_ANGULAR:
		_still_for = 0.0
		return
	_still_for += state.step
	if _still_for >= SETTLE_SECONDS:
		_tumbling = false
		_planted = true

		_settle.call_deferred()


func _on_sleeping_changed() -> void:
	if sleeping and not freeze and (_tumbling or not _planted):
		_tumbling = false
		_planted = true
		_settle.call_deferred()


func _settle() -> void:
	sync_upright_lock()


const IMPACT_MIN_DV:= 1.2


const IMPACT_FULL_DV:= 4.0


const IMPACT_COOLDOWN:= 0.14
const IMPACT_QUIET_DB:= -16.0
const IMPACT_LOUD_DB:= -3.0

var _impact_mute_until:= 0.0
var _impact_armed:= false


func impact_sfx() -> String:
	return ""


func impact_min_dv() -> float:
	return IMPACT_MIN_DV


func mute_impact(seconds: float) -> void:
	_impact_mute_until = Time.get_ticks_msec() / 1000.0 + seconds


func _arm_impact() -> void:
	if impact_sfx() == "":
		return
	_impact_armed = true


	contact_monitor = true
	max_contacts_reported = 4


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:


	if _tumbling or (stays_upright() and not _planted and not freeze):
		_watch_settle(state)


	if continuous_cd:
		_watch_flight(state)
	elif _arm_by != 0:
		_watch_arm(state)
	if not _impact_armed:
		return
	var hardest:= 0.0
	for i in state.get_contact_count():
		hardest = maxf(hardest, state.get_contact_impulse(i).length())
	if hardest > 0.0:
		_on_impact(hardest / mass)


func _on_impact(dv: float) -> void:
	var floor_dv:= impact_min_dv()
	if _held or freeze or dv < floor_dv:
		return
	var now:= Time.get_ticks_msec() / 1000.0
	if now < _impact_mute_until:
		return
	_impact_mute_until = now + IMPACT_COOLDOWN
	var t:= clampf(inverse_lerp(floor_dv, IMPACT_FULL_DV, dv), 0.0, 1.0)
	Audio.play_3d(impact_sfx(), global_position,
		lerpf(IMPACT_QUIET_DB, IMPACT_LOUD_DB, t))


func on_carried(_xform: Transform3D, _moved: Transform3D, _delta: float) -> void:
	pass


func on_drawn() -> void:
	pass


func carry_status() -> String:
	var raw:= hay_strands()
	if raw > 0:
		return tr_n("%d strand", "%d strands", raw) % raw
	return ""


func hay_strands() -> int:
	return 0


func clearance_size() -> Vector3:
	return Vector3.ZERO


static func room_for(space: PhysicsDirectSpaceState3D, at: Vector3,
		basis: Basis, size: Vector3, exclude: Array [RID] = []) -> bool:
	if space == null:
		return false
	if _room_probe == null:
		_room_probe = BoxShape3D.new()
		_room_query = PhysicsShapeQueryParameters3D.new()
		_room_query.shape = _room_probe
		_room_query.collision_mask = Cfg.L_PROP
		_room_query.collide_with_areas = false
	_room_probe.size = size
	_room_query.transform = Transform3D(basis, at)
	_room_query.exclude = exclude
	return space.intersect_shape(_room_query, 1).is_empty()


static var _room_probe: BoxShape3D = null
static var _room_query: PhysicsShapeQueryParameters3D = null


func can_rip() -> bool:
	return false


func rips_loose() -> bool:
	return false


func rips_to_shreds() -> bool:
	return false


func rip_label() -> String:
	return tr("Rip apart the %s") % Cfg.lower_in_english(display_name)


func rip_yield() -> int:
	return hay_strands()


func holds_needle() -> bool:
	return needle_index >= 0


func to_state() -> Dictionary:
	return { }


func from_state(_state: Dictionary) -> void:
	pass
