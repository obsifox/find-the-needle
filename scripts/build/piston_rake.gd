class_name PistonRake
extends Node3D


const MODEL:= "res://assets/models/compiled/piston_rake.scn"
const SPEC:= "res://assets/models/piston_rake_materials.json"

const N_HEAD:= "Marker_Head"

const CLIP:= "Cycle"
const CYCLE_FRAMES:= 72.0
const CLIP_FPS:= 30.0
const CLIP_SECONDS:= CYCLE_FRAMES / CLIP_FPS


const F_BITE:= 7.0
const F_RELEASE:= 23.0


const BITE_PASSES:= 24


const GOLDEN_ANGLE:= 2.39996323


const FACE_LIFT_RADIUS:= 1.2


const WAD_SPREAD_SCALE:= 0.33


const MOUTH_RADIUS:= 1.5


const ENGINE_GAIN:= -8.0


const DRY_STROKES_BEFORE_FAULT:= 2


const FACE_MIN_HEIGHT:= 0.06


const BODY_W:= 2.1
const BODY_H:= 1.9
const BODY_L:= 3.3
const BODY_Z:= 0.15


const SHED_HEIGHT:= 1.6


const SHED_PERIOD:= 0.4


const SHED_STILL:= 0.6


const SHED_PUSH:= 2.0
const SHED_LIFT:= 0.8


const GATHER_MAX:= 4


const GATHER_PAD:= 0.35


const GATHER_ABOVE:= 1.0


const GATHER_LOOK_PERIOD:= 0.5


const CONSOLE_REACH:= 3.2


const DRIVE_STEP:= 0.5


const DRIVE_SPEED:= 0.6


const N_WHEELS: Array [String] = ["PR_Tyre_-1", "PR_Tyre_1"]


const WHEEL_RADIUS:= 0.425


const DRIVE_GAIN:= -4.0


var placement_preview:= false

var field: HayField
var live: LiveStrandManager
var props: PropManager

var _model: Node3D
var _anim: AnimationPlayer

var _ports: Array [Node3D] = []
var _launcher: BrickLauncher


var _range: RakeRange


var _aim: ThrowAim


var _release_local:= Vector3.ZERO


var _range_asked:= false

var _engine_voice:= -1

var _drive_voice:= -1

var _wheels: Array [Node3D] = []


var _clock:= -1.0

var _shed_clock:= 0.0


var _face_clock:= GATHER_LOOK_PERIOD
var _shed_query: PhysicsShapeQueryParameters3D
var _did_bite:= false
var _did_throw:= false
var _thrown_total:= 0.0


var _put_out:= 0.0


var _held:= 0.0


var _bite_sites: Array [Vector3] = []


var last_bite:= 0.0
var last_thrown:= 0


var needle_chance: float = Cfg.RAKE_NEEDLE_CHANCE


var _release_at:= Vector3.ZERO
var _released:= false


var _last_load: Array [HayWad] = []


var _gathered: Array [HayWad] = []

var _gather_clock:= 0.0


var last_gathered:= 0


var _dry_strokes:= 0


var _jam_strokes:= 0


var throw_distance:= Cfg.RAKE_THROW_DISTANCE


var paid_cost:= -1.0


var gift:= false


var _drive_left:= 0.0


var _drive_check:= Callable()


var drive_blocked:= ""

static var _spec_cache: Dictionary = { }

static var _material_cache: Dictionary = { }


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build_model()
	_skin()
	_build_animation()
	_build_range()
	if placement_preview:
		set_process(false)
		set_preview_valid(true)
		return
	_build_body()
	_build_launcher()
	_build_aim()
	_build_audio()


	_shed_clock = fposmod(float(get_instance_id() % 1009) * 0.618034, 1.0) * SHED_PERIOD


func set_preview_valid(valid: bool) -> void:
	if _range != null:
		_range.set_preview_valid(valid)
	if _model == null:
		return
	var ghost:= ConveyorKit.ghost_material(valid)
	for mesh in _meshes():
		mesh.material_overlay = ghost


func _build_model() -> void:
	var packed: PackedScene = load(MODEL)
	if packed == null:
		push_warning("PistonRake: %s will not load" % MODEL)
		return
	_model = packed.instantiate() as Node3D
	if _model != null:
		add_child(_model)
		_align_model()


