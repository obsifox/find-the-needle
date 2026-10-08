class_name BuildManager
extends Node3D


signal changed()


signal cabinet_added(cab: NeedleCabinet)


signal t_switched(t: Node3D, joining: bool)


const RAILING_PROBE_DROP:= 0.18


const GRID_SETTLE:= 2


static var legacy_arm_aim:= "--oldaim" in OS.get_cmdline_user_args()

var conveyors: Array [Conveyor] = []

var corners: Array [ConveyorCorner] = []
var _enclosed_visuals: Node3D = null
var _enclosed_kit: EnclosedConveyorKit = null


var _enclosed_built:= PackedVector3Array()


var _enclosed_on_show:= { }
var robotic_arms: Array [RoboticArm] = []
var platforms: Array [Platform] = []
var stairs: Array [Stair] = []
var railings: Array [Railing] = []
var walls: Array [YardWall] = []
var roofs: Array [Roof] = []
var scanners: Array [HaystackScanner] = []
var compressors: Array [HayCompressor] = []
var wrappers: Array [HayWrapper] = []
var silos: Array [HaySilo] = []
var pelletizers: Array [HayPelletizer] = []


var pulpers: Array [HayPulper] = []


var papers: Array [PaperMachine] = []


var briquette_presses: Array [BriquettePress] = []
var generators: Array [HayGenerator] = []
var tube_launchers: Array [TubeLauncher] = []
var dump_hatches: Array [DumpHatch] = []
var hay_stairs: Array [HayStairs] = []


var hay_lifts: Array [HayLift] = []
var splitters: Array [ConveyorSplitter] = []
var joiners: Array [ConveyorJoiner] = []
var cabinets: Array [NeedleCabinet] = []


var needle_radars: Array [NeedleRadar] = []


const DEMO_WITHHELD_BUILDS:= ["gas_plant", "needle_radar"]

var demo_withheld: Array [Dictionary] = []


var paint_boards: Array [PaintBoard] = []


var work_lamps: Array [WorkLamp] = []
var hay_drones: Array [HayDrone] = []
var piston_rakes: Array [PistonRake] = []


var power_poles: Array [PowerPole] = []


var boreholes: Array [BoreholePump] = []


var water_mains: Array [WaterMain] = []


var water_splitters: Array [WaterSplitter] = []


var watch: MachineWatch


var grid: PowerGrid


var water: WaterGrid

var _grid_settle:= GRID_SETTLE
var _support_probe: BoxShape3D
var _support_query: PhysicsShapeQueryParameters3D
var live: LiveStrandManager
var field: HayField


var props: PropManager


var stand: HaySellingStand


var ghost_reading:= false


static var port_index_enabled:= not "--noportindex" in OS.get_cmdline_user_args()
var _yard_ports: YardPorts = null
var _yard_ports_epoch:= -1
var _yard_ports_sizes:= PackedInt32Array()


func _ready() -> void:


	Tech.tech_changed.connect(_on_tech_changed)
	Tech.tech_reset.connect(_on_tech_reset)
	watch = MachineWatch.new()
	watch.name = "MachineWatch"
	watch.builds = self
	add_child(watch)
	grid = PowerGrid.new(self)
	water = WaterGrid.new(self)


	changed.connect(_on_yard_changed)


	changed.connect(func() -> void: YardPorts.touch())
	child_entered_tree.connect(func(_n: Node) -> void: YardPorts.touch())
	child_exiting_tree.connect(func(_n: Node) -> void: YardPorts.touch())


func _ports_now() -> YardPorts:
	if not ghost_reading or not port_index_enabled:
		return null
	var sizes:= PackedInt32Array([conveyors.size(), splitters.size(), joiners.size(),
		scanners.size(), compressors.size(), pulpers.size(), papers.size(),
		briquette_presses.size(), hay_lifts.size(), wrappers.size(), silos.size(),
		pelletizers.size(), generators.size(), tube_launchers.size(), hay_stairs.size()])
	if _yard_ports == null or _yard_ports_epoch != YardPorts.epoch or sizes != _yard_ports_sizes:
		_yard_ports = YardPorts.new(self)
		_yard_ports_epoch = YardPorts.epoch
		_yard_ports_sizes = sizes
	return _yard_ports


static var yard_memo_enabled:= not "--noyardmemo" in OS.get_cmdline_user_args()
var _memo: Dictionary = { }
var _memo_epoch:= -1
var _memo_count:= -1


func ghost_memo(key: StringName) -> Variant:
	if not ghost_reading or not yard_memo_enabled:
		return null
	var count:= get_child_count()
	if _memo_epoch != YardPorts.epoch or _memo_count != count:
		_memo.clear()
		_memo_epoch = YardPorts.epoch
		_memo_count = count
	return _memo.get(key)


func ghost_keep(key: StringName, value: Variant) -> Variant:
	if ghost_reading and yard_memo_enabled and _memo_epoch == YardPorts.epoch:
		_memo [key] = value
	return value


func _on_yard_changed() -> void:
	_grid_settle = GRID_SETTLE


	_refresh_belt_supports_soon()


signal grid_rebuilt()


func _process(_delta: float) -> void:
	if grid == null:
		return
	if _grid_settle > 0:
		_grid_settle -= 1
		if _grid_settle == 0:


			if water != null:
				water.rebuild()
			grid.rebuild()
			grid_rebuilt.emit()
			return
	grid.tick()
	if water != null:
		water.tick()


func _on_tech_changed(id: String, _rank: int) -> void:
	upgrade_placed_models()


	if id == "pole_span":
		restring_for_reach()
	if id == "pole_span" or id == "pole_drop":
		_grid_settle = GRID_SETTLE


func _on_tech_reset() -> void:
	upgrade_placed_models()
	_grid_settle = GRID_SETTLE


func restring_for_reach() -> void:
	if grid == null:
		return
	for _pass in maxi(power_poles.size(), 1):
		_grid_settle = 0
		grid.rebuild()
		var added:= false
		for pole in power_poles:
			if not is_instance_valid(pole):
				continue
			var own:= grid.network_of(pole)
			var extra: Array [PowerPole] = []
			for other in poles_to_string_to(pole.global_position, pole.link_reach(), pole, pole):
				if grid.network_of(other) != own and not pole.strung_to(other):
					extra.append(other)
			if extra.is_empty():
				continue
			var links: Array [PowerPole] = pole.links_to.duplicate()
			links.append_array(extra)
			pole.link(links)
			added = true
		if not added:
			break
	changed.emit()


func upgrade_placed_models() -> int:
	var refitted:= 0
	var arm_tier:= Tech.max_arm_tier()
	for arm in robotic_arms:
		if is_instance_valid(arm) and arm.legacy_refit and arm.tier_index < arm_tier and arm.set_tier(arm_tier):
			refitted += 1
	var scanner_tier:= Tech.max_scanner_tier()
	for scanner in scanners:
		if is_instance_valid(scanner) and scanner.tier_index < scanner_tier and scanner.set_tier(scanner_tier):
			refitted += 1
	if refitted > 0:
		changed.emit()
	return refitted


func _free_name(stem: String, from: int) -> String:
	var n:= from
	while has_node(NodePath("%s%d" % [stem, n])):
		n += 1
	return "%s%d" % [stem, n]


func add_conveyor(from: Vector3, to: Vector3, line_id:= 0) -> Conveyor:
	var c:= Conveyor.new()
	c.name = _free_name("Conveyor", conveyors.size())
	c.setup(from, to)
	c.line_id = line_id
	conveyors.append(c)
	add_child(c)
	rebuild_junctions()
	changed.emit()
	return c


func add_enclosed_conveyor(from: Vector3, to: Vector3, line_id:= 0) -> EnclosedConveyor:
	var c:= EnclosedConveyor.new()
	c.name = _free_name("EnclosedConveyor", conveyors.size())
	c.setup(from, to)
	c.line_id = line_id
	conveyors.append(c)
	add_child(c)
	rebuild_junctions()
	changed.emit()
	return c


func reverse_conveyor(c: Conveyor) -> bool:
	if c == null or not is_instance_valid(c) or not conveyors.has(c):
		return false
	if reverse_blocked_reason(c) != "":
		return false


	for run in line_of(c):
		run.reverse()
	rebuild_junctions()
	changed.emit()
	return true


func new_line_id() -> int:
	var top:= 0
	for c in conveyors:
		if is_instance_valid(c):
			top = maxi(top, c.line_id)
	return top + 1


func line_of(c: Conveyor) -> Array [Conveyor]:
	var out: Array [Conveyor] = [c]
	if c == null or c.line_id == 0:
		return out
	for other in conveyors:
		if other != c and is_instance_valid(other) and other.line_id == c.line_id:
			out.append(other)
	return out


func same_building(x: Node3D, y: Node3D) -> bool:
	if x == y:
		return true
	var p:= x as Conveyor
	var q:= y as Conveyor
	return p != null and q != null and p.line_id != 0 and p.line_id == q.line_id


func reverse_blocked_reason(c: Conveyor) -> String:
	if c == null or not is_instance_valid(c) or not conveyors.has(c):
		return ""


	for run in line_of(c):

		var machine:= outfeed_owner_at(run.a)
		if machine == null:
			continue
		var what:= Cfg.lower_in_english(name_of(machine))
		return tr("take it off the %s's outfeed first") % (what if what != "" else tr("machine"))
	return ""


func outfeed_owner_at(point: Vector3) -> Node3D:
	for scanner in scanners:
		if is_instance_valid(scanner) and PointIndex.joins(scanner.port_out(), point):
			return scanner
	for press in compressors:
		if is_instance_valid(press) and PointIndex.joins(press.port_out(), point):
			return press
	for pulper in pulpers:
		if is_instance_valid(pulper) and PointIndex.joins(pulper.port_out(), point):
			return pulper
	for mill in papers:
		if is_instance_valid(mill) and PointIndex.joins(mill.port_out(), point):
			return mill


	for machine in briquette_presses:
		if is_instance_valid(machine) and PointIndex.joins(machine.port_out(), point):
			return machine
	for wrap in wrappers:
		if is_instance_valid(wrap) and PointIndex.joins(wrap.port_out(), point):
			return wrap
	for tank in silos:
		if is_instance_valid(tank) and PointIndex.joins(tank.port_out(), point):
			return tank
	for tower in hay_stairs:
		if is_instance_valid(tower) and PointIndex.joins(tower.outfeed_port(), point):
			return tower
	for lift in hay_lifts:
		if is_instance_valid(lift) and PointIndex.joins(lift.port_out(), point):
			return lift
	for splitter in splitters:
		if not is_instance_valid(splitter):
			continue
		for arm: int in splitter.output_sides():
			if PointIndex.joins(splitter.port(arm), point):
				return splitter
	for joiner in joiners:
		if is_instance_valid(joiner) and PointIndex.joins(joiner.port_out(), point):
			return joiner
	return null


func add_robotic_arm(at: Vector3, yaw: float,
		tier: int = Cfg.ROBOT_ARM_DEFAULT_TIER, paid: float = -1.0) -> RoboticArm:
	var arm:= RoboticArm.new()
	arm.name = _free_name("RoboticArm", robotic_arms.size())
	arm.builds = self
	arm.live = live
	arm.field = field
	arm.props = props
	arm.setup(at, yaw, tier)

	if paid >= 0.0:
		arm.paid_cost = paid
	robotic_arms.append(arm)
	add_child(arm)
	changed.emit()
	return arm


func add_platform(top_centre: Vector3, span: Vector2) -> Platform:
	var deck:= Platform.new()
	deck.name = _free_name("Platform", platforms.size())
	deck.setup(top_centre, span)
	platforms.append(deck)
	add_child(deck)
	regroup_deck_legs()
	_reground_decks_over(deck.footprint(), deck.top_y())
	restyle_hatches()
	changed.emit()
	return deck


func restyle_hatches() -> void:
	for lid in roofs:
		if not is_instance_valid(lid) or lid.kind != Roof.Kind.HATCH:
			continue
		var on_deck:= 0
		var on_roof:= 0
		for point in lid.surround_points():
			var found:= false
			for deck in platforms:
				if is_instance_valid(deck) and absf(point.y - deck.top_y()) < 0.25 and deck.footprint().has_point(Vector2(point.x, point.z)):
					on_deck += 1
					found = true
					break
			if found:
				continue
			for other in roofs:
				if other != lid and is_instance_valid(other) and other.covers_point(point):
					on_roof += 1
					break
		lid.set_deck_style(on_deck > on_roof)


func _reground_decks_over(rect: Rect2, top: float) -> void:
	if not is_inside_tree():
		return
	var over: Array [Platform] = []
	for other in platforms:
		if not is_instance_valid(other) or other.top_y() <= top + 0.05:
			continue
		if other.top_y() - top > Cfg.PLATFORM_LEG_MAX_DROP:
			continue
		if other.footprint().intersects(rect):
			over.append(other)
	if over.is_empty():
		return
	await get_tree().physics_frame
	for other in over:
		if is_instance_valid(other) and other.is_inside_tree():
			other.refresh_supports(true)


func regroup_deck_legs(refresh:= true) -> void:


	if _sweeping > 0:
		_sweep_legs = true
		return
	var decks: Array [Platform] = []
	for deck in platforms:
		if is_instance_valid(deck) and deck.is_inside_tree():
			decks.append(deck)
	var group:= PackedInt32Array()
	group.resize(decks.size())
	group.fill(-1)
	var groups:= 0
	for first in decks.size():
		if group [first] >= 0:
			continue
		group [first] = groups
		var stack: Array [int] = [first]
		while not stack.is_empty():
			var i: int = stack.pop_back()
			for j in decks.size():
				if group [j] < 0 and _decks_join(decks [i], decks [j]):
					group [j] = groups
					stack.append(j)
		groups += 1
	for g in groups:
		var members: Array [Platform] = []
		for i in decks.size():
			if group [i] == g:
				members.append(decks [i])
		var shares:= _deck_leg_shares(members)
		for i in members.size():
			if members [i].set_leg_points(shares [i]) and refresh:
				members [i].call_deferred("refresh_supports", true)


func _decks_join(a: Platform, b: Platform) -> bool:
	if absf(a.top_y() - b.top_y()) > SNAP_HEIGHT_BAND:
		return false
	var touch:= a.footprint().grow(0.05).intersection(b.footprint().grow(0.05))
	return maxf(touch.size.x, touch.size.y) > 0.5


func _deck_leg_shares(members: Array [Platform]) -> Array [PackedVector2Array]:
	var bounds:= members [0].footprint()
	for deck in members:
		bounds = bounds.merge(deck.footprint())
	var grid:= Platform.leg_grid(bounds)
	var claimed:= PackedByteArray()
	claimed.resize(grid.size())
	var placed:= PackedVector2Array()
	var shares: Array [PackedVector2Array] = []
	for deck in members:


		var rect:= deck.footprint().grow(0.01)
		var share:= PackedVector2Array()
		for k in grid.size():
			if claimed [k] == 0 and rect.has_point(grid [k]):
				claimed [k] = 1
				share.append(grid [k])
				placed.append(grid [k])
		shares.append(share)
	var reach:= Cfg.PLATFORM_LEG_SPACING * Cfg.PLATFORM_LEG_SPACING
	for i in members.size():
		for p in Platform.leg_grid(members [i].footprint()):
			var covered:= false
			for q in placed:
				if p.distance_squared_to(q) <= reach:
					covered = true
					break
			if not covered:
				shares [i].append(p)
				placed.append(p)
	return shares


func add_railing(from: Vector3, to: Vector3) -> Railing:
	var rail:= Railing.new()
	rail.name = _free_name("Railing", railings.size())
	rail.setup(from, to)
	railings.append(rail)
	add_child(rail)
	changed.emit()
	return rail


func add_wall(from: Vector3, to: Vector3, kind: YardWall.Bay) -> YardWall:
	if from.distance_to(YardWall.end_for(from, to, kind)) < 1e-06:
		push_warning("BuildManager: a wall with no length at %s, not built" % from)
		return null
	var wall:= YardWall.new()
	wall.name = _free_name("Wall", walls.size())
	wall.setup(from, to, kind)
	walls.append(wall)
	add_child(wall)
	share_joints()
	changed.emit()
	return wall


func add_roof(from: Vector3, to: Vector3, kind: Roof.Kind, side: int,
		rows: int = 1) -> Roof:
	var lid:= Roof.new()
	lid.name = _free_name("Roof", roofs.size())
	lid.setup(from, to, kind, side, rows)
	roofs.append(lid)
	add_child(lid)
	share_joints()
	restyle_hatches()
	changed.emit()
	return lid


func share_joints() -> void:
	var seen:= { }
	for wall in walls:
		if not is_instance_valid(wall):
			continue
		var skip:= PackedInt32Array()
		var points:= wall.post_points()
		for i in points.size():
			var key:= Vector3i((points [i] * 100.0).round())
			if seen.has(key):
				skip.append(i)
			else:
				seen [key] = true
		wall.set_shared_posts(skip)
	seen.clear()
	for lid in roofs:
		if not is_instance_valid(lid):
			continue
		var skip:= PackedInt32Array()
		var keys:= lid.rafter_keys()
		for i in keys.size():
			if seen.has(keys [i]):
				skip.append(i)
			else:
				seen [keys [i]] = true
		lid.set_shared_rafters(skip)


func rail_in_wall(rail_a: Vector3, rail_b: Vector3, wall_a: Vector3,
		wall_b: Vector3) -> bool:
	return (_on_run(rail_a, wall_a, wall_b) and _on_run(rail_b, wall_a, wall_b)
			and _on_run((rail_a + rail_b) * 0.5, wall_a, wall_b)) or (_on_run(wall_a, rail_a, rail_b) and _on_run(wall_b, rail_a, rail_b)
			and _on_run((wall_a + wall_b) * 0.5, rail_a, rail_b))


static func _on_run(point: Vector3, from: Vector3, to: Vector3) -> bool:
	if absf(point.y - from.y) > 0.05:
		return false
	var run:= to - from
	var span:= run.length()
	if span < 1e-06:
		return point.distance_to(from) < 0.05
	var t:= (point - from).dot(run / span)
	if t < -0.05 or t > span + 0.05:
		return false
	return point.distance_to(from + run / span * clampf(t, 0.0, span)) < 0.05


func wall_along(from: Vector3, to: Vector3) -> bool:
	for wall in walls:
		if is_instance_valid(wall) and rail_in_wall(from, to, wall.a, wall.b):
			return true
	return false


func railing_along(from: Vector3, to: Vector3) -> bool:
	for rail in railings:
		if is_instance_valid(rail) and rail_in_wall(rail.a, rail.b, from, to):
			return true
	return false


static func deck_tile_at(deck: Platform, point: Vector3) -> Rect2:
	var rect:= deck.footprint()
	var nx:= Platform.tiles_across(rect.size.x)
	var nz:= Platform.tiles_across(rect.size.y)
	var i:= clampi(int(floor((point.x - rect.position.x) / Cfg.PLATFORM_TILE)), 0, nx - 1)
	var j:= clampi(int(floor((point.z - rect.position.y) / Cfg.PLATFORM_TILE)), 0, nz - 1)
	return Rect2(rect.position + Vector2(float(i), float(j)) * Cfg.PLATFORM_TILE,
		Vector2.ONE * Cfg.PLATFORM_TILE)


func deck_tile_share(deck: Platform) -> float:
	var area:= deck.span.x * deck.span.y
	if area <= 0.0:
		return 0.0
	return deck.build_cost() * Cfg.PLATFORM_TILE * Cfg.PLATFORM_TILE / area


func standing_on_tile(deck: Platform, tile: Rect2) -> Array [Node3D]:
	var inside:= tile.grow(-0.02)
	var out: Array [Node3D] = []
	for building in standing_on(deck):
		var points: Array [Vector3] = []
		var a: Variant = building.get("a")
		var b: Variant = building.get("b")
		if a is Vector3 and b is Vector3:
			points.append(a as Vector3)
			points.append(b as Vector3)
		else:
			points.append(building.global_position)
		for p in points:
			if inside.has_point(Vector2(p.x, p.z)):
				out.append(building)
				break
	return out


func hatch_into_deck(deck: Platform, tile: Rect2, from: Vector3, to: Vector3,
		side: int) -> Roof:
	var top:= deck.top_y()
	_split_deck_around(deck, tile)
	var lid:= Roof.new()
	lid.name = _free_name("Roof", roofs.size())
	lid.setup(from, to, Roof.Kind.HATCH, side)
	roofs.append(lid)
	add_child(lid)
	share_joints()
	restyle_hatches()
	_settle_after_tile_cut(tile, top)
	return lid


func tile_blocked_reason(deck: Platform, tile: Rect2) -> String:
	var load_count:= standing_on_tile(deck, tile).size()
	if load_count == 0:
		return ""
	return tr("clear %d from the tile first") % load_count


func remove_deck_tile(deck: Platform, tile: Rect2) -> float:
	if not platforms.has(deck) or tile_blocked_reason(deck, tile) != "":
		return 0.0
	if Platform.tiles_across(deck.span.x) * Platform.tiles_across(deck.span.y) <= 1:
		return demolish(deck)
	var top:= deck.top_y()
	var share:= deck_tile_share(deck)
	_split_deck_around(deck, tile)
	_settle_after_tile_cut(tile, top)
	return share


func _settle_after_tile_cut(tile: Rect2, top: float) -> void:
	regroup_deck_legs()
	_reground_decks_over(tile, top)

	_wake_sleepers(AABB(Vector3(tile.position.x, top - Cfg.PLATFORM_THICK,
		tile.position.y), Vector3(tile.size.x, Cfg.PLATFORM_THICK + 0.3, tile.size.y)))
	changed.emit()


func _split_deck_around(deck: Platform, tile: Rect2) -> void:
	var rect:= deck.footprint()
	var top:= deck.top_y()
	var paid:= deck.build_cost()
	var area:= rect.get_area()
	var pieces: Array [Rect2] = []
	if tile.position.x > rect.position.x + 0.01:
		pieces.append(Rect2(rect.position,
			Vector2(tile.position.x - rect.position.x, rect.size.y)))
	if tile.end.x < rect.end.x - 0.01:
		pieces.append(Rect2(Vector2(tile.end.x, rect.position.y),
			Vector2(rect.end.x - tile.end.x, rect.size.y)))
	if tile.position.y > rect.position.y + 0.01:
		pieces.append(Rect2(Vector2(tile.position.x, rect.position.y),
			Vector2(tile.size.x, tile.position.y - rect.position.y)))
	if tile.end.y < rect.end.y - 0.01:
		pieces.append(Rect2(Vector2(tile.position.x, tile.end.y),
			Vector2(tile.size.x, rect.end.y - tile.end.y)))
	platforms.erase(deck)
	remove_child(deck)
	deck.queue_free()
	for piece in pieces:
		var made:= Platform.new()
		made.name = _free_name("Platform", platforms.size())
		var centre:= piece.get_center()
		made.setup(Vector3(centre.x, top, centre.y), piece.size)
		made.paid_cost = paid * piece.get_area() / area if area > 0.0 else 0.0
		platforms.append(made)
		add_child(made)


func add_stair(head: Vector3, yaw: float, rise: float,
		pitch: float = Cfg.STAIR_PITCH) -> Stair:
	var flight:= Stair.new()
	flight.name = _free_name("Stair", stairs.size())
	flight.setup(head, yaw, rise, pitch)
	stairs.append(flight)
	add_child(flight)
	changed.emit()
	return flight


func add_scanner(at: Vector3, yaw: float,
		tier: int = Cfg.SCANNER_DEFAULT_TIER) -> HaystackScanner:
	var scanner:= HaystackScanner.new()
	scanner.name = _free_name("HaystackScanner", scanners.size())
	scanner.live = live
	scanner.props = props
	scanner.setup(at, yaw, tier)
	scanners.append(scanner)
	add_child(scanner)


	rebuild_junctions()
	changed.emit()
	return scanner


func add_compressor(at: Vector3, yaw: float) -> HayCompressor:
	var press:= HayCompressor.new()
	press.name = _free_name("HayCompressor", compressors.size())
	press.live = live
	press.props = props
	press.setup(at, yaw)
	compressors.append(press)
	add_child(press)


	rebuild_junctions()
	changed.emit()
	return press


func add_pulper(at: Vector3, yaw: float) -> HayPulper:
	var pulper:= HayPulper.new()
	pulper.name = _free_name("HayPulper", pulpers.size())
	pulper.live = live
	pulper.props = props
	pulper.setup(at, yaw)
	pulpers.append(pulper)
	add_child(pulper)


	rebuild_junctions()
	changed.emit()
	return pulper


func add_paper(at: Vector3, yaw: float) -> PaperMachine:
	var mill:= PaperMachine.new()
	mill.name = _free_name("PaperMachine", papers.size())
	mill.props = props


	mill.live = live
	mill.setup(at, yaw)
	papers.append(mill)
	add_child(mill)
	rebuild_junctions()
	changed.emit()
	return mill


func add_briquette(at: Vector3, yaw: float) -> BriquettePress:
	var machine:= BriquettePress.new()
	machine.name = _free_name("BriquettePress", briquette_presses.size())
	machine.props = props
	machine.live = live
	machine.setup(at, yaw)
	briquette_presses.append(machine)
	add_child(machine)
	rebuild_junctions()
	changed.emit()
	return machine


func add_wrapper(at: Vector3, yaw: float) -> HayWrapper:
	var wrap:= HayWrapper.new()
	wrap.name = _free_name("HayWrapper", wrappers.size())
	wrap.props = props
	wrap.setup(at, yaw)
	wrappers.append(wrap)
	add_child(wrap)
	rebuild_junctions()
	changed.emit()
	return wrap


func add_silo(at: Vector3, yaw: float) -> HaySilo:
	var tank:= HaySilo.new()
	tank.name = _free_name("HaySilo", silos.size())
	tank.live = live
	tank.props = props
	tank.setup(at, yaw)
	silos.append(tank)
	add_child(tank)
	rebuild_junctions()
	changed.emit()
	return tank


func add_piston_rake(at: Vector3, yaw: float, paid: float = -1.0,
		gift: bool = false) -> PistonRake:
	var rake:= PistonRake.new()
	rake.name = _free_name("PistonRake", piston_rakes.size())
	rake.live = live
	rake.props = props
	rake.field = field
	rake.gift = gift
	rake.paid_cost = 0.0 if gift else (paid if paid >= 0.0 else rake_price())
	rake.setup(at, yaw)
	piston_rakes.append(rake)
	add_child(rake)
	changed.emit()
	return rake


func add_pelletizer(at: Vector3, yaw: float) -> HayPelletizer:
	var mill:= HayPelletizer.new()
	mill.name = _free_name("HayPelletizer", pelletizers.size())
	mill.live = live
	mill.props = props
	mill.setup(at, yaw)
	pelletizers.append(mill)
	add_child(mill)
	rebuild_junctions()
	changed.emit()
	return mill


func add_hay_stairs(at: Vector3, yaw: float) -> HayStairs:
	var tower:= HayStairs.new()
	tower.name = _free_name("HayStairs", hay_stairs.size())
	tower.live = live
	tower.props = props
	tower.setup(at, yaw)
	hay_stairs.append(tower)
	add_child(tower)
	rebuild_junctions()
	changed.emit()
	return tower


func snap_stairs_port(point: Vector3, ignore: HayStairs = null) -> Vector3:
	var best:= point
	var best_d:= Cfg.HAY_STAIRS_SNAP_RADIUS
	for tower in hay_stairs:
		if tower == ignore or not is_instance_valid(tower):
			continue
		var at:= tower.outfeed_port()
		var d:= at.distance_to(point)
		if d < best_d:
			best_d = d
			best = at
	return best


func stairs_overlap(at: Vector3, ignore: HayStairs = null) -> bool:
	for tower in hay_stairs:
		if tower == ignore or not is_instance_valid(tower):
			continue
		if tower.global_position.distance_to(at) < Cfg.HAY_STAIRS_HALF_WIDTH * 2.0:
			return true


	var r:= Cfg.HAY_STAIRS_HALF_WIDTH
	for box: Keepout in _module_keepouts():
		if box != null and disc_hits_keepout(at, r, box):
			return true
	for entry: Array in _wye_footprints():
		for theirs: Vector4 in entry [1]:
			var gap:= _disc_centre(theirs) - at
			if absf(gap.y) <= MODULE_STOREY and Vector2(gap.x, gap.z).length() < r + theirs.w:
				return true
	return _disc_hits_termini(at, r, &"stairs")


func add_hay_lift(at: Vector3, yaw: float, sections: int,
		riser: float = HayLift.SPACER) -> HayLift:
	var lift:= HayLift.new()
	lift.name = _free_name("HayLift", hay_lifts.size())
	lift.live = live
	lift.props = props
	lift.setup(at, yaw, sections, riser)
	hay_lifts.append(lift)
	add_child(lift)
	rebuild_junctions()
	changed.emit()
	return lift


