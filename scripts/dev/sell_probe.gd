class_name DevSellProbe
extends Node


const TIMEOUT:= 8.0

const QUIET_FOR:= 0.75


const STRAND_COUNT:= 24


const STRAND_SPACING:= 0.12
const STRAND_START:= 0.2

var world: Node3D
var stand: HaySellingStand
var props: PropManager
var live: LiveStrandManager


func run() -> void:
	var fails:= 0
	world.block_save = true
	_empty_the_yard()
	for id in ["spade", "pitchfork", "broom", "sand_shovel", "metal_detector",
			"yard_vac", "lighter", "bucket", "wheelbarrow"]:
		fails += await _not_hay(id)
	fails += _check_scale_readout()
	fails += await _sell_at("wad, stock belt", 0)
	fails += await _sell_at("wad, full belt motor", 8)
	fails += await _sell_a_bale()


	var slow:= await _sell_strands("loose hay, stock belt", 0)
	var fast:= await _sell_strands("loose hay, full belt motor", 8)
	print("\n-- loose hay, speed against speed --")
	print("  %d sold at %.2f m/s, %d at %.2f m/s" % [slow, Cfg.BELT_SPEED, fast,
		Cfg.BELT_SPEED * (1.0 + 0.45 * 8.0)])
	if fast < slow:
		fails += _fail("%d fewer strands sold once the belt was upgraded"
			% (slow - fast))
	print("\n[probe] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _check_scale_readout() -> int:
	var bad:= 0
	var marks:= [0, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000]
	for i in marks.size():
		if not is_equal_approx(HaySellingStand.scale_fraction(marks [i]), float(i) / 9.0):
			bad += _fail("scale does not point at %d" % marks [i])
	if not is_equal_approx(HaySellingStand.scale_fraction(150), 0.5):
		bad += _fail("scale does not interpolate between 100 and 200")
	if HaySellingStand.scale_digits(7) != "0007" or HaySellingStand.scale_digits(9999) != "9999":
		bad += _fail("LCD does not hold four digits")
	if HaySellingStand.scale_digits(10000) != "HI":
		bad += _fail("LCD overrange wraps or truncates")
	if stand._scale_lcd == null:
		return bad + _fail("scale model has no live LCD")
	stand._record_scale_strands(1234)
	stand._drive_scale(1.0 / 60.0)
	if stand._scale_lcd.reading() != "1234":
		bad += _fail("LCD does not show physical arrivals")
	stand._hold = 0.1
	stand._record_scale_strands(42)
	if stand._scale_strands != 1234 or stand._scale_waiting != 42:
		bad += _fail("arrivals during wind-up changed the departing load")
	stand._release_sack()
	if stand._scale_strands != 42 or stand._scale_waiting != 0:
		bad += _fail("launch lost the next load's strands")
	stand._hold = 0.0
	stand._scale_strands = 0
	stand._scale_angle = 0.0
	stand._drive_scale(1.0 / 60.0)
	print("  scale dial and LCD: %s" % ("PASS" if bad == 0 else "FAIL"))
	return bad


const NOT_HAY_SECONDS:= 10.0


const NOT_HAY_TOP_SPEED:= 6.0


func _not_hay(id: String) -> int:
	print("\n-- %s on the intake --" % id)
	Tech.reset()
	await _wait_for_quiet()
	var at:= stand.belt_entry_point() + Vector3.UP * 0.6
	var item:= props.spawn(id, Transform3D(stand.global_transform.basis, at))
	if item == null:
		return _fail("could not spawn a %s" % id)
	var tool:= item is ToolProp or item is SandShovel
	var before:= GameState.money
	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var t:= 0.0
	var peak:= 0.0
	var peak_at:= Vector3.ZERO
	var still:= 0.0
	while t < NOT_HAY_SECONDS:
		await get_tree().physics_frame
		t += step

		if not is_instance_valid(item):
			break

		var v:= item.linear_velocity.length()
		if t > 1.0 and not item.freeze and v > peak:
			peak = v
			peak_at = item.global_position
		still = still + step if v < 0.05 and t > 1.0 else 0.0

		if not tool and still > 1.0 and not BeltPath.is_rider(item) and stand.to_local(item.global_position).x > 0.0:
			break
	await get_tree().process_frame
	var bad:= 0
	var paid:= GameState.money - before
	if peak > NOT_HAY_TOP_SPEED:
		bad += _fail("%s was flung at %.1f m/s near %.2v" % [id, peak, peak_at])
	if tool:
		var price:= ItemDb.price(id)
		if is_instance_valid(item):
			bad += _fail("%s was not sold; it is at %.2v" % [id, item.global_position])
			props.remove(item)
		elif not is_equal_approx(paid, price):
			bad += _fail("%s sold for $%.2f, the shop charges $%.2f" % [id, paid, price])
		else:
			print("  sold for $%.2f after %.2f s, fastest loose %.2f m/s" % [paid, t, peak])
		return bad
	if not is_instance_valid(item):
		return bad + _fail("%s is gone; a container must never be taken" % id)
	if paid != 0.0:
		bad += _fail("%s earned $%.2f; a container is not for sale" % [id, paid])
	var local:= stand.to_local(item.global_position)

	var in_front:= local.z > 3.05 + 0.8
	var on_floor:= local.y < 0.15
	if not in_front or not on_floor:
		bad += _fail("%s came to rest at stand local %.2v, not on the floor in front"
			% [id, local])
	else:
		print("  set down at stand local %.2v, upright %.2f, fastest loose %.2f m/s"
			% [local, item.global_basis.y.dot(Vector3.UP), peak])
	props.remove(item)
	await get_tree().physics_frame
	return bad


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	return 1


func _empty_the_yard() -> void:
	var builds:= world.get("builds") as BuildManager
	var arms:= 0
	if builds != null:
		for arm in builds.robotic_arms.duplicate():
			if is_instance_valid(arm):
				arm.queue_free()
				arms += 1
		builds.robotic_arms.clear()
	if props != null:
		props.clear()
	print("-- setup --")
	print("  stopped %d arm(s), cleared the loose props" % arms)


func _wait_for_quiet() -> void:
	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var still:= 0.0
	var last:= GameState.money
	var spent:= 0.0
	while still < QUIET_FOR and spent < TIMEOUT:
		await get_tree().physics_frame
		spent += step
		if is_equal_approx(GameState.money, last):
			still += step
		else:
			still = 0.0
			last = GameState.money


func _sell_strands(label: String, belt_rank: int) -> int:
	print("\n-- %s --" % label)
	Tech.reset()
	Tech.grant("belt_speed", belt_rank)
	await _wait_for_quiet()
	print("  intake belt %.2f m/s" % stand.intake_speed())

	var basis:= stand.global_transform.basis
	var at:= stand.belt_entry_point() + Vector3.UP * 0.12
	var made:= 0
	for i in STRAND_COUNT:


		var spot:= at + basis.x * (STRAND_START + float(i) * STRAND_SPACING)
		var body:= live.spawn(spot, Basis.IDENTITY, Vector3.ZERO, Color.WHITE)
		if body != null:
			made += 1
	if made == 0:
		return _fail("could not put any hay on the belt")

	var before:= GameState.money
	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var waited:= 0.0


	while waited < TIMEOUT and GameState.money <= before:
		await get_tree().physics_frame
		waited += step
	var quiet:= 0.0
	var last:= GameState.money
	while waited < TIMEOUT and quiet < QUIET_FOR:
		await get_tree().physics_frame
		waited += step
		if is_equal_approx(GameState.money, last):
			quiet += step
		else:
			quiet = 0.0
			last = GameState.money

	var paid:= GameState.money - before
	var sold:= paid / maxf(Tech.hay_price(), 0.0001)
	print("  %d strands in, %.0f sold for $%.2f" % [made, sold, paid])
	return roundi(sold)


func _sell_a_bale() -> int:
	print("\n-- a bale, worth more than it holds --")
	var bad:= 0
	Tech.reset()
	Tech.grant("bale_quality", 3)
	await _wait_for_quiet()
	var at:= stand.belt_entry_point() + Vector3.UP * 0.35
	var bale:= props.spawn("hay_bale", Transform3D(Basis.IDENTITY, at)) as HayBale
	if bale == null:
		return _fail("could not spawn a bale")


	var worth:= bale.sale_strands()
	var held:= float(bale.hay_strands())
	if worth <= held:
		return bad + _fail("a bale is worth %.0f and holds %.0f, so this case proves nothing"
			% [worth, held])

	var before:= GameState.money
	var sold_before:= GameState.hay_sold
	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var waited:= 0.0
	while waited < TIMEOUT and GameState.money <= before:
		await get_tree().physics_frame
		waited += step
	var paid:= GameState.money - before
	var counted:= GameState.hay_sold - sold_before
	if paid <= 0.0:
		bad += _fail("a bale rode in and nothing was paid after %.1f s" % TIMEOUT)
		if is_instance_valid(bale):
			print("        the bale stopped at %.2v; the mouth is at %.2v"
				% [bale.global_position, stand.mouth_centre()])
		return bad
	if not is_equal_approx(paid, worth * Tech.hay_price()):
		bad += _fail("paid $%.4f for a bale worth %.0f, expected $%.4f: the premium is not reaching the till"
			% [paid, worth, worth * Tech.hay_price()])
	if not is_equal_approx(counted, held):
		bad += _fail("HAY SOLD moved by %.0f for a bale holding %.0f strands and worth %.0f"
			% [counted, held, worth])
	else:
		print("  %.0f strands in a bale worth %.0f: paid $%.2f, counted %.0f"
			% [held, worth, paid, counted])
	return bad


func _sell_at(label: String, belt_rank: int) -> int:
	print("\n-- %s --" % label)
	var bad:= 0
	Tech.reset()
	Tech.grant("belt_speed", belt_rank)
	await _wait_for_quiet()

	print("  intake belt %.2f m/s" % stand.intake_speed())


	var at:= stand.belt_entry_point() + Vector3.UP * 0.35
	var wad:= props.spawn("hay_wad", Transform3D(Basis.IDENTITY, at),
		{ "strands": Cfg.WAD_MAX_STRANDS }) as HayWad
	if wad == null:
		return _fail("could not spawn a wad")
	var worth:= wad.sale_strands()

	var before:= GameState.money
	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var waited:= 0.0
	while waited < TIMEOUT and GameState.money <= before:
		await get_tree().physics_frame
		waited += step

	var paid:= GameState.money - before
	if paid <= 0.0:
		bad += _fail("%d strands rode in and nothing was paid after %.1f s"
			% [Cfg.WAD_MAX_STRANDS, TIMEOUT])

		if is_instance_valid(wad):
			print("        the wad stopped at %.2v; the mouth is at %.2v"
				% [wad.global_position, stand.mouth_centre()])
		else:
			print("        the wad no longer exists")
		return bad

	var want:= worth * Tech.hay_price()
	if not is_equal_approx(paid, want):
		bad += _fail("paid $%.4f for %.0f strands, expected $%.4f" % [paid, worth, want])
	print("  sold %.0f strands for $%.2f, %.2f s after it was set down"
		% [worth, paid, waited])


	await get_tree().process_frame
	if is_instance_valid(wad):
		bad += _fail("the wad was paid for and is still lying in the world")
	return bad
