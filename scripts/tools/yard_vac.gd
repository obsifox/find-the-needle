class_name YardVac
extends Node3D


const MODEL_PATH:= "res://assets/models/compiled/yard_vac.scn"


const SPEC:= "res://assets/models/yard_vac_materials.json"


const MOUTH_MODEL:= Vector3(0.0, 0.055, 0.862)


const VIS_SCALE:= 0.56


const MOUTH_LOCAL:= Vector3(0.124, -0.243, -1.12)


const POSE_LOOK:= 2.0


const POSE_ROLL:= deg_to_rad(30.0)


const SWAY_GAIN:= 0.022
const SWAY_MAX:= 0.1


const SWAY_EASE:= 9.0


const SWAY_ROLL_RATIO:= 0.55


const BOB_PITCH:= 0.03
const BOB_HEAVE:= 0.015
const BOB_SWAY:= 0.03
const BOB_BANK:= 0.05


const KICK_BACK:= 0.07
const KICK_PITCH:= deg_to_rad(4.5)

const KICK_DECAY:= 6.0


const KICK_POUR:= 0.45


const SHAKE_AMP:= 0.0045
const SHAKE_HZ_A:= 27.0
const SHAKE_HZ_B:= 41.0


const SHAKE_BOG:= 1.9


const AIM_REACH:= 2.0


const LOOSE_REACH_H:= 0.55


const INTAKE_CLUMPS:= 7


const MAX_PULL_PER_TICK:= 120


const RUSTLE_EVERY:= 0.42


const MOTOR_DB:= -12.0


const MOTOR_BOG_PITCH:= 0.92


const INBOUND_SPEED_MIN:= 0.95
const INBOUND_SPEED_MAX:= 3.4


const INBOUND_ARRIVE:= 0.1


const INBOUND_GIVEUP:= 2.2


const INBOUND_HOLD:= 3.2


const META_VAC_MASK:= &"vac_prev_mask"


const GULP_EVERY:= 0.08

var player: Player
var field: HayField
var live: LiveStrandManager
var world_root: Node3D

var hud: Hud

var visual: Node3D
var vfx: VacVfx


var _fill:= 0


var _suck_owed:= 0.0
var _pour_owed:= 0.0

var _active:= false
var _sucking:= false
var _pouring:= false
var _rustle_t:= 0.0


var _bite:= Vector3.ZERO
var _has_bite:= false
var _bite_is_pile:= false

var _voice:= -1


var _bog:= 0.0


var _inbound: Dictionary = { }


var _bite_t:= 0.0
var _gulp_t:= 0.0


var _into: Node3D = null


var _outbound: Dictionary = { }

var _show_owed:= 0.0


var _falling: Dictionary = { }

var _heaps: Array [HayTuft] = []

var _belt_held:= 0.0


var _parcel: Array [RigidBody3D] = []
var _parcel_left:= 0
var _parcel_age:= 0.0

var _badge_gap:= 0.0
var _dump_sound:= 0.0


var _sway:= Vector2.ZERO
var _look:= Vector2.ZERO
var _looked:= false
var _kick:= 0.0
var _shake_t:= 0.0

var _run_anim: AnimationPlayer


var _fill_tracks: Array = []
var _run_clip:= ""
var _fill_clip:= ""

var _rng:= RandomNumberGenerator.new()


func _exit_tree() -> void:
	_stop_motor()
	_drop_stream()
	_land_outbound()


	for id: int in _falling.keys():
		_let_go_falling(id)


func setup(p_world: Node3D, p_field: HayField, p_live: LiveStrandManager) -> void:
	world_root = p_world
	field = p_field
	live = p_live
	_rng.randomize()
	_build()
	set_active(false)


func _build() -> void:
	_mount_mesh()
	vfx = VacVfx.new()
	vfx.name = "YardVacVfx"
	world_root.add_child(vfx)


func _mount_mesh() -> void:
	visual = Node3D.new()
	visual.name = "YardVacVisual"
	player.camera.add_child(visual)

	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		push_error("YardVac: could not load %s" % MODEL_PATH)
		return
	var inst: Node3D = packed.instantiate()
	visual.add_child(inst)
	skin(inst)
	_hide_canned_clumps(inst)
	_wire_animation(inst)
	_update_visual_pose()