func snap_lift_port(point: Vector3, ignore: HayLift = null) -> Vector3:
	var best:= point
	var best_d:= Cfg.HAY_LIFT_SNAP_RADIUS
	for lift in hay_lifts:
		if lift == ignore or not is_instance_valid(lift):
			continue
		for port: Vector3 in [lift.port_in(), lift.port_out()]:
			var d:= point.distance_to(port)
			if d < best_d:
				best_d = d
				best = port
	return best


func lift_overlap(at: Vector3, ignore: HayLift = null,
		forward: Vector3 = Vector3.BACK) -> bool:
	var mine:= HayLift.plan_rect(at, forward)
	for lift in hay_lifts:
		if lift == ignore or not is_instance_valid(lift):
			continue
		if HayLift.plan_rects_overlap(mine,
				HayLift.plan_rect(lift.global_position, lift.forward(), lift.port_reach)):
			return true
	for tower in hay_stairs:
		if not is_instance_valid(tower):
			continue
		var d:= tower.global_position - at
		if Vector2(d.x, d.z).length() < Cfg.HAY_LIFT_HALF_WIDTH + Cfg.HAY_STAIRS_HALF_WIDTH:
			return true

	return module_clash(lift_keepout(at, forward), null, &"lift")


func snap_pelletizer_port(point: Vector3, ignore: HayPelletizer = null) -> Vector3:
	var best:= point
	var best_d:= Cfg.PELLETIZER_SNAP_RADIUS
	for mill in pelletizers:
		if mill == ignore or not is_instance_valid(mill):
			continue
		var at:= mill.intake_port()
		var d:= at.distance_to(point)
		if d < best_d:
			best_d = d
			best = at
	return best


func pelletizer_overlap(at: Vector3, forward: Vector3 = Vector3.BACK,
		ignore: HayPelletizer = null) -> bool:
	var ours:= pelletizer_keepout(at, forward)
	for mill in pelletizers:
		if mill == ignore or not is_instance_valid(mill):
			continue
		if keepouts_clash(ours, pelletizer_keepout(mill.global_position,
				mill.forward())):
			return true

	return module_clash(terminus_keepout(at, forward, Cfg.PELLETIZER_KEEPOUT,
		HayPelletizer.PORT_BACK + HayPelletizer.STUB + HayPelletizer.STUB_REACH),
		null, &"pelletizer")


func add_generator(at: Vector3, yaw: float, paid: float = -1.0) -> HayGenerator:
	var gen:= HayGenerator.new()
	gen.name = _free_name("HayGenerator", generators.size())
	gen.paid_cost = paid if paid >= 0.0 else generator_price()
	return _stand_generator(gen, at, yaw)


func add_gas_plant(at: Vector3, yaw: float, paid: float = -1.0) -> GasPlant:
	var plant:= GasPlant.new()
	plant.name = _free_name("GasPlant", generators.size())
	plant.paid_cost = paid if paid >= 0.0 else gas_plant_price()
	return _stand_generator(plant, at, yaw) as GasPlant


func _stand_generator(gen: HayGenerator, at: Vector3, yaw: float) -> HayGenerator:
	gen.live = live
	gen.props = props
	gen.setup(at, yaw)
	generators.append(gen)
	add_child(gen)
	rebuild_junctions()
	changed.emit()
	return gen


func snap_generator_port(point: Vector3, ignore: HayGenerator = null) -> Vector3:
	var best:= point
	var best_d:= Cfg.GENERATOR_SNAP_RADIUS
	for gen in generators:
		if gen == ignore or not is_instance_valid(gen):
			continue
		var at:= gen.intake_port()
		var d:= at.distance_to(point)
		if d < best_d:
			best_d = d
			best = at
	return best


func generator_overlap(at: Vector3, forward: Vector3 = Vector3.BACK,
		ignore: HayGenerator = null, plant:= false) -> bool:
	var ours:= gas_plant_keepout(at, forward) if plant else generator_keepout(at, forward)
	for gen in generators:
		if gen == ignore or not is_instance_valid(gen):
			continue
		var theirs:= (gas_plant_keepout(gen.global_position, gen.forward())
			if gen is GasPlant else generator_keepout(gen.global_position, gen.forward()))
		if keepouts_clash(ours, theirs):
			return true


	return module_clash(terminus_keepout(at, forward,
		Cfg.GAS_PLANT_KEEPOUT if plant else Cfg.GENERATOR_KEEPOUT, HayGenerator.PORT_BACK),
		null, &"generator")


func add_borehole(at: Vector3, yaw: float) -> BoreholePump:
	var pump:= BoreholePump.new()
	pump.name = _free_name("BoreholePump", boreholes.size())
	pump.setup(at, yaw)
	boreholes.append(pump)
	add_child(pump)
	changed.emit()
	return pump


func borehole_overlap(at: Vector3, forward: Vector3 = Vector3.BACK,
		ignore: BoreholePump = null) -> bool:
	var ours:= borehole_keepout(at, forward)
	for pump in boreholes:
		if pump == ignore or not is_instance_valid(pump):
			continue
		if keepouts_clash(ours, borehole_keepout(pump.global_position,
				pump.global_basis.z)):
			return true
	return false


func add_water_main(from: Vector3, to: Vector3) -> WaterMain:
	var run:= WaterMain.new()
	run.name = _free_name("WaterMain", water_mains.size())
	run.setup(from, to)
	water_mains.append(run)
	add_child(run)
	rebuild_water_joints()
	changed.emit()
	return run


func rebuild_water_joints() -> void:
	var tol:= Cfg.PIPE_JOIN_TOLERANCE
	var starts:= { }
	var bends:= { }
	var headings:= { }
	var taken_end:= { }
	var taken_start:= { }


	var joined:= { }


	var starts_at:= PointIndex.new()
	for i in water_mains.size():
		starts_at.add(water_mains [i].a, water_mains [i], i)
	var flanges_at:= PointIndex.new()
	for entry: Array in _flanges():
		var port: Node3D = entry [1]
		if port != null and is_instance_valid(port):
			flanges_at.add(port.global_position, entry [0], 0)
	for incoming in water_mains:
		var meeting:= starts_at.within(incoming.b, tol)
		meeting.sort_custom(func(x: Array, y: Array) -> bool: return int(x [2]) < int(y [2]))
		for hit: Array in meeting:
			var outgoing: WaterMain = hit [1]
			if outgoing == incoming:
				continue


			joined [outgoing] = true
			if taken_end.has(incoming) or taken_start.has(outgoing):
				continue
			var t:= corner_tangent(incoming.forward, incoming.length,
				outgoing.forward, outgoing.length)
			taken_end [incoming] = true
			taken_start [outgoing] = true
			if t <= 0.0:


				continue
			bends [incoming] = t
			headings [incoming] = outgoing.forward
			starts [outgoing] = t

	for run in water_mains:
		run.set_joint(float(starts.get(run, 0.0)), float(bends.get(run, 0.0)),
			headings.get(run, Vector3.ZERO), joined.has(run),
			not flanges_at.within(run.b, tol).is_empty())


func snap_water_endpoint(point: Vector3, ignore: WaterMain = null) -> Vector3:
	var flange:= nearest_flange(point)
	if flange != Vector3.ZERO:
		return flange
	var best:= point
	var best_d:= Cfg.PIPE_SNAP_RADIUS
	for run in water_mains:
		if run == ignore or not is_instance_valid(run):
			continue
		for end: Vector3 in run.endpoints():
			var d:= point.distance_to(end)
			if d < best_d:
				best_d = d
				best = end
	return best


func nearest_flange(point: Vector3, radius: float = -1.0) -> Vector3:
	var best:= Vector3.ZERO
	var best_d:= Cfg.PIPE_SNAP_RADIUS if radius < 0.0 else radius
	for entry: Array in _flanges():
		var port: Node3D = entry [1]
		if port == null or not is_instance_valid(port):
			continue
		var at:= port.global_position
		var d:= point.distance_to(at)


		if d < best_d and water_ports_at(at) < 2:
			best_d = d
			best = at
	return best


func _flanges() -> Array:
	var kept: Variant = ghost_memo(&"flanges")
	if kept != null:
		return kept
	var out: Array = []
	for machine in water_machines():
		for port: Node3D in machine.call("water_ports"):
			out.append([machine, port])
	return ghost_keep(&"flanges", out)


func water_ports_at(at: Vector3) -> int:
	var n:= 0
	for entry: Array in _flanges():
		var port: Node3D = entry [1]
		if port != null and is_instance_valid(port) and port.global_position.distance_to(at) <= Cfg.PIPE_JOIN_TOLERANCE:
			n += 1
	return n


func nearest_free_wye_flange(point: Vector3, radius: float = -1.0) -> Dictionary:
	var best:= { }
	var best_d:= Cfg.PIPE_SNAP_RADIUS if radius < 0.0 else radius
	for wye in water_splitters:
		if not is_instance_valid(wye):
			continue
		for port: Node3D in wye.water_ports():
			var at:= port.global_position
			var d:= point.distance_to(at)
			if d >= best_d or water_port_taken(at):
				continue
			best_d = d
			best = { "wye": wye, "point": at, "away": wye.water_port_bearing(port) }
	return best


func flange_owner(point: Vector3, radius: float = -1.0) -> Node3D:
	var best: Node3D = null
	var best_d:= Cfg.PIPE_JOIN_TOLERANCE if radius < 0.0 else radius
	for entry: Array in _flanges():
		var port: Node3D = entry [1]
		if port == null or not is_instance_valid(port):
			continue
		var d:= point.distance_to(port.global_position)
		if d <= best_d:
			best_d = d
			best = entry [0]
	return best


func water_machines() -> Array [Node3D]:
	var out: Array [Node3D] = []
	for machine in all_buildings():
		if is_instance_valid(machine) and machine.has_method("water_ports"):
			out.append(machine)
	return out


func water_run_into(at: Vector3) -> WaterMain:
	for run in water_mains:
		if is_instance_valid(run) and run.b.distance_to(at) <= Cfg.PIPE_JOIN_TOLERANCE:
			return run
	return null


func water_run_out_of(at: Vector3) -> WaterMain:
	for run in water_mains:
		if is_instance_valid(run) and run.a.distance_to(at) <= Cfg.PIPE_JOIN_TOLERANCE:
			return run
	return null


func nearest_water_run_end(point: Vector3, radius: float = -1.0) -> Dictionary:
	var best:= { }
	var best_d:= Cfg.PIPE_SNAP_RADIUS if radius < 0.0 else radius
	for run in water_mains:
		if not is_instance_valid(run):
			continue
		for end: Vector3 in run.endpoints():
			var d:= point.distance_to(end)
			if d >= best_d:
				continue
			best_d = d


			var away:= run.forward if PointIndex.joins(end, run.b) else - run.forward
			best = { "run": run, "point": end, "away": away }
	return best


func water_port_taken(at: Vector3, ignore: WaterMain = null) -> bool:

	if water_ports_at(at) > 1:
		return true
	if nearest_flange(at, Cfg.PIPE_JOIN_TOLERANCE) == Vector3.ZERO:
		return false
	for run in water_mains:
		if run == ignore or not is_instance_valid(run):
			continue
		for end: Vector3 in run.endpoints():
			if end.distance_to(at) <= Cfg.PIPE_JOIN_TOLERANCE:
				return true
	return false


func add_water_splitter(at: Vector3, yaw: float, paid: float = -1.0) -> WaterSplitter:
	var wye:= WaterSplitter.new()
	wye.name = _free_name("WaterSplitter", water_splitters.size())
	wye.setup(at, yaw)
	if paid >= 0.0:
		wye.paid_cost = paid
	water_splitters.append(wye)
	add_child(wye)
	changed.emit()
	return wye


func water_splitter_overlap(at: Vector3, ignore: WaterSplitter = null,
		mated: WaterSplitter = null) -> bool:
	for wye in water_splitters:
		if wye == ignore or not is_instance_valid(wye):
			continue
		var clear:= Cfg.PIPE_SPLITTER_HALF_WIDTH * 2.0
		if wye == mated:
			clear = Cfg.PIPE_SPLITTER_PORT_R * 2.0 - Cfg.WYE_MATE_SLACK
		if wye.global_position.distance_to(at) < clear:
			return true
	for pump in boreholes:
		if not is_instance_valid(pump):
			continue


		var flat_at:= Vector3(at.x, pump.global_position.y, at.z)
		if disc_hits_keepout(flat_at, Cfg.PIPE_SPLITTER_HALF_WIDTH,
				borehole_keepout(pump.global_position, pump.global_basis.z)):
			return true
	return false


func add_power_pole(at: Vector3, yaw: float, buried: bool = false,
		gift: bool = false) -> PowerPole:
	var pole: PowerPole = PowerBox.new() if buried else PowerPole.new()
	pole.gift = gift and not buried
	pole.name = _free_name("PowerBox" if buried else "PowerPole", power_poles.size())
	pole.setup(at, yaw)
	pole.set_on_deck(deck_under(at) != null)


	add_child(pole)
	pole.link(poles_to_string_to(at, pole.link_reach(), pole, pole))
	power_poles.append(pole)
	changed.emit()
	return pole


func deck_under(point: Vector3) -> Platform:
	for deck in platforms:
		if not is_instance_valid(deck) or absf(point.y - deck.top_y()) > 0.05:
			continue
		if deck.footprint().has_point(Vector2(point.x, point.z)):
			return deck
	return null


func deck_below(point: Vector3) -> Platform:
	var best: Platform = null
	for deck in platforms:
		if not is_instance_valid(deck) or deck.top_y() > point.y - Cfg.PLATFORM_THICK:
			continue
		if not deck.footprint().has_point(Vector2(point.x, point.z)):
			continue
		if best == null or deck.top_y() > best.top_y():
			best = deck
	return best


func fit_posts_to_decks() -> void:
	for pole in power_poles:
		if is_instance_valid(pole):
			pole.set_on_deck(deck_under(pole.global_position) != null)


func poles_to_string_to(at: Vector3, reach: float,
		ignore: PowerPole = null, from: PowerPole = null) -> Array [PowerPole]:
	if grid != null and _grid_settle > 0:
		_grid_settle = 0
		grid.rebuild()
	var space: PhysicsDirectSpaceState3D = null
	var crown:= Vector3.ZERO
	var skip: Array [RID] = []
	if from != null and from.is_inside_tree():
		space = get_world_3d().direct_space_state
		crown = from.wire_point()
		skip = from.own_bodies()
	var best: Dictionary = { }
	for pole in power_poles:
		if pole == ignore or not is_instance_valid(pole):
			continue
		if not PowerGrid.links_within(maxf(reach, pole.link_reach()), at,
				pole.global_position):
			continue
		if space != null and not PowerGrid.span_clear(space, crown,
				from.buried(), skip, pole):
			continue
		var net:= grid.network_of(pole) if grid != null else -1
		var d:= PowerGrid.flat_distance(at, pole.global_position)
		if not best.has(net) or d < float((best [net] as Array) [1]):
			best [net] = [pole, d]
	var out: Array [PowerPole] = []
	for net: int in best:
		out.append((best [net] as Array) [0] as PowerPole)
	return out


func pole_overlap(at: Vector3, ignore: PowerPole = null) -> bool:
	for pole in power_poles:
		if pole == ignore or not is_instance_valid(pole):
			continue
		if pole.global_position.distance_to(at) < Cfg.POLE_HALF_WIDTH * 2.0:
			return true
	return false


func add_tube_launcher(at: Vector3, yaw: float) -> TubeLauncher:
	var gun:= TubeLauncher.new()
	gun.name = _free_name("TubeLauncher", tube_launchers.size())
	gun.live = live
	gun.props = props
	gun.setup(at, yaw)
	tube_launchers.append(gun)
	add_child(gun)
	rebuild_junctions()
	changed.emit()
	return gun


func snap_stand_port(point: Vector3) -> Vector3:
	if stand == null or not is_instance_valid(stand) or not stand.is_inside_tree():
		return point
	var at:= stand.belt_entry_point()
	return at if at.distance_to(point) < Cfg.STAND_SNAP_RADIUS else point


func snap_launcher_port(point: Vector3, ignore: TubeLauncher = null) -> Vector3:
	var best:= point
	var best_d:= Cfg.LAUNCHER_SNAP_RADIUS
	for gun in tube_launchers:
		if gun == ignore or not is_instance_valid(gun):
			continue
		var at:= gun.intake_port()
		var d:= at.distance_to(point)
		if d < best_d:
			best_d = d
			best = at
	return best


func add_dump_hatch(at: Vector3, yaw: float) -> DumpHatch:
	var tip:= DumpHatch.new()
	tip.name = _free_name("DumpHatch", dump_hatches.size())
	tip.live = live
	tip.props = props
	tip.builds = self
	tip.setup(at, yaw)
	dump_hatches.append(tip)
	add_child(tip)
	changed.emit()
	return tip


func dump_hatch_overlap(at: Vector3, ignore: DumpHatch = null) -> bool:
	for tip in dump_hatches:
		if tip == ignore or not is_instance_valid(tip):
			continue
		if tip.global_position.distance_to(at) < Cfg.DUMP_HATCH_HALF_WIDTH * 1.4:
			return true
	return false


func hatch_wanting(item: Carryable, from: Vector3) -> DumpHatch:
	var best: DumpHatch = null
	var near:= INF
	for tip in dump_hatches:
		if not is_instance_valid(tip) or not tip.wants(item, from):
			continue
		var d:= from.distance_to(tip.dock_point())
		if d < near:
			near = d
			best = tip
	return best


func launcher_overlap(at: Vector3, forward: Vector3 = Vector3.BACK,
		ignore: TubeLauncher = null) -> bool:
	var ours:= launcher_keepout(at, forward)
	for gun in tube_launchers:
		if gun == ignore or not is_instance_valid(gun):
			continue
		if keepouts_clash(ours, launcher_keepout(gun.global_position,
				gun.forward())):
			return true

	return module_clash(terminus_keepout(at, forward, Cfg.LAUNCHER_KEEPOUT,
		TubeLauncher.PORT_BACK + TubeLauncher.STUB + TubeLauncher.STUB_REACH),
		null, &"launcher")


static func scaled_price(base: float, standing: int, free: int,
		growth: float) -> float:
	var over:= maxi(0, standing + 1 - maxi(1, free))
	return snappedf(base * pow(growth, float(over)), 10.0)


static func headroom(standing: int, limit: int) -> int:
	return maxi(0, limit - standing)


func drone_price() -> float:
	return scaled_price(Cfg.DRONE_COST, hay_drones.size(), Cfg.DRONE_COST_FREE,
		Cfg.DRONE_COST_GROWTH)


func drones_left() -> int:
	return headroom(hay_drones.size(), Cfg.DRONE_LIMIT)


func arm_price(tier: int) -> float:
	var index:= clampi(tier, 0, Cfg.ROBOT_ARM_TIERS.size() - 1)
	return scaled_price(float(Cfg.ROBOT_ARM_TIERS [index] ["cost"]),
		robotic_arms.size(), Cfg.ARM_COST_FREE, Cfg.ARM_COST_GROWTH)


func arms_left() -> int:
	return headroom(robotic_arms.size(), Cfg.ARM_LIMIT)


static func arm_next_tier(arm: RoboticArm) -> int:
	var next:= arm.tier_index + 1
	return next if next < Cfg.ROBOT_ARM_TIERS.size() else -1


func arm_upgrade_price(arm: RoboticArm) -> float:
	if arm == null or not is_instance_valid(arm):
		return -1.0
	var next:= arm_next_tier(arm)
	if next < 0:
		return -1.0
	var paid:= arm.build_cost()
	var multiple:= maxf(1.0, paid / maxf(float(arm.tier_data() ["cost"]), 1.0))
	var then:= snappedf(float(Cfg.ROBOT_ARM_TIERS [next] ["cost"]) * multiple, 10.0)
	return maxf(0.0, then - paid)


func arm_upgrade_block(arm: RoboticArm) -> String:
	if arm == null or not is_instance_valid(arm):
		return tr("blocked")
	var next:= arm_next_tier(arm)
	if next < 0:
		return tr("biggest model")
	if not BuildCatalog.is_unlocked(BuildCatalog.arm_id_for_tier(next)):
		return tr("not unlocked yet")
	var price:= arm_upgrade_price(arm)
	if not GameState.can_afford(price):
		return tr("need %s") % ("$%s" % Hud.money_text(price))
	var at:= arm.global_position
	if arm_reach_conflict(at, next, arm):
		return tr("another arm in reach")
	if deck_through_arm(at, next) != null:
		return tr("a deck is in the way")
	if not _arm_base_hit(arm, next).is_empty():
		return tr("blocked")
	return ""


func arm_upgrade_detail(arm: RoboticArm) -> String:
	var block:= arm_upgrade_block(arm)
	if block == "" or arm == null or not is_instance_valid(arm):
		return ""
	var next:= arm_next_tier(arm)
	if next < 0:
		return ""
	var tier: Dictionary = Cfg.ROBOT_ARM_TIERS [next]
	if block == tr("not unlocked yet"):
		return tr("Unlock the %s in the tech tree first.") % BuildCatalog.display_name(BuildCatalog.arm_id_for_tier(next))
	if block == tr("another arm in reach"):
		return tr("The bigger arm reaches %s m. Move the other arm farther away.") % ("%.1f" % float(tier ["reach"]))
	if block == tr("a deck is in the way"):
		return tr("The bigger arm would hit a deck when it swings.")
	if block == tr("blocked"):
		var across:= "%.1f" % (ARM_BASE_RADIUS * 2.0 * float(tier ["scale"]))
		var hit:= _arm_base_hit(arm, next)
		var thing:= name_of(owner_of(hit.get("collider") as Node))
		if thing == "" and hit.get("collider") is CollisionObject3D and (hit ["collider"] as CollisionObject3D).collision_layer & Cfg.L_PILE:
			thing = tr("hay pile")
		if thing == "":
			return tr("Something next to its base is in the way. The bigger base is %s m wide.") % across
		return tr("The %s next to its base is in the way. The bigger base is %s m wide.") % [thing, across]
	return ""


func upgrade_arm(arm: RoboticArm) -> bool:
	if arm_upgrade_block(arm) != "":
		return false
	var price:= arm_upgrade_price(arm)
	var paid:= arm.build_cost()
	if not GameState.spend_money(price):
		return false
	arm.set_tier(arm_next_tier(arm))
	arm.paid_cost = paid + price
	arm.legacy_refit = false
	changed.emit()
	return true


const ARM_BASE_RADIUS:= 0.78


func _arm_base_hit(arm: RoboticArm, tier: int) -> Dictionary:
	if not is_inside_tree():
		return { }
	var scale:= float(Cfg.ROBOT_ARM_TIERS [tier] ["scale"])
	var probe:= CylinderShape3D.new()
	probe.radius = ARM_BASE_RADIUS * scale
	probe.height = 0.86 * scale
	var query:= PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD | Cfg.L_KEEPOUT
	query.collide_with_areas = false
	query.exclude = [arm.get_rid()]
	query.transform = Transform3D(Basis(),
		arm.global_position + Vector3.UP * (probe.height * 0.5 + 0.055))
	var hits:= get_world_3d().direct_space_state.intersect_shape(query, 1)
	return hits [0] if not hits.is_empty() else { }


func generator_price() -> float:
	return Cfg.GENERATOR_COST


func gas_plant_price() -> float:
	return Cfg.GAS_PLANT_COST


func rake_price() -> float:
	return scaled_price(Cfg.RAKE_COST, piston_rakes.size(), Cfg.RAKE_COST_FREE,
		Cfg.RAKE_COST_GROWTH)


func rakes_left() -> int:
	return headroom(piston_rakes.size(), Cfg.RAKE_LIMIT)


func _crowded_refund(machine: Object, fleet: Array) -> float:
	var dearest:= machine
	var model: Variant = machine.get("tier_index")
	for other in fleet:
		if not is_instance_valid(other) or other.get("tier_index") != model:
			continue

		if other.get("gift") == true:
			continue
		if float(other.call("build_cost")) > float(dearest.call("build_cost")):
			dearest = other
	var refund:= float(dearest.call("build_cost"))
	if dearest != machine:
		dearest.set("paid_cost", float(machine.call("build_cost")))
	return refund


func add_hay_drone(at: Vector3, yaw: float, paid: float = -1.0) -> HayDrone:
	var drone:= HayDrone.new()
	drone.name = _free_name("HayDrone", hay_drones.size())
	drone.paid_cost = paid if paid >= 0.0 else drone_price()
	drone.props = props
	drone.stand = stand
	drone.field = field
	drone.builds = self
	drone.live = live
	drone.setup(at, yaw)
	hay_drones.append(drone)
	add_child(drone)


	changed.emit()
	return drone


func drone_overlap(at: Vector3, radius: float) -> bool:
	for d in hay_drones:
		if d.global_position.distance_to(at) < radius:
			return true
	return HayDrone.pad_refusal(at) != ""


func add_splitter(at: Vector3, yaw: float) -> ConveyorSplitter:
	var splitter:= ConveyorSplitter.new()
	splitter.name = _free_name("ConveyorSplitter", splitters.size())
	splitter.setup(at, yaw)
	splitters.append(splitter)
	add_child(splitter)


	rebuild_junctions()
	_refresh_wye_supports()
	refit_runs_at(splitter.ports())
	changed.emit()
	return splitter


func add_joiner(at: Vector3, yaw: float) -> ConveyorJoiner:
	var joiner:= ConveyorJoiner.new()
	joiner.name = _free_name("ConveyorJoiner", joiners.size())
	joiner.setup(at, yaw)
	joiners.append(joiner)
	add_child(joiner)
	rebuild_junctions()
	_refresh_wye_supports()
	refit_runs_at(joiner.ports())
	changed.emit()
	return joiner


func add_u_splitter(at: Vector3, yaw: float) -> ConveyorUSplitter:
	var splitter:= ConveyorUSplitter.new()
	splitter.name = _free_name("ConveyorUSplitter", splitters.size())
	splitter.setup(at, yaw)
	splitters.append(splitter)
	add_child(splitter)
	rebuild_junctions()
	_refresh_wye_supports()
	refit_runs_at(splitter.ports())
	changed.emit()
	return splitter


func add_t_splitter(at: Vector3, yaw: float,
		feed: int = ConveyorTSplitter.STEM, port_r: float = NAN) -> ConveyorTSplitter:
	var splitter:= ConveyorTSplitter.new()
	if is_nan(port_r):
		port_r = Cfg.T_SPLITTER_PORT_R if is_nan(ConveyorTSplitter.placed_port_r) else ConveyorTSplitter.placed_port_r
	splitter.port_r = port_r
	splitter.name = _free_name("ConveyorTSplitter", splitters.size())
	splitter.setup(at, yaw)
	splitter.set_entry(feed)
	splitters.append(splitter)
	add_child(splitter)
	rebuild_junctions()
	_refresh_wye_supports()
	refit_runs_at(splitter.ports())
	changed.emit()
	return splitter


func add_compact_splitter(at: Vector3, yaw: float, smart: bool = false) -> ConveyorCompactSplitter:
	var splitter:= ConveyorCompactSplitter.new()
	splitter.smart = smart
	splitter.name = ("ConveyorSmartSplitter%d" if smart else "ConveyorCompactSplitter%d") % splitters.size()
	splitter.setup(at, yaw)
	splitters.append(splitter)
	add_child(splitter)
	rebuild_junctions()
	_refresh_wye_supports()
	refit_runs_at(splitter.ports())
	changed.emit()
	return splitter


func add_u_joiner(at: Vector3, yaw: float) -> ConveyorUJoiner:
	var joiner:= ConveyorUJoiner.new()
	joiner.name = _free_name("ConveyorUJoiner", joiners.size())
	joiner.setup(at, yaw)
	joiners.append(joiner)
	add_child(joiner)
	rebuild_junctions()
	_refresh_wye_supports()
	refit_runs_at(joiner.ports())
	changed.emit()
	return joiner


func add_cabinet(at: Vector3, yaw: float, gift: bool = false) -> NeedleCabinet:
	var cab:= NeedleCabinet.new()
	cab.name = _free_name("NeedleCabinet", cabinets.size())
	cab.gift = gift
	cab.setup(at, yaw)
	cab.live = live
	cabinets.append(cab)
	add_child(cab)


	cabinet_added.emit(cab)
	changed.emit()
	return cab


