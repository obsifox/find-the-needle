class_name HayFire
extends Node3D


const FLAME_SHADER:= HayGenerator.FLAME_SHADER
const SMOKE_SHADER:= HayGenerator.STEAM_SHADER

const CRACKLE_DB:= -8.0
const LIGHT_FADE_BEGIN:= 35.0
const LIGHT_FADE_LENGTH:= 10.0
const SMOKE_HEIGHT:= 3.2


const MAX_QUERY:= 192

var field: HayField
var live: LiveStrandManager
var props: PropManager


var centre:= Vector3.ZERO


var burned:= 0
var burned_loose:= 0
var burned_props:= 0
var burned_pile:= 0

var _owed:= 0.0
var _tick_t:= 0.0
var _starve_t:= 0.0
var _age:= 0.0
var _out:= false
var _out_t:= 0.0
var _voice:= -1
var _rng:= RandomNumberGenerator.new()

var _flames: GPUParticles3D
var _flame_pm: ParticleProcessMaterial
var _smoke: MeshInstance3D
var _smoke_mat: ShaderMaterial
var _light: OmniLight3D


var _scorch: MeshInstance3D
var _scorch_mat: StandardMaterial3D
var _on_floor:= true


func ignite(p_field: HayField, p_live: LiveStrandManager, p_props: PropManager,
		at: Vector3) -> void:
	field = p_field
	live = p_live
	props = p_props
	centre = at
	_rng.randomize()
	global_position = at
	_build_visuals()
	Audio.play_3d("fire_catch", at, -4.0)
	_voice = Audio.loop_acquire("fire_crackle")


func _exit_tree() -> void:
	_release_voice()


func radius() -> float:
	return lerpf(Cfg.LIGHTER_RADIUS_START, Cfg.LIGHTER_RADIUS_END,
		clampf(float(burned) / float(Cfg.LIGHTER_BURN_STRANDS), 0.0, 1.0))


func is_burning() -> bool:
	return not _out


func _physics_process(delta: float) -> void:
	if _out:
		_out_t += delta
		_fade(delta)
		return
	_age += delta
	_tick_t += delta
	while _tick_t >= Cfg.LIGHTER_TICK and not _out:
		_tick_t -= Cfg.LIGHTER_TICK
		burn_step(Cfg.LIGHTER_TICK)
	_drive_visuals()


func burn_step(dt: float) -> void:
	if _out:
		return
	_owed += Cfg.LIGHTER_BURN_RATE * dt
	var want:= mini(int(_owed), Cfg.LIGHTER_BURN_STRANDS - burned)
	if want <= 0:
		if burned >= Cfg.LIGHTER_BURN_STRANDS:
			_go_out()
		return
	_follow_surface()
	var r:= radius()
	_shed_needles(r)
	var took:= _burn_loose(r, want)
	if took < want:
		took += _burn_props(r, want - took)
	if took < want:
		took += _burn_pile(r, want - took)
	burned += took
	_owed -= float(took)
	if took <= 0:


		_owed = minf(_owed, Cfg.LIGHTER_BURN_RATE * dt)
		_starve_t += dt
	else:
		_starve_t = 0.0
	if burned >= Cfg.LIGHTER_BURN_STRANDS or _starve_t >= Cfg.LIGHTER_STARVE_SECONDS:
		_go_out()


func _follow_surface() -> void:
	if field == null:
		return
	var h:= field.height_at(centre.x, centre.z)
	if h > Shovel.BARE_HAY:
		centre.y = h
	global_position = centre


func _shed_needles(r: float) -> void:
	if live == null:
		return


	if live.reveal_needles_in(centre, r) > 0:
		Audio.play_3d("needle_ting", centre, -3.0)