static func skin(inst: Node3D) -> void:
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("YardVac: no material table at %s, it will render untextured"
			% SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	var meshes:= inst.find_children("*", "MeshInstance3D", true, false)
	if inst is MeshInstance3D:
		meshes.append(inst)
	for node in meshes:
		var mi:= node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src:= mi.get_active_material(i)
			if src == null:
				continue
			var key:= src.resource_name
			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = HayCompressor.make_material(key, spec, shader)
			if built [key] == null:


				if not (spec.get("clears", { }) as Dictionary).has(key):
					missed [key] = true
				continue
			mi.set_surface_override_material(i, built [key])
	if not missed.is_empty():
		push_warning("YardVac: no table entry for %s" % ", ".join(missed.keys()))


static var _spec_cache: Dictionary = { }


static func spec_table() -> Dictionary:
	if not _spec_cache.is_empty():
		return _spec_cache


	var res: JSON = load(SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		_spec_cache = res.data
	elif FileAccess.file_exists(SPEC):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
		if typeof(parsed) == TYPE_DICTIONARY:
			_spec_cache = parsed
	return _spec_cache


func _hide_canned_clumps(inst: Node3D) -> void:
	for lump in intake_clumps(inst):
		lump.visible = false


static func intake_clumps(inst: Node3D) -> Array [Node3D]:
	var out: Array [Node3D] = []
	for i in INTAKE_CLUMPS:
		var lump:= inst.find_child("YV_Eat_%d" % i, true, false) as Node3D
		if lump != null:
			out.append(lump)
	return out


static func strip_intake_clumps(inst: Node3D) -> void:
	for lump in intake_clumps(inst):
		lump.get_parent().remove_child(lump)
		lump.free()


func _wire_animation(inst: Node3D) -> void:
	_run_anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _run_anim == null:
		return
	_run_clip = _clip_named(_run_anim, "Run")
	_fill_clip = _clip_named(_run_anim, "Fill")


	if _run_clip != "":
		var a:= _run_anim.get_animation(_run_clip)
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR

	_read_fill()
	_keep_only_run()
	_draw_fill()


func _read_fill() -> void:
	_fill_tracks.clear()
	if _fill_clip == "":
		return
	var anim:= _run_anim.get_animation(_fill_clip)
	var base:= _run_anim.get_node_or_null(_run_anim.root_node)
	if anim == null or base == null:
		return
	for t in anim.get_track_count():
		var keys:= anim.track_get_key_count(t)
		if keys < 2:
			continue
		var node:= base.get_node_or_null(NodePath(anim.track_get_path(t).get_concatenated_names()))
		if node == null:
			continue


		var kind:= anim.track_get_type(t)
		if kind != Animation.TYPE_POSITION_3D and kind != Animation.TYPE_SCALE_3D and kind != Animation.TYPE_ROTATION_3D:
			continue
		_fill_tracks.append([node, kind, anim.track_get_key_value(t, 0),
			anim.track_get_key_value(t, keys - 1)])


func _keep_only_run() -> void:
	var run_clip:= _run_anim.get_animation(_run_clip) if _run_clip != "" else null
	for lib: StringName in _run_anim.get_animation_library_list():
		_run_anim.remove_animation_library(lib)
	var lib_out:= AnimationLibrary.new()
	if run_clip != null:
		lib_out.add_animation(&"Run", run_clip)
		_run_clip = "Run"
	else:
		_run_clip = ""
	_run_anim.add_animation_library(&"", lib_out)


func _clip_named(ap: AnimationPlayer, want: String) -> String:
	for clip: String in ap.get_animation_list():
		if clip == want or clip.get_slice("/", clip.get_slice_count("/") - 1) == want:
			return clip
	return ""


func set_active(on: bool) -> void:
	_active = on
	if visual != null:
		visual.visible = on
	if not on:
		_sucking = false
		_pouring = false
		_end_pour()
		_land_outbound()
		_into = null


		_sway = Vector2.ZERO
		_looked = false
		_kick = 0.0
		_shake_t = 0.0
		if vfx != null:
			vfx.stop()
		_stop_motor()


		_drop_stream()
	_update_visual_pose()


func is_active() -> bool:
	return _active


func set_sucking(on: bool) -> void:
	if not _active:
		return
	if on and is_full():
		if not _sucking:
			_say_full()
		return
	var was:= _sucking
	_sucking = on and not is_full()


	if _sucking:
		_bite_t = 0.0
		if not was:
			_kick = 1.0
	_sync_motor()


func set_pouring(on: bool) -> void:
	if not _active:
		return
	var was:= _pouring
	_pouring = on and _fill > 0
	if _pouring and not was:
		_kick = KICK_POUR
	if not _pouring:
		_end_pour()
	_sync_motor()


func unload_target() -> Node3D:
	return _into if is_instance_valid(_into) else null


func is_full() -> bool:
	return _fill >= Tech.vac_capacity()


func fill() -> int:
	return _fill


func fill_fraction() -> float:
	return clampf(float(_fill) / float(Tech.vac_capacity()), 0.0, 1.0)


func room() -> int:
	return maxi(Tech.vac_capacity() - _fill - _inbound.size(), 0)


func drawn_fill() -> float:
	if visual == null:
		return 0.0
	var plug:= visual.find_child("YV_Hay_Body", true, false) as Node3D
	if plug == null:
		return 0.0
	return clampf(plug.scale.z, 0.0, 1.0)


func inbound_count() -> int:
	return _inbound.size()


func is_sucking() -> bool:
	return _sucking


func is_pouring() -> bool:
	return _pouring


func has_bite() -> bool:
	return _has_bite


func bite_is_pile() -> bool:
	return _has_bite and _bite_is_pile


func aim_point() -> Dictionary:
	if not _active or not _has_bite:
		return { }
	return {
		"position": _bite,
		"loose": not _bite_is_pile,
		"radius": Tech.vac_bite_radius() if _bite_is_pile else Tech.vac_pull_radius(),
	}


func debug_fill(count: int) -> void:
	_fill = clampi(count, 0, Tech.vac_capacity())
	_draw_fill()


func clear() -> void:
	_drop_stream()
	_land_outbound()
	_fill = 0
	_suck_owed = 0.0
	_end_pour()
	_draw_fill()


func _say_full() -> void:
	Audio.play("ui_error")
	if hud != null:
		hud.show_toast(tr("THE VAC IS FULL  ·  HOLD RIGHT CLICK TO EMPTY IT"))


func _sync_motor() -> void:
	var want:= _sucking or _pouring
	if want:
		_start_motor()
	else:
		_stop_motor()


func _start_motor() -> void:
	if _run_anim != null and _run_clip != "" and not _run_anim.is_playing():
		_run_anim.play(_run_clip)


	if _voice < 0:
		_voice = Audio.loop_acquire("vac_motor")


func _stop_motor() -> void:
	if _run_anim != null and _run_anim.is_playing():
		_run_anim.stop()
	if _voice >= 0:
		Audio.loop_release(_voice)
		_voice = -1


func _drive_motor(delta: float) -> void:
	if _voice < 0:
		return
	var loaded:= _sucking and _has_bite
	_bog = move_toward(_bog, 1.0 if loaded else 0.0, delta * 4.0)
	Audio.loop_update(_voice, mouth_position(), MOTOR_DB,
		lerpf(1.0, MOTOR_BOG_PITCH, _bog))


static func pose_basis() -> Basis:
	var to_aim:= (Vector3(0.0, 0.0, - POSE_LOOK) - MOUTH_LOCAL).normalized()
	var pitch:= - asin(clampf(to_aim.y, -1.0, 1.0))
	var yaw:= atan2(to_aim.x, to_aim.z)
	return Basis.from_euler(Vector3(pitch, yaw, POSE_ROLL))


static func local_pose() -> Transform3D:
	var b:= pose_basis().scaled(Vector3.ONE * VIS_SCALE)
	return Transform3D(b, MOUTH_LOCAL - b * MOUTH_MODEL)


func motion_pose() -> Transform3D:
	var roll:= - _sway.x * SWAY_ROLL_RATIO
	var kick:= 0.0


	var stride:= Transform3D.IDENTITY
	if player != null:
		kick = player.land_kick() * 0.5
		stride = player.stride_pose(BOB_SWAY, BOB_HEAVE, BOB_PITCH, BOB_BANK)
	var b:= Basis.from_euler(Vector3(_sway.y + kick + _kick * KICK_PITCH,
		_sway.x, roll))
	var buzz:= Vector3.ZERO
	if _shake_t > 0.0:
		var s:= SHAKE_AMP * lerpf(1.0, SHAKE_BOG, _bog)
		buzz = Vector3(sin(_shake_t * TAU * SHAKE_HZ_A) * s,
			sin(_shake_t * TAU * SHAKE_HZ_B) * s * 0.8,
			sin(_shake_t * TAU * SHAKE_HZ_A * 0.5) * s * 0.5)
	return stride * Transform3D(b, buzz + Vector3(0.0, 0.0, _kick * KICK_BACK))


func _update_visual_pose() -> void:
	if visual != null:
		visual.transform = motion_pose() * local_pose()


func _process(delta: float) -> void:
	if not _active or player == null or player.camera == null:
		return
	_kick = maxf(_kick - delta * KICK_DECAY, 0.0)
	if _sucking or _pouring:
		_shake_t += delta
	else:
		_shake_t = 0.0
	_drive_sway(delta)
	_update_visual_pose()
	_draw_fill()
	if vfx != null:
		vfx.track_mouth(mouth_position())


func _drive_sway(delta: float) -> void:
	var fwd:= - player.camera.global_transform.basis.z
	var now:= Vector2(atan2(fwd.x, fwd.z), asin(clampf(fwd.y, -1.0, 1.0)))
	if not _looked:
		_looked = true
		_look = now
		return
	var rate:= Vector2(wrapf(now.x - _look.x, - PI, PI), now.y - _look.y) / maxf(delta, 0.0001)
	_look = now


	var want:= Vector2(
		clampf(- rate.x * SWAY_GAIN, - SWAY_MAX, SWAY_MAX),
		clampf(- rate.y * SWAY_GAIN, - SWAY_MAX, SWAY_MAX))
	_sway = _sway.lerp(want, clampf(delta * SWAY_EASE, 0.0, 1.0))


func mouth_position() -> Vector3:
	if player == null or player.camera == null:
		return global_position
	return player.camera.global_transform * (motion_pose() * MOUTH_LOCAL)


func mouth_direction() -> Vector3:
	if player == null or player.camera == null:
		return Vector3.FORWARD
	return (player.camera.global_transform.basis * motion_pose().basis
		* (pose_basis() * Vector3.BACK)).normalized()


func _physics_process(delta: float) -> void:


	_land_straw(delta)
	_parcel_age += delta
	_badge_gap = maxf(0.0, _badge_gap - delta)
	_dump_sound = maxf(0.0, _dump_sound - delta)
	if not _active or player == null:
		return
	_update_visual_pose()
	_aim()


	_into = _find_into() if _fill > 0 else null


	if _sucking and not _pouring:
		_gulp_wads(delta)
	if _sucking and not _pouring:
		_suck(delta)


	_fly_inbound(delta)
	_fly_outbound(delta)
	if _pouring:
		_pour(delta)
	_drive_vfx()
	_drive_motor(delta)
	if _sucking or _pouring:
		_rustle_t -= delta
		if _rustle_t <= 0.0:
			_rustle_t = RUSTLE_EVERY
			Audio.play_3d("hay_rustle", mouth_position(), -9.0)


func _aim() -> void:
	_has_bite = false
	if field == null:
		return
	var space:= get_world_3d().direct_space_state
	if space == null:
		return
	var hit:= Shovel.aim_from(player.eye_position(), player.look_direction(),
		space, field, AIM_REACH)
	if hit.is_empty():
		return
	_bite = hit ["position"]
	_has_bite = true


	_bite_is_pile = not bool(hit.get("loose", false))


func _drive_vfx() -> void:
	if vfx == null:
		return
	var mouth:= mouth_position()


	var from:= _bite if _has_bite else mouth + mouth_direction() * Cfg.VAC_REACH
	vfx.set_intake(_sucking and not _pouring, from, mouth)

	var out:= mouth_direction()
	if _pouring and is_instance_valid(_into):
		var to:= _into_point(_into) - mouth
		if to.length_squared() > 0.0001:
			out = to.normalized()
	vfx.set_pour(_pouring, mouth, out)


func _suck(delta: float) -> void:
	_suck_owed += Tech.vac_suck_rate() * delta


	_bite_t -= delta
	if _bite_t > 0.0:
		return
	_bite_t = Cfg.VAC_BITE_EVERY
	var budget:= int(_suck_owed)
	if budget <= 0:
		return


	budget = mini(budget, room())
	if budget <= 0:
		_suck_owed = 0.0
		return

	var took:= _draw_in(budget)
	if took < budget and _has_bite and _bite_is_pile:
		took += _bite_pile(budget - took)
	_suck_owed -= float(took)


	if took < budget:
		_suck_owed = 0.0


func _draw_in(budget: int) -> int:
	if live == null or budget <= 0:
		return 0
	var mouth:= mouth_position()
	var centre:= _bite if _has_bite else mouth
	var taken:= 0
	var space:= get_world_3d().direct_space_state
	if space == null:
		return 0

	live.wake_in(centre, Tech.vac_pull_radius())
	var q:= PhysicsShapeQueryParameters3D.new()
	var sphere:= SphereShape3D.new()
	sphere.radius = Tech.vac_pull_radius()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, centre)
	q.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
	q.collide_with_areas = false
	for hit: Dictionary in space.intersect_shape(q, MAX_PULL_PER_TICK):
		var rb:= hit.get("collider") as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue

		if _inbound.has(rb.get_instance_id()):
			continue


		if live.needles.has(rb):
			continue
		var wad:= rb as HayWad
		if wad == null and not (rb.collision_layer & Cfg.L_STRAND):
			continue

		if wad != null and wad.freeze:
			continue
		if live.is_held_by_a_tool(rb):
			continue


		if BeltPath.is_rider(rb):
			continue


		if wad != null:
			continue

		_take_inbound(rb)
		taken += 1
		if taken >= budget:
			break
	return taken


func _gulp_wads(delta: float) -> void:
	_gulp_t -= delta
	if _gulp_t > 0.0:
		return
	_gulp_t = GULP_EVERY
	if room() <= 0:
		return
	var space:= get_world_3d().direct_space_state
	if space == null:
		return
	var q:= PhysicsShapeQueryParameters3D.new()
	var sphere:= SphereShape3D.new()
	sphere.radius = Tech.vac_pull_radius()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, _bite if _has_bite else mouth_position())
	q.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
	q.collide_with_areas = false
	var ate:= false
	for hit: Dictionary in space.intersect_shape(q, MAX_PULL_PER_TICK):
		var wad:= hit.get("collider") as HayWad
		if wad == null or not wad.is_inside_tree() or wad.is_queued_for_deletion():
			continue

		if wad.freeze or wad.is_held() or BeltPath.is_rider(wad) or wad.has_meta(PropManager.META_CLAIM) or (live != null and live.is_held_by_a_tool(wad)):
			continue
		if _swallow(wad, room()) > 0:
			ate = true
		if room() <= 0:
			break
	if ate and is_full():
		_sucking = false
		_say_full()
		_sync_motor()