func _align_model() -> void:
	var head:= _model.find_child(N_HEAD, true, false) as Node3D
	if head == null:
		return


	var v:= to_local(head.global_position)
	v.y = 0.0
	if v.length_squared() < 0.0001:
		return
	_model.rotation.y -= atan2(v.x, v.z)


func _skin() -> void:
	if _model == null:
		return
	var spec:= spec_table()
	if spec.is_empty():
		push_warning("PistonRake: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(HayCompressor.SHADER)
	var built: Dictionary = _material_cache
	var missed: Dictionary = { }
	for mesh in _meshes():
		if mesh.mesh == null:
			continue

		mesh.lod_bias = 0.35
		for i in mesh.mesh.get_surface_count():
			var src:= mesh.get_active_material(i)
			if src == null:
				continue
			var key:= src.resource_name
			if src.get_meta("immutable_palette", false):
				preload("res://assets/models/machine_palette.gd").validate_import(src, spec)
				continue
			if key.is_empty():
				continue
			if not built.has(key):
				built [key] = HayCompressor.make_material(key, spec, shader)
			if built [key] == null:
				missed [key] = true
				continue
			mesh.set_surface_override_material(i, built [key])
	if not missed.is_empty():
		push_warning("PistonRake: no table entry for %s" % ", ".join(missed.keys()))


static func spec_table() -> Dictionary:
	if _spec_cache.is_empty():
		var fh:= FileAccess.open(SPEC, FileAccess.READ)
		if fh != null:
			var parsed: Variant = JSON.parse_string(fh.get_as_text())
			if parsed is Dictionary:
				_spec_cache = parsed as Dictionary
	return _spec_cache


func _build_animation() -> void:
	if _model == null:
		return
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		push_warning("PistonRake: %s carries no AnimationPlayer" % MODEL)
		return
	if not _anim.has_animation(CLIP):


		push_warning("PistonRake: no '%s' clip, found %s"
			% [CLIP, ", ".join(_anim.get_animation_list())])
		return
	var a:= _anim.get_animation(CLIP)
	a.loop_mode = Animation.LOOP_NONE
	_anim.play(CLIP)
	_anim.seek(0.0, true)
	_anim.pause()


func _build_body() -> void:
	var body:= StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = Cfg.L_BUILD
	body.collision_mask = 0
	var cs:= CollisionShape3D.new()
	var box:= BoxShape3D.new()
	box.size = Vector3(BODY_W, BODY_H, BODY_L)
	cs.shape = box
	cs.position = Vector3(0.0, BODY_H * 0.5, BODY_Z)
	body.add_child(cs)
	add_child(body)


func build_cost() -> float:
	if paid_cost >= 0.0:
		return paid_cost
	return Cfg.RAKE_COST


func console_position() -> Vector3:
	return global_position + global_basis.y * 1.0 - global_basis.x * 1.0


func _build_range() -> void:
	_range = RakeRange.new()
	_range.name = "Range"
	add_child(_range)
	var reach:= to_local(bite_point(0)).z
	_range.set_bite_disc(reach, bite_disc_radius() + Cfg.RAKE_BITE_RADIUS)
	_range.set_throw(throw_distance, _throw_spread())
	_range.visible = placement_preview


func show_range(on: bool) -> void:
	if _range == null:
		return
	_range_asked = on
	_range.visible = on or range_pinned_left() > 0.0
	if on:
		_range.set_throw(throw_distance, _throw_spread())
	if _aim != null:
		_aim.set_panel(on)


func _build_aim() -> void:
	_release_local = _measure_release()

	_range.set_throw_marks_shown(false)
	_aim = ThrowAim.new()
	_aim.name = "Aim"
	_aim.source = self
	add_child(_aim)
	_aim.pin_ended.connect(_on_pin_ended)


func throw_aim() -> ThrowAim:
	return _aim


func pin_range(seconds: float) -> void:
	if _aim == null or _range == null:
		return
	if seconds > 0.0:
		_range.set_throw(throw_distance, _throw_spread())
	_aim.pin(seconds)
	_range.visible = _range_asked or _aim.pinned_left() > 0.0


func range_pinned_left() -> float:
	return _aim.pinned_left() if _aim != null else 0.0


func _on_pin_ended() -> void:
	if _range != null:
		_range.visible = _range_asked


func _measure_release() -> Vector3:
	var head:= _find(N_HEAD) as Node3D
	if _anim == null or head == null:
		return to_local(_launcher.global_position) if _launcher != null else Vector3.UP
	_anim.seek(F_RELEASE / CLIP_FPS, true)
	var at:= to_local(head.global_position)
	_anim.seek(0.0, true)
	return at


func throw_path() -> Dictionary:
	if _launcher == null:
		return { }
	var from:= to_global(_release_local)
	_aim_launcher(from)
	return { "from": from, "velocity": _launcher.middle_throw(from),
		"ground_y": global_position.y, "damped": true }


func _aim_launcher(from: Vector3) -> void:
	_launcher.aim_along(- _forward())
	_launcher.ground_y = global_position.y
	var ahead:= (from - global_position).dot(_forward())
	_launcher.throw_distance = throw_distance + ahead
	_launcher.launch_angle = launch_angle()
	_launcher.solve_damping = true


func launch_angle() -> float:
	var span:= maxf(Cfg.RAKE_LOB_FROM - Cfg.RAKE_THROW_MIN, 0.001)
	var t:= clampf((Cfg.RAKE_LOB_FROM - throw_distance) / span, 0.0, 1.0)
	return lerpf(Cfg.RAKE_LAUNCH_ANGLE, Cfg.RAKE_LOB_ANGLE, t)


func _throw_spread() -> float:
	return Cfg.RAKE_THROW_SPREAD * WAD_SPREAD_SCALE


func _build_launcher() -> void:
	_launcher = BrickLauncher.new()
	_launcher.name = "Throw"
	_launcher.throw_distance = throw_distance
	_launcher.launch_angle = Cfg.RAKE_LAUNCH_ANGLE
	_launcher.spread_radius = _throw_spread()
	_launcher.dust_colour = Color(0.86, 0.74, 0.47)
	add_child(_launcher)
	_launcher.position = _marker_local(N_HEAD, Vector3(-2.9, 0.2, 0.0))
	_launcher.ground_y = global_position.y

	_launcher.aim_along(- _forward())


func _build_audio() -> void:
	pass


func _process(delta: float) -> void:
	_shed_clock += delta
	if _shed_clock >= SHED_PERIOD:
		_shed_clock = 0.0
		_shed()


	if _drive_left != 0.0 and _clock < 0.0:
		_drive_step(delta)
		return
	if _anim == null:
		return
	if _clock < 0.0:


		_set_engine(false)


		if power <= 0.0:
			return


		var face:= false
		_face_clock += delta
		if _face_clock >= GATHER_LOOK_PERIOD:
			_face_clock = 0.0
			face = _has_face()
		if face or _sees_wads(delta):
			_face_clock = GATHER_LOOK_PERIOD
			_clear_old_heap()
			_start_stroke()
		else:


			_dry_strokes = 0
			_jam_strokes = 0


			_let_go_of_scraps()
		return


	_set_engine(power > 0.0)


	var speed:= power * CLIP_SECONDS / maxf(0.2, Tech.rake_throw_seconds())
	_anim.speed_scale = speed
	_clock += delta * speed * CLIP_FPS

	if not _did_bite and _clock >= F_BITE:
		_did_bite = true
		_bite()
	if _did_bite and not _did_throw:
		_carry_gathered()
	if not _did_throw and _clock >= F_RELEASE:
		_did_throw = true
		_throw()
	if _clock >= CYCLE_FRAMES:
		_clock = -1.0
		_anim.seek(0.0, true)
		_anim.pause()


func _shed() -> void:
	if not is_inside_tree():
		return
	if _shed_query == null:
		var box:= BoxShape3D.new()


		box.size = Vector3(BODY_W, SHED_HEIGHT + 0.2, BODY_L)
		_shed_query = PhysicsShapeQueryParameters3D.new()
		_shed_query.shape = box
		_shed_query.collision_mask = Cfg.L_STRAND | Cfg.L_PROP
		_shed_query.collide_with_areas = false
	_shed_query.transform = global_transform * Transform3D(Basis(),
		Vector3(0.0, BODY_H - 0.1 + (SHED_HEIGHT + 0.2) * 0.5, BODY_Z))
	for hit in get_world_3d().direct_space_state.intersect_shape(_shed_query, 64):
		var rb:= hit.get("collider") as RigidBody3D
		if rb == null or rb.freeze:
			continue


		if rb.get_meta(LiveStrandManager.META_PROTECTED, false) or rb.has_meta(LiveStrandManager.META_RIDER):
			continue
		if rb.linear_velocity.length_squared() > SHED_STILL * SHED_STILL:
			continue


		var side:= signf(to_local(rb.global_position).x)
		if side == 0.0:
			side = 1.0


		var item:= rb as Carryable
		if item != null:
			item.unplant()
		rb.sleeping = false
		rb.linear_velocity = global_basis.x.normalized() * (side * SHED_PUSH) + Vector3.UP * SHED_LIFT


func _clear_old_heap() -> void:
	if props == null:
		return
	var spot:= discharge_spot()
	var r2:= PropManager.WORK_SPOT_R * PropManager.WORK_SPOT_R
	var heap: Array [Carryable] = []

	for item in props.items:
		if not is_instance_valid(item) or item.hay_strands() <= 0:
			continue
		if item.global_position.distance_squared_to(spot) >= r2:
			continue
		if props.is_spoken_for(item):
			continue
		heap.append(item)
	for i in heap.size() - Cfg.RAKE_PAD_WADS:
		props.fold_away(heap [i])


func _start_stroke() -> void:
	_clock = 0.0
	_did_bite = false
	_did_throw = false
	_anim.seek(0.0, true)
	_anim.play(CLIP)
	Audio.play_3d("rake_chunk", global_position)


func _head_point() -> Vector3:
	return global_position + _forward() * Cfg.RAKE_REACH


func discharge_spot() -> Vector3:
	var at:= global_position - _forward() * throw_distance
	at.y = global_position.y
	return at


func _load_stalled() -> bool:
	if _last_load.is_empty():
		return false
	for wad in _last_load:
		if not is_instance_valid(wad):
			return false
		if wad.global_position.distance_to(_release_at) > MOUTH_RADIUS:
			return false
	return true


func _has_face() -> bool:
	if field == null:
		return false
	var floor_y:= global_position.y + FACE_MIN_HEIGHT
	var half:= BITE_PASSES / 2
	for offset in range(- half, half + 1):
		var at:= bite_point(offset)
		at.y = field.height_at(at.x, at.z)
		if field.can_carve_sphere(at, Cfg.RAKE_BITE_RADIUS, floor_y):
			return true
	return false


func alert_reason() -> String:
	if placement_preview:
		return ""
	if switched_off:
		return ""


	var dead:= MachinePower.fault(power, power_blocked, power_line)
	if dead != "":
		return dead


	if _jam_strokes >= DRY_STROKES_BEFORE_FAULT:
		return tr("JAMMED  ·  a wad is stuck in the head, carry it away")
	if _dry_strokes >= DRY_STROKES_BEFORE_FAULT:
		return tr("RAKING NOTHING  ·  the head does not reach the pile")


	if _clock >= 0.0:
		return ""
	if field == null:
		return tr("NO PILE  ·  there is no hay here to rake")
	if not _has_face():


		return tr("NOTHING TO RAKE  ·  no pile left in front of the head")
	return ""


var power:= 1.0

var power_blocked:= false


var power_line:= MachinePower.LINE_OK


var switched_off:= false
var line_power:= 1.0


func rated_kw() -> float:
	return Tech.rake_draw_kw()


func draw_kw() -> float:
	return 0.0 if switched_off else rated_kw()


const WIRE_PORT_FALLBACKS: Array [Vector3] = [
	Vector3(0.975, 1.35, 0.905), Vector3(0.975, 1.35, -0.905)]


func power_ports() -> Array [Node3D]:
	if _ports.is_empty():
		_ports = MachinePower.terminals(self, _model, 2, WIRE_PORT_FALLBACKS,
			_fitting_materials())
	return _ports


func _fitting_materials() -> Dictionary:
	var spec:= spec_table()
	if spec.is_empty():
		return { }
	var shader: Shader = load(HayCompressor.SHADER)
	return {
		"steel": HayCompressor.make_material("M_Steel", spec, shader),
		"porcelain": HayCompressor.make_material("M_Porcelain", spec, shader),
		"copper": HayCompressor.make_material("M_Copper", spec, shader),
	}


func set_power(f: float) -> void:
	line_power = clampf(f, 0.0, 1.0)
	power = 0.0 if switched_off else line_power


func set_switched_off(off: bool) -> void:
	switched_off = off
	set_power(line_power)


func is_switched_off() -> bool:
	return switched_off


func set_power_line(line: int) -> void:
	power_line = line


func set_power_blocked(b: bool) -> void:
	power_blocked = b


func alert_icon() -> String:
	return "power" if MachinePower.fault(power, power_blocked, power_line) != "" else ""


func _bite() -> void:
	if field == null:
		return
	var want:= float(Tech.rake_bite_strands())


	var carried:= _held
	_held = 0.0
	_thrown_total = carried
	_bite_sites.clear()


	var half:= BITE_PASSES / 2
	_thrown_total += _bite_pass(0)
	for side: int in [1, -1]:
		for step in range(1, half + 1):
			if _thrown_total >= want:
				break
			_thrown_total += _bite_pass(side * step)
	last_bite = _thrown_total - carried
	_gather()
	Audio.play_3d("rake_clack", global_position)


func bite_point(offset: int) -> Vector3:


	var rank:= absi(offset) * 2 - (1 if offset < 0 else 0)
	var t:= float(rank) / maxf(1.0, float(BITE_PASSES))
	var r:= bite_disc_radius() * sqrt(t)
	var a:= float(rank) * GOLDEN_ANGLE
	var out:= _head_point()
	out += global_basis.x.normalized() * (cos(a) * r)
	out += _forward() * (sin(a) * r)
	return out


static func bite_disc_radius() -> float:
	return Cfg.RAKE_HALF_WIDTH * 0.7


func _bite_pass(offset: int) -> float:
	var at:= bite_point(offset)
	at.y = field.height_at(at.x, at.z)
	var res:= field.carve_sphere(at, Cfg.RAKE_BITE_RADIUS, Cfg.RAKE_BITE_DROP)
	var took:= float(res.get("strands", 0.0))
	if took > 0.0:
		_bite_sites.append(at)
	return took


func _throw() -> void:
	last_gathered = 0
	if _launcher == null or (_thrown_total <= 0.0 and _gathered.is_empty()):


		_drop_gathered()
		_return_the_overshoot()
		_dry_strokes += 1
		return
	_put_out = 0.0
	_launcher.aim_along(- _forward())
	_launcher.ground_y = global_position.y
	_launcher.burst()
	Audio.play_3d("rake_throw", global_position)


	_anim.seek(F_RELEASE / CLIP_FPS, true)
	_carry_gathered()
	var head:= _find(N_HEAD) as Node3D
	var from: Vector3 = head.global_position if head != null else _launcher.global_position
	_aim_launcher(from)


	var stalled:= _load_stalled()
	_release_at = from
	_released = true
	_last_load.clear()
	last_thrown = 0
	_throw_wad(from)
	_fling_gathered()
	_throw_needle(from)


	_anim.seek(minf(_clock, CYCLE_FRAMES) / CLIP_FPS, true)


	if stalled or (last_thrown == 0 and last_gathered == 0 and _held <= 0.0):
		_dry_strokes += 1
	elif last_thrown > 0 or last_gathered > 0:
		_dry_strokes = 0


	if stalled:
		_jam_strokes += 1
	elif last_thrown > 0 or last_gathered > 0:
		_jam_strokes = 0
	_return_the_overshoot()


func _return_the_overshoot() -> void:
	var owed:= _thrown_total - _put_out
	if owed > 0.0:
		GameState.return_hay(owed)
	_put_out = 0.0
	_thrown_total = 0.0


func _throw_wad(from: Vector3) -> void:
	if props == null:
		return
	var want:= mini(Tech.rake_wad_strands(), int(round(_thrown_total)))
	if want < Cfg.WAD_MIN_STRANDS:
		_held = _thrown_total
		_thrown_total = 0.0
		return
	for n: int in HayWad.split(want):
		var wad:= props.spawn("hay_wad",
			Transform3D(global_basis.orthonormalized(), from),
			{ "strands": n }) as HayWad
		if wad == null:
			continue
		last_thrown += 1


		_put_out += float(n)
		wad.linear_velocity = _launcher.solve_throw(from)
		BeltPath.mark_machine_throw(wad)
		wad.angular_velocity = Vector3(randf_range(-2.5, 2.5),
			randf_range(-2.5, 2.5), randf_range(-2.5, 2.5))


		_last_load.append(wad)


func _gather() -> void:
	_drop_gathered()
	for wad in _gatherable():
		if _gathered.size() >= GATHER_MAX:
			break
		if wad.freeze:
			LiveStrandManager.unpin(wad)
		wad.set_meta(PropManager.META_CLAIM, get_instance_id())
		wad.pick_up()
		_gathered.append(wad)


	for i in _gathered.size():
		var wad:= _gathered [i]
		wad.warp(Transform3D(wad.global_basis.orthonormalized(), _gather_seat(i, wad)))


func _gatherable() -> Array [HayWad]:
	var out: Array [HayWad] = []
	if props == null:
		return out
	var head:= _head_point()
	var reach:= bite_disc_radius() + Cfg.RAKE_BITE_RADIUS + GATHER_PAD
	var near: Array = []
	for item in props.items:
		if not is_instance_valid(item) or not (item is HayWad):
			continue
		var wad:= item as HayWad
		if wad.is_held() or BeltPath.is_rider(wad):
			continue
		if wad.freeze and not LiveStrandManager.is_pinned(wad):
			continue
		if wad.has_meta(PropManager.META_CLAIM):
			var other:= instance_from_id(int(wad.get_meta(PropManager.META_CLAIM)))
			if other != null and is_instance_valid(other) and other != self:
				continue
		var p:= wad.global_position
		var flat:= Vector2(p.x - head.x, p.z - head.z).length()
		if flat > reach:
			continue
		var top:= global_position.y
		if field != null:
			top = maxf(top, field.height_at(p.x, p.z))
		if p.y < global_position.y - 0.3 or p.y > top + GATHER_ABOVE:
			continue
		near.append([flat, wad])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a [0] < b [0])
	for pair: Array in near:
		out.append(pair [1] as HayWad)
	return out


