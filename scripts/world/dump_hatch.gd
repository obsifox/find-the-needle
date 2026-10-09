class_name DumpHatch
extends Node3D


const MODEL:= "res://assets/models/compiled/dump_hatch.scn"


const SPEC:= "res://assets/models/dump_hatch_materials.json"
const SHADER:= "res://assets/stand_surface.gdshader"
const TEX:= "res://assets/downloaded/textures/%s/%s_%s_1k.jpg"
const TEX_MAPS:= {
	"albedo": "diff", "normal": "nor_gl", "rough": "rough", "ao": "ao",
}

const N_DECK:= "Hatch_Deck"

const N_CLAMP:= "Hatch_Clamp"
const N_DOCK:= "Marker_Dock"
const N_APPROACH:= "Marker_Approach"
const N_SPOUT:= "Marker_Spout"


const N_FILL_LO:= "Marker_FillLo"
const N_FILL_HI:= "Marker_FillHi"

const RAM_SIDES:= ["L", "R"]
const N_RAM_BARREL:= "Hatch_RamBarrel%s"
const N_RAM_ROD:= "Hatch_RamRod%s"
const N_RAM_PIN:= "Marker_RamPin%s"


const AIM_SIZE:= Vector3(1.34, 1.62, 2.05)
const AIM_CENTRE:= Vector3(0.0, 0.81, 0.825)


const ROD_LENGTH:= 1.0


const CLAMP_OPEN:= deg_to_rad(78.0)


const CLAMP_TIME:= 0.18


const TIP_ANGLE:= deg_to_rad(90.0)
const TIP_SIGN:= -1.0


const CAPACITY:= 8400


const FILL_INSTANCES:= 620


const WAD_STRANDS:= 250


const WAD_INTERVAL:= 0.32


const WAD_THROW:= 1.6


const AIM_REACH:= 2.2


const AIM_MIN_FLAT:= 0.35


const AIM_FORWARD_MIN:= 0.35


const AIM_SPEED:= 2.6
const AIM_TIME_MIN:= 0.22
const AIM_TIME_MAX:= 0.8


const SETTLE:= 0.15
const TIP_TIME:= 0.45
const DRAIN_TAIL:= 0.12
const RETURN_TIME:= 0.45


const DUMP_FRACTION:= 0.5
const DUMP_TIME:= 0.5


const DUMP_TAIL:= 0.25


const AUTO_REACH:= 2.4

enum State {
	IDLE, SETTLING, TIPPING, EMPTYING, RETURNING, UNGRIPPING,

	DUMP_UP, DUMPING, DUMP_DOWN,
}


signal docked(item: HayContainer)
signal finished(item: HayContainer)


var placement_preview:= false


var live: LiveStrandManager
var props: PropManager


var builds: BuildManager

var _model: Node3D
var _deck: Node3D
var _clamp: Node3D
var _dock: Node3D
var _spout: Node3D


var _aim: ThrowAim


var _spout_dump_local:= Vector3.ZERO
var _approach: Node3D
var _ram_barrel: Dictionary = { }
var _ram_rod: Dictionary = { }
var _ram_pin: Dictionary = { }
var _meshes: Array [MeshInstance3D] = []

var _fill: MultiMeshInstance3D

var _state: State = State.IDLE
var _load: HayContainer
var _timer:= 0.0


var stored:= 0
var _rng:= RandomNumberGenerator.new()


var _belt_wad: RigidBody3D = null
var _belt_wad_age:= 0.0


var _asked_frame:= -100


var _angle:= 0.0


var _grip:= 0.0
var _hovered:= false


func setup(at: Vector3, yaw: float) -> void:
	position = at
	rotation.y = yaw


func _ready() -> void:
	_build()
	if placement_preview:
		set_physics_process(false)
		return


	_build_throw_aim()
	MachineLod.adopt(self, _model, MODEL)
	_build_aim_volume()
	add_to_group("dump_hatches")