func _swallow(wad: HayWad, room_left: int) -> int:
	if room_left <= 0:
		return 0
	var worth:= wad.hay_strands()
	if worth > room_left:
		return 0


	Audio.play_3d("wad_land", wad.global_position, -8.0)
	if vfx != null and not wad._meshes.is_empty():
		vfx.gulp(wad._meshes [0])
	wad.queue_free()
	_fill = mini(_fill + worth, Tech.vac_capacity())
	_draw_fill()
	return worth


func _bite_pile(budget: int) -> int:
	if field == null or live == null or budget <= 0:
		return 0
	var r:= Tech.vac_bite_radius()

	_shed_needles(_bite, r)
	var taken:= field.take_in_radius(_bite, r, budget)
	var n:= taken.size()
	if n > 0:
		GameState.remove_hay(float(n))
		field.carve_volume(_bite, r, float(n) * Cfg.STRAND_VOLUME / Cfg.PACKING)
		_launch(taken)
		return n


	var reach:= maxf(r, Cfg.CELL)
	var under:= field.strands_under(_bite, reach)
	if under <= 0.0:
		return 0
	var swept:= 0

	if under <= float(budget) + 0.5:
		swept = int(round(field.sweep_under(_bite, reach, Shovel.SWEEP_HEIGHT)))
	else:


		swept = budget
		field.carve_volume(_bite, reach, float(budget) * Cfg.STRAND_VOLUME / Cfg.PACKING)
	if swept <= 0:
		return 0
	GameState.remove_hay(float(swept))


	var made: Array = []
	for k in swept:
		var at:= _bite + Vector3(_rng.randf_range(- r, r), 0.02,
			_rng.randf_range(- r, r))
		made.append({
			"transform": Transform3D(StrandFactory.random_strand_basis(_rng), at),
			"color": StrandFactory.random_tint(_rng),
		})
	_launch(made)
	return swept


