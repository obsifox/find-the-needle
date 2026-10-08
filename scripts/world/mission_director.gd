class_name MissionDirector
extends Node


const POLL:= 0.1


const POUR_CREDIT:= 40


const FILLED_FRACTION:= 1.0


const STAND_REACH:= 9.0


const TILT_MIN:= 0.1


const TILT_TURN:= PI * 0.5


const REACH_MOVE:= 2.0


const NO_TILT:= 99.0


const READ_TIME:= 3.0

var world: Node3D
var player: Player
var panel: QuestPanel


var cue: MissionCue


var _seen: Dictionary = { }
var _clock:= 0.0

var _last_stored:= -1


var _poured_here:= 0
var _celebrating:= 0.0

var _tilts:= 0


var _stacks:= 0
var _stacks_live:= 0


var _last_stacked:= -1

var _last_throws:= -1


var _last_owned:= -1


var _last_pulled:= -1


var _last_turned:= -1


var _last_fetch:= -1


var _last_grids:= -1
var _last_turned_place:= -1
var _last_copied:= -1

var _sprint_time:= 0.0


var _run_time:= MissionBook.goal_of("run")


var _live: Dictionary = { }


var _stale: Dictionary = { }

var _priming:= true


var _open_index:= -1


var _tilts_live:= 0


var _rolled_out:= 0.0
var _rolled_in:= 0.0

var _last_reach:= -1.0


var _power_flips:= 0


var _last_cycles:= -1


var _tilt_from:= NO_TILT


var _last_dumps:= -1


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if player == null or world == null:
		return
	if _celebrating > 0.0:
		_celebrating = maxf(0.0, _celebrating - delta)
	if _open_index != GameState.mission_index:
		_open_index = GameState.mission_index
		_open_step()
	_watch(delta)
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = POLL
	_advance()


func _watch(_delta: float = 0.0) -> void:


	if player.is_sprinting():
		_sprint_time += _delta
	_saw("ran", _sprint_time >= _run_time)
	if player.carry == null:
		return
	var held:= player.carry.held()


	var on_blade:= 0
	if held is SandShovel:
		on_blade = (held as SandShovel).carried_strands()
	elif player.shovel != null and player.shovel._active:
		on_blade = player.shovel.carried_strands()
	elif player.pitchfork != null and player.pitchfork._active:
		on_blade = player.pitchfork.carried_strands()
	_saw("scoop", on_blade > 0)


	_saw("tilt", on_blade > 0 and not Cfg.simple_tools() and player.pour_intent())


	_saw("pin", GameState.contract_pinned)


	var box:= held as HayContainer
	if box == null:
		_last_stored = -1
		_poured_here = 0
	else:
		if _last_stored >= 0 and box.stored < _last_stored:
			if _stand_distance() <= STAND_REACH:
				_poured_here += _last_stored - box.stored
			else:


				_poured_here = 0
		_saw("poured_at_stand", _poured_here >= POUR_CREDIT)
		_last_stored = box.stored


	var owned:= _owned_tool_count()
	_saw("dropped_tool", _last_owned >= 0 and owned < _last_owned)
	_last_owned = owned


	var toy:= held as SandShovel
	if toy == null:
		_last_stacked = -1
	else:
		if _last_stacked >= 0 and toy.stacked_scoops > _last_stacked:
			var more:= toy.stacked_scoops - _last_stacked
			_stacks += more
			_stacks_live += more
		_last_stacked = toy.stacked_scoops
	if player.hand != null:
		_saw("threw_hay", _last_throws >= 0 and player.hand.throws > _last_throws)
		_last_throws = player.hand.throws


	if player.detector != null:
		var cycles: int = player.detector.power_cycles
		if _last_cycles >= 0 and cycles > _last_cycles:
			_power_flips += cycles - _last_cycles
		_last_cycles = cycles

	_watch_tilt()
	_saw("filled_bucket", _fullest_container() >= FILLED_FRACTION)
	_saw("equipped_toy", player.current_tool == Player.Tool.TOY)
	var shop:= world.get("shop_menu") as ShopMenu
	if shop != null:
		_saw("fetched", _last_fetch >= 0 and shop.fetched > _last_fetch)
		_last_fetch = shop.fetched
	_saw("shop", world.get("shop_menu") != null
		and (world.shop_menu as ShopMenu).is_open())
	_saw("tech", player.tech_panel != null and player.tech_panel.is_open())
	_saw("build_menu", player.catalog != null and player.catalog.is_open())
	_saw("rake_panel", player.rake_panel != null and player.rake_panel.is_open())


	if player.build != null:
		var reach:= float(player.build.status().get("reach", 0.0))
		if _last_reach >= 0.0:
			var moved:= reach - _last_reach
			if moved > 0.0:
				_rolled_out += moved
			elif moved < 0.0:
				_rolled_in += - moved
		_last_reach = reach


	if player.build != null:
		var pulled: int = player.build.dismantled
		_saw("dismantled", _last_pulled >= 0 and pulled > _last_pulled)
		_last_pulled = pulled


		var turned: int = player.build.reversed
		_saw("reversed", _last_turned >= 0 and turned > _last_turned)
		_last_turned = turned


		var gridded: int = player.build.grids
		_saw("gridded", _last_grids >= 0 and gridded > _last_grids)
		_last_grids = gridded


		var turned_place: int = player.build.turns
		_saw("turned", _last_turned_place >= 0 and turned_place > _last_turned_place)
		_last_turned_place = turned_place
		var copied: int = player.build.copied
		_saw("copy_taken", _last_copied >= 0 and copied > _last_copied)
		_last_copied = copied


	_priming = false