func add_needle_radar(at: Vector3, yaw: float) -> NeedleRadar:
	var dish:= NeedleRadar.new()
	dish.name = _free_name("NeedleRadar", needle_radars.size())
	dish.setup(at, yaw)
	dish.field = field
	needle_radars.append(dish)
	add_child(dish)

	changed.emit()
	return dish


func add_paint_board(at: Vector3, yaw: float) -> PaintBoard:
	var board:= PaintBoard.new()
	board.name = _free_name("PaintBoard", paint_boards.size())
	board.setup(at, yaw)
	paint_boards.append(board)
	add_child(board)

	changed.emit()
	return board


func add_work_lamp(at: Vector3, yaw: float) -> WorkLamp:
	var lamp:= WorkLamp.new()
	lamp.name = _free_name("WorkLamp", work_lamps.size())
	lamp.setup(at, yaw)
	work_lamps.append(lamp)
	add_child(lamp)

	changed.emit()
	return lamp


func paint_board_under(from: Vector3, look: Vector3) -> PaintBoard:
	for board in paint_boards:
		if is_instance_valid(board) and board.paintable(from, look):
			return board
	return null


func has_cabinet() -> bool:
	return not cabinets.is_empty()


func the_cabinet() -> NeedleCabinet:
	return cabinets [0] if not cabinets.is_empty() else null


func nearest_cabinet(point: Vector3) -> NeedleCabinet:
	var best: NeedleCabinet = null
	var best_d:= INF
	for cab in cabinets:
		var d:= cab.global_position.distance_squared_to(point)
		if d < best_d:
			best_d = d
			best = cab
	return best


func cabinet_in_reach(from: Vector3) -> NeedleCabinet:
	for cab in cabinets:
		if cab.in_reach(from):
			return cab
	return null


func cabinet_under(from: Vector3, look: Vector3) -> NeedleCabinet:
	if look == Vector3.ZERO or not is_inside_tree() or cabinet_in_reach(from) == null:
		return null
	var query:= PhysicsRayQueryParameters3D.create(
		from, from + look.normalized() * NeedleCabinet.LOOK, Cfg.L_BUILD)
	var hit:= get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null


	var node:= hit.get("collider") as Node
	while node != null and node is not NeedleCabinet:
		node = node.get_parent()
	var cab:= node as NeedleCabinet
	if cab == null or cab.placement_preview or not cab.in_reach(from):
		return null
	return cab


func has_needle_radar() -> bool:
	return not needle_radars.is_empty()


func needle_radar_under(from: Vector3, look: Vector3) -> NeedleRadar:
	if look == Vector3.ZERO or not is_inside_tree():
		return null
	var near:= false
	for each in needle_radars:
		if is_instance_valid(each) and each.in_reach(from):
			near = true
			break
	if not near:
		return null
	var query:= PhysicsRayQueryParameters3D.create(
		from, from + look.normalized() * NeedleRadar.LOOK, Cfg.L_BUILD)
	var hit:= get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var node:= hit.get("collider") as Node
	while node != null and node is not NeedleRadar:
		node = node.get_parent()
	var dish:= node as NeedleRadar
	if dish == null or dish.placement_preview or not dish.in_reach(from):
		return null
	return dish


func snap_scanner_port(point: Vector3, ignore: HaystackScanner = null) -> Vector3:
	var best:= point
	var best_d:= Cfg.SCANNER_SNAP_RADIUS
	for scanner in scanners:
		if scanner == ignore or not is_instance_valid(scanner):
			continue
		for port: Vector3 in [scanner.port_in(), scanner.port_out()]:
			var d:= point.distance_to(port)
			if d < best_d:
				best_d = d
				best = port
	return best


func snap_compressor_port(point: Vector3, ignore: HayCompressor = null) -> Vector3:
	var best:= point
	var best_d:= Cfg.COMPRESSOR_SNAP_RADIUS
	for press in compressors:
		if press == ignore or not is_instance_valid(press):
			continue
		for port: Vector3 in [press.port_in(), press.port_out()]:
			var d:= point.distance_to(port)
			if d < best_d:
				best_d = d
				best = port
	return best


func snap_pulper_port(point: Vector3, ignore: HayPulper = null) -> Vector3:
	var best:= point
	var best_d:= Cfg.PULPER_SNAP_RADIUS
	for pulper in pulpers:
		if pulper == ignore or not is_instance_valid(pulper):
			continue
		for port: Vector3 in [pulper.port_in(), pulper.port_out()]:
			var d:= point.distance_to(port)
			if d < best_d:
				best_d = d
				best = port
	return best


func snap_paper_port(point: Vector3, ignore: PaperMachine = null) -> Vector3:
	var best:= point
	var best_d:= Cfg.PAPER_SNAP_RADIUS
	for mill in papers:
		if mill == ignore or not is_instance_valid(mill):
			continue
		for port: Vector3 in [mill.port_in(), mill.port_out()]:
			var d:= point.distance_to(port)
			if d < best_d:
				best_d = d
				best = port
	return best


func snap_briquette_port(point: Vector3, ignore: BriquettePress = null) -> Vector3:
	var best:= point
	var best_d:= Cfg.BRIQUETTE_SNAP_RADIUS
	for machine in briquette_presses:
		if machine == ignore or not is_instance_valid(machine):
			continue
		for port: Vector3 in machine.ports():
			var d:= point.distance_to(port)
			if d < best_d:
				best_d = d
				best = port
	return best


func snap_wrapper_port(point: Vector3, ignore: HayWrapper = null) -> Vector3:
	var best:= point
	var best_d:= Cfg.WRAPPER_SNAP_RADIUS
	for wrap in wrappers:
		if wrap == ignore or not is_instance_valid(wrap):
			continue
		for port: Vector3 in [wrap.port_in(), wrap.port_out()]:
			var d:= point.distance_to(port)
			if d < best_d:
				best_d = d
				best = port
	return best


func snap_silo_port(point: Vector3, ignore: HaySilo = null) -> Vector3:
	var best:= point
	var best_d:= Cfg.SILO_SNAP_RADIUS
	for tank in silos:
		if tank == ignore or not is_instance_valid(tank):
			continue
		for port: Vector3 in [tank.port_in(), tank.port_out()]:
			var d:= point.distance_to(port)
			if d < best_d:
				best_d = d
				best = port
	return best


func snap_splitter_port(point: Vector3, ignore: ConveyorSplitter = null,
		ignore_run: Conveyor = null, avoid:= Vector3.INF) -> Vector3:
	var best:= point
	var best_d:= Cfg.SPLITTER_SNAP_RADIUS
	var yp:= _ports_now()
	var listed: Array [Array] = yp.splitter_ports if yp != null else _ports_of(splitters)
	for entry: Array in listed:

		if not is_instance_valid(entry [0]) or entry [0] == ignore:
			continue
		for mouth: Vector3 in entry [1]:
			var d:= point.distance_to(mouth)
			if d < best_d and not wye_mouth_taken(mouth, ignore_run) and not PointIndex.joins(mouth, avoid):
				best_d = d
				best = mouth
	return best


static func _ports_of(list: Array) -> Array [Array]:
	var out: Array [Array] = []
	for wye: Node3D in list:
		if is_instance_valid(wye):
			out.append([wye, wye.call("ports")])
	return out


func splitter_overlap(at: Vector3, ignore: ConveyorSplitter = null) -> bool:
	return wye_overlap([Vector4(at.x, at.y, at.z, Cfg.SPLITTER_PORT_R)], ignore)


func wye_overlap(discs: Array [Vector4], ignore: Node3D = null) -> bool:


	for entry: Array in _wye_footprints():
		var wye: Node3D = entry [0]
		if wye == ignore or not is_instance_valid(wye):
			continue


		var bound: Vector3 = entry [2]
		var reach: float = entry [3] - Cfg.WYE_MATE_SLACK + 0.001
		var close:= false
		for ours: Vector4 in discs:
			if _disc_centre(ours).distance_to(bound) < ours.w + reach:
				close = true
				break
		if yard_memo_enabled and not close:
			continue
		for theirs: Vector4 in entry [1]:
			for ours: Vector4 in discs:
				if _disc_centre(ours).distance_to(_disc_centre(theirs)) < ours.w + theirs.w - Cfg.WYE_MATE_SLACK:
					return true


	var boxes:= _module_keepouts()
	for d: Vector4 in discs:
		var c:= _disc_centre(d)
		for box: Keepout in boxes:
			if box != null and disc_hits_keepout(c, d.w, box):
				return true


	for d: Vector4 in discs:
		if _disc_hits_termini(_disc_centre(d), d.w, &""):
			return true

	for d: Vector4 in discs:
		if _post_in_disc(_disc_centre(d), d.w):
			return true
	return false


const WYE_HEADROOM:= 0.95


func _post_in_disc(centre: Vector3, radius: float) -> bool:
	var low:= centre.y - (Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR)
	var high:= centre.y + WYE_HEADROOM
	for pole in power_poles:
		if not is_instance_valid(pole):
			continue
		var at:= pole.global_position
		if not _post_spans(pole, low, high):
			continue
		if Vector2(at.x - centre.x, at.z - centre.z).length() < radius + _post_radius(pole):
			return true
	return false


func _post_in_keepout(box: Keepout) -> bool:
	var low:= box.centre.y
	var high:= box.centre.y + MODULE_STOREY
	for pole in power_poles:
		if is_instance_valid(pole) and _post_spans(pole, low, high) and disc_hits_keepout(Vector3(pole.global_position.x, box.centre.y,
					pole.global_position.z), _post_radius(pole), box):
			return true
	return false


static func _post_spans(pole: PowerPole, low: float, high: float) -> bool:
	var foot:= pole.global_position.y
	return foot < high and pole.wire_point().y > low


static func _post_radius(pole: PowerPole) -> float:
	var plan:= pole.footprint()
	return maxf(plan.x, plan.y) * 0.5


func _wye_footprints() -> Array:
	var kept: Variant = ghost_memo(&"wye_footprints")
	if kept != null:
		return kept
	var out: Array = []
	for list: Array in [splitters, joiners]:
		for wye: Node3D in list:
			if not is_instance_valid(wye):
				continue
			var discs: Array = wye.call("footprint")
			var centre:= Vector3.ZERO
			for d: Vector4 in discs:
				centre += _disc_centre(d)
			if not discs.is_empty():
				centre /= float(discs.size())
			var reach:= 0.0
			for d: Vector4 in discs:
				reach = maxf(reach, _disc_centre(d).distance_to(centre) + d.w)
			out.append([wye, discs, centre, reach])
	return ghost_keep(&"wye_footprints", out)


func _module_keepouts() -> Array:
	var kept: Variant = ghost_memo(&"module_keepouts")
	if kept != null:
		return kept
	var out: Array = []
	for node: Node3D in module_nodes():
		out.append(module_keepout(node) if is_instance_valid(node) else null)
	return ghost_keep(&"module_keepouts", out)


static func _disc_centre(d: Vector4) -> Vector3:
	return Vector3(d.x, d.y, d.z)


func snap_joiner_port(point: Vector3, ignore: ConveyorJoiner = null,
		ignore_run: Conveyor = null, avoid:= Vector3.INF) -> Vector3:
	var best:= point
	var best_d:= Cfg.JOINER_SNAP_RADIUS
	var yp:= _ports_now()
	var listed: Array [Array] = yp.joiner_ports if yp != null else _ports_of(joiners)
	for entry: Array in listed:

		if not is_instance_valid(entry [0]) or entry [0] == ignore:
			continue
		for mouth: Vector3 in entry [1]:
			var d:= point.distance_to(mouth)
			if d < best_d and not wye_mouth_taken(mouth, ignore_run) and not PointIndex.joins(mouth, avoid):
				best_d = d
				best = mouth
	return best


func joiner_overlap(at: Vector3, ignore: ConveyorJoiner = null) -> bool:
	return wye_overlap([Vector4(at.x, at.y, at.z, Cfg.JOINER_PORT_R)], ignore)


func port_bearing_at(point: Vector3) -> Vector3:
	var yp:= _ports_now()
	if yp != null:
		var hit:= yp.bearing_hit(point)
		if not hit.is_empty():
			return hit [1]
		if stand != null and is_instance_valid(stand) and stand.is_inside_tree() and PointIndex.joins(stand.belt_entry_point(), point):
			return stand.intake_forward()
		return Vector3.ZERO
	for splitter in splitters:
		if not is_instance_valid(splitter):
			continue
		if PointIndex.joins(splitter.port_in(), point):
			return splitter.forward()
		for side in splitter.output_sides():
			if PointIndex.joins(splitter.port(side), point):
				return splitter.arm_travel(side)
	for joiner in joiners:
		if not is_instance_valid(joiner):
			continue
		if PointIndex.joins(joiner.port_out(), point):
			return joiner.forward()
		for side: int in ConveyorJoiner.SIDES:
			if PointIndex.joins(joiner.port(side), point):
				return joiner.arm_travel(side)


	for scanner in scanners:
		if not is_instance_valid(scanner):
			continue
		if PointIndex.joins(scanner.port_in(), point) or PointIndex.joins(scanner.port_out(), point):
			return scanner.forward()
	for press in compressors:
		if not is_instance_valid(press):
			continue
		if PointIndex.joins(press.port_in(), point) or PointIndex.joins(press.port_out(), point):
			return press.forward()
	for pulper in pulpers:
		if not is_instance_valid(pulper):
			continue
		if PointIndex.joins(pulper.port_in(), point) or PointIndex.joins(pulper.port_out(), point):
			return pulper.forward()
	for mill in papers:
		if not is_instance_valid(mill):
			continue
		if PointIndex.joins(mill.port_in(), point) or PointIndex.joins(mill.port_out(), point):
			return mill.forward()


	for machine in briquette_presses:
		if not is_instance_valid(machine):
			continue
		var bearing:= machine.bearing_at(point)
		if bearing != Vector3.ZERO:
			return bearing


	for lift in hay_lifts:
		if not is_instance_valid(lift):
			continue
		if PointIndex.joins(lift.port_in(), point) or PointIndex.joins(lift.port_out(), point):
			return lift.forward()
	for wrap in wrappers:
		if not is_instance_valid(wrap):
			continue
		if PointIndex.joins(wrap.port_in(), point) or PointIndex.joins(wrap.port_out(), point):
			return wrap.forward()


	for tank in silos:
		if not is_instance_valid(tank):
			continue
		if PointIndex.joins(tank.port_in(), point) or PointIndex.joins(tank.port_out(), point):
			return tank.forward()


	for mill in pelletizers:
		if is_instance_valid(mill) and PointIndex.joins(mill.intake_port(), point):
			return mill.forward()
	for gen in generators:
		if is_instance_valid(gen) and PointIndex.joins(gen.intake_port(), point):
			return gen.forward()
	for gun in tube_launchers:
		if is_instance_valid(gun) and PointIndex.joins(gun.intake_port(), point):
			return gun.forward()


	for tower in hay_stairs:
		if is_instance_valid(tower) and PointIndex.joins(tower.outfeed_port(), point):
			return tower.outfeed_forward()


	if stand != null and is_instance_valid(stand) and stand.is_inside_tree() and PointIndex.joins(stand.belt_entry_point(), point):
		return stand.intake_forward()
	return Vector3.ZERO


func intake_at(point: Vector3) -> bool:
	var yp:= _ports_now()
	if yp != null and yp.intake(point):
		return true
	if yp != null:
		return stand != null and is_instance_valid(stand) and stand.is_inside_tree() and PointIndex.joins(stand.belt_entry_point(), point)
	for splitter in splitters:
		if not is_instance_valid(splitter) or splitter is ConveyorTSplitter:
			continue
		if PointIndex.joins(splitter.port_in(), point):
			return true
	for joiner in joiners:
		if not is_instance_valid(joiner) or joiner is ConveyorTJoiner:
			continue
		for side: int in ConveyorJoiner.SIDES:
			if PointIndex.joins(joiner.port(side), point):
				return true
	var spliced: Array = []
	spliced.append_array(scanners)
	spliced.append_array(compressors)
	spliced.append_array(pulpers)
	spliced.append_array(papers)
	spliced.append_array(hay_lifts)
	spliced.append_array(wrappers)
	spliced.append_array(silos)
	for machine: Node3D in spliced:
		if is_instance_valid(machine) and PointIndex.joins(machine.port_in(), point):
			return true
	for machine in briquette_presses:
		if is_instance_valid(machine) and (PointIndex.joins(machine.port_wad(), point) or PointIndex.joins(machine.port_brick(), point)):
			return true
	var termini: Array = []
	termini.append_array(pelletizers)
	termini.append_array(generators)
	termini.append_array(tube_launchers)
	for machine: Node3D in termini:
		if is_instance_valid(machine) and PointIndex.joins(machine.intake_port(), point):
			return true
	return stand != null and is_instance_valid(stand) and stand.is_inside_tree() and PointIndex.joins(stand.belt_entry_point(), point)


func water_port_bearing_at(point: Vector3) -> Vector3:
	for entry: Array in _flanges():
		var machine: Node3D = entry [0]
		var port: Node3D = entry [1]
		if port == null or not is_instance_valid(port):
			continue
		if port.global_position.distance_to(point) > Cfg.PIPE_JOIN_TOLERANCE:
			continue
		var out: Vector3
		if machine.has_method("water_port_bearing"):
			out = machine.call("water_port_bearing", port)
		else:
			out = - port.global_transform.basis.z
		out.y = 0.0
		return out.normalized() if out.length_squared() > 1e-08 else Vector3.ZERO
	return Vector3.ZERO


func nearest_wye_joint(point: Vector3, radius: float) -> Dictionary:
	var best:= nearest_belt_end(point, radius)
	if not best.is_empty():
		var along: Vector3 = best ["forward"]
		var level:= Vector3(along.x, 0.0, along.z)
		if level.length_squared() > 1e-08:
			best ["forward"] = level.normalized()
	var best_d: float = radius if best.is_empty() else point.distance_to(best ["point"] as Vector3)
	var mouths:= _wye_mouths()
	for mouth in mouths:
		var at: Vector3 = mouth ["point"]
		var d:= point.distance_to(at)
		if d >= best_d:
			continue
		if feed_run_into(at) != null or run_out_of(at) != null or _mouth_count(at) > 1 or generator_at_port(at) != null:
			continue
		best_d = d
		best = { "point": at, "forward": mouth ["forward"], "start": mouth ["start"] }
	return best


func nearest_wye_outlet(point: Vector3, radius: float) -> Dictionary:
	var best: Dictionary = { }
	var best_d:= radius
	var mouths:= _wye_mouths()
	for mouth in mouths:
		if bool(mouth ["start"]):
			continue
		var at: Vector3 = mouth ["point"]
		var d:= point.distance_to(at)
		if d >= best_d:
			continue
		if feed_run_into(at) != null or run_out_of(at) != null or _mouth_count(at) > 1 or generator_at_port(at) != null:
			continue
		var along: Vector3 = mouth ["forward"]
		var level:= Vector3(along.x, 0.0, along.z)
		if level.length_squared() < 1e-08:
			continue
		best_d = d
		best = { "point": at, "forward": level.normalized(), "start": false }
	return best


func free_line_joints(point: Vector3, radius: float) -> Array [Dictionary]:
	var out: Array [Dictionary] = []
	for c in conveyors:
		if not is_instance_valid(c):
			continue
		for is_start: bool in [false, true]:
			var end: Vector3 = c.a if is_start else c.b
			if point.distance_to(end) >= radius or _end_is_joined(c, end):
				continue
			var level:= Vector3(c.forward.x, 0.0, c.forward.z)
			if level.length_squared() < 1e-08:
				continue
			out.append({ "point": end, "forward": level.normalized(), "start": is_start,
				"wye": false, "pitch": asin(clampf(c.forward.y, -1.0, 1.0)) })
	var mouths:= _wye_mouths()
	for mouth in mouths:
		var at: Vector3 = mouth ["point"]
		if point.distance_to(at) >= radius:
			continue
		if feed_run_into(at) != null or run_out_of(at) != null or _mouth_count(at) > 1 or generator_at_port(at) != null:
			continue
		var along: Vector3 = mouth ["forward"]
		var level:= Vector3(along.x, 0.0, along.z)
		if level.length_squared() < 1e-08:
			continue
		out.append({ "point": at, "forward": level.normalized(),
			"start": bool(mouth ["start"]), "wye": true, "pitch": 0.0 })


	for splitter in splitters:
		var t:= splitter as ConveyorTSplitter
		if t == null or not is_instance_valid(t) or t.fed:
			continue
		for lane: int in ConveyorTSplitter.LANES:
			var at:= t.to_global(t.mouth_of(lane))
			if point.distance_to(at) >= radius:
				continue
			if feed_run_into(at) != null or run_out_of(at) != null or _mouth_count(at) > 1 or generator_at_port(at) != null:
				continue
			var lane_out:= t.global_basis * ConveyorTSplitter.lane_out(lane)
			lane_out = Vector3(lane_out.x, 0.0, lane_out.z).normalized()
			for is_start: bool in [false, true]:
				var dup:= false
				for j in out:
					if bool(j ["wye"]) and bool(j ["start"]) == is_start and (j ["point"] as Vector3).is_equal_approx(at):
						dup = true
						break
				if not dup:
					out.append({ "point": at, "forward": - lane_out if is_start else lane_out,
						"start": is_start, "wye": true, "pitch": 0.0 })
	return out


func generator_at_port(point: Vector3) -> HayGenerator:
	var yp:= _ports_now()
	if yp != null:
		return yp.generator(point)
	for gen in generators:
		if is_instance_valid(gen) and PointIndex.joins(gen.intake_port(), point):
			return gen
	return null


func wye_mated_at(point: Vector3) -> bool:
	var n:= _mouth_count(point)
	if n > 1:
		return true
	return n == 1 and generator_at_port(point) != null


func wye_mouth_taken(point: Vector3, ignore: Conveyor = null) -> bool:
	if _mouth_count(point) == 0:
		return false
	return wye_mated_at(point) or port_has_run(point, ignore)


func port_has_run(point: Vector3, ignore: Conveyor = null) -> bool:
	var yp:= _ports_now()
	if yp != null:
		for e: Array in yp.starts.all(point) + yp.ends.all(point):
			if e [1] != ignore and is_instance_valid(e [1]):
				return true
		return false
	for c in conveyors:
		if c == ignore or not is_instance_valid(c):
			continue
		if PointIndex.joins(c.a, point) or PointIndex.joins(c.b, point):
			return true
	return false


func _wye_mouths() -> Array [Dictionary]:
	var yp:= _ports_now()
	if yp != null:
		return yp.mouths
	var out: Array [Dictionary] = []
	for splitter in splitters:
		if not is_instance_valid(splitter):
			continue
		out.append({ "point": splitter.port_in(), "forward": splitter.forward(),
			"start": true })
		for side in splitter.output_sides():
			out.append({ "point": splitter.port(side),
				"forward": splitter.arm_travel(side),
				"start": false })
	for joiner in joiners:
		if not is_instance_valid(joiner):
			continue
		out.append({ "point": joiner.port_out(), "forward": joiner.forward(),
			"start": false })
		for side: int in ConveyorJoiner.SIDES:
			out.append({ "point": joiner.port(side), "forward": joiner.arm_travel(side),
				"start": true })
	return out


static func _mouths_at(mouths: Array [Dictionary], point: Vector3) -> int:
	var n:= 0
	for mouth in mouths:
		if PointIndex.joins(mouth ["point"] as Vector3, point):
			n += 1
	return n


func mouth_at(point: Vector3) -> bool:
	return _mouth_count(point) > 0


func _mouth_count(point: Vector3) -> int:
	var yp:= _ports_now()
	if yp != null:
		return yp.mouth_count(point)
	return _mouths_at(_wye_mouths(), point)


func _wye_inlet_at(point: Vector3) -> BeltPath:
	for splitter in splitters:
		if is_instance_valid(splitter) and PointIndex.joins(splitter.port_in(), point):
			return splitter.route(splitter.next_side)
	for joiner in joiners:
		if not is_instance_valid(joiner):
			continue
		for side: int in ConveyorJoiner.SIDES:
			if PointIndex.joins(joiner.port(side), point):
				return joiner.arm(side)
	return null


func _wye_outlet_at(point: Vector3) -> BeltPath:
	for splitter in splitters:
		if not is_instance_valid(splitter):
			continue
		for side in splitter.output_sides():
			if PointIndex.joins(splitter.port(side), point):
				return splitter.route(side)
	for joiner in joiners:
		if is_instance_valid(joiner) and PointIndex.joins(joiner.port_out(), point):
			return joiner.out_path()
	return null


func nearest_belt_end(point: Vector3, radius: float) -> Dictionary:
	var out: Dictionary = { }
	var best:= radius
	for c in conveyors:
		if not is_instance_valid(c):
			continue
		for is_start: bool in [false, true]:
			var end: Vector3 = c.a if is_start else c.b
			var d:= point.distance_to(end)
			if d >= best:
				continue
			if _end_is_joined(c, end):
				continue
			best = d
			out = { "point": end, "forward": c.forward, "start": is_start }
	return out


func _end_is_joined(owner_run: Conveyor, at: Vector3) -> bool:
	for c in conveyors:
		if c == owner_run or not is_instance_valid(c):
			continue
		if PointIndex.joins(c.a, at) or PointIndex.joins(c.b, at):
			return true
	for scanner in scanners:
		if not is_instance_valid(scanner):
			continue
		if PointIndex.joins(scanner.port_in(), at) or PointIndex.joins(scanner.port_out(), at):
			return true
	for press in compressors:
		if not is_instance_valid(press):
			continue
		if PointIndex.joins(press.port_in(), at) or PointIndex.joins(press.port_out(), at):
			return true
	for pulper in pulpers:
		if not is_instance_valid(pulper):
			continue
		if PointIndex.joins(pulper.port_in(), at) or PointIndex.joins(pulper.port_out(), at):
			return true
	for mill in papers:
		if not is_instance_valid(mill):
			continue
		if PointIndex.joins(mill.port_in(), at) or PointIndex.joins(mill.port_out(), at):
			return true
	for machine in briquette_presses:
		if not is_instance_valid(machine):
			continue
		for port: Vector3 in machine.ports():
			if PointIndex.joins(port, at):
				return true
	for lift in hay_lifts:
		if not is_instance_valid(lift):
			continue
		if PointIndex.joins(lift.port_in(), at) or PointIndex.joins(lift.port_out(), at):
			return true
	for wrap in wrappers:
		if not is_instance_valid(wrap):
			continue
		if PointIndex.joins(wrap.port_in(), at) or PointIndex.joins(wrap.port_out(), at):
			return true
	for tank in silos:
		if not is_instance_valid(tank):
			continue
		if PointIndex.joins(tank.port_in(), at) or PointIndex.joins(tank.port_out(), at):
			return true
	for splitter in splitters:
		if not is_instance_valid(splitter):
			continue
		for mouth: Vector3 in splitter.ports():
			if PointIndex.joins(mouth, at):
				return true
	for joiner in joiners:
		if not is_instance_valid(joiner):
			continue
		for mouth: Vector3 in joiner.ports():
			if PointIndex.joins(mouth, at):
				return true
	return false


const MODULE_STOREY:= 3.0


class Keepout extends RefCounted:


	var centre:= Vector3.ZERO

	var fwd:= Vector3.BACK

	var half_len:= 0.0
	var half_w:= 0.0

	func _init(at: Vector3, facing: Vector3, ahead: float, behind: float,
			right: float, left: float) -> void:
		var flat:= Vector3(facing.x, 0.0, facing.z)
		fwd = flat.normalized() if flat.length_squared() > 1e-08 else Vector3.BACK
		half_len = (ahead + behind) * 0.5
		half_w = (right + left) * 0.5
		centre = at + fwd * ((ahead - behind) * 0.5) + across() * ((right - left) * 0.5)


	func across() -> Vector3:
		return Vector3(fwd.z, 0.0, - fwd.x)


static func scanner_keepout(at: Vector3, forward: Vector3) -> Keepout:
	return Keepout.new(at, forward, Cfg.SCANNER_LENGTH * 0.5,
		Cfg.SCANNER_LENGTH * 0.5, Cfg.SCANNER_HALF_WIDTH_BARE,
		Cfg.SCANNER_HALF_WIDTH)


static func compressor_keepout(at: Vector3, forward: Vector3) -> Keepout:
	return Keepout.new(at, forward, Cfg.COMPRESSOR_LENGTH * 0.5,
		Cfg.COMPRESSOR_LENGTH * 0.5, Cfg.COMPRESSOR_HALF_WIDTH_PANEL,
		Cfg.COMPRESSOR_HALF_WIDTH)


static func wrapper_keepout(at: Vector3, forward: Vector3) -> Keepout:
	return Keepout.new(at, forward, Cfg.WRAPPER_LENGTH * 0.5,
		Cfg.WRAPPER_LENGTH * 0.5, Cfg.WRAPPER_HALF_WIDTH,
		Cfg.WRAPPER_HALF_WIDTH)