func _query(r: float, mask: int) -> Array [Dictionary]:
	var space:= get_world_3d().direct_space_state
	if space == null:
		return []
	var q:= PhysicsShapeQueryParameters3D.new()
	var sphere:= SphereShape3D.new()
	sphere.radius = r
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, centre)
	q.collision_mask = mask
	q.collide_with_areas = false
	return space.intersect_shape(q, MAX_QUERY)


func _burn_loose(r: float, budget: int) -> int:
	if live == null or budget <= 0:
		return 0
	live.wake_in(centre, r)
	var n:= 0
	for hit: Dictionary in _query(r, Cfg.L_STRAND | Cfg.L_SETTLED):
		var rb:= hit.get("collider") as RigidBody3D
		if not burnable_strand(rb, live):
			continue
		LiveStrandManager.unpin(rb)
		if live.consume(rb):
			n += 1
			if n >= budget:
				break
	burned_loose += n
	return n


func _burn_props(r: float, budget: int) -> int:
	if budget <= 0:
		return 0
	var n:= 0
	for hit: Dictionary in _query(r, Cfg.L_PROP):
		var wad:= hit.get("collider") as HayWad
		if not burnable_prop(wad):
			continue


		if wad.needle_index >= 0 and props != null:
			props.rip(wad)
			Audio.play_3d("needle_ting", centre, -3.0)
			continue
		var have:= wad.hay_strands()
		var take:= mini(have, budget - n)
		if take <= 0:
			break
		if take >= have:
			if props != null:
				props.remove(wad)
			else:
				wad.queue_free()
		else:
			wad.set_strands(have - take)
		n += take
		if n >= budget:
			break
	burned_props += n
	return n


func _burn_pile(r: float, budget: int) -> int:
	if field == null or budget <= 0:
		return 0
	var taken:= field.take_in_radius(centre, r, budget)
	var n:= taken.size()
	if n > 0:
		GameState.remove_hay(float(n))
		field.carve_volume(centre, r, float(n) * Cfg.STRAND_VOLUME / Cfg.PACKING)
		burned_pile += n
		return n


	var reach:= maxf(r, Cfg.CELL)
	var under:= field.strands_under(centre, reach)
	if under <= 0.0:
		return 0
	var swept:= 0
	if under <= float(budget) + 0.5:
		swept = int(round(field.sweep_under(centre, reach, Shovel.SWEEP_HEIGHT)))
	else:
		swept = budget
		field.carve_volume(centre, reach, float(budget) * Cfg.STRAND_VOLUME / Cfg.PACKING)
	if swept <= 0:
		return 0
	GameState.remove_hay(float(swept))
	burned_pile += swept
	return swept


static func burnable_strand(rb: RigidBody3D, p_live: LiveStrandManager) -> bool:
	if rb == null or not is_instance_valid(rb) or not rb.is_inside_tree():
		return false
	if p_live == null or rb.get_parent() != p_live:
		return false
	if p_live.needles.has(rb) or rb.has_meta("needle_index"):
		return false
	if p_live.is_held_by_a_tool(rb) or BeltPath.is_rider(rb) or rb.has_meta(LiveStrandManager.META_CLAIM):
		return false


	if rb.freeze and not LiveStrandManager.is_pinned(rb):
		return false
	return true


static func burnable_prop(wad: HayWad) -> bool:
	if wad == null or not is_instance_valid(wad) or not wad.is_inside_tree() or wad.is_queued_for_deletion():
		return false
	if wad.freeze or wad.is_held() or BeltPath.is_rider(wad) or wad.has_meta(PropManager.META_CLAIM):
		return false
	return true


