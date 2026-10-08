class_name GasPlant
extends HayGenerator


const PLANT_MODEL:= "res://assets/models/woodgas_plant/optimized/woodgas_plant_optimized.tscn"

const N_BELT_IN:= "Marker_BeltIn"
const N_PLANT_BELT_HEAD:= "Marker_BeltHead"
const N_WATER_IN:= "Marker_WaterIn"
const N_POWER_OUT:= "Marker_PowerOut"
const N_HEARTH:= "Marker_Hearth"


const BELT_IN_AT:= Vector3(0.0, 0.43, -3.0)
const BELT_HEAD_AT:= Vector3(0.0, 0.43, -2.3)
const WATER_IN_AT:= Vector3(-1.21, 1.13, 3.0)
const POWER_OUT_AT:= Vector3(1.27, 3.115, 1.66)
const HEARTH_AT:= Vector3(0.58, 1.06, -1.13)


const PLANT_HOPPER_AT:= Vector3(0.0, 0.75, -3.35)
const PLANT_HOPPER_SIZE:= Vector3(1.1, 0.8, 0.7)


const WRONG_FUEL_SHOW:= 6.0


const REFILL_BELOW:= 0.95


var water:= 1.0

var water_blocked:= false

var water_pumpless:= false


var tank:= -1.0

var _filling:= true


var _asked:= 0.0

var _water_kw:= INF

var _wrong_fuel:= 0.0
var _wrong_name:= ""
var _water_ports: Array [Node3D] = []


var _head_cache:= Vector3.INF
var _feed_cache:= -1.0


func _ready() -> void:


	port_reach = 0.0
	super._ready()
	if tank < 0.0:
		tank = tank_capacity()


func _model_path() -> String:
	return PLANT_MODEL


func _skin() -> void:
	pass


func _build_animation() -> void:
	pass


func _build_collider() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = 0 if placement_preview else Cfg.L_BUILD
	_body.collision_mask = 0
	add_child(_body)
	for spec: Array in [
			[Vector3(2.99, 0.32, 6.0), Vector3(0.0, 0.16, 0.0)],
			[Vector3(1.42, 4.15, 1.42), Vector3(0.0, 2.39, -1.18)],
			[Vector3(1.15, 2.96, 0.72), Vector3(0.0, 2.58, -2.65)],
			[Vector3(1.14, 1.08, 2.95), Vector3(0.42, 0.85, 1.17)],
			[Vector3(0.7, 2.1, 3.0), Vector3(-1.03, 1.3, 0.85)],
			[Vector3(0.4, 1.0, 0.95), Vector3(1.2, 1.7, 1.43)],
			[Vector3(1.75, 1.85, 0.24), Vector3(0.17, 1.34, 2.78)]]:
		var box:= BoxShape3D.new()
		box.size = spec [0]
		var cs:= CollisionShape3D.new()
		cs.shape = box
		cs.position = spec [1]
		_body.add_child(cs)


func _build_belt() -> void:
	super._build_belt()
	if _belt != null:
		_belt.gathers_straw = false


func _build_instruments() -> void:
	pass


func _build_fire() -> void:
	_fire_light = OmniLight3D.new()
	_fire_light.name = "FireLight"
	_fire_light.light_color = FIRE_COLOUR
	_fire_light.light_energy = 0.0
	_fire_light.omni_range = FIRE_RANGE
	_fire_light.shadow_enabled = false
	_fire_light.position = _fire_local()
	_fire_light.visible = false
	add_child(_fire_light)


func _build_steam() -> void:
	pass


func _fire_local() -> Vector3:
	return _marker_local(N_HEARTH, HEARTH_AT)


func _hopper_at() -> Vector3:
	return PLANT_HOPPER_AT


func _hopper_size() -> Vector3:
	return PLANT_HOPPER_SIZE


func _wire_port_name() -> String:
	return N_POWER_OUT


func _wire_port_fallback() -> Vector3:
	return POWER_OUT_AT


func _head_local() -> Vector3:
	if _head_cache == Vector3.INF:
		var at:= _marker_local(N_PLANT_BELT_HEAD, BELT_HEAD_AT)
		if _model == null:
			return at
		_head_cache = at
	return _head_cache


func feed_length() -> float:
	if _feed_cache < 0.0:
		var span:= _head_local().distance_to(_marker_local(N_BELT_IN, BELT_IN_AT))
		if _model == null:
			return span
		_feed_cache = span
	return _feed_cache


func console_position() -> Vector3:
	return to_global(Vector3(1.75, 0.9, 1.43))


func rated_output_kw() -> float:
	return Tech.gas_plant_output()


func kj_per_strand() -> float:
	return Cfg.GAS_PLANT_KJ_PER_STRAND


func capacity() -> float:
	return Cfg.GAS_PLANT_HOPPER_KJ


func worth_of_body(body: Node) -> float:
	if body is EcoBrick:
		return float((body as EcoBrick).hay_strands()) * Cfg.GAS_PLANT_KJ_PER_STRAND
	return 0.0


func worth_of(kind: int, strands: int) -> float:
	if kind == BeltRun.Kind.BRICK:
		return float(strands) * Cfg.GAS_PLANT_KJ_PER_STRAND
	return 0.0


func loose_worth() -> float:
	return 0.0


func straw_room() -> int:
	return 0