static func silo_keepout(at: Vector3, forward: Vector3) -> Keepout:
	return Keepout.new(at, forward, Cfg.SILO_LENGTH * 0.5,
		Cfg.SILO_LENGTH * 0.5, Cfg.SILO_HALF_WIDTH,
		Cfg.SILO_HALF_WIDTH)


static func pulper_keepout(at: Vector3, forward: Vector3) -> Keepout:
	return Keepout.new(at, forward, Cfg.PULPER_LENGTH * 0.5,
		Cfg.PULPER_LENGTH * 0.5, Cfg.PULPER_HALF_WIDTH,
		Cfg.PULPER_HALF_WIDTH)


static func paper_keepout(at: Vector3, forward: Vector3) -> Keepout:
	return Keepout.new(at, forward, Cfg.PAPER_LENGTH * 0.5,
		Cfg.PAPER_LENGTH * 0.5, Cfg.PAPER_HALF_WIDTH,
		Cfg.PAPER_HALF_WIDTH)


static func briquette_keepout(at: Vector3, forward: Vector3) -> Keepout:
	return Keepout.new(at, forward, Cfg.BRIQUETTE_PORT_DISC,
		Cfg.BRIQUETTE_PORT_BRICK, Cfg.BRIQUETTE_HALF_WIDTH,
		Cfg.BRIQUETTE_HALF_WIDTH)


static func keepout_from(at: Vector3, forward: Vector3, plan: Vector4) -> Keepout:
	return Keepout.new(at, forward, plan.x, plan.y, plan.z, plan.w)


static func pelletizer_keepout(at: Vector3, forward: Vector3) -> Keepout:
	return keepout_from(at, forward, Cfg.PELLETIZER_KEEPOUT)


static func generator_keepout(at: Vector3, forward: Vector3) -> Keepout:
	return keepout_from(at, forward, Cfg.GENERATOR_KEEPOUT)


static func gas_plant_keepout(at: Vector3, forward: Vector3) -> Keepout:
	return keepout_from(at, forward, Cfg.GAS_PLANT_KEEPOUT)


static func borehole_keepout(at: Vector3, forward: Vector3) -> Keepout:
	return keepout_from(at, forward, Cfg.BOREHOLE_KEEPOUT)


static func launcher_keepout(at: Vector3, forward: Vector3) -> Keepout:
	return keepout_from(at, forward, Cfg.LAUNCHER_KEEPOUT)


const TERMINUS_TOUCH:= 0.02


static func terminus_keepout(at: Vector3, forward: Vector3, plan: Vector4,
		port_back: float) -> Keepout:
	return Keepout.new(at, forward, plan.x - TERMINUS_TOUCH,
		maxf(plan.y, port_back) - TERMINUS_TOUCH, plan.z - TERMINUS_TOUCH,
		plan.w - TERMINUS_TOUCH)


static func lift_keepout(at: Vector3, forward: Vector3,
		reach: Array = HayLift.PORT_REACH) -> Keepout:
	return Keepout.new(at, forward,
		HayLift.PLAN_Z.y + float(reach [1]) - TERMINUS_TOUCH,
		- HayLift.PLAN_Z.x - TERMINUS_TOUCH,
		HayLift.PLAN_X.y - TERMINUS_TOUCH, - HayLift.PLAN_X.x - TERMINUS_TOUCH)


static func _port_back(at: Vector3, port: Vector3, forward: Vector3) -> float:
	var d:= at - port
	return Vector2(d.x, d.z).dot(Vector2(forward.x, forward.z).normalized())


func _terminus_boxes() -> Array:
	var kept: Variant = ghost_memo(&"terminus_boxes")
	if kept != null:
		return kept
	var out: Array = []
	for gen in generators:
		if is_instance_valid(gen):
			out.append([&"generator", terminus_keepout(gen.global_position, gen.forward(),
				Cfg.GAS_PLANT_KEEPOUT if gen is GasPlant else Cfg.GENERATOR_KEEPOUT,
				_port_back(gen.global_position, gen.intake_port(), gen.forward()))])
	for mill in pelletizers:
		if is_instance_valid(mill):
			out.append([&"pelletizer", terminus_keepout(mill.global_position, mill.forward(),
				Cfg.PELLETIZER_KEEPOUT,
				_port_back(mill.global_position, mill.intake_port(), mill.forward()))])
	for gun in tube_launchers:
		if is_instance_valid(gun):
			out.append([&"launcher", terminus_keepout(gun.global_position, gun.forward(),
				Cfg.LAUNCHER_KEEPOUT,
				_port_back(gun.global_position, gun.intake_port(), gun.forward()))])
	for lift in hay_lifts:
		if is_instance_valid(lift):
			out.append([&"lift", lift_keepout(lift.global_position, lift.forward(),
				lift.port_reach)])
	return ghost_keep(&"terminus_boxes", out)


func _box_hits_termini(ours: Keepout, own: StringName) -> bool:
	for entry: Array in _terminus_boxes():
		if entry [0] != own and keepouts_clash(ours, entry [1]):
			return true
	if own != &"stairs":
		for tower in hay_stairs:
			if is_instance_valid(tower) and disc_hits_keepout(tower.global_position,
					Cfg.HAY_STAIRS_HALF_WIDTH, ours):
				return true
	return false


func _disc_hits_termini(centre: Vector3, radius: float, own: StringName) -> bool:
	for entry: Array in _terminus_boxes():
		if entry [0] != own and disc_hits_keepout(centre, radius, entry [1]):
			return true
	if own != &"stairs":
		for tower in hay_stairs:
			if not is_instance_valid(tower):
				continue
			var gap:= tower.global_position - centre
			if absf(gap.y) <= MODULE_STOREY and Vector2(gap.x, gap.z).length() < radius + Cfg.HAY_STAIRS_HALF_WIDTH:
				return true
	return false


static func module_keepout(node: Node3D) -> Keepout:
	var scanner:= node as HaystackScanner
	if scanner != null:
		return scanner_keepout(scanner.global_position, scanner.forward())
	var press:= node as HayCompressor
	if press != null:
		return compressor_keepout(press.global_position, press.forward())
	var wrap:= node as HayWrapper
	if wrap != null:
		return wrapper_keepout(wrap.global_position, wrap.forward())
	var tank:= node as HaySilo
	if tank != null:
		return silo_keepout(tank.global_position, tank.forward())
	var pulper:= node as HayPulper
	if pulper != null:
		return pulper_keepout(pulper.global_position, pulper.forward())
	var mill:= node as PaperMachine
	if mill != null:
		return paper_keepout(mill.global_position, mill.forward())
	var briquette:= node as BriquettePress
	if briquette != null:
		return briquette_keepout(briquette.global_position, briquette.forward())
	push_error("BuildManager: no keep-clear for %s" % node)
	return Keepout.new(node.global_position, Vector3.BACK, 0.0, 0.0, 0.0, 0.0)


func module_nodes() -> Array [Node3D]:
	var out: Array [Node3D] = []
	out.append_array(scanners)
	out.append_array(compressors)
	out.append_array(wrappers)
	out.append_array(silos)
	out.append_array(pulpers)
	out.append_array(papers)
	out.append_array(briquette_presses)
	return out


static func keepouts_clash(a: Keepout, b: Keepout) -> bool:
	if absf(a.centre.y - b.centre.y) > MODULE_STOREY:
		return false
	var a_side:= a.across()
	var b_side:= b.across()
	var gap:= b.centre - a.centre
	for axis: Vector3 in [a.fwd, a_side, b.fwd, b_side]:
		var reach:= a.half_len * absf(a.fwd.dot(axis)) + a.half_w * absf(a_side.dot(axis)) + b.half_len * absf(b.fwd.dot(axis)) + b.half_w * absf(b_side.dot(axis))
		if absf(gap.dot(axis)) > reach:
			return false
	return true


static func disc_hits_keepout(centre: Vector3, radius: float, box: Keepout) -> bool:
	if absf(centre.y - box.centre.y) > MODULE_STOREY:
		return false
	var side:= box.across()
	var gap:= centre - box.centre
	var along:= clampf(gap.dot(box.fwd), - box.half_len, box.half_len)
	var across:= clampf(gap.dot(side), - box.half_w, box.half_w)
	var near:= box.centre + box.fwd * along + side * across
	return Vector2(centre.x - near.x, centre.z - near.z).length() < radius


func module_clash(ours: Keepout, ignore: Node3D = null, own: StringName = &"") -> bool:
	for node: Node3D in module_nodes():
		if node == ignore or not is_instance_valid(node):
			continue
		if keepouts_clash(ours, module_keepout(node)):
			return true
	var wyes: Array [Node3D] = []
	wyes.append_array(splitters)
	wyes.append_array(joiners)
	for wye: Node3D in wyes:
		if not is_instance_valid(wye):
			continue
		for d: Vector4 in wye.call("footprint"):
			if disc_hits_keepout(_disc_centre(d), d.w, ours):
				return true
	if _post_in_keepout(ours):
		return true
	return _box_hits_termini(ours, own)


func scanner_overlap(at: Vector3, forward: Vector3 = Vector3.BACK,
		ignore: HaystackScanner = null) -> bool:
	return module_clash(scanner_keepout(at, forward), ignore)


func compressor_overlap(at: Vector3, forward: Vector3 = Vector3.BACK,
		ignore: HayCompressor = null) -> bool:
	return module_clash(compressor_keepout(at, forward), ignore)


func pulper_overlap(at: Vector3, forward: Vector3 = Vector3.BACK,
		ignore: HayPulper = null) -> bool:
	return module_clash(pulper_keepout(at, forward), ignore)


func paper_overlap(at: Vector3, forward: Vector3 = Vector3.BACK,
		ignore: PaperMachine = null) -> bool:
	return module_clash(paper_keepout(at, forward), ignore)


func briquette_overlap(at: Vector3, forward: Vector3 = Vector3.BACK,
		ignore: BriquettePress = null) -> bool:
	return module_clash(briquette_keepout(at, forward), ignore)


func wrapper_overlap(at: Vector3, forward: Vector3 = Vector3.BACK,
		ignore: HayWrapper = null) -> bool:
	return module_clash(wrapper_keepout(at, forward), ignore)


func silo_overlap(at: Vector3, forward: Vector3 = Vector3.BACK,
		ignore: HaySilo = null) -> bool:
	return module_clash(silo_keepout(at, forward), ignore)


func show_rake_range(only: PistonRake) -> void:
	for rake in piston_rakes:
		if is_instance_valid(rake):
			rake.show_range(rake == only)


func show_mill_range(only: HayPelletizer) -> void:
	for mill in pelletizers:
		if is_instance_valid(mill):
			mill.show_range(mill == only)


const REACH_KINDS:= ["drone", "rake", "arm", "pelletizer"]


func show_reach(near: Vector3, within: float, kind: String) -> void:
	for machine in _reach_machines(kind):
		machine.call("show_range", within > 0.0
			and (machine as Node3D).global_position.distance_to(near) <= within)


func has_reach_marks(kind: String) -> bool:
	return not _reach_machines(kind).is_empty()


func _reach_machines(kind: String) -> Array [Node3D]:
	var out: Array [Node3D] = []
	var from: Array = []
	match kind:
		"drone": from = hay_drones
		"rake": from = piston_rakes
		"arm": from = robotic_arms
		"pelletizer": from = pelletizers
		_: return out
	for machine: Node3D in from:
		if is_instance_valid(machine):
			out.append(machine)
	return out


func rake_under(from: Vector3, look: Vector3) -> PistonRake:
	if not is_inside_tree():
		return null
	var query:= PhysicsRayQueryParameters3D.create(
		from, from + look.normalized() * Cfg.RAKE_CONSOLE_REACH, Cfg.L_BUILD)
	var hit:= get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null


	var node:= hit.get("collider") as Node
	while node != null:
		var rake:= node as PistonRake
		if rake != null:
			return rake if piston_rakes.has(rake) else null
		node = node.get_parent()
	return null


func launcher_under(from: Vector3, look: Vector3) -> TubeLauncher:
	if not is_inside_tree():
		return null
	var query:= PhysicsRayQueryParameters3D.create(
		from, from + look.normalized() * Cfg.LAUNCHER_CONSOLE_REACH, Cfg.L_BUILD)
	var hit:= get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null


	var node:= hit.get("collider") as Node
	while node != null:
		var gun:= node as TubeLauncher
		if gun != null:
			return gun if tube_launchers.has(gun) else null
		node = node.get_parent()
	return null


func lamp_under(from: Vector3, look: Vector3) -> WorkLamp:
	if not is_inside_tree():
		return null
	var query:= PhysicsRayQueryParameters3D.create(
		from, from + look.normalized() * Cfg.WORK_LAMP_CONSOLE_REACH, Cfg.L_BUILD)
	var hit:= get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var node:= hit.get("collider") as Node
	while node != null:
		var lamp:= node as WorkLamp
		if lamp != null:
			return lamp if work_lamps.has(lamp) else null
		node = node.get_parent()
	return null


func silo_under(from: Vector3, look: Vector3) -> HaySilo:
	if not is_inside_tree():
		return null
	var query:= PhysicsRayQueryParameters3D.create(
		from, from + look.normalized() * Cfg.SILO_CONSOLE_REACH, Cfg.L_BUILD)
	var hit:= get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null


	var node:= hit.get("collider") as Node
	while node != null:
		var tank:= node as HaySilo
		if tank != null:
			return tank if silos.has(tank) else null
		node = node.get_parent()
	return null


func splitter_under(from: Vector3, look: Vector3) -> ConveyorSplitter:
	if not is_inside_tree():
		return null
	var query:= PhysicsRayQueryParameters3D.create(
		from, from + look.normalized() * Cfg.SPLITTER_CONSOLE_REACH, Cfg.L_BUILD)
	var hit:= get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var splitter:= owner_of(hit.get("collider") as Node) as ConveyorSplitter
	return splitter if splitter != null and splitters.has(splitter) else null


func arm_under(from: Vector3, look: Vector3) -> RoboticArm:
	if not is_inside_tree():
		return null
	var query:= PhysicsRayQueryParameters3D.create(
		from, from + look.normalized() * Cfg.ROBOT_ARM_CONSOLE_REACH, Cfg.L_BUILD)
	query.collide_with_areas = true
	var hit:= get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var arm:= owner_of(hit.get("collider") as Node) as RoboticArm
	return arm if arm != null and robotic_arms.has(arm) else null


func powered_under(from: Vector3, look: Vector3) -> Node3D:
	if not is_inside_tree():
		return null
	var query:= PhysicsRayQueryParameters3D.create(
		from, from + look.normalized() * Cfg.POWERED_CONSOLE_REACH, Cfg.L_BUILD)
	query.collide_with_areas = true
	var hit:= get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var found:= owner_of(hit.get("collider") as Node)
	if found == null:
		return null
	if found is HayCompressor and compressors.has(found):
		return found
	if found is HayPulper and pulpers.has(found):
		return found
	if found is PaperMachine and papers.has(found):
		return found
	if found is BriquettePress and briquette_presses.has(found):
		return found
	if found is HayWrapper and wrappers.has(found):
		return found
	if found is HayPelletizer and pelletizers.has(found):
		return found
	if found is HayDrone and hay_drones.has(found):
		return found
	if found is HayGenerator and generators.has(found):
		return found
	if found is BoreholePump and boreholes.has(found):
		return found
	return null


func pole_under(from: Vector3, look: Vector3) -> PowerPole:
	if not is_inside_tree():
		return null
	var query:= PhysicsRayQueryParameters3D.create(
		from, from + look.normalized() * Cfg.POWERED_CONSOLE_REACH, Cfg.L_BUILD)
	var hit:= get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var pole:= owner_of(hit.get("collider") as Node) as PowerPole
	return pole if pole != null and power_poles.has(pole) else null


func console_under(from: Vector3, look: Vector3) -> Node3D:
	if look == Vector3.ZERO:
		return null
	var gun:= launcher_under(from, look)
	if gun != null:
		return gun
	var tank:= silo_under(from, look)
	if tank != null:
		return tank
	var rake:= rake_under(from, look)
	if rake != null:
		return rake
	var splitter:= splitter_under(from, look)
	if splitter != null:
		return splitter
	var arm:= arm_under(from, look)
	if arm != null:
		return arm
	var lamp:= lamp_under(from, look)
	if lamp != null:
		return lamp
	var pole:= pole_under(from, look)
	if pole != null:
		return pole
	return powered_under(from, look)


func scanner_under(from: Vector3, look: Vector3) -> HaystackScanner:
	if look == Vector3.ZERO or not is_inside_tree():
		return null
	var query:= PhysicsRayQueryParameters3D.create(
		from, from + look.normalized() * Cfg.POWERED_CONSOLE_REACH, Cfg.L_BUILD)
	var hit:= get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var scanner:= owner_of(hit.get("collider") as Node) as HaystackScanner
	return scanner if scanner != null and scanners.has(scanner) else null


func snap_deck_corner(corner: Vector2, at_height: float) -> Vector2:
	return Vector2(snap_deck_axis(corner.x, 0, at_height),
		snap_deck_axis(corner.y, 1, at_height))


func snap_deck_axis(value: float, axis: int, at_height: float,
		side: int = 0, across: Vector2 = Vector2.INF) -> float:
	var edge:= deck_edge_near(value, axis, at_height, side, across)
	return value if is_nan(edge) else edge


func deck_edge_near(value: float, axis: int, at_height: float,
		side: int = 0, across: Vector2 = Vector2.INF) -> float:
	var out:= NAN
	var best:= Cfg.PLATFORM_SNAP_RADIUS
	var other:= 1 - axis
	for deck in platforms:
		if not is_instance_valid(deck):
			continue


		if absf(deck.top_y() - at_height) >= SNAP_HEIGHT_BAND:
			continue
		var rect:= deck.footprint()
		if across != Vector2.INF:


			if rect.position [other] - Cfg.PLATFORM_SNAP_RADIUS > across.y or rect.end [other] + Cfg.PLATFORM_SNAP_RADIUS < across.x:
				continue
		var edges: Array [float] = []
		if side >= 0:
			edges.append(rect.end [axis])
		if side <= 0:
			edges.append(rect.position [axis])
		for edge: float in edges:
			var d:= absf(value - edge)
			if d < best:
				best = d
				out = edge
	return out


const SNAP_HEIGHT_BAND:= Cfg.PLATFORM_THICK


func snap_deck_height(at: Vector3) -> float:
	var out:= at.y
	var best:= SNAP_HEIGHT_BAND
	var here:= Vector2(at.x, at.z)
	for deck in platforms:
		if not is_instance_valid(deck):
			continue
		var dy:= absf(deck.top_y() - at.y)
		if dy >= best:
			continue


		var rect:= deck.footprint().grow(Cfg.PLATFORM_SNAP_RADIUS)
		if not rect.has_point(here):
			continue
		best = dy
		out = deck.top_y()
	return out


func deck_extent(target: float, tile_min: float, tile_span: float, axis: int,
		height: float, across: Vector2 = Vector2.INF) -> Vector2:
	var tile_max:= tile_min + tile_span
	if target > tile_max:


		var hi:= tile_min + Platform.quantise(target - tile_min)
		return Vector2(tile_min, _snap_edge(hi, tile_min, axis, height, -1, across))
	if target < tile_min:
		var lo:= tile_max - Platform.quantise(tile_max - target)
		return Vector2(_snap_edge(lo, tile_max, axis, height, 1, across), tile_max)
	return Vector2(tile_min, tile_max)


func _snap_edge(edge: float, fixed: float, axis: int, height: float,
		side: int = 0, across: Vector2 = Vector2.INF) -> float:
	var snapped:= snap_deck_axis(edge, axis, height, side, across)
	if absf(snapped - fixed) < Cfg.PLATFORM_MIN_SPAN:
		return edge
	if signf(snapped - fixed) != signf(edge - fixed):
		return edge
	return snapped


func snap_railing_point(point: Vector3) -> Vector3:
	var out:= point
	var best:= Cfg.RAILING_SNAP_RADIUS
	for deck in platforms:
		if not is_instance_valid(deck):
			continue
		if absf(deck.top_y() - point.y) > Cfg.PLATFORM_RAIL_H:
			continue
		var rect:= deck.footprint()
		for cx: float in [rect.position.x, rect.end.x]:
			for cz: float in [rect.position.y, rect.end.y]:
				var corner:= Vector3(cx, deck.top_y(), cz)
				var d:= Vector2(point.x - cx, point.z - cz).length()
				if d < best:
					best = d
					out = corner
	if best < Cfg.RAILING_SNAP_RADIUS:
		return out
	for deck in platforms:
		if not is_instance_valid(deck):
			continue
		if absf(deck.top_y() - point.y) > Cfg.PLATFORM_RAIL_H:
			continue
		var edge: Dictionary = deck.nearest_edge(point)
		var candidate: Vector3 = edge ["point"]
		var d:= Vector2(point.x - candidate.x, point.z - candidate.z).length()
		if d < best:
			best = d
			out = candidate
	return out


func railing_unsupported(from: Vector3, to: Vector3,
		mask: int = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD) -> bool:
	if not is_inside_tree():
		return false
	if _support_probe == null:
		_support_probe = BoxShape3D.new()
		_support_probe.size = Vector3(0.25, 0.3, 0.25)
		_support_query = PhysicsShapeQueryParameters3D.new()
		_support_query.shape = _support_probe
		_support_query.collide_with_areas = false
	_support_query.collision_mask = mask
	var space:= get_world_3d().direct_space_state
	var length:= from.distance_to(to)


	var n:= maxi(2, int(ceil(length / 1.0))) if length > 1e-06 else 0
	for i in n + 1:
		var at:= from.lerp(to, float(i) / float(n)) if n > 0 else from
		_support_query.transform = Transform3D(Basis(),
			at - Vector3(0.0, RAILING_PROBE_DROP, 0.0))
		if space.intersect_shape(_support_query, 1).is_empty():
			return true
	return false


func railing_blocked(from: Vector3, to: Vector3) -> bool:
	return _run_blocked(from, to, 0.15, Cfg.PLATFORM_RAIL_H, 0.06)


func wall_blocked(from: Vector3, to: Vector3,
		kind: YardWall.Bay = YardWall.Bay.SOLID) -> bool:
	var end:= YardWall.end_for(from, to, kind)
	if _run_blocked(from, end, 0.15, Cfg.WALL_HEIGHT - 0.6, 0.04):
		return true
	var flat:= Vector2(end.x - from.x, end.z - from.z)
	var length:= flat.length()
	if length < 0.5:
		return false
	var n:= int(ceil(length / 0.1))
	for deck in platforms:
		if not is_instance_valid(deck):
			continue
		var rise:= deck.top_y() - from.y
		if rise < 0.15 or rise > Cfg.WALL_HEIGHT - 0.05:
			continue
		var rect:= deck.footprint().grow(-0.1)
		for i in range(1, n):
			var t:= float(i) / float(n)
			if t * length < 0.25 or (1.0 - t) * length < 0.25:
				continue
			if rect.has_point(Vector2(from.x, from.z) + flat * t):
				return true
	return false


func _run_blocked(from: Vector3, to: Vector3, lift: float, top: float,
		thick: float) -> bool:
	if not is_inside_tree():
		return false
	var flat:= Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length:= flat.length()
	var clear:= length - 0.5
	if clear <= 0.05 or top <= lift:
		return false
	var dir:= flat / length
	var box:= BoxShape3D.new()
	box.size = Vector3(thick, top - lift, clear)
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collide_with_areas = false
	q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD | Cfg.L_KEEPOUT
	var mid:= from + flat * 0.5 + Vector3(0.0, lift + box.size.y * 0.5, 0.0)
	q.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), mid)
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func railing_overlap(from: Vector3, to: Vector3) -> bool:
	for rail in railings:
		if not is_instance_valid(rail):
			continue
		if rail.covers(from) and rail.covers(to) and rail.covers((from + to) * 0.5):
			return true
	return false


func snap_wall_point(point: Vector3) -> Vector3:


	var post: Variant = nearest_wall_post(point)
	if post != null:
		return post
	return snap_railing_point(point)


func nearest_wall_post(point: Vector3) -> Variant:
	var best_flat:= Cfg.WALL_SNAP_RADIUS
	var best_rise:= INF
	var out: Variant = null
	for wall in walls:
		if not is_instance_valid(wall):
			continue

		for course: float in [0.0, Cfg.WALL_COURSE]:
			var level:= wall.a.y + course
			var rise:= absf(point.y - level)
			if rise > Cfg.WALL_SNAP_RISE:
				continue
			for post: Vector3 in wall.post_points():
				var flat:= Vector2(point.x - post.x, point.z - post.z).length()
				if flat >= Cfg.WALL_SNAP_RADIUS:
					continue
				if rise < best_rise - 0.01 or (absf(rise - best_rise) <= 0.01 and flat < best_flat):
					best_rise = rise
					best_flat = flat
					out = Vector3(post.x, level, post.z)
	return out


func snap_roof_point(point: Vector3) -> Vector3:
	var joint: Variant = nearest_roof_joint(point)
	if joint != null:
		return joint
	return snap_wall_point(point)


func enclosed_side(at: Vector3, right: Vector3) -> int:
	if not is_inside_tree():
		return 0
	var flat:= Vector3(right.x, 0.0, right.z)
	if flat.length_squared() < 1e-06:
		return 0
	flat = flat.normalized()
	var space:= get_world_3d().direct_space_state
	var best:= INF
	var out:= 0
	for sign: int in [1, -1]:
		var dir:= flat * float(sign)


		var from:= at + dir * 0.35 - Vector3(0.0, 0.5, 0.0)
		var q:= PhysicsRayQueryParameters3D.create(from,
			from + dir * Cfg.ROOF_ENCLOSURE_REACH)
		q.collision_mask = Cfg.L_BUILD
		q.collide_with_areas = false
		var hit:= space.intersect_ray(q)
		if hit.is_empty():
			continue
		var d: float = from.distance_to(hit ["position"] as Vector3)
		if d < best:
			best = d
			out = sign
	return out


func roof_sockets() -> Array [Vector3]:
	var out: Array [Vector3] = []
	for wall in walls:
		if not is_instance_valid(wall):
			continue
		for post: Vector3 in wall.post_points():
			out.append(post + Vector3(0.0, Cfg.WALL_HEIGHT, 0.0))
	for lid in roofs:
		if not is_instance_valid(lid):
			continue
		out.append_array(lid.joint_points())
	return out


func aimed_roof_socket(eye: Vector3, look: Vector3, reach: float) -> Variant:
	var dir:= look.normalized()
	if dir.length_squared() < 0.5:
		return null
	var limit:= reach + Cfg.ROOF_AIM_OVERREACH
	var best:= INF
	var out: Variant = null
	for socket in roof_sockets():
		var to:= socket - eye
		var along:= to.dot(dir)
		if along < 0.4 or along > limit:
			continue
		var off:= (to - dir * along).length()
		if off > Cfg.ROOF_AIM_RADIUS:
			continue
		var angle:= off / along
		if angle < best:
			best = angle
			out = socket
	return out


func nearest_roof_joint(point: Vector3) -> Variant:
	var best:= Cfg.ROOF_SNAP_RADIUS
	var out: Variant = null
	for lid in roofs:
		if not is_instance_valid(lid):
			continue
		if absf(point.y - lid.a.y) > Cfg.ROOF_RISE + 0.05:
			continue
		for joint: Vector3 in lid.joint_points():
			var flat:= Vector2(point.x - joint.x, point.z - joint.z).length()
			if flat < best:
				best = flat
				out = joint
	return out


func roof_unsupported(from: Vector3, to: Vector3, kind: Roof.Kind,
		side: int, rows: int = 1) -> bool:
	var end:= Roof.end_for(from, to, kind)
	var dir:= end - from
	dir.y = 0.0
	if dir.length_squared() < 1e-06:
		return railing_unsupported(from, end, Cfg.L_BUILD)
	dir = dir.normalized()
	var across:= Vector3(dir.z, 0.0, - dir.x) * (float(sign(side) if side != 0 else 1) * Cfg.ROOF_DEPTH
			* float(maxi(1, rows)))
	for edge: Array in [[from, end], [from + across, end + across],
			[from, from + across], [end, end + across]]:
		if not railing_unsupported(edge [0] as Vector3, edge [1] as Vector3,
				Cfg.L_BUILD):
			return false
	return true


