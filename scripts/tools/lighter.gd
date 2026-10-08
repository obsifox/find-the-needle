class_name Lighter
extends Node3D


const MODEL_PATH:= "res://assets/models/zippo/zippo_lighter.fbx"
const TEX:= "res://assets/models/zippo/textures/"
const SOURCE_CLIP:= "Take 001"


const CLIPS:= {
	"open": [1.02, 1.92, false],
	"dud": [2.17, 2.5, false],
	"dud2": [2.97, 3.3, false],
	"strike": [3.62, 4.12, false],
	"burn": [4.17, 11.37, true],
	"close": [11.4, 11.75, false],
}


const STRIKE_CATCH:= 0.33


const PROP_POSE_AT:= 13.5


const POSE_POS:= Vector3(0.13, -0.19, -0.34)
const POSE_ROT:= Vector3(0.1, 0.55, 0.0)


const VIS_SCALE:= 1.6


const BOB_PITCH:= 0.025
const BOB_HEAVE:= 0.01
const BOB_SWAY:= 0.02
const BOB_BANK:= 0.04


const FLAME_LIGHT_ENERGY:= 0.7
const FLAME_LIGHT_RANGE:= 1.4

enum State { STOWED, OPENING, READY, DUD, STRIKING, LIT, RELIGHT, CLOSING }

var player: Player
var field: HayField
var live: LiveStrandManager
var props: PropManager
var world_root: Node3D

var hud: Hud

var visual: Node3D
var _model: Node3D
var _anim: AnimationPlayer
var _flame_light: OmniLight3D

var _active:= false
var _state:= State.STOWED
var _state_t:= 0.0
var _cooldown:= 0.0
var _fire: HayFire


var _target: Dictionary = { }


var _pending: Dictionary = { }
var _catch_t:= -1.0
var _dud_flip:= false


func setup(p_world: Node3D, p_field: HayField, p_live: LiveStrandManager,
		p_props: PropManager) -> void:
	world_root = p_world
	field = p_field
	live = p_live
	props = p_props
	_mount()
	_stow()


func _mount() -> void:
	visual = Node3D.new()
	visual.name = "LighterVisual"
	visual.visible = false
	player.camera.add_child(visual)


	if Cfg.DEMO:
		return
	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		push_error("Lighter: could not load %s" % MODEL_PATH)
		return
	_model = packed.instantiate()
	visual.add_child(_model)
	_model.transform = local_pose()
	skin(_model)
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		var built:= clips_from(_anim)
		for lib: StringName in _anim.get_animation_library_list():
			_anim.remove_animation_library(lib)
		var out:= AnimationLibrary.new()
		for clip: String in built:
			out.add_animation(StringName(clip), built [clip])
		_anim.add_animation_library(&"", out)
	var skel:= _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel != null:
		var at:= BoneAttachment3D.new()
		at.name = "FlameAttach"
		at.bone_name = "Bone034"
		skel.add_child(at)
		_flame_light = OmniLight3D.new()
		_flame_light.name = "FlameLight"
		_flame_light.light_color = HayGenerator.FIRE_COLOUR
		_flame_light.light_energy = 0.0
		_flame_light.omni_range = FLAME_LIGHT_RANGE
		_flame_light.shadow_enabled = false
		at.add_child(_flame_light)


static func local_pose() -> Transform3D:
	return Transform3D(Basis.from_euler(POSE_ROT).scaled(Vector3.ONE * VIS_SCALE),
		POSE_POS)


static var _clip_cache: Dictionary = { }


static func clips_from(ap: AnimationPlayer) -> Dictionary:
	if not _clip_cache.is_empty():
		return _clip_cache
	var src:= source_clip(ap)
	if src == null:
		push_warning("Lighter: no '%s' in the model" % SOURCE_CLIP)
		return { }
	for clip: String in CLIPS:
		var c: Array = CLIPS [clip]
		_clip_cache [clip] = _slice(src, float(c [0]), float(c [1]), bool(c [2]))
	return _clip_cache


static func source_clip(ap: AnimationPlayer) -> Animation:
	for clip: String in ap.get_animation_list():
		if clip == SOURCE_CLIP or clip.ends_with("/" + SOURCE_CLIP):
			return ap.get_animation(clip)
	return null