func _build() -> void:
	var scene: PackedScene = load(MODEL)
	if scene == null:
		push_warning("DumpHatch: no model at %s" % MODEL)
		return
	_model = scene.instantiate()
	add_child(_model)
	_layer_the_body()
	_deck = _model.find_child(N_DECK, true, false)
	_clamp = _model.find_child(N_CLAMP, true, false)
	if _deck == null:
		push_warning("DumpHatch: the model has no %s, so nothing will tip" % N_DECK)
	_dock = _model.find_child(N_DOCK, true, false)
	_spout = _model.find_child(N_SPOUT, true, false)
	_approach = _model.find_child(N_APPROACH, true, false)
	for s: String in RAM_SIDES:
		_ram_barrel [s] = _model.find_child(N_RAM_BARREL % s, true, false)
		_ram_rod [s] = _model.find_child(N_RAM_ROD % s, true, false)
		_ram_pin [s] = _model.find_child(N_RAM_PIN % s, true, false)
	_build_fill()
	_skin()
	_drive(0.0)


func _build_fill() -> void:
	if _model == null:
		return
	var lo:= _model.find_child(N_FILL_LO, true, false) as Node3D
	var hi:= _model.find_child(N_FILL_HI, true, false) as Node3D
	if lo == null or hi == null:
		push_warning("DumpHatch: the model has no fill markers, so the bin will look empty")
		return
	var a:= lo.position
	var b:= hi.position
	var box:= AABB(Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)),
		(b - a).abs())


	var heights: Array [float] = []
	for i in FILL_INSTANCES:
		heights.append(_rng.randf())
	heights.sort()

	var mm:= MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = StrandFactory.strand_mesh()
	mm.instance_count = FILL_INSTANCES
	mm.visible_instance_count = 0
	for i in FILL_INSTANCES:
		var at:= box.position + Vector3(
			_rng.randf() * box.size.x,
			(heights [i] + _rng.randf_range(-0.035, 0.035)) * box.size.y,
			_rng.randf() * box.size.z)
		mm.set_instance_transform(i,
			Transform3D(StrandFactory.random_strand_basis(_rng, 0.88), at))
		mm.set_instance_color(i, StrandFactory.random_tint(_rng))

	_fill = MultiMeshInstance3D.new()
	_fill.name = "Hopper_Load"
	_fill.multimesh = mm
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


	_fill.custom_aabb = box


	var host:= lo.get_parent()
	if host == null:
		host = _model
	host.add_child(_fill)
	_refresh_fill()


func _refresh_fill() -> void:
	if _fill == null or _fill.multimesh == null:
		return
	_fill.multimesh.visible_instance_count = int(round(fill_fraction() * float(FILL_INSTANCES)))


func _layer_the_body() -> void:
	for n in _model.find_children("*", "StaticBody3D", true, false):
		var body:= n as StaticBody3D
		body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
		body.collision_mask = 0


func _build_throw_aim() -> void:
	if _spout != null:
		_drive(DUMP_FRACTION)
		_spout_dump_local = to_local(_spout.global_position)
		_drive(0.0)
	_aim = ThrowAim.new()
	_aim.name = "ThrowAim"
	_aim.source = self
	_aim.spot_radius = 0.3
	_aim.arc_on_hover = true
	add_child(_aim)


func throw_aim() -> ThrowAim:
	return _aim


func throw_path() -> Dictionary:
	if _spout == null:
		return { }
	var at:= to_global(_spout_dump_local)
	var out:= - global_transform.basis.z
	var throw:= out * WAD_THROW + Vector3.DOWN * 0.2
	var aim:= _aim_point(at, out)
	if aim.is_finite():
		throw = _arc_to(at, aim)
	return { "from": at, "velocity": throw, "ground_y": global_position.y,
		"damped": true }


func _build_aim_volume() -> void:
	var box:= BoxShape3D.new()
	box.size = AIM_SIZE
	var shape:= CollisionShape3D.new()
	shape.name = "AimShape"
	shape.shape = box
	shape.position = AIM_CENTRE

	var aim:= Area3D.new()
	aim.name = "AimVolume"
	aim.collision_layer = Cfg.L_BUILD
	aim.collision_mask = 0
	aim.monitoring = false
	aim.add_child(shape)
	add_child(aim)


func will_take(item: Carryable) -> bool:
	if _state != State.IDLE or _deck == null or placement_preview:
		return false
	var box:= item as HayContainer


	if box == null or box.stored <= 0:
		return false
	return room() > 0


func wants(item: Carryable, from: Vector3) -> bool:
	var d:= dock_point() - from
	d.y = 0.0
	if d.length() > AUTO_REACH:
		return false
	var box:= item as HayContainer
	if box != null and box.stored > 0 and room() > 0 and not placement_preview:
		_asked_frame = Engine.get_physics_frames()
	return will_take(item)