func _launch(entries: Array) -> void:
	var mouth:= mouth_position()
	var shown:= 0
	var unseen:= 0
	for e: Dictionary in entries:


		if shown >= Cfg.VAC_STREAM_MAX:
			unseen += 1
			continue
		var xf: Transform3D = e ["transform"]
		var dir:= mouth - xf.origin
		if dir.length_squared() < 1e-06:
			dir = Vector3.UP
		var b:= live.spawn(xf.origin, xf.basis,
			dir.normalized() * INBOUND_SPEED_MIN, e ["color"])
		if b == null:


			unseen += 1
			continue
		_take_inbound(b)
		shown += 1
	if unseen <= 0:
		return
	_fill = mini(_fill + unseen, Tech.vac_capacity())
	_draw_fill()

	if is_full():
		_sucking = false
		_say_full()
		_sync_motor()


func _take_inbound(rb: RigidBody3D) -> void:
	var id:= rb.get_instance_id()
	if _inbound.has(id):
		return
	LiveStrandManager.hold(rb, INBOUND_HOLD)
	if not rb.has_meta(META_VAC_MASK):
		rb.set_meta(META_VAC_MASK, rb.collision_mask)
	rb.collision_mask &= ~ (Cfg.L_STRAND | Cfg.L_TOOL | Cfg.L_PROP)
	rb.gravity_scale = 0.0
	rb.sleeping = false


	rb.angular_velocity = Vector3(_rng.randf_range(-16.0, 16.0),
		_rng.randf_range(-16.0, 16.0), _rng.randf_range(-16.0, 16.0))
	_inbound [id] = [rb, 0.0]