func hatch_drop(from: Vector3, to: Vector3, side: int, skip: CollisionObject3D = null) -> float:
	if not is_inside_tree():
		return Cfg.LADDER_MAX_DROP
	var space:= get_world_3d().direct_space_state
	var least:= Cfg.LADDER_MAX_DROP
	for top: Vector3 in Roof.hatch_drop_points(from, to, side):


		var start:= top + Vector3(0.0, 0.05, 0.0)
		var q:= PhysicsRayQueryParameters3D.create(start,
			start - Vector3(0.0, Cfg.LADDER_MAX_DROP, 0.0))

		q.collision_mask = Cfg.L_WORLD | Cfg.L_PILE | Cfg.L_BUILD
		q.collide_with_areas = false
		if skip != null:
			q.exclude = [skip.get_rid()]
		var hit:= space.intersect_ray(q)
		if not hit.is_empty():
			least = minf(least, maxf(0.0, top.y - (hit ["position"] as Vector3).y))
	return least


func roof_lying_at(point: Vector3) -> Roof:
	for lid in roofs:
		if not is_instance_valid(lid) or lid.pitched() or lid.length < 1e-06:
			continue
		if absf(point.y - lid.a.y) > 0.08:
			continue
		var dir:= lid.b - lid.a
		dir.y = 0.0
		dir = dir.normalized()
		var right:= Vector3(dir.z, 0.0, - dir.x) * float(lid.side)
		var rel:= point - lid.a
		var t:= rel.dot(dir)
		var u:= rel.dot(right)
		if t >= -0.01 and t <= lid.length + 0.01 and u >= -0.01 and u <= lid.depth() + 0.01:
			return lid
	return null


func roof_overlap(from: Vector3, to: Vector3, kind: Roof.Kind) -> bool:
	var end:= Roof.end_for(from, to, kind)
	for lid in roofs:
		if not is_instance_valid(lid):
			continue
		if lid.covers(from) and lid.covers(end) and lid.covers((from + end) * 0.5):
			return true
	return false


func roof_blocked(from: Vector3, to: Vector3, kind: Roof.Kind,
		side: int, rows: int = 1) -> bool:
	if not is_inside_tree():
		return false
	var end:= Roof.end_for(from, to, kind)
	var dir:= end - from
	dir.y = 0.0
	var length:= dir.length()
	if length < 1e-06:
		return false
	dir /= length
	var deep:= 1 if kind == Roof.Kind.HATCH else maxi(1, rows)
	var right:= Vector3(dir.z, 0.0, - dir.x) * float(-1 if side < 0 else 1)
	var rise:= Cfg.ROOF_RISE * float(deep) if kind == Roof.Kind.PITCHED else 0.0
	var slope:= right * (Cfg.ROOF_DEPTH * float(deep)) + Vector3.UP * rise
	var up_slope:= slope.normalized()
	var normal:= dir.cross(up_slope)
	if normal.y < 0.0:
		normal = - normal
	var inset:= 0.25
	var box:= BoxShape3D.new()
	box.size = Vector3(slope.length() - inset * 2.0, 0.1, length - inset * 2.0)
	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return false
	var q:= PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collide_with_areas = false
	q.collision_mask = Cfg.L_WORLD | Cfg.L_BUILD
	var centre:= (from + end) * 0.5 + slope * 0.5 + normal * 0.1
	q.transform = Transform3D(Basis(up_slope, normal, up_slope.cross(normal)), centre)
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func roof_through_deck(from: Vector3, to: Vector3, kind: Roof.Kind,
		side: int, rows: int = 1) -> bool:
	var end:= Roof.end_for(from, to, kind)
	var dir:= end - from
	dir.y = 0.0
	if dir.length_squared() < 1e-06:
		return false
	dir = dir.normalized()
	var deep:= 1 if kind == Roof.Kind.HATCH else maxi(1, rows)
	var right:= Vector3(dir.z, 0.0, - dir.x) * float(-1 if side < 0 else 1)
	var inset:= 0.05
	var along:= dir * inset
	var inward:= right * inset
	var far:= right * (Cfg.ROOF_DEPTH * float(deep))
	var sheet:= PackedVector2Array()
	for p: Vector3 in [from + along + inward, end - along + inward,
			end - along + far - inward, from + along + far - inward]:
		sheet.append(Vector2(p.x, p.z))


	var rise:= Cfg.ROOF_RISE * float(deep) if kind == Roof.Kind.PITCHED else 0.0
	for deck in platforms:
		if not is_instance_valid(deck):
			continue
		var y:= deck.top_y()
		if y < from.y - Cfg.PLATFORM_THICK or y > from.y + rise + 0.05:
			continue
		var rect:= deck.footprint()
		var plate:= PackedVector2Array([rect.position,
			Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)])
		if not Geometry2D.intersect_polygons(sheet, plate).is_empty():
			return true
	return false


func wall_unsupported(from: Vector3, to: Vector3,
		kind: YardWall.Bay = YardWall.Bay.SOLID) -> bool:
	return railing_unsupported(from, YardWall.end_for(from, to, kind))


func wall_overlap(from: Vector3, to: Vector3,
		kind: YardWall.Bay = YardWall.Bay.SOLID) -> bool:
	var end:= YardWall.end_for(from, to, kind)
	for wall in walls:
		if not is_instance_valid(wall):
			continue
		if wall.covers(from) and wall.covers(end) and wall.covers((from + end) * 0.5):
			return true
	return false


func deck_height_at(collider: Node) -> Variant:
	var deck:= owner_of(collider) as Platform
	return deck.top_y() if deck != null else null


func deck_overlap(rect: Rect2, at_height: float, ignore: Platform = null) -> bool:
	for deck in platforms:
		if deck == ignore or not is_instance_valid(deck):
			continue
		if absf(deck.top_y() - at_height) > Cfg.PLATFORM_THICK:
			continue
		if deck.footprint().intersects(rect):
			return true
	return false


func standing_on(deck: Node3D) -> Array [Node3D]:
	var out: Array [Node3D] = []
	var on_roof:= deck is Roof
	for c in conveyors:
		if deck.supports_point(c.a) or deck.supports_point(c.b):
			out.append(c)
	for run in water_mains:
		if deck.supports_point(run.a) or deck.supports_point(run.b):
			out.append(run)
	for rail in railings:
		if on_roof:
			break
		if deck.supports_point(rail.a) or deck.supports_point(rail.b):
			out.append(rail)
	for wall in walls:
		if on_roof:
			break
		if deck.supports_point(wall.a) or deck.supports_point(wall.b):
			out.append(wall)
	for lid in roofs:
		if on_roof:
			break
		if deck.supports_point(lid.a) or deck.supports_point(lid.b):
			out.append(lid)


	for group: Array in [robotic_arms, stairs, scanners, compressors, pulpers,
			papers, briquette_presses, wrappers, silos, pelletizers, generators,
			boreholes, power_poles, tube_launchers, dump_hatches, hay_stairs,
			hay_lifts, splitters, joiners, cabinets, needle_radars, paint_boards,
			work_lamps, hay_drones, piston_rakes, water_splitters]:
		for building: Node3D in group:
			if is_instance_valid(building) and deck.supports_point(building.global_position):
				out.append(building)


	return out


func arm_reach_conflict(at: Vector3, tier: int, skip: RoboticArm = null) -> bool:
	var tier_id:= clampi(tier, 0, Cfg.ROBOT_ARM_TIERS.size() - 1)
	var candidate: Dictionary = Cfg.ROBOT_ARM_TIERS [tier_id]
	var candidate_scale:= float(candidate ["scale"])
	var candidate_origin:= at + Vector3.UP * RoboticArm.SHOULDER_HEIGHT * candidate_scale
	var candidate_reach:= float(candidate ["reach"])
	for arm in robotic_arms:
		if not is_instance_valid(arm) or arm == skip:
			continue
		var existing_origin:= arm.global_position + Vector3.UP * RoboticArm.SHOULDER_HEIGHT * arm.visual_scale()


		var exclusion_radius:= maxf(candidate_reach, arm.reach_m())
		var near:= candidate_origin.distance_to(existing_origin) <= exclusion_radius
		if yard_memo_enabled and not near:
			continue
		if _plate_between(at, arm.global_position):
			continue
		if near:
			return true
	return false


func arm_reach_neighbours(at: Vector3, tier: int, margin: float) -> Array [Dictionary]:
	var out: Array [Dictionary] = []
	var tier_id:= clampi(tier, 0, Cfg.ROBOT_ARM_TIERS.size() - 1)
	var candidate: Dictionary = Cfg.ROBOT_ARM_TIERS [tier_id]
	var candidate_origin:= at + Vector3.UP * RoboticArm.SHOULDER_HEIGHT * float(candidate ["scale"])
	var candidate_reach:= float(candidate ["reach"])
	var foot:= Vector2(at.x, at.z)
	for arm in robotic_arms:
		if not is_instance_valid(arm):
			continue
		var existing_origin:= arm.global_position + Vector3.UP * RoboticArm.SHOULDER_HEIGHT * arm.visual_scale()
		var exclusion_radius:= maxf(candidate_reach, arm.reach_m())
		var rise:= existing_origin.y - candidate_origin.y
		if absf(rise) >= exclusion_radius:
			continue
		var radius:= sqrt(exclusion_radius * exclusion_radius - rise * rise)
		var centre:= Vector2(arm.global_position.x, arm.global_position.z)
		if foot.distance_to(centre) > radius + margin:
			continue
		if _plate_between(at, arm.global_position):
			continue
		out.append({ "arm": arm, "radius": radius,
			"blocking": candidate_origin.distance_to(existing_origin) <= exclusion_radius })
	return out


func _plate_between(a: Vector3, b: Vector3) -> bool:
	var low:= a if a.y <= b.y else b
	var high:= b if a.y <= b.y else a
	for deck in platforms:
		if not is_instance_valid(deck):
			continue
		if deck.top_y() <= low.y + 0.05 or deck.top_y() > high.y + 0.05:
			continue
		if deck.footprint().has_point(Vector2(low.x, low.z)):
			return true
	return false


static func arm_deck_clash(at: Vector3, scale: float, rect: Rect2, top_y: float) -> bool:
	var top:= top_y - at.y
	var under:= top - Cfg.PLATFORM_THICK
	if top <= 0.05:
		return false
	var p:= Vector2(at.x, at.z)
	var nearest:= Vector2(clampf(p.x, rect.position.x, rect.end.x),
		clampf(p.y, rect.position.y, rect.end.y))
	var out:= p.distance_to(nearest)
	if out <= RoboticArm.AIM_RADIUS * scale:
		return under < RoboticArm.AIM_HEIGHT * scale
	if top <= RoboticArm.SHOULDER_HEIGHT * scale:
		return false
	return under < RoboticArm.boom_ceiling(out / scale) * scale


func arm_through_deck(rect: Rect2, top_y: float) -> RoboticArm:
	for arm in robotic_arms:
		if is_instance_valid(arm) and arm_deck_clash(arm.global_position,
				arm.visual_scale(), rect, top_y):
			return arm
	return null


static func hatch_deck_clash(at: Vector3, yaw: float, rect: Rect2,
		top_y: float) -> bool:

	if at.y >= top_y - 0.02 or at.y + DumpHatch.AIM_SIZE.y <= top_y - Cfg.PLATFORM_THICK:
		return false


	var ax:= Vector2(cos(yaw), - sin(yaw))
	var az:= Vector2(sin(yaw), cos(yaw))
	var half:= Vector2(DumpHatch.AIM_SIZE.x, DumpHatch.AIM_SIZE.z) * 0.5
	var c:= Vector2(at.x, at.z) + az * DumpHatch.AIM_CENTRE.z
	var corners: Array [Vector2] = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			corners.append(c + ax * half.x * sx + az * half.y * sz)
	var box: Array [Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)]
	for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN, ax, az]:
		var lo_a:= INF
		var hi_a:= - INF
		for p in corners:
			lo_a = minf(lo_a, p.dot(axis))
			hi_a = maxf(hi_a, p.dot(axis))
		var lo_b:= INF
		var hi_b:= - INF
		for p in box:
			lo_b = minf(lo_b, p.dot(axis))
			hi_b = maxf(hi_b, p.dot(axis))
		if hi_a <= lo_b + 0.01 or hi_b <= lo_a + 0.01:
			return false
	return true


func hatch_through_deck(rect: Rect2, top_y: float) -> DumpHatch:
	for tip in dump_hatches:
		if is_instance_valid(tip) and hatch_deck_clash(tip.global_position,
				tip.global_rotation.y, rect, top_y):
			return tip
	return null


func deck_through_hatch(at: Vector3, yaw: float) -> Platform:
	for deck in platforms:
		if is_instance_valid(deck) and hatch_deck_clash(at, yaw, deck.footprint(),
				deck.top_y()):
			return deck
	return null


func deck_through_arm(at: Vector3, tier: int) -> Platform:
	var tier_id:= clampi(tier, 0, Cfg.ROBOT_ARM_TIERS.size() - 1)
	var scale:= float(Cfg.ROBOT_ARM_TIERS [tier_id] ["scale"])
	for deck in platforms:
		if is_instance_valid(deck) and arm_deck_clash(at, scale, deck.footprint(),
				deck.top_y()):
			return deck
	return null


func owner_of(node: Node) -> Node3D:
	var n:= node
	while n != null:


		if n is Conveyor and conveyors.has(n):
			return n as Node3D
		if n is ConveyorCorner:
			return _feeder_of(n as ConveyorCorner)
		if n is RoboticArm:
			return n as Node3D
		if n is Platform:
			return n as Node3D
		if n is Stair:
			return n as Node3D
		if n is Railing:
			return n as Node3D
		if n is YardWall:
			return n as Node3D
		if n is Roof:
			return n as Node3D
		if n is HaystackScanner:
			return n as Node3D
		if n is HayCompressor:
			return n as Node3D
		if n is HayPulper:
			return n as Node3D
		if n is PaperMachine:
			return n as Node3D


		if n is BriquettePress:
			return n as Node3D
		if n is HayPelletizer:
			return n as Node3D


		if n is HayGenerator:
			return n as Node3D


		if n is PowerPole:
			return n as Node3D


		if n is BoreholePump:
			return n as Node3D


		if n is WaterMain:
			return n as Node3D


		if n is WaterSplitter:
			return n as Node3D


		if n is TubeLauncher:
			return n as Node3D


		if n is HayWrapper:
			return n as Node3D


		if n is HaySilo:
			return n as Node3D
		if n is PistonRake:
			return n as Node3D
		if n is HayStairs:
			return n as Node3D
		if n is HayLift:
			return n as Node3D


		if n is ConveyorSplitter:
			return n as Node3D


		if n is ConveyorJoiner:
			return n as Node3D


		if n is DumpHatch:
			return n as Node3D
		if n is NeedleCabinet:
			return n as Node3D
		if n is NeedleRadar:
			return n as Node3D


		if n is PaintBoard:
			return n as Node3D


		if n is WorkLamp:
			return n as Node3D
		if n is HayDrone:
			return n as Node3D
		if n == self:
			return null
		n = n.get_parent()
	return null


func name_of(building: Node3D) -> String:
	var id:= id_of(building)
	return BuildCatalog.display_name(id) if id != "" else ""


func id_of(building: Node3D) -> String:
	if building == null or not is_instance_valid(building):
		return ""
	var wall:= building as YardWall
	if wall != null:
		match wall.kind:
			YardWall.Bay.WINDOW:
				return "wall_window"
			YardWall.Bay.DOOR:
				return "wall_door"
			_:
				return "wall"
	var lid:= building as Roof
	if lid != null:
		match lid.kind:
			Roof.Kind.PITCHED:
				return "roof_pitch"
			Roof.Kind.HATCH:
				return "roof_hatch"
			_:
				return "roof"


	if building is EnclosedConveyor:
		return "enclosed_belt"
	if building is Conveyor:
		return "belt"
	if building is WaterMain:
		return "pipe"
	if building is BoreholePump:
		return "borehole"
	if building is WaterSplitter:
		return "water_splitter"
	if building is HayPulper:
		return "pulper"
	if building is PaperMachine:
		return "paper_machine"
	if building is BriquettePress:
		return "briquette_press"
	if building is RoboticArm:
		return BuildCatalog.arm_id_for_tier((building as RoboticArm).tier_index)
	if building is HayDrone:
		return "drone"
	if building is Platform:
		return "deck"
	if building is Stair:
		return "stair"
	if building is Railing:
		return "rail"


	if building is ConveyorTSplitter:
		return "t_splitter"
	if building is ConveyorUSplitter:
		return "u_splitter"
	if building is ConveyorCompactSplitter:
		return "smart_splitter" if (building as ConveyorCompactSplitter).smart else "compact_splitter"
	if building is ConveyorSplitter:
		return "splitter"

	if building is ConveyorTJoiner:
		return "t_splitter"
	if building is ConveyorUJoiner:
		return "u_joiner"
	if building is ConveyorJoiner:
		return "joiner"
	if building is HaystackScanner:
		return "scanner"
	if building is HayCompressor:
		return "compressor"
	if building is HayWrapper:
		return "wrapper"
	if building is PistonRake:
		return "rake"
	if building is HayPelletizer:
		return "pelletizer"


	if building is GasPlant:
		return "gas_plant"
	if building is HayGenerator:
		return "generator"

	if building is PowerBox:
		return "box"
	if building is PowerPole:
		return "pole"
	if building is DumpHatch:
		return "hatch"
	if building is TubeLauncher:
		return "launcher"
	if building is HaySilo:
		return "silo"
	if building is HayStairs:
		return "haystairs"
	if building is HayLift:
		return "haylift"
	if building is NeedleCabinet:
		return "cabinet"
	if building is NeedleRadar:
		return "needle_radar"
	if building is PaintBoard:
		return "paintboard"
	if building is WorkLamp:
		return "worklamp"
	return ""


func _feeder_of(corner: ConveyorCorner) -> Node3D:
	for c in conveyors:
		if PointIndex.joins(c.b, corner.apex):
			return c
	return null


func demolish_blocked_reason(building: Node3D) -> String:


	var scanner:= building as HaystackScanner
	if scanner != null:
		if scanner.banked.is_empty():
			return ""
		return tr_n("collect %d needle first", "collect %d needles first",
			scanner.banked.size()) % scanner.banked.size()


	var lid:= building as Roof
	if lid != null:
		var on_lid:= standing_on(lid).size()
		if on_lid == 0:
			return ""
		return tr("clear %d from the roof first") % on_lid
	var deck:= building as Platform
	if deck == null:
		return ""
	var load_count:= standing_on(deck).size()
	if load_count == 0:
		return ""
	return tr("clear %d from the deck first") % load_count


func _heal_poles(orphans: Array [PowerPole]) -> void:
	for other in orphans:
		if not is_instance_valid(other) or not power_poles.has(other):
			continue
		if grid != null:
			_grid_settle = 0
			grid.rebuild()
		var mine:= grid.network_of(other) if grid != null else -1
		var want: Array [PowerPole] = []
		for candidate in poles_to_string_to(other.global_position,
				other.link_reach(), other, other):
			if grid != null and mine >= 0 and grid.network_of(candidate) == mine:
				continue
			want.append(candidate)
		other.add_links(want)


func hay_inside(building: Node3D) -> String:
	var count:= 0
	var unit:= ""
	var busy:= false
	var tank:= building as HaySilo
	var wrap:= building as HayWrapper
	var press:= building as HayCompressor
	var pulper:= building as HayPulper
	var paper:= building as PaperMachine
	var briq:= building as BriquettePress
	var mill:= building as HayPelletizer
	var gun:= building as TubeLauncher
	var tip:= building as DumpHatch
	if tank != null:
		count = tank.held()
		unit = "loads"
	elif wrap != null:
		count = wrap.queued.size()
		unit = "bales"
		busy = wrap.is_wrapping()
	elif press != null:
		count = press.stored
		unit = "strands"
		busy = press.is_pressing()
	elif pulper != null:
		count = pulper.stored
		unit = "strands"
		busy = pulper.is_running()
	elif paper != null:


		count = paper.queued.size()
		unit = "slabs"
		busy = paper.is_running()
	elif briq != null:


		var parts:= PackedStringArray()
		if briq.stored_strands > 0:
			parts.append(_count_of(briq.stored_strands, "strands"))
		if briq.stored_bricks > 0:
			parts.append(_count_of(briq.stored_bricks, "bricks"))
		if parts.size() == 2:
			return tr("%s and %s") % [parts [0], parts [1]]
		if not parts.is_empty():
			return parts [0]
		busy = briq.is_running()
	elif mill != null:
		count = mill.stored
		unit = "strands"
		busy = mill.is_running()
	elif gun != null:
		count = gun.stored
		unit = "strands"
	elif tip != null:
		count = tip.stored
		unit = "strands"
	if count > 0:
		return _count_of(count, unit)
	if busy:
		return tr("a load")
	return ""


func _count_of(count: int, unit: String) -> String:
	match unit:
		"strands":
			return tr_n("%d strand", "%d strands", count) % count
		"loads":
			return tr_n("%d load", "%d loads", count) % count
		"bales":
			return tr_n("%d bale", "%d bales", count) % count
		"slabs":
			return tr_n("%d slab", "%d slabs", count) % count
		"bricks":
			return tr_n("%d brick", "%d bricks", count) % count
	return "%d %s" % [count, unit if count != 1 else unit.trim_suffix("s")]


var _sweeping:= 0
var _sweep_junctions:= false
var _sweep_legs:= false

var _sweep_orphans: Array [PowerPole] = []


func begin_sweep() -> void:
	_sweeping += 1


func end_sweep() -> void:
	_sweeping = maxi(_sweeping - 1, 0)
	if _sweeping > 0:
		return
	if _sweep_junctions:
		_sweep_junctions = false
		rebuild_junctions()
	if _sweep_legs:
		_sweep_legs = false
		regroup_deck_legs()


	var orphans:= _sweep_orphans
	_sweep_orphans = []
	_heal_poles(orphans)
	changed.emit()


func demolish(building: Node3D) -> float:


	var standing:= building != null and is_instance_valid(building) and not building.is_queued_for_deletion()
	var refund:= 0.0
	var run:= building as Conveyor
	if run != null and run.line_id != 0 and conveyors.has(run):


		begin_sweep()
		for piece in line_of(run):
			refund += _demolish_one(piece)
		end_sweep()
	else:

		var laid_with:= machine_belts_of(building)
		refund = _demolish_one(building)


		if not laid_with.is_empty() and (not is_instance_valid(building)
				or building.is_queued_for_deletion()):
			for c in laid_with:
				refund += _demolish_one(c)
	if standing and (not is_instance_valid(building) or building.is_queued_for_deletion()):
		Profile.note_structure_removed()
	return refund


func machine_belts_of(building: Node3D) -> Array [Conveyor]:
	var out: Array [Conveyor] = []
	if building == null or not is_instance_valid(building) or building is Conveyor:
		return out
	var ports: Array [Vector3] = []
	for m: String in ["port_in", "port_out", "intake_port", "port_brick"]:
		if building.has_method(m):
			ports.append(building.call(m))
	if ports.is_empty():
		return out
	for c in conveyors:
		if not is_instance_valid(c) or c.is_queued_for_deletion() or not c.seat_port.is_finite():
			continue
		for p in ports:
			if PointIndex.joins(c.seat_port, p):
				out.append(c)
				break
	return out


func mark_machine_belt(c: Conveyor, port: Vector3) -> Conveyor:
	if c != null:
		c.seat_port = port
	return c


func _demolish_one(building: Node3D) -> float:


	if building == null or not is_instance_valid(building) or building.is_queued_for_deletion():
		return 0.0
	var box:= _collider_bounds(building)


	var doomed:= _held_needles_of(building)
	var refund:= _demolish(building)


	if building != null and is_instance_valid(building) and building.is_queued_for_deletion():
		_wake_sleepers(box)


		_lose_held_needles(doomed)
	return refund


func _held_needles_of(building: Node3D) -> PackedInt32Array:
	if building == null or not is_instance_valid(building) or not building.has_method("held_needles"):
		return PackedInt32Array()
	return building.held_needles()


func _lose_held_needles(indices: PackedInt32Array) -> void:
	for index in indices:
		if index >= 0:
			GameState.lose_needle(index, GameState.type_of(index), 0.0,
				GameState.NeedleLoss.DEMOLISHED)


func _collider_bounds(building: Node3D) -> AABB:
	var out:= AABB()
	if building == null or not is_instance_valid(building):
		return out
	var found:= false
	var stack: Array [Node] = [building]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var cs:= n as CollisionShape3D
		if cs == null or cs.shape == null or cs.disabled:
			continue


		if not cs.is_inside_tree():
			continue
		var local: AABB = cs.shape.get_debug_mesh().get_aabb()
		var here:= cs.global_transform * local
		out = here if not found else out.merge(here)
		found = true
	return out


func _wake_sleepers(box: AABB) -> void:
	if not is_inside_tree() or box.size == Vector3.ZERO:
		return
	box = box.grow(0.15)
	var shape:= BoxShape3D.new()
	shape.size = box.size
	var query:= PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), box.get_center())
	query.collision_mask = Cfg.L_PROP | Cfg.L_STRAND
	query.collide_with_areas = false


	for hit in get_world_3d().direct_space_state.intersect_shape(query, 256):
		var rb:= hit.get("collider") as RigidBody3D
		if rb != null:
			Carryable.lost_floor(rb)


