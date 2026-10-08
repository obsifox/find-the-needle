class_name YardSale
extends RefCounted


static func _going(builds: BuildManager) -> Dictionary:
	var out: Dictionary = { }
	if builds == null:
		return out
	var yard:= builds.all_buildings()
	var added:= true
	while added:
		added = false
		for building: Node3D in yard:
			var id:= building.get_instance_id()
			if out.has(id):
				continue
			if not _clear_once(builds, building, out):
				continue
			out [id] = true
			added = true
	return out


static func _clear_once(builds: BuildManager, building: Node3D,
		going: Dictionary) -> bool:
	if builds.demolish_blocked_reason(building) == "":
		return true
	var deck:= building as Platform
	if deck == null:
		return false


	for load_on_it: Node3D in builds.standing_on(deck):
		if not going.has(load_on_it.get_instance_id()):
			return false
	return true


static func tally(builds: BuildManager, props: PropManager) -> Dictionary:
	var out:= {
		"machines": 0, "machines_value": 0.0,
		"structures": 0, "structures_value": 0.0,
		"tools": 0, "tools_value": 0.0,
		"total": 0.0, "kept": PackedStringArray(),
	}
	var going:= _going(builds)
	if builds != null:
		for building: Node3D in builds.all_buildings():
			if not going.has(building.get_instance_id()):
				continue
			var value:= builds.value_of(building)
			if _is_structure(building):
				out.structures += 1
				out.structures_value += value
			else:
				out.machines += 1
				out.machines_value += value
	if props != null:
		for item: Carryable in props.items:
			if not _buys(item):
				continue
			out.tools += 1
			out.tools_value += ItemDb.price(item.item_id)
	out.total = out.machines_value + out.structures_value + out.tools_value


	out.kept = _kept_lines(builds, props, going)
	return out


static func sell(builds: BuildManager, props: PropManager) -> Dictionary:
	var out:= {
		"machines": 0, "machines_value": 0.0,
		"structures": 0, "structures_value": 0.0,
		"tools": 0, "tools_value": 0.0,
		"paid": 0.0, "total": 0.0, "kept": PackedStringArray(),
	}
	if props != null:


		for item: Carryable in props.items.duplicate():
			if not _buys(item):
				continue
			out.tools += 1
			out.tools_value += ItemDb.price(item.item_id)


			BeltPath.release(item)
			props.remove(item)
	if builds != null:


		builds.begin_sweep()


		var guard:= builds.all_buildings().size() + 1
		while guard > 0:
			guard -= 1
			var went:= 0
			for building: Node3D in builds.all_buildings():
				if not is_instance_valid(building):
					continue
				if builds.demolish_blocked_reason(building) != "":
					continue


				var structural:= _is_structure(building)
				var refund:= builds.demolish(building)
				went += 1
				if structural:
					out.structures += 1
					out.structures_value += refund
				else:
					out.machines += 1
					out.machines_value += refund
			if went == 0:
				break
		builds.end_sweep()
	out.total = out.machines_value + out.structures_value + out.tools_value
	out.paid = out.total
	out.kept = kept_lines(builds, props)
	return out


static func kept_lines(builds: BuildManager, props: PropManager) -> PackedStringArray:
	return _kept_lines(builds, props, _going(builds))


static func _kept_lines(builds: BuildManager, props: PropManager,
		going: Dictionary) -> PackedStringArray:
	var out:= PackedStringArray()
	var scanners:= 0
	var decks:= 0
	var others:= 0
	if builds != null:


		for building: Node3D in builds.all_buildings():
			if going.has(building.get_instance_id()):
				continue
			if building is HaystackScanner:
				scanners += 1
			elif building is Platform:
				decks += 1
			else:
				others += 1


	if scanners > 0:
		out.append(Cfg.tr_n(
			"a scanner with needles still in the drawer. Collect them at the console first",
			"{n} scanners with needles still in the drawer. Collect them at the console first",
			scanners).format({ "n": scanners }))
	if decks > 0:
		out.append(Cfg.tr_n(
			"a deck with something standing on it that the sale does not buy",
			"{n} decks with something standing on them that the sale does not buy",
			decks).format({ "n": decks }))
	if others > 0:
		out.append(Cfg.tr_n("a building that cannot come down yet",
			"{n} buildings that cannot come down yet",
			others).format({ "n": others }))


	var full: Dictionary = { }
	if props != null:
		for item: Carryable in props.items:
			if item.is_held() or ItemDb.price(item.item_id) <= 0.0:
				continue
			if item.hay_strands() <= 0:
				continue


			var what:= Cfg.lower_in_english(ItemDb.display_name(item.item_id))
			full [what] = int(full.get(what, 0)) + 1
	for what: String in full:
		var n: int = full [what]


		var line:= ""
		if what.begins_with("a"):
			line = Cfg.tr_n("an {item} with hay in it. Tip it out first",
				"{n} {item}s with hay in them. Tip them out first", n)
		else:
			line = Cfg.tr_n("a {item} with hay in it. Tip it out first",
				"{n} {item}s with hay in them. Tip them out first", n)
		out.append(line.format({ "n": n, "item": what }))
	return out


static func _buys(item: Carryable) -> bool:
	if item == null or not is_instance_valid(item):
		return false
	if item.is_held():
		return false
	if ItemDb.price(item.item_id) <= 0.0:
		return false
	return item.hay_strands() <= 0


static func _is_structure(building: Node3D) -> bool:
	return building is Platform or building is Stair or building is Railing or building is YardWall or building is Roof or building is HayStairs