static func _slice(src: Animation, t0: float, t1: float, loops: bool) -> Animation:
	var a:= Animation.new()
	a.length = t1 - t0
	a.loop_mode = Animation.LOOP_PINGPONG if loops else Animation.LOOP_NONE
	for t in src.get_track_count():
		var kind:= src.track_get_type(t)
		if kind != Animation.TYPE_POSITION_3D and kind != Animation.TYPE_ROTATION_3D and kind != Animation.TYPE_SCALE_3D:
			continue
		var nt:= a.add_track(kind)
		a.track_set_path(nt, src.track_get_path(t))
		a.track_set_interpolation_type(nt, src.track_get_interpolation_type(t))
		var times: Array [float] = [t0]
		for k in src.track_get_key_count(t):
			var kt:= src.track_get_key_time(t, k)
			if kt > t0 and kt < t1:
				times.append(kt)
		times.append(t1)
		for kt in times:
			match kind:
				Animation.TYPE_POSITION_3D:
					a.position_track_insert_key(nt, kt - t0, src.position_track_interpolate(t, kt))
				Animation.TYPE_ROTATION_3D:
					a.rotation_track_insert_key(nt, kt - t0, src.rotation_track_interpolate(t, kt))
				Animation.TYPE_SCALE_3D:
					a.scale_track_insert_key(nt, kt - t0, src.scale_track_interpolate(t, kt))
	return a


static func apply_frame(ap: AnimationPlayer, src: Animation, at: float) -> void:
	var base:= ap.get_node_or_null(ap.root_node)
	if base == null:
		return
	for t in src.get_track_count():
		var path:= src.track_get_path(t)
		var node:= base.get_node_or_null(NodePath(path.get_concatenated_names()))
		if node == null:
			continue
		var kind:= src.track_get_type(t)
		var bone:= str(path.get_concatenated_subnames())
		var skel:= node as Skeleton3D
		var idx:= skel.find_bone(bone) if skel != null and bone != "" else -1
		var n3:= node as Node3D
		match kind:
			Animation.TYPE_POSITION_3D:
				var v:= src.position_track_interpolate(t, at)
				if idx >= 0:
					skel.set_bone_pose_position(idx, v)
				elif n3 != null and bone == "":
					n3.position = v
			Animation.TYPE_ROTATION_3D:
				var q:= src.rotation_track_interpolate(t, at)
				if idx >= 0:
					skel.set_bone_pose_rotation(idx, q)
				elif n3 != null and bone == "":
					n3.quaternion = q
			Animation.TYPE_SCALE_3D:
				var s:= src.scale_track_interpolate(t, at)
				if idx >= 0:
					skel.set_bone_pose_scale(idx, s)
				elif n3 != null and bone == "":
					n3.scale = s


static func prepare_prop(inst: Node3D) -> void:
	skin(inst)
	var ap:= inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return


	if not _baked_meshes.is_empty():
		ap.get_parent().remove_child(ap)
		ap.free()
		_reuse_bake(inst)
		return
	var src:= source_clip(ap)
	if src != null:
		apply_frame(ap, src, PROP_POSE_AT)
	ap.get_parent().remove_child(ap)
	ap.free()
	_bake_pose(inst)


static func _bake_pose(inst: Node3D) -> void:
	var skel:= inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var globals:= _bone_globals(skel)
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi:= node as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		var baked:= _skin_mesh(mi.mesh, mi.skin, skel, globals)
		if baked == null:
			continue
		_baked_meshes [_rel_path(inst, mi)] = baked
		_swap_in(mi, baked)


static var _baked_meshes: Dictionary = { }


static func _reuse_bake(inst: Node3D) -> void:
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi:= node as MeshInstance3D
		if mi.skin == null:
			continue
		var baked:= _baked_meshes.get(_rel_path(inst, mi)) as ArrayMesh
		if baked != null:
			_swap_in(mi, baked)


static func _swap_in(mi: MeshInstance3D, baked: ArrayMesh) -> void:
	var overrides: Array [Material] = []
	for i in mi.mesh.get_surface_count():
		overrides.append(mi.get_surface_override_material(i))
	mi.skin = null
	mi.skeleton = NodePath()
	mi.mesh = baked
	for i in mini(overrides.size(), baked.get_surface_count()):
		mi.set_surface_override_material(i, overrides [i])


static func _rel_path(inst: Node, n: Node) -> String:
	var parts:= PackedStringArray()
	while n != null and n != inst:
		parts.append(String(n.name))
		n = n.get_parent()
	parts.reverse()
	return "/".join(parts)


static func _bone_globals(skel: Skeleton3D) -> Array [Transform3D]:
	var out: Array [Transform3D] = []
	out.resize(skel.get_bone_count())
	for b in skel.get_bone_count():
		var local:= Transform3D(Basis(skel.get_bone_pose_rotation(b))
			.scaled(skel.get_bone_pose_scale(b)), skel.get_bone_pose_position(b))
		var parent:= skel.get_bone_parent(b)
		out [b] = out [parent] * local if parent >= 0 else local
	return out