func _release_inbound(rb: RigidBody3D) -> void:
	if not is_instance_valid(rb):
		return
	rb.gravity_scale = 1.0
	if rb.has_meta(META_VAC_MASK):
		rb.collision_mask = int(rb.get_meta(META_VAC_MASK))
		rb.remove_meta(META_VAC_MASK)


func _fly_inbound(delta: float) -> void:
	if _inbound.is_empty():
		return
	var mouth:= mouth_position()
	var done: Array [int] = []
	var arrived:= 0
	for id: int in _inbound:
		var rec: Array = _inbound [id]
		var rb:= rec [0] as RigidBody3D
		if not is_instance_valid(rb) or not rb.is_inside_tree():
			done.append(id)
			continue
		rec [1] = float(rec [1]) + delta
		var to:= mouth - rb.global_position
		var gap:= to.length()
		if gap <= INBOUND_ARRIVE:
			_release_inbound(rb)
			if live.consume(rb):
				arrived += 1
			done.append(id)
			continue


		if float(rec [1]) > INBOUND_GIVEUP:
			_release_inbound(rb)
			done.append(id)
			continue
		var near:= clampf(1.0 - gap / Tech.vac_pull_radius(), 0.0, 1.0)
		rb.linear_velocity = to / gap * lerpf(INBOUND_SPEED_MIN,
			INBOUND_SPEED_MAX, near * near)
		rb.sleeping = false
	for id: int in done:
		_inbound.erase(id)
	if arrived > 0:
		_fill = mini(_fill + arrived, Tech.vac_capacity())
		_draw_fill()
		if is_full():
			_sucking = false
			_say_full()
			_sync_motor()


func _drop_stream() -> void:
	for id: int in _inbound:
		var rec: Array = _inbound [id]
		_release_inbound(rec [0] as RigidBody3D)
	_inbound.clear()


func _shed_needles(at: Vector3, radius: float) -> void:
	if live == null:
		return
	if live.reveal_needles_in(at, radius, _needle_landing) > 0:
		Audio.play_3d("needle_ting", mouth_position(), -3.0)


func _needle_landing() -> Vector3:
	var m:= mouth_position()
	return m + Vector3(_rng.randf_range(-0.12, 0.12), -0.1,
		_rng.randf_range(-0.12, 0.12))


const POUR_THROW:= 2.0


const POUR_ARC_SPEED:= 2.6
const POUR_ARC_TIME_MIN:= 0.22
const POUR_ARC_TIME_MAX:= 0.8


const POUR_SCATTER:= 0.35

const DUMP_SOUND_EVERY:= 0.28


const OUT_SPEED:= 4.0
const OUT_GIVEUP:= 1.2

const OUT_ARRIVE:= 0.2


const LAND_MIN:= 0.1
const LAND_SPEED:= 1.0
const LAND_GIVEUP:= 1.5


const HEAP_REACH:= 1.0

const HEAPS_KEPT:= 6


const FLOOR_RING:= 1.6
const FLOOR_RING_TRIES:= 7


const PLAYER_CLEAR:= 0.75


func _pour(delta: float) -> void:
	if live == null or _fill <= 0:
		_pouring = false
		_end_pour()
		_sync_motor()
		return
	if _into != null:
		_unload(_into, delta)
	else:
		_pour_straw(delta)
	if _fill <= 0:
		_pouring = false
		_end_pour()
		_sync_motor()


func _end_pour() -> void:
	_pour_owed = 0.0
	_show_owed = 0.0
	_belt_held = 0.0
	_parcel_left = 0


func _find_into() -> Node3D:
	if player == null or _fill <= 0:
		return null
	var space:= get_world_3d().direct_space_state
	if space == null:
		return null
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * Cfg.VAC_UNLOAD_REACH)
	q.collision_mask = Cfg.L_BUILD | Cfg.L_PROP | Cfg.L_WORLD | Cfg.L_PILE
	q.collide_with_areas = true
	q.exclude = [player.get_rid()]
	var hit:= space.intersect_ray(q)
	if hit.is_empty():
		return null
	var n:= hit.get("collider") as Node
	while n != null:
		if n is DumpHatch:
			return null if (n as DumpHatch).placement_preview else n as DumpHatch
		if n is HayContainer:
			return n as HayContainer if (n as HayContainer).takes_loose() else null
		n = n.get_parent()
	return null


