class_name DeliveryBook
extends RefCounted


const CONTRACTS:= [
	{
		"id": "bales_20",
		"title": "Twenty bales",
		"detail": "Load twenty bales onto the truck. Make them with a compressor.",
		"want": "hay_bale",
		"also": "foiled_bale",
		"count": 20,
		"unit": "BALES",
		"pay": 150.0,
		"reward_tech": "scanner_mk1",
	},
	{
		"id": "foiled_18",
		"title": "Eighteen wrapped",
		"detail": "Load eighteen wrapped bales onto the truck. Make them with a wrapper.",
		"want": "foiled_bale",
		"count": 18,
		"unit": "WRAPPED",
		"pay": 400.0,
		"reward_tech": "drone",
	},
	{
		"id": "bricks_30",
		"title": "Thirty eco bricks",
		"detail": "Load thirty eco bricks onto the truck. Make them with a pelletizer.",
		"want": "eco_brick",
		"count": 30,
		"unit": "BRICKS",
		"pay": 900.0,


		"reward_tech": "brick_quality",
	},


	{
		"id": "bricks_50",
		"title": "Fifty bricks",
		"detail": "Load fifty eco bricks onto the truck.",
		"want": "eco_brick",
		"count": 50,
		"unit": "BRICKS",
		"pay": 1000.0,


		"reward_tech": "briquette_press",
	},


	{
		"id": "discs_12",
		"title": "Twelve feed discs",
		"detail": "Load twelve feed discs onto the truck. A disc press makes them from hay and eco bricks.",
		"want": "feed_disc",
		"count": 12,
		"unit": "DISCS",


		"pay": 1800.0,
		"reward_tech": "smart_splitter",
	},
	{
		"id": "pulp_20",
		"title": "Twenty pulp slabs",
		"detail": "Load twenty pulp slabs onto the truck. You need a borehole pump, a water pipe and a pulper.",
		"want": "hay_pulp",
		"count": 20,
		"unit": "SLABS",
		"pay": 800.0,


		"reward_tech": "paper_machine",
	},
	{
		"id": "paper_10",
		"title": "Ten paper rolls",
		"detail": "Load ten paper rolls onto the truck. Make them with a paper mill.",
		"want": "paper_roll",
		"count": 10,
		"unit": "ROLLS",
		"pay": 2500.0,


		"reward_tech": "underground_power",
	},
]


static func count() -> int:
	return CONTRACTS.size()


static func contract(index: int) -> Dictionary:
	if index < 0 or index >= CONTRACTS.size():
		return { }
	return CONTRACTS [index]


static func id_at(index: int) -> String:
	return str(contract(index).get("id", ""))


static func title_of(index: int) -> String:
	var raw:= str(contract(index).get("title", ""))
	return Cfg.tr(raw) if raw != "" else ""


static func title_quiet_of(index: int) -> String:
	match id_at(index):
		"bales_20":
			return Cfg.tr("twenty bales")
		"foiled_18":
			return Cfg.tr("eighteen wrapped")
		"bricks_30":
			return Cfg.tr("thirty eco bricks")
		"bricks_50":
			return Cfg.tr("fifty bricks")
		"discs_12":
			return Cfg.tr("twelve feed discs")
		"pulp_20":
			return Cfg.tr("twenty pulp slabs")
		"paper_10":
			return Cfg.tr("ten paper rolls")
	return title_of(index)


static func detail_of(index: int) -> String:
	var raw:= str(contract(index).get("detail", ""))
	return Cfg.tr(raw) if raw != "" else ""


static func count_text(index: int, have: int, need: int) -> String:
	match id_at(index):
		"bales_20":
			return Cfg.tr_n("%d / %d BALE", "%d / %d BALES", need) % [have, need]
		"foiled_18":
			return Cfg.tr_n("%d / %d WRAPPED", "%d / %d WRAPPED", need) % [have, need]
		"bricks_30", "bricks_50":
			return Cfg.tr_n("%d / %d BRICK", "%d / %d BRICKS", need) % [have, need]
		"discs_12":
			return Cfg.tr_n("%d / %d DISC", "%d / %d DISCS", need) % [have, need]
		"pulp_20":
			return Cfg.tr_n("%d / %d SLAB", "%d / %d SLABS", need) % [have, need]
		"paper_10":
			return Cfg.tr_n("%d / %d ROLL", "%d / %d ROLLS", need) % [have, need]
	return "%d / %d" % [have, need]


static func index_of(id: String) -> int:
	for i in CONTRACTS.size():
		if CONTRACTS [i] ["id"] == id:
			return i
	return -1


static func needed(index: int) -> int:
	return int(contract(index).get("count", 0))


static func accepts(index: int, item_id: String) -> bool:
	var c:= contract(index)
	if c.is_empty():
		return false
	return item_id == str(c.get("want", "")) or item_id == str(c.get("also", ""))


static func reward_tech(index: int) -> String:
	return str(contract(index).get("reward_tech", ""))


static func gate_for(tech_id: String) -> int:
	if tech_id.is_empty():
		return -1
	for i in CONTRACTS.size():
		if str(CONTRACTS [i].get("reward_tech", "")) == tech_id:
			return i
	return -1


static func wanted_now(item_id: String) -> bool:
	return accepts(GameState.contract_index, item_id)


static func first_open(signed: Dictionary) -> int:
	for i in CONTRACTS.size():
		if not signed.has(str(CONTRACTS [i] ["id"])):
			return i
	return CONTRACTS.size()