func _demolish(building: Node3D) -> float:
	var deck:= building as Platform
	if deck != null:
		if not platforms.has(deck) or demolish_blocked_reason(deck) != "":
			return 0.0
		var deck_refund:= deck.build_cost()
		var gone_rect:= deck.footprint()
		var gone_top:= deck.top_y()
		platforms.erase(deck)
		remove_child(deck)
		deck.queue_free()
		regroup_deck_legs()
		_reground_decks_over(gone_rect, gone_top)
		restyle_hatches()
		changed.emit()
		return deck_refund
	var scanner:= building as HaystackScanner
	if scanner != null:
		if not scanners.has(scanner) or demolish_blocked_reason(scanner) != "":
			return 0.0
		var scanner_refund:= scanner.build_cost()
		scanners.erase(scanner)
		remove_child(scanner)
		scanner.queue_free()


		rebuild_junctions()
		changed.emit()
		return scanner_refund
	var press:= building as HayCompressor
	if press != null:


		if not compressors.has(press) or demolish_blocked_reason(press) != "":
			return 0.0
		var press_refund:= press.build_cost()
		compressors.erase(press)
		remove_child(press)
		press.queue_free()


		rebuild_junctions()
		changed.emit()
		return press_refund
	var pulper:= building as HayPulper
	if pulper != null:


		if not pulpers.has(pulper) or demolish_blocked_reason(pulper) != "":
			return 0.0
		var pulper_refund:= pulper.build_cost()
		pulpers.erase(pulper)
		remove_child(pulper)
		pulper.queue_free()


		rebuild_junctions()
		changed.emit()
		return pulper_refund
	var paper:= building as PaperMachine
	if paper != null:


		if not papers.has(paper) or demolish_blocked_reason(paper) != "":
			return 0.0
		var paper_refund:= paper.build_cost()
		papers.erase(paper)
		remove_child(paper)
		paper.queue_free()


		rebuild_junctions()
		changed.emit()
		return paper_refund
	var briq:= building as BriquettePress
	if briq != null:


		if not briquette_presses.has(briq) or demolish_blocked_reason(briq) != "":
			return 0.0
		var briq_refund:= briq.build_cost()
		briquette_presses.erase(briq)
		remove_child(briq)
		briq.queue_free()


		rebuild_junctions()
		changed.emit()
		return briq_refund
	var wrap:= building as HayWrapper
	if wrap != null:

		if not wrappers.has(wrap) or demolish_blocked_reason(wrap) != "":
			return 0.0
		var wrap_refund:= wrap.build_cost()
		wrappers.erase(wrap)
		remove_child(wrap)
		wrap.queue_free()


		rebuild_junctions()
		changed.emit()
		return wrap_refund
	var tank:= building as HaySilo
	if tank != null:

		if not silos.has(tank) or demolish_blocked_reason(tank) != "":
			return 0.0
		var silo_refund:= tank.build_cost()
		silos.erase(tank)
		remove_child(tank)
		tank.queue_free()


		rebuild_junctions()
		changed.emit()
		return silo_refund
	var mill:= building as HayPelletizer
	if mill != null:

		if not pelletizers.has(mill) or demolish_blocked_reason(mill) != "":
			return 0.0
		var mill_refund:= mill.build_cost()
		pelletizers.erase(mill)
		remove_child(mill)
		mill.queue_free()


		rebuild_junctions()
		changed.emit()
		return mill_refund
	var gen:= building as HayGenerator
	if gen != null:
		if not generators.has(gen):
			return 0.0


		var gen_refund:= gen.build_cost()
		generators.erase(gen)
		remove_child(gen)
		gen.queue_free()


		rebuild_junctions()
		changed.emit()
		return gen_refund
	var pump:= building as BoreholePump
	if pump != null:
		if not boreholes.has(pump):
			return 0.0
		var pump_refund:= pump.build_cost()
		boreholes.erase(pump)
		remove_child(pump)
		pump.queue_free()


		changed.emit()
		return pump_refund
	var pole:= building as PowerPole
	if pole != null:
		if not power_poles.has(pole):
			return 0.0

		var pole_refund:= pole.build_cost()
		if pole.gift:
			GameState.give_gift("pole")
		power_poles.erase(pole)


		if grid != null and _sweeping == 0:
			_grid_settle = 0
			grid.rebuild()


		var orphans: Array [PowerPole] = []
		for other in power_poles:
			if is_instance_valid(other) and other.strung_to(pole):
				other.unlink(pole)
				orphans.append(other)
		for other in pole.links_to:
			if is_instance_valid(other) and power_poles.has(other) and not orphans.has(other):
				orphans.append(other)
		if _sweeping > 0:
			for other in orphans:
				if not _sweep_orphans.has(other):
					_sweep_orphans.append(other)
		else:
			_heal_poles(orphans)


		remove_child(pole)
		pole.queue_free()
		changed.emit()
		return pole_refund
	var tip:= building as DumpHatch
	if tip != null:


		if not dump_hatches.has(tip) or demolish_blocked_reason(tip) != "":
			return 0.0
		var tip_refund:= tip.build_cost()


		tip.give_back_load()
		dump_hatches.erase(tip)
		remove_child(tip)
		tip.queue_free()

		changed.emit()
		return tip_refund
	var gun:= building as TubeLauncher
	if gun != null:

		if not tube_launchers.has(gun) or demolish_blocked_reason(gun) != "":
			return 0.0
		var gun_refund:= gun.build_cost()
		tube_launchers.erase(gun)
		remove_child(gun)
		gun.queue_free()


		rebuild_junctions()
		changed.emit()
		return gun_refund
	var tower:= building as HayStairs
	if tower != null:
		if not hay_stairs.has(tower):
			return 0.0
		var tower_refund:= tower.build_cost()
		hay_stairs.erase(tower)
		remove_child(tower)
		tower.queue_free()


		rebuild_junctions()
		changed.emit()
		return tower_refund
	var lift:= building as HayLift
	if lift != null:
		if not hay_lifts.has(lift):
			return 0.0


		var lift_refund:= lift.build_cost()
		hay_lifts.erase(lift)
		remove_child(lift)
		lift.queue_free()


		rebuild_junctions()
		changed.emit()
		return lift_refund
	var splitter:= building as ConveyorSplitter
	if splitter != null:
		if not splitters.has(splitter):
			return 0.0
		var splitter_refund:= splitter.build_cost()
		var splitter_mouths:= splitter.ports()
		splitters.erase(splitter)
		remove_child(splitter)
		splitter.queue_free()


		rebuild_junctions()
		_refresh_wye_supports()
		refit_runs_at(splitter_mouths)
		changed.emit()
		return splitter_refund
	var joiner:= building as ConveyorJoiner
	if joiner != null:
		if not joiners.has(joiner):
			return 0.0
		var joiner_refund:= joiner.build_cost()
		var joiner_mouths:= joiner.ports()
		joiners.erase(joiner)
		remove_child(joiner)
		joiner.queue_free()


		rebuild_junctions()
		_refresh_wye_supports()
		refit_runs_at(joiner_mouths)
		changed.emit()
		return joiner_refund
	var rake:= building as PistonRake
	if rake != null:
		if not piston_rakes.has(rake):
			return 0.0


		var rake_refund:= 0.0
		if rake.gift:
			GameState.give_gift("rake")
		else:
			rake_refund = _crowded_refund(rake, piston_rakes)
		piston_rakes.erase(rake)
		remove_child(rake)
		rake.queue_free()
		changed.emit()
		return rake_refund
	var drone:= building as HayDrone
	if drone != null:
		if not hay_drones.has(drone):
			return 0.0
		var drone_refund:= _crowded_refund(drone, hay_drones)
		hay_drones.erase(drone)
		remove_child(drone)


		drone.queue_free()
		changed.emit()
		return drone_refund
	var cab:= building as NeedleCabinet
	if cab != null:
		if not cabinets.has(cab):
			return 0.0

		var cab_refund:= cab.build_cost()
		if cab.gift:
			GameState.give_gift("cabinet")
		cabinets.erase(cab)
		remove_child(cab)
		cab.queue_free()


		changed.emit()
		return cab_refund
	var dish:= building as NeedleRadar
	if dish != null:
		if not needle_radars.has(dish):
			return 0.0
		var dish_refund:= dish.build_cost()
		needle_radars.erase(dish)
		remove_child(dish)


		dish.queue_free()
		changed.emit()
		return dish_refund
	var board:= building as PaintBoard
	if board != null:
		if not paint_boards.has(board):
			return 0.0
		var board_refund:= board.build_cost()
		paint_boards.erase(board)
		remove_child(board)
		board.queue_free()


		changed.emit()
		return board_refund
	var lamp:= building as WorkLamp
	if lamp != null:
		if not work_lamps.has(lamp):
			return 0.0
		var lamp_refund:= lamp.build_cost()
		work_lamps.erase(lamp)
		remove_child(lamp)
		lamp.queue_free()


		changed.emit()
		return lamp_refund
	var rail:= building as Railing
	if rail != null and railings.has(rail):
		var rail_refund:= rail.build_cost()
		railings.erase(rail)
		remove_child(rail)
		rail.queue_free()
		changed.emit()
		return rail_refund
	var wall:= building as YardWall
	if wall != null and walls.has(wall):
		var wall_refund:= wall.build_cost()
		walls.erase(wall)
		remove_child(wall)
		wall.queue_free()
		share_joints()
		changed.emit()
		return wall_refund
	var lid:= building as Roof
	if lid != null and roofs.has(lid):
		if demolish_blocked_reason(lid) != "":
			return 0.0
		var roof_refund:= lid.build_cost()
		roofs.erase(lid)
		remove_child(lid)
		lid.queue_free()
		share_joints()
		restyle_hatches()
		changed.emit()
		return roof_refund
	var flight:= building as Stair
	if flight != null and stairs.has(flight):
		var stair_refund:= flight.build_cost()
		stairs.erase(flight)
		remove_child(flight)
		flight.queue_free()
		changed.emit()
		return stair_refund
	var arm:= building as RoboticArm
	if arm != null and robotic_arms.has(arm):
		var refund:= _crowded_refund(arm, robotic_arms)
		robotic_arms.erase(arm)
		remove_child(arm)
		arm.queue_free()
		changed.emit()
		return refund
	var main:= building as WaterMain
	if main != null:
		if not water_mains.has(main):
			return 0.0


		var main_refund:= main.build_cost()
		water_mains.erase(main)
		remove_child(main)
		main.queue_free()


		rebuild_water_joints()
		changed.emit()
		return main_refund
	var wye:= building as WaterSplitter
	if wye != null:
		if not water_splitters.has(wye):
			return 0.0


		var wye_refund:= wye.build_cost()
		water_splitters.erase(wye)
		remove_child(wye)
		wye.queue_free()


		changed.emit()
		return wye_refund
	var c:= building as Conveyor
	if c == null or not conveyors.has(c):
		return 0.0


	var refund:= c.build_cost()
	conveyors.erase(c)
	remove_child(c)
	c.queue_free()
	rebuild_junctions()
	changed.emit()
	return refund


func nearest_conveyor_drop(from: Vector3, max_distance: float) -> Dictionary:
	var runs:= conveyor_drops(from, max_distance)
	return { } if runs.is_empty() else runs [0]


func conveyor_drops(from: Vector3, max_distance: float,
		only: BeltPath = null, among: Array = []) -> Array [Dictionary]:
	var out: Array [Dictionary] = []


	if only != null and not (only is Conveyor and conveyors.has(only)) and not (only is ConveyorCorner and corners.has(only)):
		return out
	var max_d2:= max_distance * max_distance
	var candidates: Array = [only] if only != null else (among if not among.is_empty() else conveyors)
	for conveyor in candidates:

		if conveyor is EnclosedConveyor or conveyor is EnclosedConveyorCorner:
			continue
		if conveyor is ConveyorCorner:
			if legacy_arm_aim:
				continue
			var bend:= _bend_drop(conveyor as ConveyorCorner, from, max_d2)
			if not bend.is_empty():
				out.append(bend)
			continue
		var straight:= conveyor as Conveyor
		var segment:= straight.b - straight.a
		var length2:= segment.length_squared()
		if length2 < 1e-08:
			continue
		var amount:= clampf((from - straight.a).dot(segment) / length2, 0.0, 1.0)
		var deck:= straight.a + segment * amount
		var point:= deck + Vector3.UP * 0.26
		var d2:= point.distance_squared_to(from)
		if d2 >= max_d2:
			continue
		out.append({
			"conveyor": straight,
			"point": point,
			"forward": straight.forward,
			"distance2": d2,
		})
	if only == null and among.is_empty() and not legacy_arm_aim:
		for corner in corners:
			if corner is EnclosedConveyorCorner or not is_instance_valid(corner):
				continue
			var bend:= _bend_drop(corner, from, max_d2)
			if not bend.is_empty():
				out.append(bend)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x ["distance2"]) < float(y ["distance2"]))
	return out


const MACHINE_NEAR_SLACK:= 1.5


func arm_neighbour(from: Vector3, reach: float) -> Dictionary:
	var limit:= reach + MACHINE_NEAR_SLACK
	var best: Node3D = null
	var best_d2:= limit * limit
	for list: Array in [generators, compressors, wrappers, pelletizers, pulpers,
			papers, briquette_presses, scanners, silos, tube_launchers, splitters,
			joiners]:
		for machine in list:
			if not is_instance_valid(machine):
				continue
			var gap: Vector3 = (machine as Node3D).global_position - from
			gap.y = 0.0
			var d2:= gap.length_squared()
			if d2 < best_d2:
				best_d2 = d2
				best = machine as Node3D
	if best == null:
		return { }


	var kind:= "machine"
	if best is ConveyorSplitter or best is ConveyorTJoiner:
		kind = "splitter"
	elif best is ConveyorJoiner:
		kind = "joiner"
	return { "name": name_of(best), "kind": kind }


func _bend_drop(corner: ConveyorCorner, from: Vector3, max_d2: float) -> Dictionary:
	if corner.path_length() <= 0.0:
		return { }


	var centre:= (corner.from_point + corner.to_point) * 0.5
	var radius:= maxf(centre.distance_to(corner.from_point),
		centre.distance_to(corner.apex))
	var slack:= sqrt(max_d2) + radius
	if centre.distance_squared_to(from) > slack * slack:
		return { }
	var s:= float(corner._nearest(from) ["s"])
	var point:= corner._point_at(s) + Vector3.UP * 0.26
	var d2:= point.distance_squared_to(from)
	if d2 >= max_d2:
		return { }
	return {
		"conveyor": corner,
		"point": point,
		"forward": corner._direction_at(s),
		"distance2": d2,
	}


func runs_ending_at(at: Vector3) -> Array [Conveyor]:
	var yp:= _ports_now()
	if yp != null:
		return yp.runs_ending_at(at)
	var out: Array [Conveyor] = []
	for c in conveyors:
		if is_instance_valid(c) and c.b.is_equal_approx(at):
			out.append(c)
	return out


func runs_starting_at(at: Vector3) -> Array [Conveyor]:
	var yp:= _ports_now()
	if yp != null:
		return yp.runs_starting_at(at)
	var out: Array [Conveyor] = []
	for c in conveyors:
		if is_instance_valid(c) and c.a.is_equal_approx(at):
			out.append(c)
	return out


func joint_full(at: Vector3, ignore: Conveyor = null) -> bool:
	var feeds:= 0
	var outs:= 0
	var yp:= _ports_now()
	if yp != null:
		for c in yp.runs_ending_at(at):
			if c != ignore:
				feeds += 1
		for c in yp.runs_starting_at(at):
			if c != ignore:
				outs += 1
		return (feeds > 0 and outs > 0) or feeds > 1 or outs > 1
	for c in conveyors:
		if c == ignore or not is_instance_valid(c):
			continue
		if c.b.is_equal_approx(at):
			feeds += 1
		if c.a.is_equal_approx(at):
			outs += 1
	return (feeds > 0 and outs > 0) or feeds > 1 or outs > 1


func on_machine_port(at: Vector3) -> bool:
	var off:= at + Vector3(0.0, 0.001, 0.0)
	for snap: Callable in [snap_compressor_port, snap_pulper_port, snap_paper_port,
			snap_briquette_port, snap_wrapper_port, snap_silo_port,
			snap_pelletizer_port, snap_generator_port, snap_launcher_port,
			snap_stairs_port, snap_lift_port, snap_stand_port, snap_scanner_port]:
		var hit: Vector3 = snap.call(off)
		if not hit.is_equal_approx(off) and PointIndex.joins(hit, at):
			return true
	return false


func snap_endpoint(point: Vector3, ignore: Conveyor = null,
		avoid:= Vector3.INF) -> Vector3:
	var best:= point
	var best_d:= Cfg.BELT_SNAP_RADIUS


	var ends: Array [Vector3] = []
	for c in conveyors:
		if c == ignore:
			continue
		for end in [c.a, c.b]:
			if point.distance_to(end) < best_d:
				ends.append(end)
	ends.sort_custom(func(x: Vector3, y: Vector3) -> bool:
		return point.distance_squared_to(x) < point.distance_squared_to(y))
	for end in ends:
		if joint_full(end, ignore) or wye_mouth_taken(end, ignore) or on_machine_port(end) or PointIndex.joins(end, avoid):
			continue
		best = end
		best_d = point.distance_to(end)
		break


	var split_port:= snap_splitter_port(point, null, ignore, avoid)
	if not split_port.is_equal_approx(point):
		if best.is_equal_approx(point) or point.distance_to(split_port) < best_d:
			best = split_port
			best_d = point.distance_to(split_port)


	var join_port:= snap_joiner_port(point, null, ignore, avoid)
	if not join_port.is_equal_approx(point):
		if best.is_equal_approx(point) or point.distance_to(join_port) < best_d:
			best = join_port
			best_d = point.distance_to(join_port)


	var press_port:= snap_compressor_port(point)
	if not press_port.is_equal_approx(point) and not port_has_run(press_port, ignore):
		if best.is_equal_approx(point) or point.distance_to(press_port) < best_d:
			best = press_port
			best_d = point.distance_to(press_port)


	var pulper_port:= snap_pulper_port(point)
	if not pulper_port.is_equal_approx(point) and not port_has_run(pulper_port, ignore):
		if best.is_equal_approx(point) or point.distance_to(pulper_port) < best_d:
			best = pulper_port
			best_d = point.distance_to(pulper_port)


	var paper_port:= snap_paper_port(point)
	if not paper_port.is_equal_approx(point) and not port_has_run(paper_port, ignore):
		if best.is_equal_approx(point) or point.distance_to(paper_port) < best_d:
			best = paper_port
			best_d = point.distance_to(paper_port)


	var briq_port:= snap_briquette_port(point)
	if not briq_port.is_equal_approx(point) and not port_has_run(briq_port, ignore):
		if best.is_equal_approx(point) or point.distance_to(briq_port) < best_d:
			best = briq_port
			best_d = point.distance_to(briq_port)


	var wrap_port:= snap_wrapper_port(point)
	if not wrap_port.is_equal_approx(point) and not port_has_run(wrap_port, ignore):
		if best.is_equal_approx(point) or point.distance_to(wrap_port) < best_d:
			best = wrap_port
			best_d = point.distance_to(wrap_port)


	var silo_port:= snap_silo_port(point)
	if not silo_port.is_equal_approx(point) and not port_has_run(silo_port, ignore):
		if best.is_equal_approx(point) or point.distance_to(silo_port) < best_d:
			best = silo_port
			best_d = point.distance_to(silo_port)


	var mill_port:= snap_pelletizer_port(point)
	if not mill_port.is_equal_approx(point) and not port_has_run(mill_port, ignore):
		if best.is_equal_approx(point) or point.distance_to(mill_port) < best_d:
			best = mill_port
			best_d = point.distance_to(mill_port)


	var gen_port:= snap_generator_port(point)
	if not gen_port.is_equal_approx(point) and not port_has_run(gen_port, ignore):
		if best.is_equal_approx(point) or point.distance_to(gen_port) < best_d:
			best = gen_port
			best_d = point.distance_to(gen_port)


	var gun_port:= snap_launcher_port(point)
	if not gun_port.is_equal_approx(point) and not port_has_run(gun_port, ignore):
		if best.is_equal_approx(point) or point.distance_to(gun_port) < best_d:
			best = gun_port
			best_d = point.distance_to(gun_port)


	var stairs_port:= snap_stairs_port(point)
	if not stairs_port.is_equal_approx(point) and not port_has_run(stairs_port, ignore):
		if best.is_equal_approx(point) or point.distance_to(stairs_port) < best_d:
			best = stairs_port
			best_d = point.distance_to(stairs_port)


	var lift_port:= snap_lift_port(point)
	if not lift_port.is_equal_approx(point) and not port_has_run(lift_port, ignore):
		if best.is_equal_approx(point) or point.distance_to(lift_port) < best_d:
			best = lift_port
			best_d = point.distance_to(lift_port)


	var till_port:= snap_stand_port(point)
	if not till_port.is_equal_approx(point) and not port_has_run(till_port, ignore):
		if best.is_equal_approx(point) or point.distance_to(till_port) < best_d:
			best = till_port
			best_d = point.distance_to(till_port)
	var port:= snap_scanner_port(point)
	if not port.is_equal_approx(point) and not port_has_run(port, ignore):


		if best.is_equal_approx(point) or point.distance_to(port) < best_d:
			best = port


	if PointIndex.joins(best, avoid):
		return point
	return best


func rebuild_junctions() -> void:
	YardPorts.touch()


	if _sweeping > 0:
		_sweep_junctions = true
		return
	var wanted: Array [Dictionary] = []
	var trims:= { }
	var taken_end:= { }
	var taken_start:= { }


	var starts: PointIndex = _run_ends() [0]


	var pairs: Array [Dictionary] = []
	var want_end:= { }
	var want_start:= { }
	for incoming in conveyors:
		if taken_end.has(incoming):
			continue
		for entry: Array in starts.all(incoming.b):
			var outgoing: Conveyor = entry [1]
			if outgoing == incoming or taken_start.has(outgoing):
				continue
			taken_end [incoming] = true
			taken_start [outgoing] = true
			var want:= corner_want(incoming.forward, outgoing.forward)


			if want <= 0.0:
				break
			pairs.append({ "in": incoming, "out": outgoing, "want": want })
			want_end [incoming] = want
			want_start [outgoing] = want
			break


	var give_end:= { }
	var give_start:= { }
	for run in conveyors:
		if not is_instance_valid(run):
			continue
		var wa:= float(want_start.get(run, 0.0))
		var wb:= float(want_end.get(run, 0.0))
		if wa + wb <= 0.0:
			continue
		var free:= corner_give(run.length)
		var share:= 1.0 if wa + wb <= free else free / (wa + wb)
		give_start [run] = wa * share
		give_end [run] = wb * share

	for pair in pairs:
		var incoming: Conveyor = pair ["in"]
		var outgoing: Conveyor = pair ["out"]
		var t: float = minf(float(pair ["want"]),
			minf(float(give_end.get(incoming, 0.0)),
			float(give_start.get(outgoing, 0.0))))


		if t <= 0.05:
			continue
		var ti: Vector2 = trims.get(incoming, Vector2.ZERO)
		var to_: Vector2 = trims.get(outgoing, Vector2.ZERO)
		trims [incoming] = Vector2(ti.x, t)
		trims [outgoing] = Vector2(t, to_.y)
		wanted.append({
			"from": incoming.b - incoming.forward * t,
			"apex": incoming.b,
			"to": outgoing.a + outgoing.forward * t,
			"enclosed": incoming is EnclosedConveyor and outgoing is EnclosedConveyor })

	_fit_corners(wanted)

	for c in conveyors:
		var t: Vector2 = trims.get(c, Vector2.ZERO)
		c.set_trim(t.x, t.y)


	_rebuild_rail_windows()
	_settle_t_feeds()


	var links:= _run_ends()
	_rewire_downstream(links [0], links [1])
	_reserve_machine_heads()
	_rebuild_enclosed_visuals()


	_refresh_water_supports_soon()


func _rebuild_enclosed_visuals() -> void:
	_index_enclosed()
	var specs: Array = []


	var sig:= PackedVector3Array()
	for c in conveyors:
		if is_instance_valid(c) and c is EnclosedConveyor:
			(c as EnclosedConveyor).set_open_ends(_enclosed_ending_at(c.a) == null,
				_enclosed_starting_at(c.b) == null)
		if is_instance_valid(c) and c is EnclosedConveyor and not _enclosed_on_show.has(c):
			var spec:= _enclosed_spec(c)
			specs.append(spec)
			sig.append(spec ["a"])
			sig.append(spec ["b"])
	if _enclosed_visuals != null and is_instance_valid(_enclosed_visuals) and sig == _enclosed_built:
		return
	if _enclosed_visuals != null:
		remove_child(_enclosed_visuals)
		_enclosed_visuals.queue_free()
		_enclosed_visuals = null


	_enclosed_built = PackedVector3Array()
	if specs.is_empty():
		return
	if _enclosed_kit == null:
		_enclosed_kit = EnclosedConveyorKit.new()
	var result:= _enclosed_kit.build_network(specs)
	if result.get("root") == null:
		push_warning("Enclosed conveyor visuals: %s" % result.get("error", "unknown error"))
		return
	_enclosed_visuals = result ["root"]
	add_child(_enclosed_visuals)
	_enclosed_built = sig


func _enclosed_spec(c: Conveyor) -> Dictionary:
	return {
		"a": c.a if _enclosed_ending_at(c.a) != null else c.laid_start(),
		"b": c.b if _enclosed_starting_at(c.b) != null else c.laid_end() }


func show_enclosed_apart(pieces: Array [Node3D]) -> Array [Node3D]:

	_index_enclosed()
	var mine: Array [Node3D] = []
	var specs: Array = []
	for piece in pieces:
		if piece is EnclosedConveyor and is_instance_valid(piece) and not _enclosed_on_show.has(piece):
			mine.append(piece)
			specs.append(_enclosed_spec(piece as Conveyor))
	if mine.is_empty():
		return mine
	if _enclosed_kit == null:
		_enclosed_kit = EnclosedConveyorKit.new()
	var result:= _enclosed_kit.build_network(specs)
	var root:= result.get("root") as Node3D
	if root == null:
		return [] as Array [Node3D]
	root.name = "ShowShell"
	mine [0].add_child(root)
	for run_node in mine:
		_enclosed_on_show [run_node] = root
	_rebuild_enclosed_visuals()
	return mine


func end_enclosed_show(runs: Array [Node3D]) -> void:
	var shells:= { }
	for key in _enclosed_on_show.keys():
		var gone:= not is_instance_valid(key)
		if not gone and not runs.has(key):
			continue
		var shell: Variant = _enclosed_on_show [key]
		if shell != null and is_instance_valid(shell):
			shells [shell] = true
		_enclosed_on_show.erase(key)
	for shell: Node in shells:


		var parent:= shell.get_parent()
		if parent != null:
			parent.remove_child(shell)
		shell.queue_free()
	if is_inside_tree():
		_rebuild_enclosed_visuals()


var _enclosed_starts: PointIndex = null
var _enclosed_ends: PointIndex = null


func _index_enclosed() -> void:
	_enclosed_starts = PointIndex.new()
	_enclosed_ends = PointIndex.new()
	var rank:= 0
	for c in conveyors:
		if c is EnclosedConveyor and is_instance_valid(c):
			_enclosed_starts.add(c.a, c, rank)
			_enclosed_starts.add(c.laid_start(), c, rank)
			_enclosed_ends.add(c.b, c, rank)
			_enclosed_ends.add(c.laid_end(), c, rank)
			rank += 1


func _enclosed_starting_at(at: Vector3) -> EnclosedConveyor:
	if _enclosed_starts == null:
		_index_enclosed()
	var hit:= _enclosed_starts.best(at)
	if hit.is_empty() or not is_instance_valid(hit [1]):
		return null
	return hit [1] as EnclosedConveyor


func _enclosed_ending_at(at: Vector3) -> EnclosedConveyor:
	if _enclosed_ends == null:
		_index_enclosed()
	var hit:= _enclosed_ends.best(at)
	if hit.is_empty() or not is_instance_valid(hit [1]):
		return null
	return hit [1] as EnclosedConveyor


var _water_supports_pending:= false


func _refresh_water_supports_soon() -> void:
	if _water_supports_pending or water_mains.is_empty() or not is_inside_tree():
		return
	_water_supports_pending = true
	await get_tree().physics_frame
	_water_supports_pending = false
	for run in water_mains:
		if is_instance_valid(run):
			run.refresh_supports()


var _belt_supports_pending:= false


func _refresh_belt_supports_soon() -> void:
	if _belt_supports_pending or not is_inside_tree():
		return
	_belt_supports_pending = true
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_belt_supports_pending = false
	for c in conveyors:
		if is_instance_valid(c):
			c.refresh_supports()
	_refresh_wye_supports()


var _corner_serial:= 0


func _fit_corners(wanted: Array [Dictionary]) -> void:
	var spare: Array [ConveyorCorner] = []
	for k in corners:
		if is_instance_valid(k):
			spare.append(k)
	var kept: Array [ConveyorCorner] = []
	var to_build: Array [Dictionary] = []
	for want in wanted:
		var found:= -1
		for i in spare.size():
			var k:= spare [i]
			if (k is EnclosedConveyorCorner) != bool(want.get("enclosed", false)):
				continue
			if k.from_point.is_equal_approx(want ["from"]) and k.apex.is_equal_approx(want ["apex"]) and k.to_point.is_equal_approx(want ["to"]):
				found = i
				break
		if found < 0:
			to_build.append(want)
			continue
		kept.append(spare [found])
		spare.remove_at(found)


	for k in spare:
		remove_child(k)
		k.queue_free()
	corners.assign(kept)
	for want in to_build:
		var corner: ConveyorCorner = (EnclosedConveyorCorner.new()
			if bool(want.get("enclosed", false)) else ConveyorCorner.new())
		corner.name = "Corner%d" % _corner_serial
		_corner_serial += 1
		corner.setup(want ["from"], want ["apex"], want ["to"])
		corners.append(corner)
		add_child(corner)


func _rebuild_rail_windows() -> void:
	var windows:= { }
	for joint in _joints():
		var at: Vector3 = joint ["at"]
		var arms: Array = joint ["arms"]


		var bend:= _corner_at(at)
		for mine in arms:
			var run: Conveyor = mine ["run"]
			var across: Vector3 = mine ["across"]

			var open_pos:= false
			var open_neg:= false
			for other in arms:
				if other ["run"] == run:
					continue
				var side: float = (other ["bearing"] as Vector3).dot(across)
				if absf(side) < Cfg.BELT_JOINT_MIN_SIDE:
					continue
				if side > 0.0:
					open_pos = true
				else:
					open_neg = true
			if not open_pos and not open_neg:
				continue


			if bend != null and not _arm_reaches(mine, at):
				continue


			var from:= 0.0
			var to:= Cfg.BELT_JOINT_REACH
			if bool(mine ["at_end"]):
				var laid: float = run.laid_start().distance_to(run.laid_end())
				from = laid - Cfg.BELT_JOINT_REACH
				to = laid
			if open_pos:
				_add_window(windows, run, 1, from, to)
			if open_neg:
				_add_window(windows, run, -1, from, to)


		if bend == null:
			continue
		var s_apex:= bend.apex_s()
		var across_bend:= bend.basis_at(s_apex).x
		for mine in arms:
			if not _arm_reaches(mine, at):
				continue
			var side: float = (mine ["bearing"] as Vector3).dot(across_bend)
			if absf(side) < Cfg.BELT_JOINT_MIN_SIDE:
				continue
			_add_window(windows, bend, 1 if side > 0.0 else -1,
				s_apex - Cfg.BELT_JOINT_REACH, s_apex + Cfg.BELT_JOINT_REACH)

	for c in conveyors:
		if is_instance_valid(c):
			c.set_rail_windows(windows.get(c, [] as Array [Dictionary]))
	for k in corners:
		if is_instance_valid(k):
			k.set_rail_windows(windows.get(k, [] as Array [Dictionary]))


func _corner_at(point: Vector3) -> ConveyorCorner:
	for k in corners:
		if is_instance_valid(k) and PointIndex.joins(k.apex, point):
			return k
	return null