func _sees_wads(delta: float) -> bool:
	_gather_clock += delta
	if _gather_clock < GATHER_LOOK_PERIOD:
		return false
	_gather_clock = 0.0
	return not _gatherable().is_empty()


func _gather_seat(i: int, wad: HayWad) -> Vector3:
	var head:= _find(N_HEAD) as Node3D
	var at: Vector3 = head.global_position if head != null else global_position
	var k:= i + 1
	var side:= float(ceili(k / 2.0)) * (1.0 if k % 2 == 1 else -1.0)
	return at + global_basis.x.normalized() * (side * Cfg.WAD_CLEAR * HayWad.scale_for(wad.strands))


func _carry_gathered() -> void:
	for i in _gathered.size():
		var wad:= _gathered [i]
		if is_instance_valid(wad) and wad.is_held():
			wad.global_transform = Transform3D(wad.global_basis.orthonormalized(),
				_gather_seat(i, wad))


func _fling_gathered() -> void:
	for wad in _gathered:
		if not is_instance_valid(wad):
			continue
		_unclaim(wad)
		if not wad.is_held():
			continue
		wad.release(_launcher.solve_throw(wad.global_position),
			Vector3(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)))
		BeltPath.mark_machine_throw(wad)
		_last_load.append(wad)
		last_gathered += 1
	_gathered.clear()


