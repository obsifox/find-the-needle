class_name DevFleetProbe
extends Node


var world: Node3D
var player: Player

const SETTLE_FRAMES:= 10

var _pass:= 0
var _fail:= 0


func run() -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame


	GameState.add_money(2000000.0)
	player.global_position = Vector3(9.0, 0.4, -2.0)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	await _drone_curve()
	await _drone_cap()
	await _arm_curve()
	await _arm_cap()
	await _rake_curve()
	await _rake_cap()
	await _sell_early_and_rebuy_is_free()
	await _refunds_match_the_bills()
	await _over_limit_save_loads_whole()

	print("\n%d passed, %d failed" % [_pass, _fail])
	world.block_save = true
	get_tree().quit(1 if _fail > 0 else 0)


func _drone_curve() -> void:
	print("\n=== drone price curve ===")
	var builds: BuildManager = world.builds
	_check("an empty yard quotes the catalogue price ($%.0f)" % builds.drone_price(),
		is_equal_approx(builds.drone_price(), Cfg.DRONE_COST))
	_check("...and the whole fleet is still to build (%d)" % builds.drones_left(),
		builds.drones_left() == Cfg.DRONE_LIMIT)

	var prices: Array [float] = []
	for i in Cfg.DRONE_LIMIT:
		prices.append(builds.drone_price())
		builds.add_hay_drone(_pad(i, -6.0), 0.0)
	print("  drones: %s" % str(prices))
	_check("a drone's allowance is one, so the second already costs more",
		Cfg.DRONE_COST_FREE <= 1 and prices [1] > prices [0])
	_check("every drone costs more than the one before it", _rising(prices))
	_check("...by about the growth factor each time (x%.2f)" % Cfg.DRONE_COST_GROWTH,
		_ratio_holds(prices, Cfg.DRONE_COST_FREE, Cfg.DRONE_COST_GROWTH))


	_check("...and the last is at least 5x the first ($%.0f -> $%.0f)"
		% [prices [0], prices [prices.size() - 1]],
		prices [prices.size() - 1] >= prices [0] * 5.0)
	_check("the fleet stands at the limit (%d of %d)"
		% [builds.hay_drones.size(), Cfg.DRONE_LIMIT],
		builds.hay_drones.size() == Cfg.DRONE_LIMIT)
	_check("...with nothing left to build", builds.drones_left() == 0)
	await get_tree().physics_frame


func _drone_cap() -> void:
	print("\n=== the drone cap refuses ===")
	var builds: BuildManager = world.builds
	var full: Dictionary = player.build._evaluate_drone(_clear_spot(), Vector3.UP)
	_check("a full yard will not place another (%s)" % full ["reason"], not full ["ok"])
	_check("...and says the limit is why", str(full ["reason"]).contains("limit"))


	var last: HayDrone = builds.hay_drones [builds.hay_drones.size() - 1]
	builds.demolish(last)
	await get_tree().physics_frame
	var room: Dictionary = player.build._evaluate_drone(_clear_spot(), Vector3.UP)
	_check("taking one down makes room again (%s)"
		% ("ok" if room ["ok"] else str(room ["reason"])), room ["ok"])
	_check("...and the price fell back with it ($%.0f)" % builds.drone_price(),
		is_equal_approx(builds.drone_price(),
			BuildManager.scaled_price(Cfg.DRONE_COST, Cfg.DRONE_LIMIT - 1,
				Cfg.DRONE_COST_FREE, Cfg.DRONE_COST_GROWTH)))


