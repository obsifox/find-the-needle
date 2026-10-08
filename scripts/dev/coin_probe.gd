class_name DevCoinProbe
extends Node


const LEG_SECONDS:= 2.0
const PAIRS:= 7
const RATES: Array [float] = [1.0, 4.0, 10.0]
const CALLS:= 240

const SALE:= 10.0
const BIG_SALE:= 60.0


const TARGET_US:= 50.0
const FAIL_US:= 150.0

const PARTS: Array [String] = ["all", "sound", "popup", "till text", "burst",
	"open till", "cycle", "coins for", "drop 1", "drop 4", "drop 8"]

var world: Node3D
var stand: HaySellingStand
var props: PropManager
var player: Player


func run() -> void:
	world.block_save = true
	stand.coins_anywhere = true
	var fails:= 0
	fails += _check_pool()
	fails += _check_tiers()
	fails += await _check_land_and_go()
	fails += await _check_held_and_eaten()
	fails += await _check_hold_to_eat()
	fails += await _check_thrown()
	fails += await _check_belt()
	fails += await _check_cap()
	fails += await _time_it()
	print("\n[probe] %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))
	get_tree().quit(1 if fails > 0 else 0)


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	return 1


func _open_gates() -> void:
	stand._coin_ready_at = 0.0
	stand._big_ready_at = 0.0


func _check_pool() -> int:
	print("\n-- the pool --")
	var bad:= 0
	var n:= stand._coin_pool.size()
	print("  %d coins built with the stand, %d out" % [n, stand._coins_out])
	if n != HaySellingStand.COIN_POOL:
		bad += _fail("expected %d coins, the stand built %d" % [HaySellingStand.COIN_POOL, n])
	for coin: ExtraLifeCoin in stand._coin_pool:
		if coin.is_active() or coin.visible or coin.collision_layer != 0:
			bad += _fail("%s is not parked" % coin.name)
		if props.items.has(coin):
			bad += _fail("%s is on the prop ledger" % coin.name)
	return bad


func _check_tiers() -> int:
	print("\n-- which sales throw coins --")
	var bad:= 0
	var kept_best:= GameState.best_sale
	var kept_avg:= stand._sale_avg


	var cases: Array = [
		[10.0, 10.0, 1000.0, 1000.0, 1, "an ordinary sale"],
		[10.0, 29.0, 1000.0, 1000.0, 1, "just under three times the average"],
		[10.0, 35.0, 1000.0, 1000.0, 3, "three times the average"],
		[10.0, 70.0, 1000.0, 1000.0, 4, "six times"],
		[10.0, 130.0, 1000.0, 1000.0, 5, "twelve times"],
		[0.02, 1.2, 1000.0, 1000.0, 1, "a scoop after single strands"],
		[0.02, 0.02, 1000.0, 1000.0, 0, "one strand plucked by hand"],
		[10.0, 20.0, 100.0, 120.0, HaySellingStand.COIN_POOL, "a new best by a fifth"],
		[10.0, 20.0, 100.0, 105.0, 1, "a new best by a twentieth"],
		[10.0, 20.0, 2.0, 4.0, 1, "a new best worth next to nothing"],
	]
	for c: Array in cases:
		stand._sale_avg = float(c [0])
		GameState.best_sale = float(c [3])
		var got:= stand._coins_for(float(c [1]), float(c [2]))
		var want:= int(c [4])
		print("  %-36s %d coin(s)" % [String(c [5]), got])
		if got != want:
			bad += _fail("%s threw %d coins, expected %d" % [String(c [5]), got, want])
	GameState.best_sale = kept_best
	stand._sale_avg = kept_avg
	return bad


func _check_land_and_go() -> int:
	print("\n-- five coins thrown and left alone --")
	var bad:= 0


	stand._coin_land = Vector3.INF
	stand._coin_seen = Vector3.INF
	_open_gates()
	stand._drop_coins(5)
	print("  as the world is built: aimed at %.2v rising %.2f m, kept %s, %d thrown"
		% [stand._coin_seen, stand._coin_rise, stand._coin_land != Vector3.INF,
			stand._coins_out])
	if stand._coin_land != Vector3.INF:
		bad += _fail("a throw was kept from the first scan")
	if stand._coins_out > 0:
		bad += _fail("%d coins were thrown before a throw was kept" % stand._coins_out)
	await _wait_all_parked(ExtraLifeCoin.MAX_LOOSE + 2.0)


	var waited:= 0.0
	var scan_us:= 0
	while stand._coin_land == Vector3.INF and waited < 3.0:
		var t0:= Time.get_ticks_usec()
		stand._coin_landing()
		scan_us = maxi(scan_us, Time.get_ticks_usec() - t0)
		await _sim(0.25)
		waited += 0.25
	if stand._coin_land == Vector3.INF:
		return bad + _fail("no throw was kept after 3 s of asking")
	print("  kept after %.2f s: aimed at %.2v rising %.2f m, slowest scan %d us"
		% [waited, stand._coin_land, stand._coin_rise, scan_us])
	_open_gates()
	stand._drop_coins(5)
	if stand._coins_out != 5:
		return bad + _fail("asked for 5 coins, %d came out" % stand._coins_out)
	print("  aimed at %.2v, rising %.2f m" % [stand._coin_land, stand._coin_rise])
	await _sim(0.25)
	for entry: Dictionary in props.to_array():
		if String(entry.get("id", "")) == "extra_life_coin":
			bad += _fail("a coin is in the save")
	await _sim(1.75)
	var floor_y:= stand.global_position.y
	var on_floor:= 0
	for coin: ExtraLifeCoin in _out():
		print("  %s at %.2v, %.2f m/s" % [coin.name, coin.global_position,
			coin.linear_velocity.length()])
		if coin.global_position.y < floor_y - 0.05:
			bad += _fail("%s is below the floor" % coin.name)
		elif coin.global_position.y < floor_y + 0.1:
			on_floor += 1
	print("  %d of 5 on the floor" % on_floor)


	if on_floor < 3:
		bad += _fail("only %d of 5 coins came down on the floor" % on_floor)
	var took: float = await _wait_all_parked(ExtraLifeCoin.MAX_LOOSE + 2.0)
	if took < 0.0:
		bad += _fail("coins were still out long after the drop")
	else:
		print("  all parked %.2f s after that" % took)
	return bad


func _check_held_and_eaten() -> int:
	print("\n-- one coin picked up, held past its time, then eaten --")
	var bad:= 0
	_open_gates()
	stand._drop_coins(1)
	var coin:= _newest()
	if coin == null:
		return _fail("no coin came out")
	await _sim(1.5)
	if not player.carry.take(coin):
		return _fail("the hands would not take the coin")
	var hold:= ExtraLifeCoin.REST_LIFE + ExtraLifeCoin.SHRINK + 3.0
	await _sim(hold)
	print("  held %.1f s: out %s, in the hands %s" % [hold, coin.is_active(), coin.is_held()])
	if not coin.is_active() or not coin.is_held():
		bad += _fail("the coin went while it was in the hands")
	player.stamina.current = 5.0
	player.stamina.glow = 0.0
	player.stamina.rush = 0.0
	if not player.carry.eat_held():
		return bad + _fail("the hands would not eat the coin")
	await _sim(0.1)
	print("  eaten: stamina %.0f of %.0f, glowing for %.2f s"
		% [player.stamina.current, player.stamina.maximum(), player.stamina.glow])
	if player.carry.is_carrying():
		bad += _fail("still carrying after eating")
	if coin.is_active():
		bad += _fail("an eaten coin was not parked")
	if player.stamina.current < player.stamina.maximum() - 0.01:
		bad += _fail("eating did not fill the bar")
	if player.stamina.glow <= 0.0:
		bad += _fail("the bar was not lit")
	return bad


func _check_hold_to_eat() -> int:
	print("\n-- the left button let go too soon, then held until the coin is gone --")
	var bad:= 0
	_open_gates()
	stand._drop_coins(1)
	var coin:= _newest()
	if coin == null:
		return _fail("no coin came out")
	await _sim(1.0)
	if not player.carry.take(coin):
		return _fail("the hands would not take the coin")
	player.stamina.current = 5.0
	player.stamina.glow = 0.0

	player.stamina.rush = 0.0

	Input.action_press("primary")
	if not player.carry.begin_eat():
		Input.action_release("primary")
		return _fail("the hands would not start eating the coin")
	await _sim(ExtraLifeCoin.EAT_HOLD * 0.5)
	var shaken:= coin._model.transform.origin.length()
	var voice:= coin._charge_voice
	print("  charging sound: %s" % ("playing" if voice != null and voice.playing else "silent"))
	if voice == null or not voice.playing:
		bad += _fail("the charging sound did not start")
	Input.action_release("primary")
	await _sim(0.1)
	if voice != null and voice.playing and (Audio._streams ["coin_charge"] as Array).has(voice.stream):
		bad += _fail("the charging sound played on after letting go")
	if coin._charge_voice != null:
		bad += _fail("the coin kept hold of its charging sound after letting go")
	print("  let go halfway through the shake (moved %.1f mm): eating %s, held %s, stamina %.0f"
		% [shaken * 1000.0, coin.is_eating(), coin.is_held(), player.stamina.current])
	if shaken < 0.0001:
		bad += _fail("the coin did not shake while the button was down")
	if coin.is_eating():
		bad += _fail("letting go did not stop the eating")
	if not coin.is_held():
		bad += _fail("letting go too soon lost the coin")


	if player.stamina.glow > 0.0:
		bad += _fail("a coin let go of too soon was still eaten")
	if coin._model.transform.origin.length() > 0.0001 or not coin._model.visible:
		bad += _fail("the shake was left on the coin")
	for mi in coin._meshes:
		if mi.material_overlay != null:
			bad += _fail("the shine was left on the coin")
			break

	Input.action_press("primary")
	player.carry.begin_eat()
	await _sim(ExtraLifeCoin.EAT_HOLD + 0.05)

	Input.action_release("primary")
	var rays_up:= coin._rays != null and coin._rays.visible
	print("  held past the shake: committed %s, rays %s, stamina %.0f"
		% [coin.eat_committed(), rays_up, player.stamina.current])
	if not coin.eat_committed():
		bad += _fail("held past the shake and still not committed")
	if not rays_up:
		bad += _fail("no rays behind the coin")
	if player.stamina.glow > 0.0:
		bad += _fail("the coin was eaten before it was gone")
	await _sim(ExtraLifeCoin.eat_seconds() - ExtraLifeCoin.EAT_HOLD + 0.1)
	print("  after the rest of it: carrying %s, out %s, stamina %.0f of %.0f"
		% [player.carry.is_carrying(), coin.is_active(), player.stamina.current,
			player.stamina.maximum()])
	if player.carry.is_carrying():
		bad += _fail("still carrying after the coin was eaten")
	if coin.is_active():
		bad += _fail("an eaten coin was not parked")
	if player.stamina.current < player.stamina.maximum() - 0.01:
		bad += _fail("holding the button did not fill the bar")
	if player.stamina.glow <= 0.0:
		bad += _fail("holding the button did not light the bar")
	if coin._rays != null and coin._rays.visible:
		bad += _fail("the rays outlived the coin")

	var jump:= player.stamina.jump_scale()
	print("  power rush: %s, %.1f s, jump x%.2f high, speed x%.2f"
		% [player.stamina.rushing(), player.stamina.rush, jump * jump,
			player.stamina.speed_scale()])
	if not player.stamina.rushing():
		bad += _fail("eating did not start a power rush")
	if absf(jump * jump - Stamina.RUSH_JUMP_HEIGHT) > 0.01:
		bad += _fail("a jump in the rush is not %.0f times as high" % Stamina.RUSH_JUMP_HEIGHT)
	if player.stamina.speed_scale() <= 1.0:
		bad += _fail("the rush is no faster")
	var had:= player.stamina.current
	if not player.stamina.spend(had + 50.0) or player.stamina.current < had:
		bad += _fail("spending cost stamina during the rush")
	await _sim(Stamina.EXTRA_LIFE_RUSH + 0.2)
	print("  %.1f s later: rushing %s, glow %.2f s" % [Stamina.EXTRA_LIFE_RUSH + 0.2,
		player.stamina.rushing(), player.stamina.glow])
	if player.stamina.rushing() or player.stamina.speed_scale() != 1.0 or player.stamina.jump_scale() != 1.0:
		bad += _fail("the rush did not end")
	return bad


func _check_thrown() -> int:
	print("\n-- one coin picked up and thrown --")
	_open_gates()
	stand._drop_coins(1)
	var coin:= _newest()
	if coin == null:
		return _fail("no coin came out")
	await _sim(0.5)
	if not player.carry.take(coin):
		return _fail("the hands would not take the coin")
	await _sim(0.2)
	player.carry.throw()
	var took: float = await _wait_all_parked(ExtraLifeCoin.MAX_LOOSE + 2.0)
	if took < 0.0:
		return _fail("a thrown coin never went")
	print("  gone %.2f s after the throw" % took)
	return 0


func _check_belt() -> int:
	print("\n-- a coin set down on the stand's own belt --")
	var bad:= 0
	_open_gates()
	stand._drop_coins(1)
	var coin:= _newest()
	if coin == null:
		return _fail("no coin came out")
	var before:= GameState.money
	coin.launch(Transform3D(Basis.IDENTITY, stand.belt_entry_point() + Vector3.UP * 0.1),
		Vector3.ZERO, Vector3.ZERO)
	await _sim(2.0)
	print("  after 2 s at %.2v, riding %s" % [coin.global_position, BeltPath.is_rider(coin)])
	if BeltPath.is_rider(coin):
		bad += _fail("the belt took the coin as a load")
	if not is_equal_approx(GameState.money, before):
		bad += _fail("the till paid $%.2f for a coin" % (GameState.money - before))
	var took: float = await _wait_all_parked(ExtraLifeCoin.MAX_LOOSE + 2.0)
	if took < 0.0:
		bad += _fail("a coin on the belt never went")
	return bad


func _check_cap() -> int:
	print("\n-- three full drops in a row, then the two cooldowns --")
	var bad:= 0
	var most:= 0
	for _r in 3:
		_open_gates()
		stand._drop_coins(HaySellingStand.COIN_POOL)
		await _sim(0.3)
		var really:= _out().size()
		most = maxi(most, really)
		if stand._coins_out != really:
			bad += _fail("the stand counts %d out and %d are" % [stand._coins_out, really])
	print("  at most %d out of %d" % [most, HaySellingStand.COIN_POOL])
	if most > HaySellingStand.COIN_POOL:
		bad += _fail("more coins out than the stand built")
	var took: float = await _wait_all_parked(ExtraLifeCoin.MAX_LOOSE + 2.0)
	if took < 0.0:
		return bad + _fail("the full drops never went")
	_open_gates()
	stand._drop_coins(2)
	stand._drop_coins(2)
	print("  two drops of two back to back: %d out" % stand._coins_out)
	if stand._coins_out != 2:
		bad += _fail("a big drop inside the big cooldown threw coins")
	await _wait_all_parked(ExtraLifeCoin.MAX_LOOSE + 2.0)
	_open_gates()
	stand._drop_coins(1)
	stand._drop_coins(1)
	print("  two single coins back to back: %d out" % stand._coins_out)
	if stand._coins_out != 1:
		bad += _fail("a single coin inside the cooldown was thrown")
	await _wait_all_parked(ExtraLifeCoin.MAX_LOOSE + 2.0)
	return bad


func _time_it() -> int:
	print("\n-- what it costs the frame: mean CPU frame time, microseconds --")
	print("  rate      off       on   on-off   pairs")
	var bad:= 0
	for rate: float in RATES:
		var median: float = await _pairs(rate)
		if _noisy:
			print("  NOISY  the off legs alone differ by more than %d%%, so this row is not judged"
				% roundi((NOISE_SPREAD - 1.0) * 100.0))
		elif median > FAIL_US:
			bad += _fail("%.0f us a frame at %.0f sales a second" % [median, rate])
		elif median > TARGET_US:
			print("  NOTE  over the %.0f us target at %.0f sales a second" % [TARGET_US, rate])
	print("\n-- what one sale costs inside the call, microseconds --")
	for part: String in PARTS:
		var mean: float = await _call_cost(part)
		print("  %-10s %7.1f" % [part, mean])
	return bad


const NOISE_SPREAD:= 1.25
var _noisy:= false


func _pairs(rate: float) -> float:
	var deltas: Array [float] = []
	var offs:= 0.0
	var ons:= 0.0
	var off_min:= INF
	var off_max:= 0.0
	for _p in PAIRS:
		var off: float = await _leg(rate, false)
		var on: float = await _leg(rate, true)
		deltas.append(on - off)
		offs += off
		ons += on
		off_min = minf(off_min, off)
		off_max = maxf(off_max, off)
	_noisy = off_max > off_min * NOISE_SPREAD
	deltas.sort()
	var median:= deltas [int(deltas.size() / 2.0)]
	var each:= ""
	for d: float in deltas:
		each += " %+.0f" % d
	print("  %4.0f/s  %7.0f  %7.0f  %+7.0f  %s" % [rate, offs / PAIRS, ons / PAIRS, median, each])
	return median


func _leg(rate: float, on: bool) -> float:
	await _wait_all_parked(ExtraLifeCoin.MAX_LOOSE + 2.0)
	await _sim(HaySellingStand.POPUP_LIFE + 0.2)
	var sim:= 0.0
	var next_sale:= 0.0
	var next_single:= 0.0
	var next_big:= 0.5
	var bigs:= 0
	var total:= 0
	var frames:= 0
	var last:= Time.get_ticks_usec()
	while sim < LEG_SECONDS:
		await get_tree().process_frame
		var now:= Time.get_ticks_usec()
		if frames > 0:
			total += now - last
		last = now
		frames += 1
		sim += get_process_delta_time()
		while next_sale <= sim:
			next_sale += 1.0 / rate
			if not on:


				stand._run_cycle()
				continue


			if sim >= next_big:
				next_big += HaySellingStand.COIN_BIG_COOLDOWN
				next_single = sim + HaySellingStand.COIN_COOLDOWN
				bigs += 1
				_open_gates()
				stand._celebrate(BIG_SALE, HaySellingStand.COIN_POOL if bigs % 2 == 0 else 4)
				continue
			if sim >= next_single:
				next_single = sim + HaySellingStand.COIN_COOLDOWN
				stand._coin_ready_at = 0.0
			stand._celebrate(SALE, 1)
	return float(total) / float(maxi(frames - 1, 1))


func _call_cost(part: String) -> float:
	await _wait_all_parked(ExtraLifeCoin.MAX_LOOSE + 2.0)
	var total:= 0
	for _i in CALLS:
		await get_tree().process_frame
		_open_gates()
		var t0:= Time.get_ticks_usec()
		_sell_part(part)
		total += Time.get_ticks_usec() - t0
	return float(total) / float(CALLS)


func _sell_part(part: String) -> void:
	match part:
		"all":
			stand._celebrate(SALE, 1)
		"sound":

			Audio.play_3d("sell_register", stand.global_position + Vector3(0, 1.1, 0), 1.0)
		"popup":
			stand._popup("+$%s" % Hud.money_text(SALE), HaySellingStand.COL_PAY)
		"till text":
			if stand._till != null:
				stand._till.text = "$%s" % Hud.money_text(SALE)
		"burst":
			stand._burst(SALE)
		"open till":
			stand._open_till()
		"cycle":
			stand._run_cycle()
		"coins for":
			stand._coins_for(SALE, GameState.best_sale)
		"drop 1":
			stand._drop_coins(1)
		"drop 4":
			stand._drop_coins(4)
		"drop 8":
			stand._drop_coins(HaySellingStand.COIN_POOL)


func _sim(seconds: float) -> void:
	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var t:= 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += step


func _wait_all_parked(timeout: float) -> float:
	var step:= 1.0 / float(Engine.get_physics_ticks_per_second())
	var t:= 0.0
	while stand._coins_out > 0:
		if t >= timeout:
			return -1.0
		await get_tree().physics_frame
		t += step
	return t


func _out() -> Array [ExtraLifeCoin]:
	var out: Array [ExtraLifeCoin] = []
	for coin: ExtraLifeCoin in stand._coin_pool:
		if coin.is_active():
			out.append(coin)
	return out


func _newest() -> ExtraLifeCoin:
	var newest: ExtraLifeCoin = null
	for coin: ExtraLifeCoin in _out():
		if newest == null or coin.launched_at > newest.launched_at:
			newest = coin
	return newest