static func catch_at(at: Vector3, body: CollisionObject3D, p_field: HayField,
		p_live: LiveStrandManager) -> Dictionary:
	if body == null:
		return { }
	var rb:= body as RigidBody3D
	if rb != null:
		if p_live != null and p_live.needles.has(rb):
			return { }
		if rb is HayWad:
			return { "position": at } if burnable_prop(rb as HayWad) else { }
		if rb.collision_layer & (Cfg.L_STRAND | Cfg.L_SETTLED):
			return { "position": at } if burnable_strand(rb, p_live) else { }
		return { }
	if body.collision_layer & Cfg.L_BUILD:
		return { }
	if (body.collision_layer & Cfg.L_PILE) and p_field != null and p_field.height_at(at.x, at.z) > Shovel.BARE_HAY:
		return { "position": at }
	if hay_near(at, body.get_world_3d().direct_space_state, p_field, p_live):
		return { "position": at }
	return { }


static func hay_near(at: Vector3, space: PhysicsDirectSpaceState3D, p_field: HayField,
		p_live: LiveStrandManager) -> bool:
	if p_field != null and p_field.strands_under(at, Cfg.LIGHTER_CATCH_RADIUS) >= 1.0:
		return true
	if space == null:
		return false
	var q:= PhysicsShapeQueryParameters3D.new()
	var sphere:= SphereShape3D.new()
	sphere.radius = Cfg.LIGHTER_CATCH_RADIUS
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, at)
	q.collision_mask = Cfg.L_STRAND | Cfg.L_SETTLED | Cfg.L_PROP
	q.collide_with_areas = false
	for hit: Dictionary in space.intersect_shape(q, 32):
		var other:= hit.get("collider") as RigidBody3D
		if other is HayWad:
			if burnable_prop(other as HayWad):
				return true
		elif burnable_strand(other, p_live):
			return true
	return false


func _go_out() -> void:
	if _out:
		return
	_out = true
	if _flames != null:
		_flames.emitting = false
	_release_voice()


func _release_voice() -> void:
	if _voice >= 0:
		Audio.loop_release(_voice)
		_voice = -1


func _build_visuals() -> void:
	_flame_pm = ParticleProcessMaterial.new()
	_flame_pm.direction = Vector3.UP
	_flame_pm.spread = 14.0
	_flame_pm.initial_velocity_min = 0.35
	_flame_pm.initial_velocity_max = 0.9
	_flame_pm.gravity = Vector3(0.0, 0.9, 0.0)
	_flame_pm.damping_min = 0.8
	_flame_pm.damping_max = 1.6
	_flame_pm.scale_min = 0.7
	_flame_pm.scale_max = 1.3
	_flame_pm.scale_curve = HayGenerator._flame_curve()
	_flame_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_flame_pm.emission_box_extents = Vector3(Cfg.LIGHTER_RADIUS_START, 0.04,
		Cfg.LIGHTER_RADIUS_START)
	_flame_pm.color = HayGenerator.FIRE_COLOUR
	_flame_pm.angle_min = -180.0
	_flame_pm.angle_max = 180.0
	_flame_pm.anim_offset_min = 0.0
	_flame_pm.anim_offset_max = 1.0

	var quad:= QuadMesh.new()
	quad.size = Vector2(0.42, 0.42)
	var fm:= ShaderMaterial.new()
	fm.shader = load(FLAME_SHADER)
	quad.material = fm

	_flames = GPUParticles3D.new()
	_flames.name = "Flames"
	_flames.amount = 40
	_flames.lifetime = 0.9
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flames.process_material = _flame_pm
	_flames.draw_pass_1 = quad
	_flames.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 3, 4))
	add_child(_flames)
	_flames.emitting = true

	var mesh:= CylinderMesh.new()
	mesh.top_radius = 1.1
	mesh.bottom_radius = 0.3
	mesh.height = SMOKE_HEIGHT
	mesh.radial_segments = 20
	mesh.rings = 8
	mesh.cap_top = false
	mesh.cap_bottom = false
	_smoke_mat = ShaderMaterial.new()
	_smoke_mat.shader = load(SMOKE_SHADER)
	_smoke_mat.set_shader_parameter("scale", 2.6)
	_smoke_mat.set_shader_parameter("tex_speed", Vector3(0.0, -1.6, 0.25))
	_smoke_mat.set_shader_parameter("smoke_volume", 0.0)
	_smoke_mat.set_shader_parameter("smoke_color", Color(0.3, 0.28, 0.26, 0.8))
	_smoke_mat.set_shader_parameter("top_fade", 0.55)
	_smoke_mat.set_shader_parameter("base_fade", 0.2)
	_smoke = MeshInstance3D.new()
	_smoke.name = "Smoke"
	_smoke.mesh = mesh
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_smoke.material_override = _smoke_mat
	_smoke.position = Vector3(0.0, SMOKE_HEIGHT * 0.5 + 0.2, 0.0)
	add_child(_smoke)

	_light = OmniLight3D.new()
	_light.name = "FireLight"
	_light.light_color = HayGenerator.FIRE_COLOUR
	_light.light_energy = 0.0
	_light.omni_range = HayGenerator.FIRE_RANGE
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 0.45, 0.0)

	_light.distance_fade_enabled = true
	_light.distance_fade_begin = LIGHT_FADE_BEGIN
	_light.distance_fade_length = LIGHT_FADE_LENGTH
	add_child(_light)


	var g:= Gradient.new()
	g.set_color(0, Color(0.03, 0.025, 0.02, 0.92))
	g.set_color(1, Color(0.03, 0.025, 0.02, 0.0))
	var tex:= GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_scorch_mat = StandardMaterial3D.new()
	_scorch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_scorch_mat.albedo_texture = tex
	_scorch_mat.albedo_color = Color(1, 1, 1, 0.0)
	_scorch_mat.roughness = 1.0
	var disc:= PlaneMesh.new()
	disc.size = Vector2(2.0, 2.0)
	_scorch = MeshInstance3D.new()
	_scorch.name = "Scorch"
	_scorch.mesh = disc
	_scorch.material_override = _scorch_mat
	_scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_scorch.position = Vector3(0.0, 0.01, 0.0)
	_scorch.scale = Vector3.ONE * Cfg.LIGHTER_RADIUS_START
	_on_floor = field == null or field.height_at(centre.x, centre.z) <= Shovel.BARE_HAY
	_scorch.visible = _on_floor
	add_child(_scorch)