func _saw(key: String, on: bool) -> void:
	if not on:
		_stale.erase(key)
		return
	_seen [key] = true
	if _priming:
		_stale [key] = true
	elif not _stale.has(key):
		_live [key] = true


func _watch_tilt() -> void:


	if Cfg.simple_tools():
		var total:= _tool_dumps()
		if _last_dumps >= 0 and total > _last_dumps:
			var made:= total - _last_dumps
			_tilts += made
			_tilts_live += made
		_last_dumps = total
		return
	if not player.pour_intent():
		return
	var up:= _held_tool_up()
	if up == Vector3.ZERO:
		return
	var lean:= Vector2(up.x, up.z)
	if lean.length() < TILT_MIN:
		return
	var angle:= lean.angle()
	if _tilt_from != NO_TILT and absf(angle_difference(_tilt_from, angle)) < TILT_TURN:
		return
	_tilt_from = angle
	_tilts += 1
	_tilts_live += 1


func _tool_dumps() -> int:
	var total:= 0
	if player.shovel != null:
		total += player.shovel.dumps
	if player.pitchfork != null:
		total += player.pitchfork.dumps
	if player.carry != null and player.carry.held() is SandShovel:
		total += (player.carry.held() as SandShovel).dumps
	return total


func _held_tool_up() -> Vector3:
	var held:= player.carry.held()
	if held != null:
		return held.global_transform.basis.y
	if player.shovel != null and player.shovel._active and player.shovel.body != null:
		return player.shovel.body.global_transform.basis.y
	if player.pitchfork != null and player.pitchfork._active and player.pitchfork.body != null:
		return player.pitchfork.body.global_transform.basis.y
	return Vector3.ZERO


func _tilt_count() -> int:
	return _tilts_live if is_live_lesson("tilt_pour") else _tilts


func _stack_count() -> int:
	return _stacks_live if is_live_lesson("stack_scoop") else _stacks


func _toy_blade_full() -> bool:
	if player == null or player.carry == null:
		return false
	var toy:= player.carry.held() as SandShovel
	return toy != null and toy.is_full()


func _reach_ways() -> int:
	var n:= 0
	if _rolled_out >= REACH_MOVE:
		n += 1
	if _rolled_in >= REACH_MOVE:
		n += 1
	return n