func _drop_gathered() -> void:
	for wad in _gathered:
		if not is_instance_valid(wad):
			continue
		_unclaim(wad)
		if wad.is_held():
			wad.release(Vector3.ZERO)
	_gathered.clear()


func _unclaim(wad: HayWad) -> void:
	if wad.has_meta(PropManager.META_CLAIM) and int(wad.get_meta(PropManager.META_CLAIM)) == get_instance_id():
		wad.remove_meta(PropManager.META_CLAIM)


func _let_go_of_scraps() -> void:
	if _held > 0.0:
		GameState.return_hay(_held)
	_held = 0.0


func _throw_needle(from: Vector3) -> void:
	if live == null or _bite_sites.is_empty():
		return


	var drop:= func() -> Vector3:
		return from + Vector3(randf_range(-0.1, 0.1), randf_range(-0.05, 0.05),
			randf_range(-0.1, 0.1))
	var lifted: Array [RigidBody3D] = []


	for at: Vector3 in _bite_sites:
		live.lift_loose_needles_in(at, Cfg.RAKE_BITE_RADIUS, drop, lifted)


	var head:= _head_point()
	live.lift_loose_needles_in(
		Vector3(head.x, global_position.y + FACE_LIFT_RADIUS * 0.5, head.z),
		FACE_LIFT_RADIUS, drop, lifted)

	if randf() < needle_chance:
		var at: Vector3 = _bite_sites [randi() % _bite_sites.size()]
		live.reveal_needles_in(at, Cfg.RAKE_BITE_RADIUS, drop, lifted)
	if lifted.is_empty():
		return
	for b in lifted:
		if not is_instance_valid(b):
			continue


		b.linear_velocity = _launcher.solve_throw(from)
		b.angular_velocity = Vector3(randf_range(-4.0, 4.0),
			randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))


		live.set_ccd(b, true)


	Audio.play_3d("needle_ting", from, -2.0)