func _asked() -> bool:
	return Engine.get_physics_frames() - _asked_frame <= 2


func room() -> int:
	return maxi(0, CAPACITY - stored)


func fill_fraction() -> float:
	return clampf(float(stored) / float(CAPACITY), 0.0, 1.0)


func take_loose(count: int) -> int:
	if placement_preview or _deck == null or count <= 0:
		return 0
	var took:= mini(count, room())
	if took <= 0:
		return 0
	stored += took
	_refresh_fill()
	if _state == State.IDLE or _state == State.DUMP_DOWN:
		_state = State.DUMP_UP
	return took


func take(item: HayContainer) -> bool:
	if not will_take(item):
		return false
	_load = item
	item.docked_in = self


	item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	item.freeze = true
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	item.sleeping = false
	_meter()
	BeltPath.release(item)
	_seat_load()
	_state = State.SETTLING
	_timer = SETTLE
	_grip = 0.0
	Audio.play_3d("machine_clunk", global_position + Vector3(0, 0.7, 0), -6.0)
	docked.emit(item)
	return true


func _seat_load() -> void:
	if _load == null or _dock == null:
		return
	_load.global_transform = _dock.global_transform


func give_back_load() -> void:
	if _load == null:
		return
	_release_load()


func _release_load() -> void:
	var item:= _load
	_load = null
	if item == null:
		return
	item.docked_in = null
	item.pour_boost = 1.0
	item.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	item.freeze = false
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	item.sleeping = false


	if item.global_basis.y.dot(Vector3.UP) < 0.99:
		item.tumble()
	finished.emit(item)


func _physics_process(delta: float) -> void:


	_seat_load()


	_meter()
	_belt_wad_age += delta


	match _state:
		State.IDLE:


			if stored > 0 and not _asked():
				_state = State.DUMP_UP
		State.SETTLING:


			_grip = minf(1.0, _grip + delta / CLAMP_TIME)
			_timer -= delta
			if _timer <= 0.0 and _grip >= 1.0:
				_state = State.TIPPING
		State.TIPPING:
			_angle = minf(1.0, _angle + delta / TIP_TIME)
			if _angle >= 1.0:
				_swallow()
				_state = State.EMPTYING
				_timer = DRAIN_TAIL
		State.EMPTYING:


			_timer -= delta
			if _timer <= 0.0:


				_state = State.RETURNING
		State.RETURNING:
			_angle = maxf(0.0, _angle - delta / RETURN_TIME)
			if _angle <= 0.0:
				_state = State.UNGRIPPING
				Audio.play_3d("machine_clunk",
					global_position + Vector3(0, 0.7, 0), -9.0)
		State.UNGRIPPING:


			_grip = maxf(0.0, _grip - delta / CLAMP_TIME)
			if _grip <= 0.0:
				_release_load()


				_state = State.DUMP_UP if stored > 0 else State.IDLE
		State.DUMP_UP:
			_angle = minf(DUMP_FRACTION, _angle + delta / DUMP_TIME)
			if _asked():
				_state = State.DUMP_DOWN
				_timer = 0.0
			elif _angle >= DUMP_FRACTION:
				_state = State.DUMPING
				_timer = 0.0
		State.DUMPING:


			_timer -= delta
			if _timer <= 0.0 and _throw_wad():
				_timer = WAD_INTERVAL
			if stored <= 0 or _asked():


				_state = State.DUMP_DOWN
				_timer = DUMP_TAIL
			elif _timer <= 0.0:


				_timer = WAD_INTERVAL
		State.DUMP_DOWN:
			_timer -= delta
			if _timer > 0.0:
				pass
			else:
				_angle = maxf(0.0, _angle - delta / DUMP_TIME)
				if _angle <= 0.0:
					_state = State.IDLE
					Audio.play_3d("machine_clunk",
						global_position + Vector3(0, 0.7, 0), -9.0)
	_drive(_angle)


func _meter() -> void:
	if _load == null:
		return
	_load.pour_boost = 0.0


func _swallow() -> void:
	if _load == null:
		return
	var took:= _load.take_out(mini(_load.stored, room()))
	if took <= 0:
		return
	stored += took
	_refresh_fill()


	Audio.play_3d("hay_dump", global_position + Vector3(0, 0.7, 0), -4.0)