func _advance() -> void:
	var guard:= 0


	while GameState.mission_index < MissionBook.count() and guard < MissionBook.count():
		guard += 1
		var id:= MissionBook.id_at(GameState.mission_index)
		if not is_done(id):
			break
		if not _has_been_read(GameState.mission_index):
			break
		GameState.mission_index += 1
		_open_index = GameState.mission_index
		_open_step()
		if panel != null:
			panel.mark_complete(id)
	if panel != null:
		panel.show_step(GameState.mission_index)
		panel.show_progress(progress_of(MissionBook.id_at(GameState.mission_index)))


	var on:= panel.showing() if panel != null else GameState.mission_index
	if cue != null:
		cue.show_step(on if _cue_due(on) else -1)
		cue.show_progress(progress_of(MissionBook.id_at(on)))


	if player.tech_panel != null:
		player.tech_panel.set_hint(MissionBook.board_node(on) if Cfg.show_missions else "")


func _open_step() -> void:
	_live.clear()
	_stale.clear()
	_tilts_live = 0
	_stacks_live = 0


	_last_owned = -1
	_last_pulled = -1
	_last_turned = -1
	_last_grids = -1
	_last_turned_place = -1
	_last_copied = -1
	_sprint_time = 0.0
	_last_stacked = -1
	_last_throws = -1
	_last_fetch = -1


	_tilt_from = NO_TILT


	_rolled_out = 0.0
	_rolled_in = 0.0
	_last_reach = -1.0
	_power_flips = 0
	_last_cycles = -1
	_priming = true


	var open:= GameState.mission_index
	var open_id:= MissionBook.id_at(open)
	if str(MissionBook.step(open).get("goal_from", "")) == "earned" and GameState.mission_earned_step != open_id:
		GameState.mission_earned_step = open_id
		GameState.mission_earned_from = GameState.money_earned


	_give_reward(open - 1)


func _earned_since_open(id: String) -> float:
	if GameState.mission_earned_step != id:
		if MissionBook.id_at(GameState.mission_index) != id:
			return 0.0
		GameState.mission_earned_step = id
		GameState.mission_earned_from = GameState.money_earned
	return maxf(0.0, GameState.money_earned - GameState.mission_earned_from)


var gift_card: GiftCard


const MARK_OVER_SHOP:= 1.1
const MARK_OVER_RAKE:= PistonRake.BODY_H + 0.35

const MARK_OVER_BELT:= 0.9


const MARK_OVER_TOOL:= 0.6


const MARK_ICONS:= { "find_shop": "cart", "rake_throw": "throw", "reverse_belt": "reset",
	"pick_up_shovel": "shovel" }


func marker_icon() -> String:
	var on:= panel.showing() if panel != null else GameState.mission_index
	return str(MARK_ICONS.get(MissionBook.id_at(on), "")) if on >= 0 else ""


func marker_point() -> Variant:
	if world == null or player == null:
		return null
	var on:= panel.showing() if panel != null else GameState.mission_index
	var id:= MissionBook.id_at(on) if on >= 0 else ""
	if id == "":
		return null
	match id:
		"find_shop":
			var shop:= world.get("shop") as HayShop
			if shop != null and shop.is_inside_tree():
				return shop.focus_point() + Vector3.UP * MARK_OVER_SHOP
		"pick_up_shovel":
			return _nearest_loose_point("sand_shovel", MARK_OVER_TOOL)
		"rake_throw":
			var builds: BuildManager = world.builds
			if builds == null:
				return null
			var best: PistonRake = null
			var best_d:= INF
			var here:= player.global_position
			for rake: PistonRake in builds.piston_rakes:
				if not is_instance_valid(rake) or not rake.is_inside_tree():
					continue
				var d:= here.distance_squared_to(rake.global_position)
				if d < best_d:
					best_d = d
					best = rake
			if best != null:
				return best.global_transform * Vector3(0.0, MARK_OVER_RAKE, PistonRake.BODY_Z)
		"reverse_belt":
			return _nearest_belt_point()
	return null