func _set_engine(running: bool) -> void:
	if running:
		if _engine_voice < 0:
			_engine_voice = Audio.loop_acquire("rake_engine")
		if _engine_voice >= 0:

			Audio.loop_update(_engine_voice, global_position, ENGINE_GAIN,
				MachinePower.loop_pitch(power))
	elif _engine_voice >= 0:
		Audio.loop_release(_engine_voice)
		_engine_voice = -1


func drive(direction: float, check: Callable) -> void:
	if placement_preview or direction == 0.0:
		return
	_drive_check = check
	drive_blocked = ""
	_drive_left = signf(direction) * DRIVE_STEP


func is_driving() -> bool:
	return _drive_left != 0.0


func _drive_step(delta: float) -> void:
	var step:= minf(DRIVE_SPEED * delta, absf(_drive_left)) * signf(_drive_left)
	var to:= global_position + _forward() * step
	var why:= ""
	if _drive_check.is_valid():
		why = str(_drive_check.call(self, to))
	if why != "":
		drive_blocked = why
		_drive_left = 0.0
		Audio.play_3d("build_denied", global_position)
		_drive_done()
		return

	_set_engine(false)
	if _drive_voice < 0:
		_drive_voice = Audio.loop_acquire("rake_drive")
	if _drive_voice >= 0:
		Audio.loop_update(_drive_voice, global_position, DRIVE_GAIN)
	global_position = to
	_turn_wheels(_forward() * step)
	_drive_left -= step
	if absf(_drive_left) < 0.0001:
		_drive_left = 0.0
		_drive_done()