func _into_point(into: Node3D) -> Vector3:
	if into is DumpHatch:
		return into.to_global(DumpHatch.AIM_CENTRE)
	return (into as HayContainer).pour_point()


func _room_in(into: Node3D) -> int:
	var room:= 0
	if into is DumpHatch:
		room = (into as DumpHatch).room()
	elif into is HayContainer and (into as HayContainer).takes_loose():
		var box:= into as HayContainer
		room = box.capacity() - box.stored
	for id: int in _outbound:
		if (_outbound [id] as Array) [2] == into:
			room -= 1
	return maxi(room, 0)


func _credit(into: Node3D, n: int) -> int:
	if n <= 0 or not is_instance_valid(into):
		return 0
	if into is DumpHatch:
		return (into as DumpHatch).take_loose(n)
	if into is HayContainer:
		return (into as HayContainer).put_in(n)
	return 0


func _unload(into: Node3D, delta: float) -> void:
	_pour_owed += Cfg.VAC_UNLOAD_RATE * delta
	var want:= mini(int(_pour_owed), _fill)
	if want <= 0:
		return
	var room:= _room_in(into)
	if room <= 0:


		_pour_owed = 0.0
		if into is HayContainer:
			(into as HayContainer).flash_full()
		elif _badge_gap <= 0.0:
			_badge_gap = HayContainer.FULL_BADGE_GAP
			FullBadge.flash_over(into, DumpHatch.AIM_CENTRE + Vector3.UP)
		return
	want = mini(want, room)
	_pour_owed -= float(want)
	_show_owed += Cfg.VAC_UNLOAD_SHOWN * delta
	var shown:= 0
	var mouth:= mouth_position()
	var to:= _into_point(into)
	while shown < want and _show_owed >= 1.0 and live.has_headroom():
		var at:= mouth + Vector3(_rng.randf_range(-0.05, 0.05),
			_rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.05, 0.05))
		var b:= live.spawn(at, StrandFactory.random_strand_basis(_rng),
			(to - at).normalized() * OUT_SPEED, StrandFactory.random_tint(_rng))
		if b == null:
			break
		_take_outbound(b, into)
		shown += 1
		_show_owed -= 1.0
	var took:= _credit(into, want - shown)
	_fill = maxi(_fill - shown - took, 0)
	_draw_fill()
	if _dump_sound <= 0.0:
		_dump_sound = DUMP_SOUND_EVERY
		Audio.play_3d("hay_dump", to, -4.0)


func _take_outbound(rb: RigidBody3D, into: Node3D) -> void:
	LiveStrandManager.hold(rb, INBOUND_HOLD)
	if not rb.has_meta(META_VAC_MASK):
		rb.set_meta(META_VAC_MASK, rb.collision_mask)
	rb.collision_mask &= ~ (Cfg.L_STRAND | Cfg.L_TOOL | Cfg.L_PROP)
	rb.gravity_scale = 0.0
	rb.sleeping = false
	rb.angular_velocity = Vector3(_rng.randf_range(-12.0, 12.0),
		_rng.randf_range(-12.0, 12.0), _rng.randf_range(-12.0, 12.0))
	var id:= rb.get_instance_id()
	var gone:= _outbound_gone.bind(id)
	rb.tree_exiting.connect(gone, CONNECT_ONE_SHOT)
	_outbound [id] = [rb, 0.0, into, gone]


func _outbound_gone(id: int) -> void:
	_outbound.erase(id)


func _unhook_outbound(rec: Array) -> void:
	var rb:= rec [0] as RigidBody3D
	var gone:= rec [3] as Callable
	if is_instance_valid(rb) and rb.tree_exiting.is_connected(gone):
		rb.tree_exiting.disconnect(gone)


func _fly_outbound(delta: float) -> void:
	if _outbound.is_empty():
		return


	for id: int in _outbound.keys():
		if not _outbound.has(id):
			continue
		var rec: Array = _outbound [id]
		var rb:= rec [0] as RigidBody3D
		if not is_instance_valid(rb) or not rb.is_inside_tree():
			_outbound.erase(id)
			continue
		rec [1] = float(rec [1]) + delta
		var into: Variant = rec [2]
		if is_instance_valid(into):
			var to:= _into_point(into as Node3D) - rb.global_position
			if to.length() > OUT_ARRIVE and float(rec [1]) < OUT_GIVEUP:
				rb.linear_velocity = to.normalized() * OUT_SPEED
				rb.sleeping = false
				continue
		_finish_outbound(id)


func _land_outbound() -> void:
	for id: int in _outbound.keys():
		if _outbound.has(id):
			_finish_outbound(id)
	_outbound.clear()


func _finish_outbound(id: int) -> void:
	var rec: Array = _outbound [id]
	_outbound.erase(id)
	_unhook_outbound(rec)
	var rb:= rec [0] as RigidBody3D
	if not is_instance_valid(rb) or not rb.is_inside_tree():
		return
	var into: Variant = rec [2]
	if is_instance_valid(into) and _credit(into as Node3D, 1) > 0:
		_release_inbound(rb)
		live.consume(rb)
	else:
		_let_go_outbound(rb)


func _let_go_outbound(rb: RigidBody3D) -> void:
	_release_inbound(rb)
	LiveStrandManager.release_hold(rb)
	if live != null:
		live.mark_poured(rb)