func refuse_straw() -> void:
	_wrong_fuel = WRONG_FUEL_SHOW
	_wrong_name = ""


func _refuse_fuel(rb: RigidBody3D) -> void:
	var item:= rb as Carryable
	if item != null and item.is_held():
		return
	_refused = true
	_wrong_fuel = WRONG_FUEL_SHOW
	_wrong_name = Cfg.lower_in_english(item.display_name) if item != null else tr("loose hay")


func _intake_fuel() -> void:
	super._intake_fuel()
	if _belt == null:
		return
	var rb:= _belt.waiting_rider()
	if rb != null and worth_of_body(rb) <= 0.0 and burn_value(rb) > 0.0:
		_refuse_fuel(rb)


func list_price() -> float:
	return Cfg.GAS_PLANT_COST


func tank_capacity() -> float:
	return Cfg.GAS_PLANT_TANK_SECONDS * rated_output_kw() * Cfg.GAS_PLANT_LPS_PER_KW


func tank_seconds() -> float:
	var per:= rated_output_kw() * Cfg.GAS_PLANT_LPS_PER_KW
	return 0.0 if per <= 0.0 else maxf(tank, 0.0) / per


func water_draw_lps() -> float:
	if switched_off:
		return 0.0
	if not _filling and made_kw <= Cfg.GENERATOR_PILOT_KW + 0.001:
		return 0.0
	return rated_output_kw() * Cfg.GAS_PLANT_LPS_PER_KW


func water_ports() -> Array [Node3D]:
	if _water_ports.is_empty():
		var node:= _find(N_WATER_IN) as Node3D
		if node == null:
			var stand_in:= Node3D.new()
			stand_in.name = N_WATER_IN
			stand_in.position = WATER_IN_AT
			add_child(stand_in)
			node = stand_in
		_water_ports.append(node)
	return _water_ports


func water_port_bearing(_port: Node3D) -> Vector3:
	var out:= global_basis.z
	out.y = 0.0
	return out.normalized() if out.length_squared() > 1e-08 else Vector3.BACK


func water_port() -> Vector3:
	var ports:= water_ports()
	return global_position if ports.is_empty() else ports [0].global_position


func set_water(f: float) -> void:
	water = clampf(f, 0.0, 1.0)


func set_water_blocked(b: bool) -> void:
	water_blocked = b


func set_water_pumpless(b: bool) -> void:
	water_pumpless = b


func _water_fault() -> String:
	if placement_preview or switched_off or water > 0.0 or tank > 0.001:
		return ""
	if water_blocked:
		return tr("NO WATER  ·  run a water pipe onto its flange")
	if water_pumpless:
		return tr("NO WATER  ·  no pump is on this pipe, build a borehole pump on it")


	return tr("NO WATER  ·  get the pump running, feed a Hay Generator on its line")


func factory_tick(delta: float) -> void:
	_wrong_fuel = maxf(_wrong_fuel - delta, 0.0)
	var cap:= tank_capacity()
	if tank < 0.0:
		tank = cap
	if tank >= cap - 0.001:
		_filling = false
	elif tank < cap * REFILL_BELOW:
		_filling = true


	var ask:= water_draw_lps()
	tank = minf(tank + water * minf(ask, _asked) * delta, cap)
	_asked = ask
	var per:= Cfg.GAS_PLANT_LPS_PER_KW
	_water_kw = INF if delta <= 0.0 else tank / maxf(per * delta, 1e-09)
	super.factory_tick(delta)
	tank = maxf(tank - made_kw * per * delta, 0.0)
	_apply_drive()


func wanted_kw() -> float:
	return minf(super.wanted_kw(), _water_kw)


func deliverable_kw() -> float:
	var own:= super.deliverable_kw()
	var from_tank:= maxf(tank, 0.0) / Cfg.GAS_PLANT_LPS_PER_KW
	return minf(own, maxf(rated_output_kw() * water, from_tank))


func _apply_drive() -> void:
	if _model == null:
		return
	var rated:= maxf(rated_output_kw(), 0.001)
	var drive:= 0.0
	if _burning:
		drive = 0.3 + 0.7 * clampf(made_kw / rated, 0.0, 1.0)
	if "drive" in _model:
		_model.set("drive", drive)


func is_waiting() -> bool:
	if _filling or tank < tank_capacity() - 0.001 or _wrong_fuel > 0.0:
		_idle_memo.clear()
		return false
	return super.is_waiting()


func alert_reason() -> String:
	if placement_preview or switched_off:
		return ""
	if _wrong_fuel > 0.0:
		if _wrong_name == "":
			return tr("BRICKS ONLY  ·  a gas plant burns eco bricks and nothing else")
		return tr("BRICKS ONLY  ·  take the %s off the intake") % _wrong_name
	var dry:= _water_fault()
	if dry != "":
		return dry
	return super.alert_reason()


func alert_icon() -> String:
	if placement_preview or switched_off:
		return ""
	if _wrong_fuel > 0.0:
		return "jam"
	if _water_fault() != "":
		return "water"
	return super.alert_icon()


func _empty_reason() -> String:
	return tr("NO BRICKS  ·  nothing is reaching the intake")


func to_dict() -> Dictionary:
	var d:= super.to_dict()
	d ["type"] = "gas_plant"
	d ["tank"] = tank

	d.erase("port_reach")
	return d