func _nearest_loose_point(id: String, over: float) -> Variant:
	var props: PropManager = world.props
	if props == null:
		return null
	var here:= player.global_position
	var best: Carryable = null
	var best_d:= INF
	for item: Carryable in props.items:
		if not is_instance_valid(item) or item.item_id != id or not item.is_inside_tree() or item.is_held():
			continue
		var d:= here.distance_squared_to(item.global_position)
		if d < best_d:
			best_d = d
			best = item
	return best.global_position + Vector3.UP * over if best != null else null


func _nearest_belt_point() -> Variant:
	var builds: BuildManager = world.builds
	if builds == null:
		return null
	var here:= player.global_position
	var best: Variant = null
	var best_d:= INF
	for belt: Conveyor in builds.conveyors:
		if not is_instance_valid(belt) or not belt.is_inside_tree():
			continue
		var p:= Geometry3D.get_closest_point_to_segment(here, belt.a, belt.b)
		var d:= here.distance_squared_to(p)


		if d < best_d and builds.reverse_blocked_reason(belt) == "":
			best_d = d
			best = p + Vector3.UP * MARK_OVER_BELT
	return best


func _give_reward(index: int) -> void:
	if index < 0 or world == null:
		return
	var what:= str(MissionBook.step(index).get("reward", ""))
	if what == "":
		return
	var step_id:= MissionBook.id_at(index)
	if GameState.gifts_given.has(step_id):
		return
	GameState.gifts_given [step_id] = true
	var builds: BuildManager = world.builds
	if builds == null:
		return
	if what == "cabinet" and builds.has_cabinet():
		return
	if what == "rake" and not builds.piston_rakes.is_empty():
		return
	if what == "pole" and not builds.power_poles.is_empty():
		return
	var card:= BuildCatalog.unlock_of(what)
	if card != "" and not Tech.is_unlocked(card):
		Tech.grant(card)
	GameState.give_gift(what)


	GameState.gift_card_due = what


func _has_been_read(index: int) -> bool:
	if index >= MissionBook.LIVE_COUNT or panel == null:
		return true
	return panel.seconds_shown(index) >= READ_TIME


func _cue_due(index: int) -> bool:
	if index < 0:
		return true
	var s:= MissionBook.step(index)
	if not bool(s.get("cue_when_paid", false)):
		return true
	return GameState.money >= float(s.get("goal", 0.0))


func progress_of(id: String) -> Dictionary:
	var s:= MissionBook.step(MissionBook.index_of(id))
	if not s.has("goal"):
		return { }
	var need:= float(s ["goal"])
	var kind:= str(s.get("goal_kind", "count"))
	var have:= 0.0
	match id:
		"first_dollar":

			have = GameState.money
		"twenty_dollars":


			have = _earned_since_open(id)
		"buy_toy_licence":


			have = GameState.money
		"fill_bucket":
			have = _fullest_container()
		"tilt_pour":
			have = float(_tilt_count())
		"stack_scoop":
			have = float(_stack_count())
		"build_distance":
			have = float(_reach_ways())
		"detector_power":
			have = float(_power_flips)
		"run":
			have = _sprint_time
		_:
			return { }
	have = minf(have, need)
	var text:= ""
	if kind == "money":


		text = tr("$%s / $%s   ·   $%s left") % [
			_money(have), _money(need), _money(maxf(need - have, 0.0))]
	elif kind == "fraction":


		text = tr("%d%% full") % int(round(have * 100.0))
	elif kind == "seconds":


		text = tr("%.1fs / %ds") % [have, int(need)]
	elif kind == "bar":
		pass
	else:


		text = "%d / %d" % [int(have), int(need)]
	return { "have": have, "need": need, "text": text }


static func _money(v: float) -> String:
	return "%.2f" % v


