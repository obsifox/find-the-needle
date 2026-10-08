class_name DevDeliveryProbe
extends Node


var world: Node3D
var player: Player


const ARRIVE_FRAMES:= 1800
const DEPART_FRAMES:= 1800
const SETTLE_FRAMES:= 12


const MADE_BY:= {
	"hay_bale": "compressor",
	"foiled_bale": "wrapper",
	"eco_brick": "pelletizer",
	"hay_pulp": "pulper",
	"paper_roll": "paper_machine",
	"feed_disc": "briquette_press",
}

var _pass:= 0
var _fail:= 0


func run() -> void:
	_go()


func _go() -> void:
	await _frames(20)
	var truck: DeliveryTruck = world.truck
	var board: DeliveryBoard = world.delivery_board
	var panel: ContractPanel = world.contracts
	var director: DeliveryDirector = world.deliveries
	var props: PropManager = world.props

	print("\n=== the book ===")
	_check("there are contracts to fill (%d)" % DeliveryBook.count(),
		DeliveryBook.count() >= 3)
	_check("a fresh yard opens on the first one (%d)" % GameState.contract_index,
		GameState.contract_index == 0)
	_check("...with nothing delivered against it (%d)" % GameState.contract_delivered,
		GameState.contract_delivered == 0)
	var want:= str(DeliveryBook.contract(0).get("want", ""))
	_check("...for a thing the item table actually names (%s)" % want,
		ItemDb.has_item(want))
	_check("a bale counts toward it", DeliveryBook.accepts(0, "hay_bale"))
	_check("...and so does the wrapped version", DeliveryBook.accepts(0, "foiled_bale"))
	_check("...but a bucket does not", not DeliveryBook.accepts(0, "bucket"))

	print("\n=== the book holds together ===")


	var seen: Dictionary = { }
	for i in DeliveryBook.count():
		var id:= DeliveryBook.id_at(i)
		_check("order %d has an id nobody else has (%s)" % [i + 1, id],
			not id.is_empty() and not seen.has(id))
		seen [id] = true
		var w:= str(DeliveryBook.contract(i).get("want", ""))
		_check("...wants a thing the item table names (%s)" % w, ItemDb.has_item(w))
		_check("...that the bed knows how to draw", DeliveryTruck.can_draw(w))
		_check("...and can draw (%s)" % w, DeliveryTruck.load_mesh(w) != null)
		_check("...with a picture to pin beside its count (%s)" % w,
			TechPanel.icon_for(w) != null)
		_check("...in a count somebody can stack (%d)" % DeliveryBook.needed(i),
			DeliveryBook.needed(i) > 0)
		var reward:= DeliveryBook.reward_tech(i)
		_check("...releasing a real card or none (%s)" % reward,
			reward.is_empty() or TechTree.has_id(reward))
		if not reward.is_empty():
			_check("...that is not free already (%s)" % reward, not Tech.is_unlocked(reward))
		var also:= str(DeliveryBook.contract(i).get("also", ""))
		if not also.is_empty():
			_check("...and its better version is in the item table (%s)" % also,
				ItemDb.has_item(also))
		var maker: String = str(MADE_BY.get(w, ""))
		_check("...by a machine this probe knows the maker of (%s)" % maker,
			not maker.is_empty())
		var chain: Array = _ancestry(maker)
		var blocked:= ""
		for need: String in chain:
			var g:= DeliveryBook.gate_for(need)
			if g >= i:
				blocked = "%s behind order %d" % [need, g + 1]
		_check("...whose whole chain is buyable before it opens%s"
			% ("" if blocked.is_empty() else " (" + blocked + ")"), blocked.is_empty())
	_check("an empty signed set opens the first order", DeliveryBook.first_open({ }) == 0)
	_check("...the first signed opens the second",
		DeliveryBook.first_open({ DeliveryBook.id_at(0): true }) == 1)
	var all: Dictionary = { }
	for i in DeliveryBook.count():
		all [DeliveryBook.id_at(i)] = true
	_check("...and a full set opens nothing (%d)" % DeliveryBook.first_open(all),
		DeliveryBook.first_open(all) == DeliveryBook.count())

	print("\n=== stock by the bay is the truck's ===")


	var at_bay:= truck.bay_point() + Vector3(0.6, 0.5, 0.0)
	var stock:= props.spawn(want, Transform3D(Basis(), at_bay))
	_check("a wanted item by the bay is order stock", props.is_order_stock(stock))
	_check("...so the yard cap drain leaves it", props.is_spoken_for(stock))
	var far:= props.spawn(want, Transform3D(Basis(),
		truck.bay_point() + Vector3(Cfg.DELIVERY_STOCK_R + 4.0, 0.5, 0.0)))
	_check("...but the same thing across the yard is not", not props.is_order_stock(far))
	var pail:= props.spawn("bucket", Transform3D(Basis(), at_bay + Vector3(0.0, 0.0, 0.6)))
	_check("...and a bucket by the bay is not", not props.is_order_stock(pail))
	for p in [stock, far, pail]:
		if p != null:
			props.remove(p)
	await _frames(2)

	print("\n=== the lock, before ===")
	var gated:= DeliveryBook.reward_tech(0)
	_check("the reward node exists (%s)" % gated, TechTree.has_id(gated))


	GameState.money = 100000.0
	for need: String in TechTree.requires(gated):
		Tech.grant(need)
	_check("...with its ordinary requirements met", Tech.requires_met(gated))
	var before:= Tech.can_buy(gated)
	_check("...and is refused with the money in hand", not before ["ok"])
	_check("...for the delivery rather than for the price (%s)" % before ["reason"],
		str(before ["reason"]).find("delivery") >= 0)
	_check("...at its own price, unchanged (%.2f)" % float(before ["cost"]),
		float(before ["cost"]) > 0.0)

	print("\n=== the truck is not called for an empty yard ===")
	await _frames(40)
	_check("no bale in the yard, no truck", truck.is_away())

	print("\n=== a bale pushed onto a belt counts as made ===")


	_check("an empty yard with nothing pushed has no bale", not director._yard_has(0))
	BeltPath.pushed_kinds = 1 << BeltRun.Kind.BALE
	_check("...and a bale pushed onto a belt is one", director._yard_has(0))
	BeltPath.pushed_kinds = 1 << BeltRun.Kind.FOILED_BALE
	_check("...as is the order's other kind, a foiled bale", director._yard_has(0))
	BeltPath.pushed_kinds = 1 << BeltRun.Kind.WAD
	_check("...but a wad is not", not director._yard_has(0))


	for i in DeliveryBook.count():
		var wants:= str(DeliveryBook.contract(i).get("want", ""))
		var kind:= BeltRun.ITEM_IDS.find(wants)
		_check("order %d's %s has a belt kind" % [i, wants], kind >= 0)
		BeltPath.pushed_kinds = (1 << kind) if kind >= 0 else 0
		_check("...and pushing one onto a belt calls its truck", director._yard_has(i))
	BeltPath.pushed_kinds = 0

	print("\n=== it comes a while after the first bale does ===")


	director.call_wait = 2.0


	var seed_bale:= props.spawn("hay_bale", Transform3D(Basis(),
		world.bay_door.to_global(Vector3(-8.0, 0.6, 3.0))))
	_check("a bale was spawned to call it", seed_bale != null)
	await _frames(30)
	_check("...and the truck is still away half a second later", truck.is_away())
	var waiting:= director.state_line(0)


	var calling_head:= tr("TRUCK ON ITS WAY: %s").get_slice("%s", 0)
	_check("...with the docket counting it in (%s)" % waiting,
		truck.is_away() and waiting.begins_with(calling_head)
			and waiting.length() > calling_head.length())
	var voices_away:= Audio.loops_available()


	var heard:= await _until(
		func() -> bool: return Audio.loops_available() < voices_away, ARRIVE_FRAMES)
	_check("the engine runs while it drives in", heard)
	var came:= await _until(func() -> bool: return truck.is_parked(), ARRIVE_FRAMES)
	_check("the truck arrives and parks", came)
	_check("...and the engine stops with it (%d voices free, was %d)"
		% [Audio.loops_available(), voices_away],
		Audio.loops_available() == voices_away)
	if not came:
		_finish()
		return

	print("\n=== where it parked ===")
	var door: BayDoor = world.bay_door
	var park:= door.inboard_point(DeliveryTruck.PARK_IN)
	_check("...on the doorway's own centre line (%.3f m off)"
		% Vector2(truck.global_position.x - park.x, truck.global_position.z - park.z).length(),
		Vector2(truck.global_position.x - park.x,
			truck.global_position.z - park.z).length() < 0.3)
	_check("...outside the shed, on the apron (%.2f m out)"
		% - door.to_local(truck.global_position).z,
		door.to_local(truck.global_position).z < 0.0)


	var tail_at:= door.to_local(truck.to_global(Vector3(0.0, 0.0, 2.017))).z
	_check("...with its tail on the doorway itself (%.2f m off the wall plane)"
		% tail_at, absf(tail_at) < 0.6)


	var nose:= truck.to_global(Vector3(0.0, 0.0, -3.0))
	var tail:= truck.to_global(Vector3(0.0, 0.0, 2.0))
	_check("...tail first, so the gate faces the yard (%.2f vs %.2f)"
		% [door.to_local(tail).z, door.to_local(nose).z],
		door.to_local(tail).z > door.to_local(nose).z)


	_check("the bay door is standing open (%.0f%%)" % (door.open_amount() * 100.0),
		not door.is_shut())
	_check("...and the truck is solid now it has stopped", _hull_live(truck))

	print("\n=== the doorway is clear to load from ===")


	var pile: HayField = world.field
	_check("the yard has a pile to measure against", pile != null)
	if pile != null:
		var deepest:= 0.0
		var worst:= Vector3.ZERO
		for n in 10:
			var spot:= door.inboard_point(float(n) * 0.35)
			var deep:= pile.height_at(spot.x, spot.z)
			if deep > deepest:
				deepest = deep
				worst = spot
		_check("the floor inside the doorway is walkable (%.2f m of hay at %.1f, %.1f)"
			% [deepest, worst.x, worst.z], deepest < 0.4)
		_check("...and so is the spot the bales go (%.2f m of hay)"
			% pile.height_at(truck.loading_point().x, truck.loading_point().z),
			pile.height_at(truck.loading_point().x, truck.loading_point().z) < 0.4)
		_check("...which is inside the shed, not out on the apron",
			door.to_local(truck.loading_point()).z > 0.0)

	print("\n=== the gate and the load ===")


	var gate:= truck.find_child("Marker_Gate", true, false) as Node3D
	_check("the model has a tailgate hinge", gate != null)
	if gate != null:


		var timed:= gate.rotation.x
		truck.snap_parked()
		await _frames(4)
		var ended:= gate.rotation.x
		_check("...opened at all (%.0f degrees)" % rad_to_deg(ended),
			absf(rad_to_deg(ended)) > 60.0)
		_check("...and was fully down before the bed went live (%.1f vs %.1f degrees)"
			% [rad_to_deg(timed), rad_to_deg(ended)],
			absf(timed - ended) < deg_to_rad(1.0))


		var leaf:= gate.find_children("*", "MeshInstance3D", true, false)
		if not leaf.is_empty():
			var mi:= leaf [0] as MeshInstance3D
			var box:= truck.global_transform.affine_inverse() * mi.global_transform * mi.mesh.get_aabb()
			_check("...lying flat rather than standing up (%.2f long, %.2f tall)"
				% [box.size.z, box.size.y], box.size.z > box.size.y)

	for kind in ["hay_bale", "foiled_bale", "eco_brick"]:
		var mesh:= DeliveryTruck.load_mesh(kind)
		_check("%s has a mesh to draw the load with" % kind, mesh != null)
		if mesh == null:
			continue


		var box:= mesh.get_aabb()
		_check("...solid rather than a plate (%.2f x %.2f x %.2f)"
			% [box.size.x, box.size.y, box.size.z],
			box.size [box.size.min_axis_index()] > 0.05
			and box.size [box.size.max_axis_index()] < 1.2)

	var load_node:= truck.get_node_or_null("Load") as Node3D
	_check("the truck has somewhere to draw a load", load_node != null)
	if load_node != null:
		var was:= load_node.get_child_count()
		truck.stack_one("hay_bale")
		truck.stack_one("foiled_bale")
		_check("...and stacking adds to it (%d to %d)"
			% [was, load_node.get_child_count()],
			load_node.get_child_count() == was + 2)
		var drawn:= 0
		for c in load_node.get_children():
			var mi:= c as MeshInstance3D
			if mi != null and mi.mesh != null:
				drawn += 1

				var at:= mi.position
				_check("...bale %d sits in the bed (%.2f, %.2f, %.2f)"
					% [drawn, at.x, at.y, at.z],
					absf(at.x) < 1.3 and at.y > -0.6 and at.y < 0.8)


		for c in load_node.get_children():
			var sunk:= c as MeshInstance3D
			if sunk == null or sunk.mesh == null:
				continue
			var bottom:= sunk.position.y + sunk.mesh.get_aabb().position.y
			_check("...and standing ON the deck, not in it (%.0f mm above %.2f)"
				% [(bottom - truck.deck_height()) * 1000.0, truck.deck_height()],
				bottom >= truck.deck_height() - 0.02)
		_check("...with every one of them carrying a mesh (%d of %d)"
			% [drawn, load_node.get_child_count()],
			drawn == load_node.get_child_count())
		for c in load_node.get_children():
			load_node.remove_child(c)
			c.queue_free()

	print("\n=== what the bed takes ===")
	if seed_bale != null and is_instance_valid(seed_bale):
		props.remove(seed_bale)
	var bucket:= _put_in_bed(props, truck, "bucket")
	await _frames(SETTLE_FRAMES)
	await _frames(30)
	_check("a bucket set down in the bed is left alone",
		bucket != null and is_instance_valid(bucket))
	_check("...and is not counted (%d)" % GameState.contract_delivered,
		GameState.contract_delivered == 0)
	if bucket != null and is_instance_valid(bucket):
		props.remove(bucket)


	var held:= _put_in_bed(props, truck, "hay_bale")
	if held != null:
		held.pick_up()
		held.carrier = player
	await _frames(30)
	_check("a bale still in the player's hands is not counted (%d)"
		% GameState.contract_delivered, GameState.contract_delivered == 0)
	if held != null and is_instance_valid(held):
		held.release(Vector3.ZERO)
		props.remove(held)
	await _frames(10)

	print("\n=== filling the order ===")
	var need:= DeliveryBook.needed(0)
	var made:= 0
	var guard:= 0
	while GameState.contract_delivered < need and guard < 4000:
		guard += 1
		if made < need and props.count_of("hay_bale") < 4:
			if _put_in_bed(props, truck, "hay_bale") != null:
				made += 1
		if GameState.contract_index != 0:
			break
		await _frames(4)
	_check("every bale put in was counted (%d made, %d counted)"
		% [made, need if GameState.contract_index > 0 else GameState.contract_delivered],
		made >= need)
	var closed:= await _until(func() -> bool: return GameState.contract_index == 1,
		600)
	_check("the order closes at its number", closed)
	_check("...and the count resets for the next one (%d)"
		% GameState.contract_delivered, GameState.contract_delivered == 0)
	_check("...and it is written down by id, not by index",
		GameState.contract_signed(DeliveryBook.id_at(0)))

	print("\n=== the lock, after ===")
	var after:= Tech.can_buy(gated)
	_check("the card is offered now (%s)" % after ["reason"], after ["ok"])
	_check("...at the price it always cost (%.2f then, %.2f now)"
		% [float(before ["cost"]), float(after ["cost"])],
		is_equal_approx(float(before ["cost"]), float(after ["cost"])))
	_check("...and was not quietly handed over", not Tech.is_unlocked(gated))
	_check("buying it still costs the money", Tech.buy(gated) and Tech.is_unlocked(gated))

	print("\n=== the truck leaves ===")
	var voices_parked:= Audio.loops_available()
	var gone:= await _until(func() -> bool: return truck.is_away(), DEPART_FRAMES)
	_check("it pulls out once the order is signed off", gone)
	if gone:
		_check("...and gave the engine voice back on the way out (%d free, was %d)"
			% [Audio.loops_available(), voices_parked],
			Audio.loops_available() == voices_parked)
		_check("...clear off the doorway (%.1f m out)"
			% - door.to_local(truck.global_position).z,
			door.to_local(truck.global_position).z
				< - DeliveryTruck.STAGE_OUT + 1.0)

		_check("...leaving the door open behind it (%.0f%%)" % (door.open_amount() * 100.0),
			not door.is_shut())
		_check("...and handed back to the player", not door.held)
		_check("...and nothing of the old load left in the bed",
			truck.settled_items().is_empty())
		_check("...and it is not solid out there", not _hull_live(truck))

	print("\n=== what is still in the bed comes down with the hull ===")


	truck.snap_parked()
	await _frames(2)
	var deck:= truck.get_node_or_null("Hull/Bed_Floor") as CollisionShape3D
	_check("the truck has a deck to leave something on", deck != null)
	if deck != null:
		var on_deck:= truck.to_global(deck.position + Vector3(0.0, 0.4, 0.0))
		var stray:= props.spawn("bucket", Transform3D(Basis(), on_deck))
		var asleep:= await _until(func() -> bool:
			return stray != null and is_instance_valid(stray) and stray.sleeping, 600)
		_check("...and a bucket left on it settles there and sleeps", asleep)
		if asleep:
			var was_y:= stray.global_position.y
			truck.depart()
			await _frames(2)
			_check("...pulling out wakes it", not stray.sleeping)
			var fell:= await _until(func() -> bool:
				return stray.global_position.y < was_y - 0.3, 600)
			_check("...so it falls rather than hanging (%.2f m to %.2f m)"
				% [was_y, stray.global_position.y], fell)
		if stray != null and is_instance_valid(stray):
			props.remove(stray)
		await _until(func() -> bool: return truck.is_away(), DEPART_FRAMES)

	print("\n=== the board and the card ===")
	var docket:= board.get_node_or_null("Docket") as Node3D
	_check("the board has a live docket on it", docket != null)
	if docket != null:
		_check("...which is up while an order is open", docket.visible)
		var head:= docket.get_node_or_null("Title") as Label3D
		var tally:= docket.get_node_or_null("Count") as Label3D


		_check("...printed with the order's own title (%s)"
			% (head.text if head != null else "none"),
			head != null and head.text == DeliveryBook.title_of(1))
		_check("...and a count of the right shape (%s)"
			% (tally.text if tally != null else "none"),
			tally != null and tally.text == "0 / %d" % DeliveryBook.needed(1))


		var out:= board.to_local(docket.global_position)
		var cork:= DeliveryBoard.board_to_local(Vector3(
			DeliveryBoard.SHEET_AT.x, DeliveryBoard.CORK_Y, DeliveryBoard.SHEET_AT.y))
		var proud:= (out - cork).dot(DeliveryBoard.face_normal())
		_check("...standing proud of the cork it is pinned to (%.1f mm)" % (proud * 1000.0),
			proud > 0.001 and proud < 0.01)


		_check("...on the board rather than beside it (%.2f, %.2f, %.2f)"
			% [out.x, out.y, out.z],
			absf(out.x) < 0.9 and out.y > 0.8 and out.y < 2.0
			and out.z > -0.5 and out.z < 0.1)
	_check("the board stands inside the shed",
		door.to_local(board.global_position).z > 0.0)
	_check("...and clear of where the truck parks (%.2f m)"
		% board.global_position.distance_to(door.inboard_point(DeliveryTruck.PARK_IN)),
		board.global_position.distance_to(
			door.inboard_point(DeliveryTruck.PARK_IN)) > 3.0)


	_check("the contract card stays off while nobody has pinned it",
		not GameState.contract_pinned and not panel.visible)
	GameState.contract_pinned = true
	GameState.contract_pin_changed.emit(true)
	await _frames(2)
	_check("...and comes up the moment it is pinned", panel.visible)
	var under: PanelContainer = null
	for c in panel.get_children():
		under = c as PanelContainer
		if under != null:
			break
	_check("...as a plate of its own", under != null)
	if under != null:


		_check("...hung off the right hand corner (x %.0f, y %.0f)"
			% [under.position.x, under.position.y],
			under.position.x < 0.0 and under.position.y > 0.0)
	GameState.contract_pinned = false
	GameState.contract_pin_changed.emit(false)
	await _frames(2)
	_check("...and goes again when it is taken down", not panel.visible)

	print("\n=== the next order is posted ===")
	await _frames(30)
	_check("the board is showing something again", board != null)
	_check("the card is showing the second order (%d of %d)"
		% [GameState.contract_index + 1, DeliveryBook.count()],
		panel != null and GameState.contract_index == 1)
	_check("...whose reward is a different node (%s)"
		% DeliveryBook.reward_tech(1),
		DeliveryBook.reward_tech(1) != gated)
	_check("...and which is not yet signed",
		not GameState.contract_signed(DeliveryBook.id_at(1)))
	var p:= director.progress()
	_check("...with a fresh bar under it (%d of %d)"
		% [int(p.get("have", -1)), int(p.get("need", -1))],
		int(p.get("have", -1)) == 0 and int(p.get("need", 0)) > 0)

	print("\n=== the save carries it ===")
	var d:= GameState.to_dict()
	_check("the open order is in the save (%d)" % int(d.get("contract_index", -1)),
		int(d.get("contract_index", -1)) == 1)
	_check("...and so is what has been signed",
		DeliveryBook.id_at(0) in Array(d.get("contracts_done", [])))
	GameState.contract_index = 0
	GameState.contracts_done = { }
	GameState.from_dict(d)
	_check("...and both come back off it",
		GameState.contract_index == 1
		and GameState.contract_signed(DeliveryBook.id_at(0)))

	print("\n=== the docket fits its sheet ===")
	if docket != null:


		var half:= DeliveryBoard.SHEET_HALF
		var spans: Array = []
		for line_name in ["Title", "State", "Count", "Body", "Reward"]:
			var l:= docket.get_node_or_null(line_name) as Label3D
			if l == null:
				continue
			var box:= l.get_aabb()
			var lo:= l.position.y + box.position.y
			var hi:= lo + box.size.y
			var wide:= box.size.x
			_check("%s fits across the sheet (%.0f mm of %.0f)"
				% [line_name, wide * 1000.0, half.x * 2000.0], wide <= half.x * 2.0)
			_check("...and inside its top and bottom edges (%.0f mm to %.0f mm)"
				% [lo * 1000.0, hi * 1000.0],
				lo >= - half.y and hi <= half.y)
			spans.append([line_name, lo, hi])
		for n in range(1, spans.size()):
			var above: Array = spans [n - 1]
			var below: Array = spans [n]
			_check("%s does not print over %s (%.0f mm apart)"
				% [below [0], above [0], (float(above [1]) - float(below [2])) * 1000.0],
				float(below [2]) <= float(above [1]))


	print("\n=== and so does every other order in the book ===")
	if docket != null:
		var sheet:= DeliveryBoard.SHEET_HALF
		for i in DeliveryBook.count():
			board.show_contract(i, 0, DeliveryBook.needed(i), director.state_line(i))
			await _frames(2)
			for line_name in ["Title", "Body"]:
				var l:= docket.get_node_or_null(line_name) as Label3D
				if l == null:
					continue
				var box:= l.get_aabb()
				_check("order %d's %s fits across the sheet (%.0f mm of %.0f)"
					% [i + 1, line_name, box.size.x * 1000.0, sheet.x * 2000.0],
					box.size.x <= sheet.x * 2.0)


		var open_at:= GameState.contract_index
		board.show_contract(open_at, GameState.contract_delivered,
			DeliveryBook.needed(open_at), director.state_line(open_at))
		await _frames(2)

	print("\n=== the tally strip fits its card ===")
	var tally:= board.get_node_or_null("Tally/Spin/TallyLine") as Label3D
	if tally != null:
		var strip:= DeliveryBoard.TALLY_HALF


		_check("the card clears the docket below it (%.0f mm)"
			% (((DeliveryBoard.TALLY_AT.y - strip.y)
				- (DeliveryBoard.SHEET_AT.y + DeliveryBoard.SHEET_HALF.y)) * 1000.0),
			DeliveryBoard.TALLY_AT.y - strip.y
				>= DeliveryBoard.SHEET_AT.y + DeliveryBoard.SHEET_HALF.y)


		_check("...and the plank above it (%.0f mm)"
			% ((DeliveryBoard.HEADER_BOTTOM
				- (DeliveryBoard.TALLY_AT.y + strip.y)) * 1000.0),
			DeliveryBoard.TALLY_AT.y + strip.y <= DeliveryBoard.HEADER_BOTTOM)


		var was_mode: int = Cfg.hay_readout


		var tally_head:= tr("HAY LEFT   %s").get_slice("%s", 0)
		for mode: int in [Cfg.HayReadout.PERCENT, Cfg.HayReadout.AMOUNT]:
			Cfg.hay_readout = mode
			await _frames(30)
			var box:= tally.get_aabb()
			_check("as %s it reads '%s'"
				% [Cfg.HAY_READOUT_NAMES [mode], tally.text],
				tally.text.begins_with(tally_head))
			_check("...and fits across the card (%.0f mm of %.0f)"
				% [box.size.x * 1000.0, strip.x * 2000.0],
				box.size.x <= strip.x * 2.0)
			_check("...and inside its top and bottom edges (%.0f mm of %.0f)"
				% [box.size.y * 1000.0, strip.y * 2000.0],
				box.size.y <= strip.y * 2.0)
		Cfg.hay_readout = was_mode

	print("\n=== extending the shed moves both of them ===")
	var board_was:= board.global_position
	var wall_was: float = world.warehouse.inner
	Tech.grant("yard_space")
	await _frames(6)
	_check("the shed grew (%.1f m to %.1f m)" % [wall_was, world.warehouse.inner],
		world.warehouse.inner > wall_was)
	_check("...the door went with it",
		absf(door.global_position.x) > wall_was - 0.01)


	_check("...and so did the board (%.2f m)"
		% board.global_position.distance_to(board_was),
		board.global_position.distance_to(board_was) > 0.5)
	_check("...to the same spot beside the doorway (%.3f m off)"
		% board.global_position.distance_to(
			door.to_global(Vector3(DeliveryBoard.SEAT_ACROSS, 0.0, DeliveryBoard.SEAT_IN))),
		board.global_position.distance_to(door.to_global(Vector3(
			DeliveryBoard.SEAT_ACROSS, 0.0, DeliveryBoard.SEAT_IN))) < 0.1)


	var staged:= truck.away_point()
	var drift:= Vector2(truck.global_position.x - staged.x,
		truck.global_position.z - staged.z).length()
	_check("...and the truck is still staged on the new door's line (%.3f m off, %.2f m up)"
		% [drift, truck.global_position.y - staged.y], drift < 0.05)

	print("\n=== the book runs out ===")


	for i in DeliveryBook.count():
		GameState.sign_contract(DeliveryBook.id_at(i))
	GameState.contract_index = DeliveryBook.count()
	GameState.contract_delivered = 0
	GameState.contract_pinned = false
	GameState.contract_pin_changed.emit(false)
	await _frames(30)
	_check("the open order is off the end of the book (%d of %d)"
		% [GameState.contract_index, DeliveryBook.count()],
		DeliveryBook.contract(GameState.contract_index).is_empty())
	_check("...and the docket is still on the cork", board.docket_visible())


	var out:= (board.global_transform.basis * DeliveryBoard.face_normal()).normalized()
	var eye:= board.docket_point() + out * 1.2
	board.take_press(eye, - out)
	_check("...and still answers E", GameState.contract_pinned)
	await _frames(2)
	_check("...with a card in the corner that says why", panel.visible)
	GameState.contract_pinned = false
	GameState.contract_pin_changed.emit(false)
	await _frames(2)
	_check("...which comes down again like any other", not panel.visible)


	if docket != null:
		var edge:= DeliveryBoard.SHEET_HALF
		for line_name in ["Title", "State", "Count", "Body"]:
			var l:= docket.get_node_or_null(line_name) as Label3D
			if l == null:
				continue
			var box:= l.get_aabb()
			_check("%s fits the finished sheet (%.0f mm of %.0f)"
				% [line_name, box.size.x * 1000.0, edge.x * 2000.0],
				box.size.x <= edge.x * 2.0)
			_check("...and inside its edges (%.0f mm to %.0f mm)"
				% [(l.position.y + box.position.y) * 1000.0,
					(l.position.y + box.position.y + box.size.y) * 1000.0],
				l.position.y + box.position.y >= - edge.y
				and l.position.y + box.position.y + box.size.y <= edge.y)

	_finish()


func _put_in_bed(props: PropManager, truck: DeliveryTruck, id: String) -> Carryable:
	var at:= truck.loading_point() + Vector3(0.0, 0.45, 0.0)
	return props.spawn(id, Transform3D(Basis(), at))


func _hull_live(truck: DeliveryTruck) -> bool:
	var hull:= truck.get_node_or_null("Hull") as StaticBody3D
	return hull != null and hull.collision_layer != 0


func _ancestry(id: String) -> Array:
	var out: Array = []
	var todo: Array = [id]
	while not todo.is_empty():
		var cur: String = todo.pop_back()
		if cur.is_empty() or cur == TechTree.ROOT or cur in out or not TechTree.has_id(cur):
			continue
		out.append(cur)
		for need: String in TechTree.requires(cur):
			todo.append(need)
	return out


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _until(test: Callable, limit: int) -> bool:
	for _i in limit:
		if bool(test.call()):
			return true
		await get_tree().physics_frame
	return bool(test.call())


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		print("DELIVERY PROBE FAILED")
	get_tree().quit(1 if _fail > 0 else 0)
