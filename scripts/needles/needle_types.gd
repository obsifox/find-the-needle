class_name NeedleTypes
extends RefCounted


const SPEC:= "res://assets/models/needle_cabinet_slots.json"


const EFFECTS:= {

	0: { "name": "Steady Hands", "text": "Digging costs 12% less stamina",
		"keys": { "dig_effort": -0.12 } },
	1: { "name": "Fine Work", "text": "Hand tools lift 8% more straw",
		"keys": { "scoop": 0.08 } },
	2: { "name": "Quick Pour", "text": "Buckets and barrows pour 15% faster",
		"keys": { "pour": 0.15 } },
	3: { "name": "Long Reach", "text": "You can pick things up from 15% further away",
		"keys": { "carry_reach": 0.15 } },
	4: { "name": "Second Wind", "text": "Stamina comes back 25% faster",
		"keys": { "stamina_regen": 0.25 } },


	5: { "name": "Pinpoint", "text": "Digging finds needles from twice as far away",
		"keys": { "reveal_radius": 1.0 } },


	6: { "name": "Belt Grease", "text": "Every belt in the yard runs 6% faster",
		"keys": { "belt_speed": 0.06 } },
	7: { "name": "Tape Measure", "text": "You can place buildings 20% further out",
		"keys": { "build_reach": 0.2 } },
	8: { "name": "Deep Bucket", "text": "Buckets and wheelbarrows hold 12% more",
		"keys": { "container": 0.12 } },
	9: { "name": "Quick Count", "text": "The selling stand takes hay 25% faster",
		"keys": { "stand_belt": 0.25 } },
	10: { "name": "Good Price", "text": "Hay sells for 8% more",
		"keys": { "hay_price": 0.08 } },


	11: { "name": "Fast Belts", "text": "Every belt in the yard runs 25% faster",
		"keys": { "belt_speed": 0.25 } },


	12: { "name": "Discount", "text": "Everything in the catalogue costs 8% less",
		"keys": { "build_cost": -0.08 } },
	13: { "name": "Deep Store", "text": "Machine buffers hold 40% more",
		"keys": { "machine_buffer": 0.4 } },
	14: { "name": "Fired Up", "text": "Compressors and pelletizers work 12% faster",
		"keys": { "machine_speed": 0.12 } },
	15: { "name": "Quick Arms", "text": "Robotic arms swing 15% faster",
		"keys": { "arm_speed": 0.15 } },
	16: { "name": "Clear Lens", "text": "Scanners take 25% bigger batches",
		"keys": { "scan_batch": 0.25 } },


	17: { "name": "Sharp Eye", "text": "Digging finds needles from 50% further away",
		"keys": { "reveal_radius": 0.5 } },


	18: { "name": "Top Price", "text": "Hay sells for 10% more",
		"keys": { "hay_price": 0.1 } },
	19: { "name": "Full Speed", "text": "Every machine in the yard works 10% faster",
		"keys": { "machine_speed": 0.1, "arm_speed": 0.1, "scan_speed": 0.1 } },
	20: { "name": "Sharp Edge", "text": "Every dig lifts 25% more",
		"keys": { "scoop": 0.25 } },
	21: { "name": "Big Drawer", "text": "Scanner drawers hold twice as much",
		"keys": { "scanner_bin": 1.0 } },
	22: { "name": "Meteoric Iron", "text": "Scanners work 25% faster",
		"keys": { "scan_speed": 0.25 } },


	23: { "name": "The Golden Needle", "text": "The whole yard earns and runs 15% better",
		"keys": { "hay_price": 0.15, "machine_speed": 0.15, "arm_speed": 0.15,
			"scan_speed": 0.15, "scoop": 0.15, "belt_speed": 0.15 } },
}


static var _slots: Array = []
static var _by_lot: Dictionary = { }
static var _lots:= 0
static var _cols:= 6
static var _specimen: Dictionary = { }


static func _load() -> void:
	if not _slots.is_empty():
		return
	var res: JSON = load(SPEC) as JSON
	if res == null or typeof(res.data) != TYPE_DICTIONARY:
		push_error("NeedleTypes: cannot read %s" % SPEC)
		return
	var d: Dictionary = res.data
	_slots = d.get("slots", [])
	_lots = int(d.get("lots", 0))
	_cols = int(d.get("cols", 6))
	_specimen = d.get("specimen", { })
	for row in _slots:
		var lot:= int(row.get("lot", 0))
		if not _by_lot.has(lot):
			_by_lot [lot] = PackedInt32Array()
		var pool: PackedInt32Array = _by_lot [lot]
		pool.append(int(row.get("slot", 0)))
		_by_lot [lot] = pool