func _pour_straw(delta: float) -> void:
	_pour_owed += Cfg.VAC_POUR_RATE * delta
	var want:= mini(int(_pour_owed), _fill)
	if want <= 0:
		return
	var mouth:= mouth_position()
	var launch:= _pour_launch(mouth)
	var belt: int = BeltPath.pour_verdict(mouth, launch, _tuft_reach())


	var to_floor:= belt == BeltPath.Pour.NO_BELT
	if to_floor:
		_belt_held = 0.0
		_parcel_left = 0
	elif _parcel_left <= 0:
		if _belt_holds_pour(belt, delta) or _parcel_waits():
			_pour_owed = minf(_pour_owed, float(want))
			return
		_parcel.clear()
		_parcel_age = 0.0
		_parcel_left = clampi(roundi(Cfg.VAC_POUR_RATE * HayContainer.POUR_TUFT_SECONDS),
			Cfg.TUFT_MERGE_AT, Cfg.TUFT_MAX)
	if not to_floor:
		want = mini(want, _parcel_left)
	var made:= 0
	for i in want:
		if not live.has_headroom():
			break
		var at:= mouth + Vector3(_rng.randf_range(-0.06, 0.06),
			_rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.06, 0.06))
		var vel:= launch * _rng.randf_range(0.9, 1.1) + Vector3(
			_rng.randf_range(- POUR_SCATTER, POUR_SCATTER), _rng.randf_range(-0.1, 0.35),
			_rng.randf_range(- POUR_SCATTER, POUR_SCATTER))
		var b:= live.spawn(at, StrandFactory.random_strand_basis(_rng), vel,
			StrandFactory.random_tint(_rng))
		if b == null:
			break
		live.mark_poured(b)
		if to_floor:
			_take_falling(b)
		else:
			_parcel.append(b)
			_parcel_left -= 1
		made += 1


	_pour_owed = minf(_pour_owed - float(made), float(want))
	if made > 0:
		_fill = maxi(_fill - made, 0)
		_draw_fill()


func _take_falling(rb: RigidBody3D) -> void:
	LiveStrandManager.hold(rb, LAND_GIVEUP + 1.0)
	rb.collision_mask &= ~ Cfg.L_STRAND
	var id:= rb.get_instance_id()
	var gone:= _falling_gone.bind(id)
	rb.tree_exiting.connect(gone, CONNECT_ONE_SHOT)
	_falling [id] = [rb, 0.0, gone]


func _falling_gone(id: int) -> void:
	_falling.erase(id)


func _land_straw(delta: float) -> void:
	if _falling.is_empty():
		return
	var down: Array [RigidBody3D] = []
	var stale:= false
	for id: int in _falling.keys():
		if not _falling.has(id):
			continue
		var rec: Array = _falling [id]
		var rb:= rec [0] as RigidBody3D
		if not is_instance_valid(rb) or not rb.is_inside_tree():
			_falling.erase(id)
			continue
		var age:= float(rec [1]) + delta
		rec [1] = age

		if rb.has_meta(LiveStrandManager.META_RIDER):
			_let_go_falling(id)
			continue
		if age < LAND_MIN:
			continue
		if age < LAND_GIVEUP and rb.linear_velocity.length_squared() > LAND_SPEED * LAND_SPEED:
			continue
		down.append(rb)
		if age >= LAND_GIVEUP:
			stale = true
	if down.is_empty():
		return
	var waiting: Array [RigidBody3D] = []
	for rb in down:
		var heap:= _heap_near(rb.global_position, HEAP_REACH)
		if heap != null and heap.add_strands(1) > 0:
			_gather_falling(rb)
			continue
		waiting.append(rb)
	if waiting.is_empty():
		return


	if waiting.size() < Cfg.TUFT_MERGE_AT and not stale:
		return
	_place_down(waiting)


func _place_down(waiting: Array [RigidBody3D]) -> void:
	var left:= waiting.duplicate()
	while not left.is_empty():
		var centre:= Vector3.ZERO
		for rb: RigidBody3D in left:
			centre += rb.global_position
		centre /= float(left.size())
		var count:= mini(left.size(), Cfg.TUFT_MAX)
		var took:= 0
		var spot:= _free_floor(centre)
		if not spot.is_empty():
			took = _start_heap((spot ["position"] as Vector3) + Vector3.UP * 0.02, count)
		if took == 0:
			var into:= _tuft_with_room(centre, HEAP_REACH * 2.0)
			if into != null:
				took = into.add_strands(left.size())
		if took == 0:


			took = _start_heap(_stack_point(centre), count)
		if took <= 0:
			for rb: RigidBody3D in left:
				_let_go_falling(rb.get_instance_id())
			return
		for i in took:
			_gather_falling(left [i])
		left = left.slice(took)


func _start_heap(at: Vector3, count: int) -> int:
	if live.props == null or count <= 0:
		return 0
	var tuft:= live.props.spawn("hay_tuft", Transform3D(Basis(Vector3.UP,
		_rng.randf() * TAU), at), { "strands": count }) as HayTuft
	if tuft == null:
		return 0
	_heaps.append(tuft)
	if _heaps.size() > HEAPS_KEPT:
		_heaps.remove_at(0)
	return count


func _stack_point(centre: Vector3) -> Vector3:
	var at:= centre + Vector3.UP * 0.15
	if player == null:
		return at
	var me:= player.global_position
	var flat:= Vector3(at.x - me.x, 0.0, at.z - me.z)
	if flat.length() < PLAYER_CLEAR:
		flat = flat.normalized() if flat.length_squared() > 0.0001 else - player.global_basis.z
		at = Vector3(me.x, at.y, me.z) + flat * PLAYER_CLEAR
	return at