func is_done(id: String) -> bool:
	var builds: BuildManager = world.builds
	var props: PropManager = world.props
	match id:
		"first_hay":
			return GameState.hay_dug > 0.0
		"pin_contract":


			return GameState.contract_pinned and _gesture(id, "pin", true)
		"first_contract":


			return not GameState.contracts_done.is_empty()
		"first_dollar":
			return _cash_goal_met(id)
		"find_shop":
			return _gesture(id, "shop", _owns_any_shop_item(props))
		"buy_toy_licence":
			return Tech.is_unlocked("sand_shovel")
		"buy_handful":
			return Tech.rank_of("hand_carry") >= 1
		"buy_toy_shovel":
			return _owns_or_has("sand_shovel", props)
		"pick_up_shovel":


			if is_live_lesson(id):
				return _seen.has("equipped_toy")
			return _seen.has("equipped_toy") or _owns_or_has("spade", props)
		"scoop":


			return _gesture(id, "scoop",
				_owns_or_has("spade", props) or GameState.hay_dug >= 500.0)
		"stack_scoop":


			if _stacks_live >= MissionBook.goal_of(id):
				return true
			if _toy_blade_full():
				return true
			if is_live_lesson(id):
				return false
			return _stacks >= MissionBook.goal_of(id) or GameState.money_earned >= 20.0
		"throw_hay":


			return _gesture(id, "threw_hay", GameState.money_earned >= 20.0)
		"tilt_pour":


			if is_live_lesson(id):
				return _tilts_live >= MissionBook.goal_of(id)
			return _tilts >= MissionBook.goal_of(id) or GameState.money_earned >= 20.0
		"twenty_dollars":


			return _earned_since_open(id) >= MissionBook.goal_of(id) or _cash_goal_met(id)
		"power_up":


			if not builds.piston_rakes.is_empty():
				return true
			for gen in builds.generators:
				if is_instance_valid(gen) and (gen.fuel > 0.0 or gen.output_kw() > 0.0):
					return true
			return false
		"open_tech":
			return _gesture(id, "tech", _any_node_bought())
		"buy_spade":
			return _owns_or_has("spade", props)
		"drop_tool":


			return _gesture(id, "dropped_tool", GameState.money_earned >= 250.0)
		"bring_to_me":


			return _gesture(id, "fetched",
				GameState.used_fetch or GameState.money_earned >= 400.0)
		"buy_bucket":
			return props.count_of("bucket") > 0
		"fill_bucket":


			return _gesture(id, "filled_bucket",
				_fullest_container() >= FILLED_FRACTION or GameState.money_earned >= 250.0)
		"pour_bucket":
			return _gesture(id, "poured_at_stand", GameState.money_earned >= 400.0)
		"open_build":


			return _gesture(id, "build_menu", _anything_built(builds))
		"dismantle":


			return _gesture(id, "dismantled", builds.robotic_arms.size() > 0)
		"reverse_belt":


			return _gesture(id, "reversed", builds.robotic_arms.size() > 0)
		"build_distance":


			return _reach_ways() >= 2 or builds.robotic_arms.size() > 0
		"build_belt":
			return builds.conveyors.size() > 0
		"run":


			return _gesture(id, "ran", false)
		"grid_place", "turn_build", "copy_build":


			var latch:= { "grid_place": "gridded", "turn_build": "turned",
				"copy_build": "copy_taken" } [id] as String
			return _gesture(id, latch, builds.robotic_arms.size() > 0)
		"belt_feeds_stand":
			return _belt_reaches_stand(builds)
		"first_needle":
			return GameState.needles_found > 0
		"build_cabinet":
			return builds.has_cabinet()
		"bank_needle":
			return _any_needle_banked()
		"build_arm":
			return builds.robotic_arms.size() > 0
		"build_rake":
			return builds.piston_rakes.size() > 0
		"upgrade_belt":


			return Tech.rank_of("belt_speed") > 0
		"rake_throw":


			return _gesture(id, "rake_panel",
				_any_rake_throw_set(builds) or not GameState.contracts_done.is_empty())
		"extend_shed":


			if Tech.off_site("yard_space"):
				return true

			return Tech.rank_of("yard_space") > 0
		"build_scanner":
			return builds.scanners.size() > 0
		"build_power":
			return _yard_has_power(builds)
		"buy_detector":
			return GameState.has_tool("metal_detector")
		"detector_power":


			return _power_flips >= int(MissionBook.goal_of("detector_power"))
		"wrapped_order":
			return GameState.contracts_done.has(DeliveryBook.id_at(1))
		"build_drone":
			return builds.hay_drones.size() > 0
		"build_gas_plant", "feed_gas_plant":


			if Cfg.DEMO:
				return true
			for gen in builds.generators:
				if gen is GasPlant and is_instance_valid(gen):

					if id == "build_gas_plant" or gen.fuel > 0.0 or gen.output_kw() > 0.0:
						return true
			return false
	return false