func _throw_wad() -> bool:
	if stored <= 0 or props == null or _spout == null or placement_preview:
		return false
	var take:= mini(stored, WAD_STRANDS)
	var at:= spout_point()


	var out:= - global_transform.basis.z


	var parts: Array [int] = HayWad.split(take)
	if parts.is_empty():
		parts = [take]

	var throw:= out * WAD_THROW + Vector3.DOWN * 0.2
	var aim:= _aim_point(at, out)
	if aim.is_finite():
		throw = _arc_to(at, aim)

	var clear:= HayWad.clearance_for(parts [0])
	var belt: int = BeltPath.pour_verdict(at, throw, maxf(clear.x, clear.z) * 0.5)
	if _belt_holds_throw(belt):
		return false
	if belt != BeltPath.Pour.NO_BELT:
		parts = [parts [0]]


	var across:= global_basis.x.normalized()
	var made:= 0
	for i in parts.size():
		var n: int = parts [i]
		var step:= Cfg.WAD_CLEAR * HayWad.scale_for(n)
		var seat:= at + across * (float(i) - float(parts.size() - 1) * 0.5) * step
		var item:= props.spawn("hay_wad", Transform3D(global_basis, seat),
			{ "strands": n }) as Carryable
		if item == null:
			continue
		made += n
		var rb:= item as RigidBody3D
		if rb != null:


			rb.linear_velocity = throw
			if belt != BeltPath.Pour.NO_BELT:
				_belt_wad = rb
				_belt_wad_age = 0.0
			rb.angular_velocity = Vector3(_rng.randf_range(-1.5, 1.5), 0.0,
				_rng.randf_range(-1.5, 1.5))


	if made <= 0:
		return false
	stored -= made
	_refresh_fill()
	Audio.play_3d("hay_dump", at, -6.0)
	return true


func _belt_holds_throw(belt: int) -> bool:
	if belt == BeltPath.Pour.NO_BELT:
		return false
	if belt == BeltPath.Pour.NO_ROOM:
		return true
	return is_instance_valid(_belt_wad) and _belt_wad.is_inside_tree() and not BeltPath.is_rider(_belt_wad) and _belt_wad_age < HayContainer.POUR_BELT_WAIT


func _aim_point(from: Vector3, out: Vector3) -> Vector3:
	if builds == null or not is_instance_valid(builds):
		return Vector3.INF
	var ahead:= Vector3(out.x, 0.0, out.z)
	if ahead.length_squared() < 1e-06:
		return Vector3.INF
	ahead = ahead.normalized()
	for drop in builds.conveyor_drops(from, AIM_REACH):
		var to: Vector3 = drop ["point"] as Vector3
		var flat:= Vector3(to.x - from.x, 0.0, to.z - from.z)
		var span:= flat.length()
		if span < AIM_MIN_FLAT:
			continue
		if flat.dot(ahead) / span < AIM_FORWARD_MIN:
			continue
		return to
	return Vector3.INF


func _arc_to(from: Vector3, to: Vector3) -> Vector3:
	var delta:= to - from
	var flat:= Vector3(delta.x, 0.0, delta.z)
	var t:= clampf(flat.length() / AIM_SPEED, AIM_TIME_MIN, AIM_TIME_MAX)
	var g:= absf(float(ProjectSettings.get_setting(
		"physics/3d/default_gravity", 9.8)))
	return flat / t + Vector3.UP * (delta.y / t + 0.5 * g * t)
func _drive(t: float) -> void:
	if _deck == null:
		return
	var eased:= smoothstep(0.0, 1.0, t)
	_deck.rotation.x = TIP_SIGN * TIP_ANGLE * eased
	if _clamp != null:


		_clamp.rotation.x = CLAMP_OPEN * (1.0 - smoothstep(0.0, 1.0, _grip))
	_drive_rams()


func _drive_rams() -> void:
	for s: String in RAM_SIDES:
		var pin: Node3D = _ram_pin.get(s)
		var barrel: Node3D = _ram_barrel.get(s)
		var rod: Node3D = _ram_rod.get(s)
		if pin == null or barrel == null or rod == null:
			continue
		var target:= pin.global_position
		var reach:= target - barrel.global_position


		if reach.length_squared() < 1e-06:
			continue
		barrel.look_at(target, Vector3.UP)
		rod.look_at(target, Vector3.UP)
		rod.scale = Vector3(1.0, 1.0, reach.length() / ROD_LENGTH)