static func count() -> int:
	_load()
	return _slots.size()


static func cols() -> int:
	_load()
	return maxi(_cols, 1)


static func specimen_length() -> float:
	_load()
	return maxf(float(_specimen.get("length", 0.118)), 0.001)


static func lot_count() -> int:
	_load()
	return _lots


static func pool(lot: int) -> PackedInt32Array:
	_load()
	return _by_lot.get(clampi(lot, 0, maxi(_lots - 1, 0)), PackedInt32Array())


const LOT_NAMES: Array [String] = [
	"Pins and sewing needles",
	"Threading tools",
	"Workshop steel",
	"Gemstones",
]


static func lot_name(lot: int) -> String:

	if lot < 0 or lot >= LOT_NAMES.size():
		return Cfg.tr("A new row")
	return Cfg.tr(LOT_NAMES [lot])


const DEEP_PER_LOT:= 2


static func deep_pool(lot: int) -> PackedInt32Array:
	var ids:= pool(lot)
	if ids.size() <= DEEP_PER_LOT:
		return ids
	var sorted:= Array(ids)
	sorted.sort_custom(func(a: int, b: int) -> bool:
		return one_in(a) > one_in(b))
	var out:= PackedInt32Array()
	for i in mini(DEEP_PER_LOT, sorted.size()):
		out.append(int(sorted [i]))
	return out


static func is_deep(type: int) -> bool:
	return type in deep_pool(lot_of(type))


const SHALLOW_PER_LOT:= 2


static func shallow_pool(lot: int) -> PackedInt32Array:
	var ids:= pool(lot)
	if ids.size() <= SHALLOW_PER_LOT + DEEP_PER_LOT:
		return PackedInt32Array()
	var sorted:= Array(ids)
	sorted.sort_custom(func(a: int, b: int) -> bool:
		return one_in(a) < one_in(b))
	var out:= PackedInt32Array()
	for i in mini(SHALLOW_PER_LOT, sorted.size()):
		out.append(int(sorted [i]))
	return out


static func is_shallow(type: int) -> bool:
	return type in shallow_pool(lot_of(type))


static func site_band(type: int) -> int:
	if is_deep(type):
		return HayField.SITE_DEEP
	if is_shallow(type):
		return HayField.SITE_SHALLOW
	return HayField.SITE_ANY


static func name_of(type: int) -> String:
	return String(_row(type).get("name", "NEEDLE"))


static func research_of(type: int) -> int:
	return int(_row(type).get("research", 1))


static func effect_name(type: int) -> String:


	var raw:= String(_effect(type).get("name", ""))
	return Cfg.tr(raw) if raw != "" else ""


static func effect_text(type: int) -> String:
	var raw:= String(_effect(type).get("text", ""))
	return Cfg.tr(raw) if raw != "" else ""


static func effect_keys(type: int) -> Dictionary:
	return _effect(type).get("keys", { })


static func has_effect(type: int) -> bool:
	return not _effect(type).is_empty()


static func _effect(type: int) -> Dictionary:
	return EFFECTS.get(type, { })


static func one_in(type: int) -> int:
	return int(_row(type).get("one_in", 1))


static func lot_of(type: int) -> int:
	return int(_row(type).get("lot", 0))


static func object_of(type: int) -> String:
	return String(_row(type).get("object", "Needle_%02d" % type))


static func material_of(type: int) -> String:
	return String(_row(type).get("material", "M_NC_Steel"))


static func label_of(type: int) -> PackedStringArray:
	var out:= PackedStringArray()
	for line in _row(type).get("label", []):
		out.append(String(line))
	return out


static func roll(lot: int, rng: RandomNumberGenerator) -> int:
	var ids:= pool(lot)
	if ids.is_empty():
		return 0
	var t:= rng.randf()
	var acc:= 0.0
	for id in ids:
		acc += 1.0 / float(maxi(one_in(id), 1))
		if t < acc:
			return id
	return ids [ids.size() - 1]


static func _row(type: int) -> Dictionary:
	_load()
	if type < 0 or type >= _slots.size():
		return { }
	return _slots [type]