func _arm_reaches(arm: Dictionary, at: Vector3) -> bool:
	var run: Conveyor = arm ["run"]
	var tip: Vector3 = run.laid_end() if bool(arm ["at_end"]) else run.laid_start()
	return PointIndex.joins(tip, at)


func _joints() -> Array [Dictionary]:
	var out: Array [Dictionary] = []


	var ends:= PointIndex.new()
	for i in conveyors.size():
		var run:= conveyors [i]
		if not is_instance_valid(run) or run.length < 0.0001:
			continue
		ends.add(run.a, run, i * 2)
		ends.add(run.b, run, i * 2 + 1)
	var joints_at:= PointIndex.new()
	for c in conveyors:
		if not is_instance_valid(c) or c.length < 0.0001:
			continue
		for point: Vector3 in [c.a, c.b]:
			if not joints_at.best(point).is_empty():
				continue
			var arms: Array = []
			var met:= { }
			for hit: Array in ends.all(point):
				var other: Conveyor = hit [1]
				if met.has(other):
					continue
				met [other] = true


				var at_a:= int(hit [2]) % 2 == 0
				var basis:= BeltPath.run_basis(other.laid_start(), other.laid_end())
				if at_a:
					arms.append({ "run": other, "bearing": other.forward,
						"across": basis.x, "at_end": false })
				else:
					arms.append({ "run": other, "bearing": - other.forward,
						"across": basis.x, "at_end": true })
			if arms.size() >= 3:
				out.append({ "at": point, "arms": arms })
				joints_at.add(point, true, 0)
	return out


func _add_window(windows: Dictionary, run: BeltPath, side: int,
		from: float, to: float) -> void:
	if not windows.has(run):
		windows [run] = [] as Array [Dictionary]
	var list: Array [Dictionary] = windows [run]
	list.append({ "side": side, "from": from, "to": to })


func _rewire_downstream(starts: PointIndex = null, ends: PointIndex = null) -> void:
	var successors:= _successor_index()
	for c in conveyors:
		c.downstream = _successor_at(successors, c.laid_end(), c.b)
		if c.downstream == null:
			c.downstream = _overlapped_intake(c.laid_end(), c.forward, successors)
	for c in corners:
		c.downstream = _successor_at(successors, c.to_point, c.to_point)
		if c.downstream == null and c._line.size() >= 2:
			c.downstream = _overlapped_intake(c.to_point,
				c._direction_at(c.path_length()), successors)


	for scanner in scanners:
		if is_instance_valid(scanner) and scanner.deck() != null:
			scanner.deck().downstream = _onward_from(scanner.port_out(), starts, successors)
	for press in compressors:
		if is_instance_valid(press) and press.deck() != null:
			press.deck().downstream = _onward_from(press.port_out(), starts, successors)


	for pulper in pulpers:
		if is_instance_valid(pulper) and pulper.outfeed_deck() != null:
			pulper.outfeed_deck().downstream = _onward_from(pulper.port_out(), starts,
				successors)


	for mill in papers:
		if is_instance_valid(mill) and mill.outfeed_deck() != null:
			mill.outfeed_deck().downstream = _onward_from(mill.port_out(), starts, successors)


	for machine in briquette_presses:
		if is_instance_valid(machine) and machine.outfeed_deck() != null:
			machine.outfeed_deck().downstream = _onward_from(machine.port_out(), starts,
				successors)


	for lift in hay_lifts:
		if is_instance_valid(lift) and lift.outfeed_deck() != null:
			lift.outfeed_deck().downstream = _onward_from(lift.port_out(), starts, successors)
	for wrap in wrappers:
		if is_instance_valid(wrap) and wrap.deck() != null:
			wrap.deck().downstream = _onward_from(wrap.port_out(), starts, successors)


	for tower in hay_stairs:
		if is_instance_valid(tower) and tower.deck() != null:
			tower.deck().downstream = _onward_from(tower.outfeed_port(), starts, successors)
	for tank in silos:
		if is_instance_valid(tank) and tank.deck() != null:
			tank.deck().downstream = _onward_from(tank.port_out(), starts, successors)


	for splitter in splitters:
		if not is_instance_valid(splitter):
			continue


		for side: int in splitter.output_sides():
			var route:= splitter.route(side)
			if route != null:
				route.downstream = _onward_from(splitter.port(side), starts, successors,
					splitter.arm_travel(side))
	for joiner in joiners:
		if not is_instance_valid(joiner):
			continue


		if joiner.out_path() != null:
			joiner.out_path().downstream = _onward_from(joiner.port_out(), starts,
				successors, joiner.forward())
	_seat_open_ends(successors)


	var outfeeds:= _machine_outfeeds()
	for splitter in splitters:
		if not is_instance_valid(splitter):
			continue


		splitter.set_feeder(_feed_into_wye(splitter.port_in(), ends, outfeeds))


func _settle_t_feeds() -> void:
	var outfeeds:= _machine_outfeeds()
	for pass_no in 4:
		if not _settle_t_pass(outfeeds):
			return


func _settle_t_pass(outfeeds: PointIndex) -> bool:
	var changed:= false
	var ts: Array [Node3D] = []
	for splitter in splitters:
		if splitter is ConveyorTSplitter and is_instance_valid(splitter):
			ts.append(splitter)
	for joiner in joiners:
		if joiner is ConveyorTJoiner and is_instance_valid(joiner):
			ts.append(joiner)
	for t: Node3D in ts:
		var arriving: Array [int] = []
		for lane: int in ConveyorTSplitter.LANES:
			var mouth:= t.to_global(ConveyorTSplitter.lane_mouth(lane, t.get("port_r")))
			if feed_run_into(mouth) != null or _outlet_of_another(t, mouth) or not outfeeds.best(mouth).is_empty():
				arriving.append(lane)
		var split:= t as ConveyorTSplitter
		var join:= t as ConveyorTJoiner
		if split != null and split.fed != (arriving.size() == 1):
			split.set_fed(arriving.size() == 1)
			changed = true
		if split != null:
			var leaving: Array [int] = []
			for lane: int in ConveyorTSplitter.LANES:
				if run_out_of(split.to_global(split.mouth_of(lane))) != null:
					leaving.append(lane)
			split.leaving = leaving
			split.arriving = arriving


			if arriving.is_empty() and leaving.has(split.entry) and leaving.size() < 3:
				for lane: int in ConveyorTSplitter.LANES:
					if not leaving.has(lane):
						split.set_entry(lane)
						refit_runs_at(split.ports())
						changed = true
						break
		if arriving.size() == 2:
			var outlet:= 3 - arriving [0] - arriving [1]
			if join != null:
				if join.out_lane != outlet:
					join.set_out(outlet)
					refit_runs_at(join.ports())
					changed = true
				continue
			var made:= ConveyorTJoiner.new()
			made.out_lane = outlet
			made.port_r = split.port_r
			_swap_t(split, made)
			t_switched.emit(made, true)
			changed = true
		elif arriving.size() == 1:
			if split != null:
				if arriving [0] != split.entry:
					split.set_entry(arriving [0])
					refit_runs_at(split.ports())
					changed = true
				continue
			var back:= ConveyorTSplitter.new()
			back.port_r = join.port_r
			back.fed = true
			back.set_entry(arriving [0])
			_swap_t(join, back)
			t_switched.emit(back, false)
			changed = true
	return changed


const META_SWAPPED_IN:= "t_swapped_in"


func _swap_t(old: Node3D, made: Node3D) -> void:
	var at:= old.global_position
	var yaw:= old.global_rotation.y
	if old is ConveyorSplitter:
		splitters.erase(old)
	else:
		joiners.erase(old)
	remove_child(old)
	old.queue_free()
	made.call("setup", at, yaw)


	made.set_meta(META_SWAPPED_IN, true)
	if made is ConveyorTSplitter:
		made.name = _free_name("ConveyorTSplitter", splitters.size())
		splitters.append(made as ConveyorSplitter)
	else:
		made.name = _free_name("ConveyorTJoiner", joiners.size())
		joiners.append(made as ConveyorJoiner)
	add_child(made)
	refit_runs_at(made.call("ports"))


func t_mouth_out(point: Vector3) -> Vector3:
	var yp:= _ports_now()
	if yp != null:
		return yp.t_out(point)
	var ts: Array [Node3D] = []
	for splitter in splitters:
		if splitter is ConveyorTSplitter and is_instance_valid(splitter):
			ts.append(splitter)
	for joiner in joiners:
		if joiner is ConveyorTJoiner and is_instance_valid(joiner):
			ts.append(joiner)
	for t: Node3D in ts:
		var lane: int = t.call("lane_at", point)
		if lane >= 0:
			return (t.global_basis * ConveyorTSplitter.lane_out(lane)).normalized()
	return Vector3.ZERO


func _outlet_of_another(asker: Node, point: Vector3) -> bool:
	for splitter in splitters:
		if splitter == asker or not is_instance_valid(splitter):
			continue
		if splitter is ConveyorTSplitter and not (splitter as ConveyorTSplitter).fed:
			continue
		for side in splitter.output_sides():
			if PointIndex.joins(splitter.port(side), point):
				return true
	for joiner in joiners:
		if joiner != asker and is_instance_valid(joiner) and PointIndex.joins(joiner.port_out(), point):
			return true
	return false


func _onward_from(mouth: Vector3, starts: PointIndex = null,
		successors: Array [PointIndex] = [], bearing: Vector3 = Vector3.ZERO) -> BeltPath:
	var run:= run_out_of(mouth, starts)
	if run != null:
		return run
	if not successors.is_empty():
		var next:= _successor_at(successors, mouth, mouth)
		if next == null:


			if bearing.length_squared() < 1e-06:
				bearing = port_bearing_at(mouth)
			next = _overlapped_intake(mouth, bearing, successors)
			if next == null:
				next = _overlapped_successor(mouth, bearing, successors)
		return next
	var inlet:= _wye_inlet_at(mouth)
	if inlet != null:
		return inlet
	var gen:= generator_at_port(mouth)
	return gen.deck() if gen != null else null


func _feed_into_wye(mouth: Vector3, ends: PointIndex = null,
		outfeeds: PointIndex = null) -> BeltPath:
	var run:= feed_run_into(mouth, ends)
	if run != null:
		return run
	var wye:= _wye_outlet_at(mouth)
	if wye != null or outfeeds == null:
		return wye
	var hit:= outfeeds.best(mouth)
	if not hit.is_empty():
		return hit [1]


	var inward:= port_bearing_at(mouth)
	if inward.length_squared() < 1e-06:
		return null
	var best: BeltPath = null
	var best_in:= INF
	for e: Array in outfeeds.within(mouth, PORT_OVERLAP):
		var d:= (e [0] as Vector3) - mouth
		var along:= d.dot(inward)
		if along < PointIndex.JOIN or along > PORT_OVERLAP:
			continue
		if (d - inward * along).length() > PORT_OVERLAP_ACROSS:
			continue
		if port_bearing_at(e [0]).dot(inward) < 0.98:
			continue
		if along < best_in:
			best_in = along
			best = e [1]
	return best


func _machine_outfeeds() -> PointIndex:
	var out:= PointIndex.new()
	var rank:= 0
	for scanner in scanners:
		if is_instance_valid(scanner) and scanner.deck() != null:
			out.add(scanner.port_out(), scanner.deck(), rank)
			rank += 1
	for press in compressors:
		if is_instance_valid(press) and press.deck() != null:
			out.add(press.port_out(), press.deck(), rank)
			rank += 1
	for pulper in pulpers:
		if is_instance_valid(pulper) and pulper.outfeed_deck() != null:
			out.add(pulper.port_out(), pulper.outfeed_deck(), rank)
			rank += 1
	for mill in papers:
		if is_instance_valid(mill) and mill.outfeed_deck() != null:
			out.add(mill.port_out(), mill.outfeed_deck(), rank)
			rank += 1
	for machine in briquette_presses:
		if is_instance_valid(machine) and machine.outfeed_deck() != null:
			out.add(machine.port_out(), machine.outfeed_deck(), rank)
			rank += 1
	for lift in hay_lifts:
		if is_instance_valid(lift) and lift.outfeed_deck() != null:
			out.add(lift.port_out(), lift.outfeed_deck(), rank)
			rank += 1
	for wrap in wrappers:
		if is_instance_valid(wrap) and wrap.deck() != null:
			out.add(wrap.port_out(), wrap.deck(), rank)
			rank += 1
	for tower in hay_stairs:
		if is_instance_valid(tower) and tower.deck() != null:
			out.add(tower.outfeed_port(), tower.deck(), rank)
			rank += 1
	for tank in silos:
		if is_instance_valid(tank) and tank.deck() != null:
			out.add(tank.port_out(), tank.deck(), rank)
			rank += 1
	return out


func _refresh_wye_supports() -> void:
	for splitter in splitters:
		if is_instance_valid(splitter):
			splitter.refresh_supports()
	for joiner in joiners:
		if is_instance_valid(joiner):
			joiner.refresh_supports()


func refit_runs_at(mouths: Array [Vector3]) -> void:
	for mouth: Vector3 in mouths:
		for c: Conveyor in [feed_run_into(mouth), run_out_of(mouth)]:
			if c != null:
				c.refresh_supports()


func _reserve_machine_heads() -> void:
	for c in conveyors:
		if is_instance_valid(c):
			c.clear_head_reserve()
	for press in compressors:
		if not is_instance_valid(press):
			continue
		var out:= run_out_of(press.port_out())
		if out != null:
			out.reserve_head(press.bale_spot(), press.outfeed_reserve())
	for wrap in wrappers:
		if not is_instance_valid(wrap):
			continue
		var out:= run_out_of(wrap.port_out())
		if out != null:
			out.reserve_head(wrap.product_spot(), wrap.outfeed_reserve())


	for pulper in pulpers:
		if not is_instance_valid(pulper):
			continue
		var beyond:= run_out_of(pulper.port_out())
		if beyond != null:
			beyond.reserve_head(pulper.slab_spot(), pulper.outfeed_reserve())


	for mill in papers:
		if not is_instance_valid(mill):
			continue
		var past:= run_out_of(mill.port_out())
		if past != null:
			past.reserve_head(mill.product_spot(), mill.outfeed_reserve())


	for machine in briquette_presses:
		if not is_instance_valid(machine):
			continue
		var onward:= run_out_of(machine.port_out())
		if onward != null:
			onward.reserve_head(machine.disc_spot(), machine.outfeed_reserve())


func _successor_at(index: Array [PointIndex], laid: Vector3, nominal: Vector3) -> BeltPath:
	var on_laid:= index [0].best(laid)
	var on_nominal:= index [1].best(nominal)
	if on_laid.is_empty() and on_nominal.is_empty():
		return null
	if on_nominal.is_empty() or (not on_laid.is_empty() and int(on_laid [0]) < int(on_nominal [0])):
		return on_laid [1]
	return on_nominal [1]


func _successor_index() -> Array [PointIndex]:
	var by_laid:= PointIndex.new()
	var by_nominal:= PointIndex.new()
	var rank:= 0
	for c in corners:
		if is_instance_valid(c):
			by_laid.add(c.from_point, c, rank)
			rank += 1
	for scanner in scanners:
		if is_instance_valid(scanner) and scanner.deck() != null:
			by_nominal.add(scanner.port_in(), scanner.deck(), rank)
			rank += 1
	for press in compressors:
		if is_instance_valid(press) and press.deck() != null:
			by_nominal.add(press.port_in(), press.deck(), rank)
			rank += 1


	for pulper in pulpers:
		if is_instance_valid(pulper) and pulper.deck() != null:
			by_nominal.add(pulper.port_in(), pulper.deck(), rank)
			rank += 1

	for mill in papers:
		if is_instance_valid(mill) and mill.deck() != null:
			by_nominal.add(mill.port_in(), mill.deck(), rank)
			rank += 1


	for machine in briquette_presses:
		if not is_instance_valid(machine):
			continue
		if machine.wad_deck() != null:
			by_nominal.add(machine.port_wad(), machine.wad_deck(), rank)
			rank += 1
		if machine.brick_deck() != null:
			by_nominal.add(machine.port_brick(), machine.brick_deck(), rank)
			rank += 1
	for wrap in wrappers:
		if is_instance_valid(wrap) and wrap.deck() != null:
			by_nominal.add(wrap.port_in(), wrap.deck(), rank)
			rank += 1


	for tank in silos:
		if is_instance_valid(tank) and tank.feed_deck() != null:
			by_nominal.add(tank.port_in(), tank.feed_deck(), rank)
			rank += 1


	for mill in pelletizers:
		if is_instance_valid(mill) and mill.deck() != null:
			by_nominal.add(mill.intake_port(), mill.deck(), rank)
			rank += 1


	for gen in generators:
		if is_instance_valid(gen) and gen.deck() != null:
			by_nominal.add(gen.intake_port(), gen.deck(), rank)
			rank += 1
	for gun in tube_launchers:
		if is_instance_valid(gun) and gun.deck() != null:
			by_nominal.add(gun.intake_port(), gun.deck(), rank)
			rank += 1


	for lift in hay_lifts:
		if is_instance_valid(lift) and lift.deck() != null:
			by_nominal.add(lift.port_in(), lift.deck(), rank)
			rank += 1


	if stand != null and is_instance_valid(stand) and stand.intake_path() != null:
		by_nominal.add(stand.belt_entry_point(), stand.intake_path(), rank)
		rank += 1
	for splitter in splitters:
		if is_instance_valid(splitter):


			by_nominal.add(splitter.port_in(), splitter.route(splitter.next_side), rank)
			rank += 1


	for joiner in joiners:
		if not is_instance_valid(joiner):
			continue
		for side: int in ConveyorJoiner.SIDES:
			by_nominal.add(joiner.port(side), joiner.arm(side), rank)
			rank += 1


	for c in conveyors:
		if not is_instance_valid(c):
			continue
		by_laid.add(c.laid_start(), c, rank)
		by_nominal.add(c.a, c, rank)
		rank += 1
	return [by_laid, by_nominal, _intake_bearing_index()]


const PORT_OVERLAP:= 0.3


const PORT_OVERLAP_ACROSS:= 0.03


func _intake_bearing_index() -> PointIndex:
	var out:= PointIndex.new()
	for scanner in scanners:
		if is_instance_valid(scanner) and scanner.deck() != null:
			out.add(scanner.port_in(), [scanner.forward(), scanner.deck()], 0)
	for press in compressors:
		if is_instance_valid(press) and press.deck() != null:
			out.add(press.port_in(), [press.forward(), press.deck()], 0)
	for pulper in pulpers:
		if is_instance_valid(pulper) and pulper.deck() != null:
			out.add(pulper.port_in(), [pulper.forward(), pulper.deck()], 0)
	for mill in papers:
		if is_instance_valid(mill) and mill.deck() != null:
			out.add(mill.port_in(), [mill.forward(), mill.deck()], 0)
	for machine in briquette_presses:
		if not is_instance_valid(machine):
			continue
		if machine.wad_deck() != null:
			out.add(machine.port_wad(), [machine.bearing_at(machine.port_wad()),
				machine.wad_deck()], 0)
		if machine.brick_deck() != null:
			out.add(machine.port_brick(), [machine.bearing_at(machine.port_brick()),
				machine.brick_deck()], 0)
	for wrap in wrappers:
		if is_instance_valid(wrap) and wrap.deck() != null:
			out.add(wrap.port_in(), [wrap.forward(), wrap.deck()], 0)
	for tank in silos:
		if is_instance_valid(tank) and tank.feed_deck() != null:
			out.add(tank.port_in(), [tank.forward(), tank.feed_deck()], 0)
	for mill in pelletizers:
		if is_instance_valid(mill) and mill.deck() != null:
			out.add(mill.intake_port(), [mill.forward(), mill.deck()], 0)
	for gen in generators:
		if is_instance_valid(gen) and gen.deck() != null:
			out.add(gen.intake_port(), [gen.forward(), gen.deck()], 0)
	for gun in tube_launchers:
		if is_instance_valid(gun) and gun.deck() != null:
			out.add(gun.intake_port(), [gun.forward(), gun.deck()], 0)
	for lift in hay_lifts:
		if is_instance_valid(lift) and lift.deck() != null:
			out.add(lift.port_in(), [lift.forward(), lift.deck()], 0)
	if stand != null and is_instance_valid(stand) and stand.intake_path() != null:
		out.add(stand.belt_entry_point(), [stand.intake_forward(), stand.intake_path()], 0)
	return out


func _overlapped_intake(mouth: Vector3, bearing: Vector3,
		successors: Array [PointIndex]) -> BeltPath:
	if successors.size() < 3 or bearing.length_squared() < 1e-06:
		return null
	var best: BeltPath = null
	var best_in:= INF
	for e: Array in successors [2].within(mouth, PORT_OVERLAP):
		var pair: Array = e [1]
		var facing: Vector3 = pair [0]
		if facing.dot(bearing) < 0.98:
			continue
		var d:= (e [0] as Vector3) - mouth
		var along:= d.dot(bearing)
		if along > PointIndex.JOIN or along < - PORT_OVERLAP:
			continue
		if (d - bearing * along).length() > PORT_OVERLAP_ACROSS:
			continue
		if - along < best_in:
			best_in = - along
			best = pair [1]
	return best


func _overlapped_successor(mouth: Vector3, bearing: Vector3,
		successors: Array [PointIndex]) -> BeltPath:
	if successors.size() < 2 or bearing.length_squared() < 1e-06:
		return null
	var best: BeltPath = null
	var best_in:= INF
	for e: Array in successors [1].within(mouth, PORT_OVERLAP):
		var path:= e [1] as BeltPath
		if path == null or not is_instance_valid(path) or path._line.size() < 2:
			continue
		if path._direction_at(0.0).dot(bearing) < 0.98:
			continue
		var d:= (e [0] as Vector3) - mouth
		var along:= d.dot(bearing)
		if along > - PointIndex.JOIN or along < - PORT_OVERLAP:
			continue
		if (d - bearing * along).length() > PORT_OVERLAP_ACROSS:
			continue
		if - along < best_in:
			best_in = - along
			best = path
	return best


func _seat_open_ends(successors: Array [PointIndex]) -> void:
	if successors.size() < 3:
		return
	var decks:= successors [2].entries()
	for e: Array in decks:
		var deck:= (e [1] as Array) [1] as BeltPath
		if is_instance_valid(deck):
			deck.clear_end_feeders()
	var paths: Array = []
	paths.append_array(conveyors)
	paths.append_array(corners)
	for splitter in splitters:
		if not is_instance_valid(splitter):
			continue
		for side: int in splitter.output_sides():
			paths.append(splitter.route(side))
	for joiner in joiners:
		if is_instance_valid(joiner):
			paths.append(joiner.out_path())
	for p in paths:
		var path:= p as BeltPath
		if path == null or not is_instance_valid(path) or path._line.size() < 2:
			continue
		var over: BeltPath = null
		if path.downstream == null:
			over = _deck_under(path._point_at(path.path_length()), decks)
		path.set_end_deck(over)


const PORT_NEAR:= 0.6


const PORT_NEAR_ACROSS:= 0.25


func unjoined_near(point: Vector3, forward: Vector3, outward: bool) -> Dictionary:
	var f:= Vector3(forward.x, 0.0, forward.z)
	if f.length_squared() < 1e-06:
		return { }
	f = f.normalized()
	var found: Array [Dictionary] = []
	for joint in free_line_joints(point, PORT_NEAR):
		if bool(joint ["start"]) != outward:
			continue
		found.append({ "point": joint ["point"], "forward": joint ["forward"], "machine": false })
	if outward:
		for e: Array in _intake_bearing_index().within(point, PORT_NEAR):
			found.append({ "point": e [0], "forward": (e [1] as Array) [0], "machine": true })
	else:
		for e: Array in _machine_outfeeds().within(point, PORT_NEAR):
			found.append({ "point": e [0], "forward": port_bearing_at(e [0]), "machine": true })
	for c in found:
		var cf: Vector3 = c ["forward"]
		cf = Vector3(cf.x, 0.0, cf.z)
		if cf.length_squared() < 1e-06 or cf.normalized().dot(f) < 0.9:
			continue
		var d:= (c ["point"] as Vector3) - point
		var along:= d.dot(f)
		if absf(along) <= PointIndex.JOIN:
			continue
		var off:= d - f * along
		if Vector2(off.x, off.z).length() > PORT_NEAR_ACROSS or absf(off.y) > 0.2:
			continue


		if outward and along < 0.0 and - along <= PORT_OVERLAP:
			continue
		if not outward and along > 0.0 and along <= PORT_OVERLAP:
			continue
		return { "point": c ["point"], "along": along }
	return { }


static func joins_by_overlap(port: Vector3, forward: Vector3, joint: Vector3, intake: bool) -> bool:
	var f:= Vector3(forward.x, 0.0, forward.z).normalized()
	var along:= (joint - port).dot(f)
	if intake:
		return along > PointIndex.JOIN and along <= PORT_OVERLAP
	return along < - PointIndex.JOIN and - along <= PORT_OVERLAP


const LANE_PORT_RISE:= 1.2


func machine_port_on_lane(mouth: Vector3, out: Vector3, reach: float) -> Dictionary:
	var f:= Vector3(out.x, 0.0, out.z)
	if f.length_squared() < 1e-06:
		return { }
	f = f.normalized()
	var found: Array [Dictionary] = []
	for e: Array in _intake_bearing_index().within(mouth, reach + PORT_NEAR_ACROSS):
		found.append({ "point": e [0], "forward": (e [1] as Array) [0], "intake": true })
	for e: Array in _machine_outfeeds().within(mouth, reach + PORT_NEAR_ACROSS):
		found.append({ "point": e [0], "forward": port_bearing_at(e [0]), "intake": false })
	var best: Dictionary = { }
	var best_d:= INF
	for c in found:
		var cf: Vector3 = c ["forward"]
		cf = Vector3(cf.x, 0.0, cf.z)
		if cf.length_squared() < 1e-06:
			continue


		var want:= f if bool(c ["intake"]) else - f
		if cf.normalized().dot(want) < 0.98:
			continue
		var d:= (c ["point"] as Vector3) - mouth
		var along:= d.dot(f)
		if absf(along) > reach:
			continue
		var off:= d - f * along
		if Vector2(off.x, off.z).length() > PORT_NEAR_ACROSS or absf(off.y) > LANE_PORT_RISE:
			continue
		var p: Vector3 = c ["point"]
		if bool(c ["intake"]) and feed_run_into(p) != null:
			continue
		if not bool(c ["intake"]) and run_out_of(p) != null:
			continue


		if mouth_at(p):
			continue
		if absf(along) < best_d:
			best_d = absf(along)
			best = { "point": p, "forward": cf.normalized(), "intake": c ["intake"],
				"along": along }
	return best


func _deck_under(point: Vector3, decks: Array) -> BeltPath:
	var best: BeltPath = null
	var best_d:= Cfg.BELT_WIDTH * 0.5 + 0.05
	for e: Array in decks:
		var deck:= (e [1] as Array) [1] as BeltPath
		if deck == null or not is_instance_valid(deck) or deck._line.size() < 2:
			continue
		var n:= deck._nearest(point)
		var d:= deck._point_at(float(n ["s"])).distance_to(point)
		if d < best_d:
			best_d = d
			best = deck
	return best


func feed_run_into(port: Vector3, ends: PointIndex = null) -> Conveyor:
	if ends == null and _ports_now() != null:
		ends = _ports_now().ends
	if ends != null:
		var hit:= ends.best(port)
		return hit [1] if not hit.is_empty() else null
	for c in conveyors:
		if is_instance_valid(c) and PointIndex.joins(c.b, port):
			return c
	return null


func run_out_of(port: Vector3, starts: PointIndex = null) -> Conveyor:
	if starts == null and _ports_now() != null:
		starts = _ports_now().starts
	if starts != null:
		var hit:= starts.best(port)
		return hit [1] if not hit.is_empty() else null
	for c in conveyors:
		if is_instance_valid(c) and PointIndex.joins(c.a, port):
			return c
	return null


func _run_ends() -> Array [PointIndex]:
	var starts:= PointIndex.new()
	var ends:= PointIndex.new()
	for i in conveyors.size():
		var c:= conveyors [i]
		if is_instance_valid(c):
			starts.add(c.a, c, i)
			ends.add(c.b, c, i)
	return [starts, ends]


static func corner_tangent(in_forward: Vector3, in_length: float,
		out_forward: Vector3, out_length: float) -> float:
	var t:= minf(corner_want(in_forward, out_forward),
		minf(corner_give(in_length), corner_give(out_length)))
	return t if t > 0.05 else 0.0