func _arm_curve() -> void:
	print("\n=== arm price curve ===")
	var builds: BuildManager = world.builds
	var base:= float(Cfg.ROBOT_ARM_TIERS [0] ["cost"])
	var prices: Array [float] = []
	for i in Cfg.ARM_LIMIT:
		prices.append(builds.arm_price(0))


		builds.add_robotic_arm(_pad(i, 12.0), 0.0, 0, prices [i])
	print("  arms:   %s" % str(prices))


	var free_flat:= true
	for i in mini(Cfg.ARM_COST_FREE, prices.size()):
		if not is_equal_approx(prices [i], base):
			free_flat = false
	_check("the first %d arms cost the catalogue price ($%.0f)"
		% [Cfg.ARM_COST_FREE, base], free_flat)
	_check("...and the one after the allowance costs more ($%.0f -> $%.0f)"
		% [prices [Cfg.ARM_COST_FREE - 1], prices [Cfg.ARM_COST_FREE]],
		prices [Cfg.ARM_COST_FREE] > prices [Cfg.ARM_COST_FREE - 1])
	_check("...climbing by about the growth factor from there (x%.2f)"
		% Cfg.ARM_COST_GROWTH,
		_ratio_holds(prices, Cfg.ARM_COST_FREE, Cfg.ARM_COST_GROWTH))


	_check("...gently: the last arm is under $30,000 ($%.0f -> $%.0f)"
		% [prices [0], prices [prices.size() - 1]],
		prices [prices.size() - 1] < 30000.0)


	var small:= builds.arm_price(0)
	var long:= builds.arm_price(Cfg.ROBOT_ARM_TIERS.size() - 1)
	var tier_ratio:= float(Cfg.ROBOT_ARM_TIERS [Cfg.ROBOT_ARM_TIERS.size() - 1] ["cost"]) / float(Cfg.ROBOT_ARM_TIERS [0] ["cost"])
	_check("a crowded yard prices each model off its own tier ($%.0f vs $%.0f)"
		% [small, long], absf(long / small - tier_ratio) < 0.03)
	await get_tree().physics_frame


func _arm_cap() -> void:
	print("\n=== the arm cap refuses ===")
	var builds: BuildManager = world.builds
	_check("the yard is full of arms (%d of %d)"
		% [builds.robotic_arms.size(), Cfg.ARM_LIMIT], builds.arms_left() == 0)
	var full: Dictionary = player.build._evaluate_arm(_clear_spot(), Vector3.UP,
		builds.arm_price(0), 1.0)
	_check("...so another is refused (%s)" % full ["reason"], not full ["ok"])
	_check("...for the limit rather than the ground",
		str(full ["reason"]).contains("limit"))

	var last: RoboticArm = builds.robotic_arms [builds.robotic_arms.size() - 1]
	builds.demolish(last)
	await get_tree().physics_frame
	var room: Dictionary = player.build._evaluate_arm(_clear_spot(), Vector3.UP,
		builds.arm_price(0), 1.0)


	_check("...and taking one down stops the limit being the answer (%s)"
		% ("ok" if room ["ok"] else str(room ["reason"])),
		not str(room ["reason"]).contains("limit"))


func _rake_curve() -> void:
	print("\n=== rake price curve ===")
	var builds: BuildManager = world.builds
	var prices: Array [float] = []
	for i in Cfg.RAKE_LIMIT:
		prices.append(builds.rake_price())
		builds.add_piston_rake(_pad(i, 24.0), 0.0)
	print("  rakes:  %s" % str(prices))

	var free_flat:= true
	for i in mini(Cfg.RAKE_COST_FREE, prices.size()):
		if not is_equal_approx(prices [i], Cfg.RAKE_COST):
			free_flat = false
	_check("the first %d rakes cost the catalogue price ($%.0f)"
		% [Cfg.RAKE_COST_FREE, Cfg.RAKE_COST], free_flat)
	_check("...and the one after the allowance costs more ($%.0f -> $%.0f)"
		% [prices [Cfg.RAKE_COST_FREE - 1], prices [Cfg.RAKE_COST_FREE]],
		prices [Cfg.RAKE_COST_FREE] > prices [Cfg.RAKE_COST_FREE - 1])
	_check("...climbing by about the growth factor from there (x%.2f)"
		% Cfg.RAKE_COST_GROWTH,
		_ratio_holds(prices, Cfg.RAKE_COST_FREE, Cfg.RAKE_COST_GROWTH))
	_check("the yard is full of rakes (%d of %d)"
		% [builds.piston_rakes.size(), Cfg.RAKE_LIMIT], builds.rakes_left() == 0)
	await get_tree().physics_frame