func _free_floor(at: Vector3) -> Dictionary:
	var basis:= Basis(Vector3.UP, _rng.randf() * TAU)
	var spot:= live.free_floor_near(at, basis)
	if _clear_of_player(spot):
		return spot
	var away:= Vector3.FORWARD
	if player != null:
		away = at - player.global_position
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.0001 else Vector3.FORWARD


	for ring: float in [FLOOR_RING * 0.5, FLOOR_RING]:
		for i in FLOOR_RING_TRIES:
			var k:= (i + 1) / 2
			var a:= (0.45 * float(k)) * (1.0 if i % 2 == 1 else -1.0)
			spot = live.free_floor_near(at + away.rotated(Vector3.UP, a) * ring, basis)
			if _clear_of_player(spot):
				return spot
	return { }


func _clear_of_player(spot: Dictionary) -> bool:
	if spot.is_empty():
		return false
	if player == null:
		return true
	var p:= spot ["position"] as Vector3
	var me:= player.global_position
	return Vector2(p.x - me.x, p.z - me.z).length() >= PLAYER_CLEAR


func _heap_near(at: Vector3, reach: float) -> HayTuft:
	var best: HayTuft = null
	var best_d:= reach
	for t in _heaps:
		if not _takes_poured(t):
			continue
		var p:= t.global_position
		var d:= Vector2(at.x - p.x, at.z - p.z).length()
		if d <= best_d:
			best_d = d
			best = t
	return best


func _tuft_with_room(at: Vector3, reach: float) -> HayTuft:
	var best:= _heap_near(at, reach)
	if best != null:
		return best
	var best_d:= reach
	for t in HayTuft.all:
		if not _takes_poured(t):
			continue
		var p:= t.global_position
		var d:= Vector2(at.x - p.x, at.z - p.z).length()
		if d <= best_d:
			best_d = d
			best = t
	return best


func _takes_poured(t) -> bool:
	if not is_instance_valid(t) or not (t is HayTuft):
		return false
	var tuft:= t as HayTuft
	return tuft.takes_straw() and not BeltPath.is_rider(tuft)


func _gather_falling(rb: RigidBody3D) -> void:
	var id:= rb.get_instance_id()
	if _falling.has(id):
		var rec: Array = _falling [id]
		_falling.erase(id)
		var gone:= rec [2] as Callable
		if rb.tree_exiting.is_connected(gone):
			rb.tree_exiting.disconnect(gone)
	live.consume(rb)


func _let_go_falling(id: int) -> void:
	if not _falling.has(id):
		return
	var rec: Array = _falling [id]
	_falling.erase(id)
	var rb:= rec [0] as RigidBody3D
	if not is_instance_valid(rb):
		return
	var gone:= rec [2] as Callable
	if rb.tree_exiting.is_connected(gone):
		rb.tree_exiting.disconnect(gone)
	LiveStrandManager.release_hold(rb)
	rb.collision_mask |= Cfg.L_STRAND


func _pour_launch(from: Vector3) -> Vector3:
	var at:= _pour_spot()
	if at == Vector3.INF:
		return mouth_direction() * POUR_THROW
	var d:= at - from
	var flat:= Vector3(d.x, 0.0, d.z)
	var t:= clampf(flat.length() / POUR_ARC_SPEED, POUR_ARC_TIME_MIN, POUR_ARC_TIME_MAX)
	var g:= absf(float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)))
	return flat / t + Vector3.UP * (d.y / t + 0.5 * g * t)


func _pour_spot() -> Vector3:
	var space:= get_world_3d().direct_space_state
	if space == null or player == null:
		return Vector3.INF
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * Cfg.VAC_POUR_REACH)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
	q.exclude = [player.get_rid()]
	var hit:= space.intersect_ray(q)
	return Vector3.INF if hit.is_empty() else hit ["position"] as Vector3


func _parcel_waits() -> bool:
	if _parcel_age >= HayContainer.POUR_BELT_WAIT:
		return false
	for rb in _parcel:
		if is_instance_valid(rb) and rb.is_inside_tree() and not rb.has_meta(LiveStrandManager.META_RIDER):
			return true
	return false


func _belt_holds_pour(belt: int, delta: float) -> bool:
	if belt != BeltPath.Pour.NO_ROOM:
		_belt_held = 0.0
		return false
	_belt_held += delta
	if _belt_held > HayContainer.POUR_BELT_NUDGE and _badge_gap <= 0.0:
		_badge_gap = HayContainer.FULL_BADGE_GAP
		FullBadge.flash_over(self, to_local(mouth_position() + Vector3.UP * 0.25),
			FullBadge.NO_ROOM)
	return true


func _tuft_reach() -> float:
	var box:= HayTuft.full_collider_size()
	return maxf(box.x, box.z) * 0.5


func _draw_fill() -> void:
	if _fill_tracks.is_empty():
		return
	var t:= fill_fraction()
	for entry: Array in _fill_tracks:
		var node:= entry [0] as Node3D
		if node == null or not is_instance_valid(node):
			continue
		match int(entry [1]):
			Animation.TYPE_POSITION_3D:
				node.position = (entry [2] as Vector3).lerp(entry [3] as Vector3, t)
			Animation.TYPE_SCALE_3D:
				node.scale = (entry [2] as Vector3).lerp(entry [3] as Vector3, t)
			Animation.TYPE_ROTATION_3D:
				node.quaternion = (entry [2] as Quaternion).slerp(
					entry [3] as Quaternion, t)