func _drive_done() -> void:
	_set_engine(false)
	_stop_drive_sound()
	var yard:= get_parent() as BuildManager
	if yard != null:
		yard.changed.emit()


func _turn_wheels(moved: Vector3) -> void:
	if _wheels.is_empty() and _model != null:
		for wheel_name in N_WHEELS:
			var w:= _model.find_child(wheel_name, true, false) as Node3D
			if w != null:
				_wheels.append(w)
	var axle:= Vector3.UP.cross(moved)
	if axle.length_squared() < 1e-08:
		return
	var angle:= moved.length() / WHEEL_RADIUS
	for w in _wheels:
		if is_instance_valid(w):
			w.global_rotate(axle.normalized(), angle)


func _stop_drive_sound() -> void:
	if _drive_voice >= 0:
		Audio.loop_release(_drive_voice)
		_drive_voice = -1


func _exit_tree() -> void:
	_stop_drive_sound()
	_let_go_of_scraps()
	_drop_gathered()
	if _engine_voice >= 0:
		Audio.loop_release(_engine_voice)
		_engine_voice = -1


func _forward() -> Vector3:
	var f:= global_basis.z
	f.y = 0.0
	if f.length_squared() < 0.0001:
		return Vector3.FORWARD
	return f.normalized()


func _meshes() -> Array [MeshInstance3D]:
	var out: Array [MeshInstance3D] = []
	if _model == null:
		return out
	var stack: Array [Node] = [_model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n as MeshInstance3D)
		for c in n.get_children():
			stack.append(c)
	return out


func _marker_local(node_name: String, fallback: Vector3) -> Vector3:
	var marker:= _find(node_name) as Node3D
	if marker == null:
		return fallback
	return to_local(marker.global_position)


func _find(node_name: String) -> Node:
	if _model == null:
		return null
	return _model.find_child(node_name, true, false)


func to_dict() -> Dictionary:
	return {
		"type": "piston_rake",
		"off": switched_off,
		"position": global_position,
		"yaw": global_rotation.y,


		"throw": throw_distance,


		"paid": build_cost(),
		"gift": gift,
	}