func _cash_goal_met(id: String) -> bool:
	return GameState.money >= MissionBook.goal_of(id)


func _yard_has_power(builds: BuildManager) -> bool:
	if builds.generators.is_empty():
		return false
	if builds.piston_rakes.is_empty():
		return not builds.power_poles.is_empty()
	for rake: PistonRake in builds.piston_rakes:
		if bool(builds.grid.report(rake).get("connected", false)):
			return true
	return false


func _gesture(id: String, latch: String, evidence: bool) -> bool:
	if is_live_lesson(id):
		return _live.has(latch)
	return _seen.has(latch) or evidence


static func is_live_lesson(id: String) -> bool:
	var i:= MissionBook.index_of(id)
	if i < 0:
		return false


	return i < MissionBook.LIVE_COUNT or bool(MissionBook.step(i).get("live", false))


func _owns_any_shop_item(props: PropManager) -> bool:
	for id: String in ["bucket", "wheelbarrow", "sand_shovel"]:
		if props.count_of(id) > 0 or GameState.has_tool(id):
			return true
	return false


func _anything_built(builds: BuildManager) -> bool:
	return builds.conveyors.size() > 0 or builds.robotic_arms.size() > 0 or builds.scanners.size() > 0 or builds.compressors.size() > 0 or builds.hay_drones.size() > 0 or builds.platforms.size() > 0 or builds.has_cabinet()


func _any_rake_throw_set(builds: BuildManager) -> bool:
	for rake: PistonRake in builds.piston_rakes:
		if is_instance_valid(rake) and not is_equal_approx(rake.throw_distance, Cfg.RAKE_THROW_DISTANCE):
			return true
	return false


func _any_node_bought() -> bool:
	for id: String in TechTree.ids():
		if id != TechTree.ROOT and Tech.rank_of(id) > 0:
			return true
	return false


func _owns_or_has(id: String, props: PropManager) -> bool:
	return GameState.has_tool(id) or props.count_of(id) > 0


func _owned_tool_count() -> int:
	var n:= 0
	for id: String in GameState.TOOL_IDS:
		if GameState.has_tool(id):
			n += 1
	return n


func _fullest_container() -> float:
	var props: PropManager = world.props
	var best:= 0.0
	for item in props.items:
		var box:= item as HayContainer
		if box == null or box.capacity() <= 0:
			continue
		best = maxf(best, float(box.stored) / float(box.capacity()))
	return best


func _stand_distance() -> float:
	var stand: HaySellingStand = world.stand
	if stand == null:
		return 1000000000.0
	return player.global_position.distance_to(stand.mouth_centre())


const STAND_FEED_REACH:= 2.5


func _belt_reaches_stand(builds: BuildManager) -> bool:
	var stand: HaySellingStand = world.stand
	if stand == null:
		return false
	for c in builds.conveyors:
		if not is_instance_valid(c):
			continue


		if stand.floor_distance(c.laid_end()) <= STAND_FEED_REACH:
			return true
		if stand.floor_distance(c.laid_start()) <= STAND_FEED_REACH:
			return true
	for c in builds.corners:
		if not is_instance_valid(c):
			continue
		if stand.floor_distance(c.to_point) <= STAND_FEED_REACH:
			return true
		if stand.floor_distance(c.from_point) <= STAND_FEED_REACH:
			return true
	return false


func _any_needle_banked() -> bool:
	for t in GameState.discovered.size():
		if GameState.discovered [t] != 0:
			return true
	return false