func _drive_visuals() -> void:
	var r:= radius()
	if _flame_pm != null:
		_flame_pm.emission_box_extents = Vector3(r * 0.7, 0.04, r * 0.7)
	var ramp:= clampf(_age * 3.0, 0.0, 1.0)
	if _light != null:
		var flicker:= 1.0 + HayGenerator.FIRE_FLICKER * (sin(_age * 17.0)
			+ 0.6 * sin(_age * 7.3 + 1.7)) * 0.6
		_light.light_energy = HayGenerator.FIRE_ENERGY * ramp * flicker
	if _smoke_mat != null:
		_smoke_mat.set_shader_parameter("smoke_volume", 0.7 * ramp)
	if _scorch != null:
		_scorch.scale = Vector3(r * 1.1, 1.0, r * 1.1)
		_scorch_mat.albedo_color.a = _scorch_alpha()
	if _voice >= 0:
		Audio.loop_update(_voice, centre, CRACKLE_DB)


func _scorch_alpha() -> float:
	return clampf(0.35 + float(burned) / 200.0, 0.0, 1.0)


func _fade(_delta: float) -> void:
	if _light != null:
		_light.light_energy = HayGenerator.FIRE_ENERGY * maxf(0.0, 1.0 - _out_t)
	if _smoke_mat != null:
		_smoke_mat.set_shader_parameter("smoke_volume", 0.7 * maxf(0.0, 1.0 - _out_t / 3.0))
	if _scorch != null:
		_scorch_mat.albedo_color.a = _scorch_alpha() * maxf(0.0, 1.0 - _out_t / Cfg.LIGHTER_SCORCH_SECONDS)
	if _out_t >= Cfg.LIGHTER_SCORCH_SECONDS:
		queue_free()