func _rake_cap() -> void:
	print("\n=== the rake cap refuses ===")
	var builds: BuildManager = world.builds
	var full: Dictionary = player.build._evaluate_rake(_clear_spot(), Vector3.UP,
		Vector3.FORWARD)
	_check("a full yard will not place another (%s)" % full ["reason"], not full ["ok"])
	_check("...and says the limit is why", str(full ["reason"]).contains("limit"))


	_check("...before it complains about where the hay is",
		not str(full ["reason"]).contains("hay"))

	var last: PistonRake = builds.piston_rakes [builds.piston_rakes.size() - 1]
	builds.demolish(last)
	await get_tree().physics_frame
	var room: Dictionary = player.build._evaluate_rake(_clear_spot(), Vector3.UP,
		Vector3.FORWARD)
	_check("...and taking one down stops the limit being the answer (%s)"
		% ("ok" if room ["ok"] else str(room ["reason"])),
		not str(room ["reason"]).contains("limit"))


func _sell_early_and_rebuy_is_free() -> void:
	print("\n=== selling an early one and buying it back ===")
	var builds: BuildManager = world.builds
	var before:= _bills(builds.robotic_arms)
	var early:= builds.robotic_arms [0].build_cost()
	var refund: float = builds.demolish(builds.robotic_arms [0])
	await get_tree().physics_frame
	_rebuy_check("an arm", early, refund, builds.arm_price(0), before,
		_bills(builds.robotic_arms))

	before = _bills(builds.hay_drones)
	early = builds.hay_drones [0].build_cost()
	refund = builds.demolish(builds.hay_drones [0])
	await get_tree().physics_frame
	_rebuy_check("a drone", early, refund, builds.drone_price(), before,
		_bills(builds.hay_drones))

	before = _bills(builds.piston_rakes)
	early = builds.piston_rakes [0].build_cost()
	refund = builds.demolish(builds.piston_rakes [0])
	await get_tree().physics_frame
	_rebuy_check("a rake", early, refund, builds.rake_price(), before,
		_bills(builds.piston_rakes))


func _rebuy_check(what: String, early: float, refund: float, rebuy: float,
		before: float, after: float) -> void:
	_check("%s bought early at $%.0f sells for what buying it back costs ($%.0f, $%.0f)"
		% [what, early, refund, rebuy],
		early < rebuy and is_equal_approx(refund, rebuy))
	_check("...and the bills left plus the refund are what was paid ($%.0f + $%.0f = $%.0f)"
		% [after, refund, before], is_equal_approx(after + refund, before))


func _bills(fleet: Array) -> float:
	var total:= 0.0
	for machine in fleet:
		total += float(machine.call("build_cost"))
	return total