static func corner_want(in_forward: Vector3, out_forward: Vector3) -> float:
	var turn:= in_forward.angle_to(out_forward)
	if turn < Cfg.BELT_CORNER_MIN_TURN:
		return 0.0
	return minf(Cfg.BELT_CORNER_RADIUS * tan(minf(turn, PI * 0.94) * 0.5),
		Cfg.BELT_CORNER_MAX_TANGENT)


static func corner_give(length: float) -> float:
	return maxf(length - Cfg.BELT_CORNER_MIN_STRAIGHT, 0.0)


func all_buildings() -> Array [Node3D]:
	var out: Array [Node3D] = []
	for group: Array in [conveyors, water_mains, water_splitters, robotic_arms,
			scanners, compressors,
			pulpers, papers, briquette_presses, wrappers, silos, pelletizers,
			generators, boreholes,
			power_poles,
			tube_launchers, dump_hatches, hay_stairs, hay_lifts, splitters,
			joiners, cabinets, needle_radars, paint_boards, work_lamps, hay_drones,
			piston_rakes, railings, walls, roofs, stairs]:
		for building: Node3D in group:
			out.append(building)
	var decks:= platforms.duplicate()
	decks.sort_custom(func(x: Platform, y: Platform) -> bool:
		return x.top_y() > y.top_y())
	for deck: Platform in decks:
		out.append(deck)
	return out


func value_of(building: Node3D) -> float:
	if building != null and building.has_method("build_cost"):
		return building.build_cost()
	return 0.0


func clear() -> void:


	demo_withheld.clear()
	if _enclosed_visuals != null:
		remove_child(_enclosed_visuals)
		_enclosed_visuals.queue_free()
		_enclosed_visuals = null


	_enclosed_built = PackedVector3Array()

	_enclosed_on_show.clear()
	for c in conveyors:
		remove_child(c)
		c.queue_free()
	conveyors.clear()
	for c in corners:
		remove_child(c)
		c.queue_free()
	corners.clear()
	for run in water_mains:
		remove_child(run)
		run.queue_free()
	water_mains.clear()
	for wye in water_splitters:
		remove_child(wye)
		wye.queue_free()
	water_splitters.clear()
	for arm in robotic_arms:
		remove_child(arm)
		arm.queue_free()
	robotic_arms.clear()
	for deck in platforms:
		remove_child(deck)
		deck.queue_free()
	platforms.clear()
	for flight in stairs:
		remove_child(flight)
		flight.queue_free()
	stairs.clear()
	for rail in railings:
		remove_child(rail)
		rail.queue_free()
	railings.clear()
	for wall in walls:
		remove_child(wall)
		wall.queue_free()
	walls.clear()
	for lid in roofs:
		remove_child(lid)
		lid.queue_free()
	roofs.clear()
	for scanner in scanners:
		remove_child(scanner)
		scanner.queue_free()
	scanners.clear()
	for press in compressors:
		remove_child(press)
		press.queue_free()
	compressors.clear()
	for pulper in pulpers:
		remove_child(pulper)
		pulper.queue_free()
	pulpers.clear()
	for mill in papers:
		remove_child(mill)
		mill.queue_free()
	papers.clear()
	for machine in briquette_presses:
		remove_child(machine)
		machine.queue_free()
	briquette_presses.clear()
	for wrap in wrappers:
		remove_child(wrap)
		wrap.queue_free()
	wrappers.clear()
	for tank in silos:
		remove_child(tank)
		tank.queue_free()
	silos.clear()
	for mill in pelletizers:
		remove_child(mill)
		mill.queue_free()
	pelletizers.clear()
	for gen in generators:
		remove_child(gen)
		gen.queue_free()
	generators.clear()
	for pump in boreholes:
		remove_child(pump)
		pump.queue_free()
	boreholes.clear()
	for pole in power_poles:
		remove_child(pole)
		pole.queue_free()
	power_poles.clear()
	for gun in tube_launchers:
		remove_child(gun)
		gun.queue_free()
	tube_launchers.clear()
	for tip in dump_hatches:
		tip.give_back_load()
		remove_child(tip)
		tip.queue_free()
	dump_hatches.clear()
	for tower in hay_stairs:
		remove_child(tower)
		tower.queue_free()
	hay_stairs.clear()
	for lift in hay_lifts:
		remove_child(lift)
		lift.queue_free()
	hay_lifts.clear()
	for splitter in splitters:
		remove_child(splitter)
		splitter.queue_free()
	splitters.clear()
	for joiner in joiners:
		remove_child(joiner)
		joiner.queue_free()
	joiners.clear()
	for cab in cabinets:
		remove_child(cab)
		cab.queue_free()
	cabinets.clear()
	for dish in needle_radars:
		remove_child(dish)
		dish.queue_free()
	needle_radars.clear()
	for board in paint_boards:
		remove_child(board)
		board.queue_free()
	paint_boards.clear()
	for lamp in work_lamps:
		remove_child(lamp)
		lamp.queue_free()
	work_lamps.clear()
	for drone in hay_drones:
		remove_child(drone)
		drone.queue_free()
	hay_drones.clear()
	for rake in piston_rakes:
		remove_child(rake)
		rake.queue_free()
	piston_rakes.clear()
	changed.emit()


func every_placed() -> Array [Node3D]:
	var out: Array [Node3D] = []
	var groups: Array = [conveyors, corners, water_mains, water_splitters,
		robotic_arms, platforms,
		stairs, railings, walls, roofs, scanners, compressors, pulpers, papers,
		briquette_presses, wrappers,
		silos, pelletizers, generators, boreholes, tube_launchers, dump_hatches,
		hay_stairs, hay_lifts, splitters, joiners, cabinets, needle_radars,
		paint_boards, work_lamps, hay_drones, piston_rakes, power_poles]
	for g in groups:
		for n in g:
			var n3:= n as Node3D
			if n3 != null and is_instance_valid(n3):
				out.append(n3)
	return out


func to_array() -> Array:
	var out: Array = []
	var ordered:= platforms.duplicate()
	ordered.sort_custom(func(x: Platform, y: Platform) -> bool:
		return x.top_y() < y.top_y())
	for deck in ordered:
		out.append(deck.to_dict())
	for flight in stairs:
		out.append(flight.to_dict())
	for rail in railings:
		out.append(rail.to_dict())
	for wall in walls:
		out.append(wall.to_dict())


	for lid in roofs:
		out.append(lid.to_dict())


	for scanner in scanners:
		out.append(scanner.to_dict())
	for press in compressors:
		out.append(press.to_dict())
	for pulper in pulpers:
		out.append(pulper.to_dict())
	for mill in papers:
		out.append(mill.to_dict())
	for machine in briquette_presses:
		out.append(machine.to_dict())
	for wrap in wrappers:
		out.append(wrap.to_dict())
	for tank in silos:
		out.append(tank.to_dict())
	for mill in pelletizers:
		out.append(mill.to_dict())
	for gen in generators:
		out.append(gen.to_dict())
	out.append_array(_withheld_rows("gas_plant"))


	for pump in boreholes:
		out.append(pump.to_dict())
	for pole in power_poles:
		out.append(pole.to_dict())
	for gun in tube_launchers:
		out.append(gun.to_dict())
	for tip in dump_hatches:
		out.append(tip.to_dict())
	for tower in hay_stairs:
		out.append(tower.to_dict())
	for lift in hay_lifts:
		out.append(lift.to_dict())
	for splitter in splitters:
		out.append(splitter.to_dict())


	for wye in water_splitters:
		out.append(wye.to_dict())
	for joiner in joiners:
		out.append(joiner.to_dict())
	for cab in cabinets:
		out.append(cab.to_dict())
	for dish in needle_radars:
		out.append(dish.to_dict())
	out.append_array(_withheld_rows("needle_radar"))
	for board in paint_boards:
		out.append(board.to_dict())
	for lamp in work_lamps:
		out.append(lamp.to_dict())
	for drone in hay_drones:
		out.append(drone.to_dict())
	for rake in piston_rakes:
		out.append(rake.to_dict())
	for c in conveyors:
		out.append(c.to_dict())


	for run in water_mains:
		out.append(run.to_dict())
	for arm in robotic_arms:
		out.append(arm.to_dict())
	return out


func _withheld_rows(type: String) -> Array:
	return demo_withheld.filter(func(d: Dictionary) -> bool:
		return str(d.get("type", "")) == type)


static func _needle_list(d: Dictionary) -> PackedInt32Array:
	var out:= PackedInt32Array()
	for n: Variant in d.get("needles", []):
		out.append(int(n))
	return out


var restore_slice_usec:= 0

var _pass_usec:= 0


func from_array(data: Array) -> void:
	clear()
	var slice_from:= Time.get_ticks_usec()
	for entry in data:
		if restore_slice_usec > 0 and Time.get_ticks_usec() - slice_from >= restore_slice_usec:
			await get_tree().process_frame
			slice_from = Time.get_ticks_usec()
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry
		if Cfg.DEMO and str(d.get("type", "")) in DEMO_WITHHELD_BUILDS:
			demo_withheld.append(d)
			continue
		match d.get("type", ""):
			"platform":
				var deck:= Platform.new()
				deck.name = _free_name("Platform", platforms.size())
				deck.setup(d.get("position", Vector3.ZERO),
					d.get("span", Vector2(Cfg.PLATFORM_TILE, Cfg.PLATFORM_TILE)))


				if d.has("paid"):
					deck.paid_cost = float(d ["paid"])
				platforms.append(deck)
				add_child(deck)
			"stair":
				var flight:= Stair.new()
				flight.name = _free_name("Stair", stairs.size())


				flight.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)), float(d.get("rise", 2.0)),
					float(d.get("pitch", Cfg.STAIR_PITCH)))

				if d.has("paid"):
					flight.paid_cost = float(d ["paid"])
				stairs.append(flight)
				add_child(flight)
			"railing":
				var rail:= Railing.new()
				rail.name = _free_name("Railing", railings.size())
				rail.setup(d.get("a", Vector3.ZERO), d.get("b", Vector3.ZERO))

				if d.has("paid"):
					rail.paid_cost = float(d ["paid"])
				railings.append(rail)
				add_child(rail)
			"wall":


				var saved_a: Vector3 = d.get("a", Vector3.ZERO)
				if saved_a.distance_to(YardWall.end_for(saved_a,
						d.get("b", Vector3.ZERO))) < 1e-06:
					push_warning("BuildManager: a saved wall with no length at %s, dropped"
						% saved_a)
					continue
				var wall:= YardWall.new()
				wall.name = _free_name("Wall", walls.size())


				var bay:= YardWall.Bay.SOLID
				if d.has("kind"):
					bay = int(d ["kind"]) as YardWall.Bay
				elif bool(d.get("windowed", false)):
					bay = YardWall.Bay.WINDOW
				wall.setup(d.get("a", Vector3.ZERO), d.get("b", Vector3.ZERO), bay)

				if d.has("paid"):
					wall.paid_cost = float(d ["paid"])
				walls.append(wall)
				add_child(wall)
			"roof":
				var lid:= Roof.new()
				lid.name = _free_name("Roof", roofs.size())


				lid.setup(d.get("a", Vector3.ZERO), d.get("b", Vector3.ZERO),
					int(d.get("kind", Roof.Kind.FLAT)), int(d.get("side", 1)),
					int(d.get("rows", 1)))

				if d.has("paid"):
					lid.paid_cost = float(d ["paid"])
				roofs.append(lid)
				add_child(lid)
			"haystack_scanner":
				var scanner:= HaystackScanner.new()
				scanner.name = _free_name("HaystackScanner", scanners.size())
				scanner.live = live
				scanner.props = props
				scanner.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)),
					int(d.get("tier", Cfg.SCANNER_DEFAULT_TIER)))


				if d.has("paid"):
					scanner.paid_cost = float(d ["paid"])
				scanner.banked = d.get("banked", PackedInt32Array())
				scanner.stored = int(d.get("stored", 0))


				var carried: Variant = d.get("blocks", null)
				if typeof(carried) == TYPE_ARRAY:
					for record: Variant in carried:
						if typeof(record) == TYPE_DICTIONARY:
							scanner.blocks.append(record)
				else:
					var one: Variant = d.get("block", { })
					if typeof(one) == TYPE_DICTIONARY and not (one as Dictionary).is_empty():
						scanner.blocks.append(one)
				scanner.set_switched_off(bool(d.get("off", false)))
				scanners.append(scanner)
				add_child(scanner)
			"hay_compressor":
				var press:= HayCompressor.new()
				press.name = _free_name("HayCompressor", compressors.size())
				press.live = live
				press.props = props
				press.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				press.stored = int(d.get("stored", 0))


				press.pending_needles = _needle_list(d)
				press.set_switched_off(bool(d.get("off", false)))
				compressors.append(press)
				add_child(press)
			"hay_pulper":
				var pulper:= HayPulper.new()
				pulper.name = _free_name("HayPulper", pulpers.size())
				pulper.live = live
				pulper.props = props
				pulper.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				pulper.stored = int(d.get("stored", 0))


				pulper.pending_needles = _needle_list(d)
				pulper.set_switched_off(bool(d.get("off", false)))
				pulpers.append(pulper)
				add_child(pulper)
			"paper_machine":
				var mill:= PaperMachine.new()
				mill.name = _free_name("PaperMachine", papers.size())
				mill.props = props
				mill.live = live
				mill.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))


				mill.from_dict(d)
				mill.set_switched_off(bool(d.get("off", false)))
				papers.append(mill)
				add_child(mill)
			"briquette_press":
				var briq:= BriquettePress.new()
				briq.name = _free_name("BriquettePress", briquette_presses.size())
				briq.props = props
				briq.live = live
				briq.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))


				briq.from_dict(d)
				briq.set_switched_off(bool(d.get("off", false)))
				briquette_presses.append(briq)
				add_child(briq)
			"hay_wrapper":
				var wrap:= HayWrapper.new()
				wrap.name = _free_name("HayWrapper", wrappers.size())
				wrap.props = props
				wrap.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				wrap.from_dict(d)
				wrap.set_switched_off(bool(d.get("off", false)))
				wrappers.append(wrap)
				add_child(wrap)
			"hay_silo":
				var tank:= HaySilo.new()
				tank.name = _free_name("HaySilo", silos.size())
				tank.live = live
				tank.props = props
				tank.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))


				tank.from_dict(d)
				tank.set_switched_off(bool(d.get("off", false)))
				silos.append(tank)
				add_child(tank)
			"hay_pelletizer":
				var mill:= HayPelletizer.new()
				mill.name = _free_name("HayPelletizer", pelletizers.size())
				mill.live = live
				mill.props = props
				mill.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))


				mill.port_reach = float(d.get("port_reach", 0.0))
				mill.stored = int(d.get("stored", 0))


				mill.set_throw_distance(
					float(d.get("throw", Cfg.PELLETIZER_THROW_DISTANCE)))
				mill.pending_needles = _needle_list(d)
				mill.set_switched_off(bool(d.get("off", false)))
				pelletizers.append(mill)
				add_child(mill)
			"hay_generator":
				var gen:= HayGenerator.new()
				gen.name = _free_name("HayGenerator", generators.size())
				gen.live = live
				gen.props = props
				gen.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))


				gen.port_reach = float(d.get("port_reach", 0.0))


				gen.fuel = float(d.get("fuel", 0.0))


				if d.has("paid"):
					gen.paid_cost = minf(float(d ["paid"]), Cfg.GENERATOR_COST)


				gen.adopt_saved_ash(_needle_list(d))
				gen.set_switched_off(bool(d.get("off", false)))
				generators.append(gen)
				add_child(gen)


			"gas_plant":
				var plant:= GasPlant.new()
				plant.name = _free_name("GasPlant", generators.size())
				plant.live = live
				plant.props = props
				plant.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				plant.fuel = float(d.get("fuel", 0.0))
				plant.tank = float(d.get("tank", -1.0))
				if d.has("paid"):
					plant.paid_cost = float(d ["paid"])
				plant.set_switched_off(bool(d.get("off", false)))
				generators.append(plant)
				add_child(plant)
			"borehole_pump":


				var pump:= BoreholePump.new()
				pump.name = _free_name("BoreholePump", boreholes.size())
				pump.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				pump.set_switched_off(bool(d.get("off", false)))
				boreholes.append(pump)
				add_child(pump)
			"power_pole", "power_box":


				var buried_box:= str(d.get("type", "")) == "power_box"
				var pole: PowerPole = PowerBox.new() if buried_box else PowerPole.new()
				pole.name = _free_name("PowerBox" if buried_box else "PowerPole",
					power_poles.size())
				pole.gift = not buried_box and bool(d.get("gift", false))
				pole.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))


				if d.has("links"):
					for at: Variant in (d ["links"] as Array):
						pole.links_at.append(at as Vector3)
				elif d.has("link"):

					pole.links_at.append(d ["link"] as Vector3)
				power_poles.append(pole)
				add_child(pole)
			"dump_hatch":
				var tip:= DumpHatch.new()
				tip.name = _free_name("DumpHatch", dump_hatches.size())
				tip.live = live
				tip.props = props
				tip.builds = self
				tip.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				tip.from_dict(d)
				dump_hatches.append(tip)
				add_child(tip)
			"tube_launcher":
				var gun:= TubeLauncher.new()
				gun.name = _free_name("TubeLauncher", tube_launchers.size())
				gun.live = live
				gun.props = props
				gun.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				gun.from_dict(d)
				gun.set_switched_off(bool(d.get("off", false)))
				tube_launchers.append(gun)
				add_child(gun)
			"piston_rake":
				var rake:= PistonRake.new()
				rake.name = _free_name("PistonRake", piston_rakes.size())
				rake.live = live
				rake.props = props
				rake.field = field
				rake.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				rake.throw_distance = clampf(
					float(d.get("throw", Cfg.RAKE_THROW_DISTANCE)),
					Cfg.RAKE_THROW_MIN, Cfg.RAKE_THROW_MAX)


				if d.has("paid"):
					rake.paid_cost = float(d ["paid"])
				rake.gift = bool(d.get("gift", false))
				if rake.gift:
					rake.paid_cost = 0.0
				rake.set_switched_off(bool(d.get("off", false)))
				piston_rakes.append(rake)
				add_child(rake)
			"hay_stairs":
				var tower:= HayStairs.new()
				tower.name = _free_name("HayStairs", hay_stairs.size())
				tower.live = live
				tower.props = props
				tower.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				hay_stairs.append(tower)
				add_child(tower)
			"hay_lift":
				var lift:= HayLift.new()
				lift.name = _free_name("HayLift", hay_lifts.size())
				lift.live = live
				lift.props = props


				lift.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)),
					int(d.get("sections", lift.sections)),
					float(d.get("riser", 0.0)))


				lift.port_reach = [0.0, 0.0]
				var reach: Variant = d.get("port_reach", [])
				if reach is Array:
					for i in mini(reach.size(), 2):
						lift.port_reach [i] = float(reach [i])
				hay_lifts.append(lift)
				add_child(lift)
			"conveyor_splitter", "conveyor_u_splitter", "conveyor_t_splitter", "conveyor_compact_splitter", "conveyor_smart_splitter":


				var kind: String = d.get("type", "")
				var splitter: ConveyorSplitter
				if kind == "conveyor_smart_splitter" or kind == "conveyor_compact_splitter":
					var compact:= ConveyorCompactSplitter.new()
					compact.smart = kind == "conveyor_smart_splitter"
					compact.name = ("ConveyorSmartSplitter%d" if compact.smart else "ConveyorCompactSplitter%d") % splitters.size()
					splitter = compact
				elif kind == "conveyor_t_splitter":
					var t_split:= ConveyorTSplitter.new()


					t_split.port_r = float(d.get("port_r", Cfg.T_SPLITTER_PORT_R_V1))
					splitter = t_split
					splitter.name = _free_name("ConveyorTSplitter", splitters.size())
				elif kind == "conveyor_u_splitter":
					splitter = ConveyorUSplitter.new()
					splitter.name = _free_name("ConveyorUSplitter", splitters.size())
				else:
					splitter = ConveyorSplitter.new()
					splitter.name = _free_name("ConveyorSplitter", splitters.size())
				splitter.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))


				if splitter is ConveyorTSplitter:
					(splitter as ConveyorTSplitter).set_entry(clampi(
						int(d.get("entry", ConveyorTSplitter.STEM)),
						ConveyorTSplitter.STEM, ConveyorTSplitter.BAR_NEG))


				var max_side:= ConveyorCompactSplitter.OUT_RIGHT if splitter is ConveyorCompactSplitter else ConveyorSplitter.RIGHT
				splitter.next_side = clampi(
					int(d.get("next_side", ConveyorSplitter.LEFT)),
					ConveyorSplitter.LEFT, max_side)
				if splitter is ConveyorCompactSplitter:
					var saved_filters: Array = d.get("filters", [])
					for side in range(mini(saved_filters.size(), 3)):
						(splitter as ConveyorCompactSplitter).filters [side] = int(saved_filters [side])


				if not splitter is ConveyorCompactSplitter:
					splitter.set_forced_side(clampi(int(d.get("forced_side", -1)),
						-1, ConveyorSplitter.RIGHT))


				if not splitter is ConveyorCompactSplitter:
					splitter.set_priority_side(clampi(int(d.get("priority_side", -1)),
						-1, ConveyorSplitter.RIGHT))
				splitters.append(splitter)
				add_child(splitter)
			"conveyor_joiner", "conveyor_u_joiner", "conveyor_t_joiner":

				var join_kind: String = d.get("type", "")
				var joiner: ConveyorJoiner
				if join_kind == "conveyor_t_joiner":
					var t_join:= ConveyorTJoiner.new()

					t_join.out_lane = clampi(int(d.get("out_lane", ConveyorTSplitter.STEM)),
						ConveyorTSplitter.STEM, ConveyorTSplitter.BAR_NEG)
					t_join.port_r = float(d.get("port_r", Cfg.T_SPLITTER_PORT_R_V1))
					joiner = t_join
					joiner.name = _free_name("ConveyorTJoiner", joiners.size())
				elif join_kind == "conveyor_u_joiner":
					joiner = ConveyorUJoiner.new()
					joiner.name = _free_name("ConveyorUJoiner", joiners.size())
				else:
					joiner = ConveyorJoiner.new()
					joiner.name = _free_name("ConveyorJoiner", joiners.size())
				joiner.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))


				joiner.next_side = clampi(
					int(d.get("next_side", ConveyorJoiner.LEFT)),
					ConveyorJoiner.LEFT, ConveyorJoiner.RIGHT)
				joiners.append(joiner)
				add_child(joiner)
			"needle_cabinet":
				var cab:= NeedleCabinet.new()
				cab.name = _free_name("NeedleCabinet", cabinets.size())
				cab.gift = bool(d.get("gift", false))
				cab.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				cab.live = live
				cabinets.append(cab)
				add_child(cab)


				cabinet_added.emit(cab)
			"needle_radar":
				var dish:= NeedleRadar.new()
				dish.name = _free_name("NeedleRadar", needle_radars.size())
				dish.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				dish.field = field
				dish.from_dict(d)
				needle_radars.append(dish)
				add_child(dish)
			"paint_board":
				var board:= PaintBoard.new()
				board.name = _free_name("PaintBoard", paint_boards.size())
				board.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				paint_boards.append(board)
				add_child(board)


				board.from_dict(d)
			"work_lamp":
				var lamp:= WorkLamp.new()
				lamp.name = _free_name("WorkLamp", work_lamps.size())
				lamp.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				work_lamps.append(lamp)
				add_child(lamp)


				lamp.from_dict(d)
			"conveyor":
				var c:= Conveyor.new()
				c.name = _free_name("Conveyor", conveyors.size())
				c.setup(d.get("a", Vector3.ZERO), d.get("b", Vector3.ZERO))

				if d.has("paid"):
					c.paid_cost = float(d ["paid"])


				c.line_id = int(d.get("line", 0))

				if d.get("seat") is Vector3:
					c.seat_port = d ["seat"]
				conveyors.append(c)
				add_child(c)
			"enclosed_conveyor":
				var c:= EnclosedConveyor.new()
				c.name = _free_name("EnclosedConveyor", conveyors.size())
				c.setup(d.get("a", Vector3.ZERO), d.get("b", Vector3.ZERO))
				if d.has("paid"):
					c.paid_cost = float(d ["paid"])
				c.line_id = int(d.get("line", 0))
				conveyors.append(c)
				add_child(c)
			"water_splitter":


				var wye:= WaterSplitter.new()
				wye.name = _free_name("WaterSplitter", water_splitters.size())
				wye.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)))
				if d.has("paid"):
					wye.paid_cost = float(d ["paid"])
				water_splitters.append(wye)
				add_child(wye)
			"water_main":


				var main:= WaterMain.new()
				main.name = _free_name("WaterMain", water_mains.size())
				main.setup(d.get("a", Vector3.ZERO), d.get("b", Vector3.ZERO))
				if d.has("paid"):
					main.paid_cost = float(d ["paid"])
				water_mains.append(main)
				add_child(main)
			"robotic_arm":
				var arm:= RoboticArm.new()
				arm.name = _free_name("RoboticArm", robotic_arms.size())
				arm.builds = self
				arm.live = live
				arm.field = field
				arm.props = props
				arm.setup(d.get("position", Vector3.ZERO),
					float(d.get("yaw", 0.0)), int(d.get("tier", Cfg.ROBOT_ARM_DEFAULT_TIER)))


				if d.has("paid"):
					arm.paid_cost = float(d ["paid"])
				else:
					arm.legacy_refit = true


				if d.has("refuses"):
					arm.accept_mask = RoboticArm.mask_from_refusals(d ["refuses"])
				elif d.has("accepts"):
					arm.accept_mask = RoboticArm.mask_from_legacy(int(d ["accepts"]))
				else:
					arm.accept_mask = RoboticArm.PICK_ALL


				if d.has("links"):
					arm.load_links(d ["links"])

				arm.pick_order = RoboticArm.order_from_id(str(d.get("order", "")))
				arm.set_switched_off(bool(d.get("off", false)))
				robotic_arms.append(arm)
				add_child(arm)
			"hay_drone":
				var drone:= HayDrone.new()
				drone.name = _free_name("HayDrone", hay_drones.size())
				drone.props = props
				drone.stand = stand
				drone.field = field
				drone.builds = self
				drone.live = live
				drone.setup(d.get("position", Vector3.ZERO), float(d.get("yaw", 0.0)))


				if d.has("paid"):
					drone.paid_cost = float(d ["paid"])
				drone.set_switched_off(bool(d.get("off", false)))


				drone.restore_job(d)
				hay_drones.append(drone)
				add_child(drone)
			_:
				push_warning("BuildManager: unknown building type '%s' in save" % d.get("type", ""))
	await _restore_pass_done("")

	rebuild_junctions()
	await _restore_pass_done("junctions")


	rebuild_water_joints()
	await _restore_pass_done("water joints")


	upgrade_placed_models()
	await _restore_pass_done("model upgrades")
	fit_posts_to_decks()
	share_joints()
	_reground_after_load()
	changed.emit()


func _restore_pass_done(what: String) -> void:
	if restore_slice_usec <= 0:
		return
	var now:= Time.get_ticks_usec()
	if what != "" and now - _pass_usec >= 50000:
		print("[load]   restore pass %s: %.0f ms" % [what, (now - _pass_usec) / 1000.0])
	await get_tree().process_frame
	_pass_usec = Time.get_ticks_usec()


func _reground_after_load() -> void:
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	regroup_deck_legs(false)
	for deck in platforms:
		if is_instance_valid(deck):
			deck.refresh_supports(true)
	restyle_hatches()
	for lid in roofs:
		if is_instance_valid(lid):
			lid.refresh_ladder(true)
	for c in conveyors:
		if is_instance_valid(c):
			c.refresh_supports()
	for run in water_mains:
		if is_instance_valid(run):
			run.refresh_supports()
	for scanner in scanners:
		if is_instance_valid(scanner):
			scanner.refresh_supports()
	for press in compressors:
		if is_instance_valid(press):
			press.refresh_supports()
	for pulper in pulpers:
		if is_instance_valid(pulper):
			pulper.refresh_supports()
	for mill in papers:
		if is_instance_valid(mill):
			mill.refresh_supports()
	for machine in briquette_presses:
		if is_instance_valid(machine):
			machine.refresh_supports()
	for wrap in wrappers:
		if is_instance_valid(wrap):
			wrap.refresh_supports()
	for tank in silos:
		if is_instance_valid(tank):
			tank.refresh_supports()
	for splitter in splitters:
		if is_instance_valid(splitter):
			splitter.refresh_supports()
	for joiner in joiners:
		if is_instance_valid(joiner):
			joiner.refresh_supports()