static func _skin_mesh(mesh: Mesh, skin: Skin, skel: Skeleton3D,
		globals: Array [Transform3D]) -> ArrayMesh:
	var binds: Array [Transform3D] = []
	for i in skin.get_bind_count():
		var bone:= skin.get_bind_bone(i)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(i))
		binds.append(globals [bone] * skin.get_bind_pose(i) if bone >= 0
			else Transform3D.IDENTITY)
	var out:= ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays:= mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays [Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays [Mesh.ARRAY_BONES] if arrays [Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arrays [Mesh.ARRAY_WEIGHTS] if arrays [Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		if verts.is_empty() or bones.is_empty():
			return null
		var per:= bones.size() / verts.size()
		var normals: PackedVector3Array = arrays [Mesh.ARRAY_NORMAL] if arrays [Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var tangents: PackedFloat32Array = arrays [Mesh.ARRAY_TANGENT] if arrays [Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		for v in verts.size():
			var m:= Transform3D()
			m.basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
			var total:= 0.0
			for j in per:
				var w:= weights [v * per + j]
				if w <= 0.0:
					continue
				var t:= binds [bones [v * per + j]]
				m.basis.x += t.basis.x * w
				m.basis.y += t.basis.y * w
				m.basis.z += t.basis.z * w
				m.origin += t.origin * w
				total += w
			if total <= 0.0:
				continue
			verts [v] = m * verts [v]
			if not normals.is_empty():
				normals [v] = (m.basis * normals [v]).normalized()
			if not tangents.is_empty():
				var tv:= (m.basis * Vector3(tangents [v * 4], tangents [v * 4 + 1],
					tangents [v * 4 + 2])).normalized()
				tangents [v * 4] = tv.x
				tangents [v * 4 + 1] = tv.y
				tangents [v * 4 + 2] = tv.z
		arrays [Mesh.ARRAY_VERTEX] = verts
		if not normals.is_empty():
			arrays [Mesh.ARRAY_NORMAL] = normals
		if not tangents.is_empty():
			arrays [Mesh.ARRAY_TANGENT] = tangents
		arrays [Mesh.ARRAY_BONES] = null
		arrays [Mesh.ARRAY_WEIGHTS] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var src_mat:= mesh.surface_get_material(s)
		if src_mat != null:
			out.surface_set_material(s, src_mat)
	return out


static var _materials: Dictionary = { }


static func skin(inst: Node3D) -> void:
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi:= node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src:= mi.mesh.surface_get_material(i)
			if src == null:
				continue
			var m:= material(src.resource_name)
			if m != null:
				mi.set_surface_override_material(i, m)


static func material(key: String) -> Material:
	if _materials.has(key):
		return _materials [key]
	var m: Material = null
	match key:
		"zippo":


			var s:= StandardMaterial3D.new()
			s.albedo_texture = load(TEX + "zippo_basecolor.png")
			s.metallic = 1.0
			s.metallic_texture = load(TEX + "zippo_m.png")
			s.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			s.roughness = 1.0
			s.roughness_texture = load(TEX + "zippo_r.png")
			s.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			s.normal_enabled = true
			s.normal_texture = load(TEX + "zippo_n.png")
			m = s
		"wick":
			var s:= StandardMaterial3D.new()
			s.albedo_texture = load(TEX + "wick_basecolor.png")
			s.roughness = 0.9
			m = s
		"wick_emit":
			m = _glow(TEX + "wick_sketchfab_emit.png", 1.2)
		"flame":
			m = _glow(TEX + "flame.png", 1.4)
		"flame_top":
			m = _glow(TEX + "flame_top.png", 1.4)
		"sparks":
			m = _glow(TEX + "spark.png", 2.0)
	_materials [key] = m
	return m


static func _glow(path: String, gain: float) -> StandardMaterial3D:
	var s:= StandardMaterial3D.new()
	s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	s.cull_mode = BaseMaterial3D.CULL_DISABLED
	s.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	s.albedo_texture = load(path)
	s.albedo_color = Color(gain, gain, gain, 1.0)
	return s


func set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	if on:
		if visual != null:
			visual.visible = true
		_enter(State.OPENING, "open")
		Audio.play("lighter_open", -6.0)
		return
	_pending = { }
	_catch_t = -1.0
	_target = { }
	if visual != null and visual.visible and _state != State.STOWED:
		_enter(State.CLOSING, "close")
		Audio.play("lighter_close", -6.0)
	else:
		_stow()


func let_go() -> void:
	_active = false
	_pending = { }
	_catch_t = -1.0
	_target = { }
	_stow()


func is_active() -> bool:
	return _active


func strike() -> bool:
	if not _active or _state != State.READY:
		return false
	var can_light:= _cooldown <= 0.0 and not is_fire_burning()
	Audio.play("lighter_strike", -4.0)
	if not can_light or _target.is_empty():
		_dud_flip = not _dud_flip
		_enter(State.DUD, "dud2" if _dud_flip else "dud")
		return false
	_pending = _target
	_catch_t = STRIKE_CATCH
	_enter(State.STRIKING, "strike")
	return true


func light_at(at: Vector3) -> HayFire:
	var fire:= HayFire.new()
	fire.name = "HayFire"
	world_root.add_child(fire)
	fire.ignite(field, live, props, at)
	_fire = fire
	_cooldown = Cfg.LIGHTER_COOLDOWN
	return fire


func cooldown_left() -> float:
	return _cooldown


func debug_clear_cooldown() -> void:
	_cooldown = 0.0


func is_ready() -> bool:
	return _active and _state == State.READY


func has_target() -> bool:
	return not _target.is_empty()


func is_fire_burning() -> bool:
	return is_instance_valid(_fire) and _fire.is_burning()


func current_fire() -> HayFire:
	return _fire if is_instance_valid(_fire) else null


func state_name() -> String:
	return State.keys() [_state]


func debug_hold(clip: String, at: float) -> void:
	_active = true
	if visual != null:
		visual.visible = true
	_state = State.READY
	_update_visual()
	if _anim != null and _anim.has_animation(clip):
		_anim.play(clip)
		_anim.seek(at, true)
		_anim.pause()


func aim_point() -> Dictionary:
	if not _active or _target.is_empty() or _cooldown > 0.0 or is_fire_burning():
		return { }
	return { "position": _target ["position"], "radius": Cfg.LIGHTER_RADIUS_START }


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _state == State.STOWED:
		return
	_update_visual()
	_target = aim_target() if _active else { }
	if _catch_t >= 0.0:
		_catch_t -= delta
		if _catch_t < 0.0 and not _pending.is_empty():
			var at: Vector3 = _pending ["position"]
			_pending = { }
			light_at(at)
	_drive_flame_light()
	_state_t -= delta
	if _state_t > 0.0:
		return
	match _state:
		State.OPENING, State.DUD:
			_state = State.READY
		State.STRIKING:
			_enter(State.LIT, "burn")
			_state_t = Cfg.LIGHTER_FLAME_SECONDS
		State.LIT:
			_enter(State.RELIGHT, "close")
			Audio.play("lighter_close", -6.0)
		State.RELIGHT:
			if _active:
				_enter(State.OPENING, "open")
				Audio.play("lighter_open", -8.0)
			else:
				_stow()
		State.CLOSING:
			_stow()


func aim_target() -> Dictionary:
	if player == null or not is_inside_tree():
		return { }
	var space:= get_world_3d().direct_space_state
	if space == null:
		return { }
	var from:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(from,
		from + player.look_direction() * Cfg.LIGHTER_REACH)
	q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_STRAND | Cfg.L_SETTLED | Cfg.L_PROP
	q.collide_with_areas = false
	var hit:= space.intersect_ray(q)
	if hit.is_empty():
		return { }
	return HayFire.catch_at(hit ["position"], hit.get("collider") as CollisionObject3D,
		field, live)


func _enter(state: State, clip: String) -> void:
	_state = state
	_state_t = float(CLIPS [clip] [1]) - float(CLIPS [clip] [0])
	if _anim != null and _anim.has_animation(clip):
		_anim.play(clip)
		_anim.seek(0.0, true)


func _stow() -> void:
	_state = State.STOWED
	_state_t = 0.0
	if visual != null:
		visual.visible = false
	if _anim != null and _anim.has_animation("open"):
		_anim.play("open")
		_anim.seek(0.0, true)
		_anim.pause()
	if _flame_light != null:
		_flame_light.light_energy = 0.0


func _update_visual() -> void:
	if visual == null or player == null:
		return
	visual.transform = player.stride_pose(BOB_SWAY, BOB_HEAVE, BOB_PITCH, BOB_BANK) * Transform3D(Basis.from_euler(Vector3(player.land_kick() * 0.4, 0.0, 0.0)),
			Vector3.ZERO)


func _drive_flame_light() -> void:
	if _flame_light == null:
		return
	var lit:= _state == State.LIT or (_state == State.STRIKING and _catch_t < 0.0)
	var want:= FLAME_LIGHT_ENERGY if lit else 0.0
	_flame_light.light_energy = move_toward(_flame_light.light_energy, want, 0.2)