func _refunds_match_the_bills() -> void:
	print("\n=== bills and refunds ===")
	var builds: BuildManager = world.builds
	var drone_bill:= builds.drone_price()
	var arm_bill:= builds.arm_price(0)
	var rake_bill:= builds.rake_price()
	var drone:= builds.add_hay_drone(_clear_spot(), 0.0, drone_bill)
	var arm:= builds.add_robotic_arm(_pad(1, 36.0), 0.0, 0, arm_bill)
	var rake:= builds.add_piston_rake(_pad(2, 36.0), 0.0, rake_bill)
	await get_tree().physics_frame
	_check("a drone keeps the price it was charged ($%.0f)" % drone.build_cost(),
		is_equal_approx(drone.build_cost(), drone_bill))
	_check("an arm keeps the price it was charged ($%.0f)" % arm.build_cost(),
		is_equal_approx(arm.build_cost(), arm_bill))
	_check("a rake keeps the price it was charged ($%.0f)" % rake.build_cost(),
		is_equal_approx(rake.build_cost(), rake_bill))
	_check("...and none of the three is the flat catalogue price",
		absf(drone_bill - Cfg.DRONE_COST) > 1.0
			and absf(arm_bill - float(Cfg.ROBOT_ARM_TIERS [0] ["cost"])) > 1.0
			and absf(rake_bill - Cfg.RAKE_COST) > 1.0)

	var saved: Array = builds.to_array()
	var missing:= 0
	for row: Dictionary in saved:
		if row.get("type", "") in ["hay_drone", "robotic_arm", "piston_rake"] and not row.has("paid"):
			missing += 1
	_check("every crowdable machine writes what it cost into the save", missing == 0)

	builds.from_array(saved)
	await get_tree().physics_frame
	var back_drone: HayDrone = builds.hay_drones [builds.hay_drones.size() - 1]
	var back_arm: RoboticArm = builds.robotic_arms [builds.robotic_arms.size() - 1]
	var back_rake: PistonRake = builds.piston_rakes [builds.piston_rakes.size() - 1]
	_check("...and comes back off it still knowing ($%.0f, $%.0f, $%.0f)"
		% [back_drone.build_cost(), back_arm.build_cost(), back_rake.build_cost()],
		is_equal_approx(back_drone.build_cost(), drone_bill)
			and is_equal_approx(back_arm.build_cost(), arm_bill)
			and is_equal_approx(back_rake.build_cost(), rake_bill))

	var drone_refund: float = builds.demolish(back_drone)
	var arm_refund: float = builds.demolish(back_arm)
	var rake_refund: float = builds.demolish(back_rake)
	await get_tree().physics_frame
	_check("demolishing pays back exactly the bill ($%.0f, $%.0f, $%.0f)"
		% [drone_refund, arm_refund, rake_refund],
		is_equal_approx(drone_refund, drone_bill)
			and is_equal_approx(arm_refund, arm_bill)
			and is_equal_approx(rake_refund, rake_bill))


func _over_limit_save_loads_whole() -> void:
	print("\n=== an over full save ===")
	var builds: BuildManager = world.builds
	var saved: Array = builds.to_array()
	var template:= { }
	var rest: Array = []
	for row: Dictionary in saved:
		if row.get("type", "") == "hay_drone":
			template = row
		elif row.get("type", "") != "robotic_arm" and row.get("type", "") != "piston_rake":
			rest.append(row)
	if template.is_empty():
		_check("a drone row to copy", false)
		return

	var over:= rest.duplicate()
	var want:= Cfg.DRONE_LIMIT + 3
	for i in want:
		var row: Dictionary = template.duplicate()
		row ["position"] = _pad(i, -6.0)
		over.append(row)
	builds.from_array(over)
	await get_tree().physics_frame
	_check("every drone in the save is still standing (%d of %d)"
		% [builds.hay_drones.size(), want], builds.hay_drones.size() == want)
	_check("...and the yard reports no room rather than a negative one (%d)"
		% builds.drones_left(), builds.drones_left() == 0)
	var full: Dictionary = player.build._evaluate_drone(_clear_spot(), Vector3.UP)
	_check("...so the next one is refused (%s)" % full ["reason"], not full ["ok"])


func _rising(prices: Array [float]) -> bool:
	for i in range(1, prices.size()):
		if prices [i] <= prices [i - 1]:
			return false
	return true


func _ratio_holds(prices: Array [float], free: int, growth: float) -> bool:
	for i in range(maxi(1, free), prices.size()):
		if absf(prices [i] / prices [i - 1] - growth) > 0.06:
			return false
	return true


func _pad(i: int, lane: float) -> Vector3:
	return Vector3(13.0 + float(i % 4) * 3.0, 0.02,
		lane - float(i / 4) * 3.0)


func _clear_spot() -> Vector3:
	return Vector3(13.0, 0.02, 6.0)


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["pass" if ok else "FAIL", label])