func is_busy() -> bool:
	return _state != State.IDLE


func load_item() -> HayContainer:
	return _load


func approach_point() -> Vector3:
	return _approach.global_position if _approach != null else global_position


func dock_point() -> Vector3:
	return _dock.global_position if _dock != null else global_position


func dock_transform() -> Transform3D:
	return _dock.global_transform if _dock != null else global_transform


func spout_point() -> Vector3:
	return _spout.global_position if _spout != null else global_position


func set_highlighted(on: bool) -> void:
	if on == _hovered:
		return
	_hovered = on
	var m:= Carryable.hover_material() if on else null
	for mi in _meshes:
		mi.material_overlay = m


func is_highlighted() -> bool:
	return _hovered


func _skin() -> void:
	if _model == null:
		return
	var spec:= _load_spec()
	if spec.is_empty():
		push_warning("DumpHatch: no material table at %s, the model will render untextured" % SPEC)
		return
	var shader: Shader = load(SHADER)
	var built: Dictionary = { }
	var missed: Dictionary = { }
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		var mi:= n as MeshInstance3D
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
				built [key] = _make_surface(key, spec, shader)
			if built [key] == null:
				missed [key] = true
				continue
			mi.set_surface_override_material(i, built [key])
		_meshes.append(mi)
	if not missed.is_empty():
		push_warning("DumpHatch: no table entry for %s" % ", ".join(missed.keys()))


func _load_spec() -> Dictionary:


	var res: JSON = load(SPEC) as JSON
	if res != null and typeof(res.data) == TYPE_DICTIONARY:
		return res.data
	if not FileAccess.file_exists(SPEC):
		return { }
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else { }


func _make_surface(key: String, spec: Dictionary, shader: Shader) -> Material:
	var surfaces: Dictionary = spec.get("surfaces", { })
	if surfaces.has(key):
		var d: Dictionary = surfaces [key]
		var asset: String = d ["asset"]
		var m:= ShaderMaterial.new()
		m.shader = shader
		m.resource_name = key
		for slot: String in TEX_MAPS:
			var path: String = TEX % [asset, asset, TEX_MAPS [slot]]
			if ResourceLoader.exists(path):
				m.set_shader_parameter("tex_" + slot, load(path))
		m.set_shader_parameter("per_metre", float(d ["per_metre"]))
		m.set_shader_parameter("tint", _col(d ["tint"]))
		m.set_shader_parameter("saturation", float(d.get("sat", 1.0)))
		var rough: Array = d ["rough"]
		m.set_shader_parameter("rough_min", float(rough [0]))
		m.set_shader_parameter("rough_max", float(rough [1]))
		m.set_shader_parameter("metallic_amount", float(d.get("metal", 0.0)))
		m.set_shader_parameter("normal_strength", float(d.get("nor", 1.0)))
		m.set_shader_parameter("ao_strength", float(d.get("ao", 0.0)))
		return m

	var flats: Dictionary = spec.get("flats", { })
	if flats.has(key):
		var f: Dictionary = flats [key]
		var sm:= StandardMaterial3D.new()
		sm.resource_name = key
		var colour:= _col(f ["color"])
		sm.albedo_color = colour
		sm.roughness = float(f.get("rough", 0.6))
		sm.metallic = float(f.get("metal", 0.0))
		sm.metallic_specular = 0.4
		return sm
	return null


func _col(a: Variant) -> Color:
	var v: Array = a
	return Color(float(v [0]), float(v [1]), float(v [2]))


func set_preview_valid(ok: bool) -> void:
	var m:= StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.35, 1.0, 0.45, 0.34) if ok else Color(1.0, 0.32, 0.28, 0.34)
	m.render_priority = 1
	for mi in _meshes:
		mi.material_overlay = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func build_cost() -> float:
	return Cfg.DUMP_HATCH_COST


func to_dict() -> Dictionary:
	return {


		"type": "dump_hatch",


		"position": global_position,
		"yaw": global_rotation.y,


		"stored": stored,
	}


func from_dict(d: Dictionary) -> void:
	stored = clampi(int(d.get("stored", 0)), 0, CAPACITY)


	_refresh_fill()
