extends Node


signal tech_changed(id: String, rank: int)


signal tech_reset()


const ARM_VISUAL_CAP:= 40


const YARD_METRES_PER_RANK:= 3.0


const JUMP_METRES_PER_RANK:= 0.05


var ranks: Dictionary = { }


const TRUNCATED_RANK_COSTS:= {
	"quick_till": [10.0, 20.0, 40.0, 108.0, 292.0],
	"hand_carry": [0.1, 0.2, 0.35, 0.55, 0.8, 1.0, 3.0, 5.0, 10.0],
	"belt_speed": [15.0, 30.0, 55.0, 90.0, 140.0, 210.0, 405.0, 784.0,
		1476.0, 2723.0, 4933.0, 8777.0],
	"vac_bin": [100.0, 200.0, 350.0, 743.0, 1549.0, 3198.0],
	"vac_suction": [100.0, 200.0, 350.0, 743.0, 1549.0, 3198.0],
	"shovel_size": [15.0, 30.0, 55.0, 122.0, 255.0],
}

const V5_RANK_COSTS:= {
	"pellet_batch": [700.0, 1400.0, 2800.0, 5600.0, 11000.0, 21000.0, 39000.0, 70000.0],
	"pellet_speed": [900.0, 1800.0, 3500.0, 7000.0, 14000.0, 26000.0, 49000.0, 88000.0],
	"yard_space": [600.0, 1000.0, 1600.0, 2600.0, 4200.0, 6800.0, 11000.0, 17000.0, 27000.0, 43000.0, 68000.0, 110000.0],
	"scan_batch": [400.0, 800.0, 1600.0, 3200.0, 6400.0, 12000.0, 22000.0, 40000.0],
	"scan_speed": [500.0, 1000.0, 2000.0, 4000.0, 8000.0, 15000.0, 28000.0, 50000.0],
	"work_boots": [40.0, 80.0, 160.0, 320.0, 640.0, 1200.0, 2200.0, 4000.0, 7000.0, 12000.0],
	"grab_reach": [75.0, 150.0, 300.0, 600.0, 1200.0, 2200.0, 4000.0, 7000.0, 12000.0, 20000.0],
	"steady_carry": [50.0, 100.0, 200.0, 400.0, 800.0, 1500.0, 2800.0, 5000.0, 9000.0, 16000.0],
}


var _specimen_mul: Dictionary = { }
var _specimen_dirty:= true


func _ready() -> void:
	reset()


	GameState.needle_discovered.connect(_on_needle_discovered)
	GameState.collection_loaded.connect(_invalidate_specimens)


func reset() -> void:
	ranks = { TechTree.ROOT: 1 }


	_invalidate_specimens()
	tech_reset.emit()


func rank_of(id: String) -> int:
	return int(ranks.get(id, 0))


func is_unlocked(id: String) -> bool:
	return rank_of(id) > 0


func is_maxed(id: String) -> bool:
	return rank_of(id) >= TechTree.max_rank(id)


func requires_met(id: String) -> bool:
	for need: String in TechTree.requires(id):
		if not is_unlocked(need):
			return false
	return true


func next_cost(id: String) -> float:
	return TechTree.cost_at(id, rank_of(id))


func off_site(id: String) -> bool:
	var site:= TechTree.site_of(id)
	return site != "" and site != SaveManager.current_map


func can_buy(id: String) -> Dictionary:
	if not TechTree.has_id(id):
		return { "ok": false, "reason": tr("no such upgrade"), "cost": 0.0 }


	if TechTree.is_demo(id):
		return { "ok": false, "reason": tr(TechTree.DEMO_TEXT), "cost": 0.0 }


	if off_site(id):
		return { "ok": false, "reason": tr(TechTree.SITE_TEXT), "cost": 0.0 }
	if is_maxed(id):
		return { "ok": false, "reason": tr("fully upgraded"), "cost": 0.0 }

	if TechTree.is_bundled(id):
		return { "ok": false, "cost": 0.0, "reason": tr("comes with %s")
			% TechTree.display_name(TechTree.bundled_with(id)) }
	var cost:= next_cost(id)
	if not requires_met(id):
		var missing: Array = []
		for need: String in TechTree.requires(id):
			if not is_unlocked(need):
				missing.append(TechTree.display_name(need))


		return { "ok": false, "reason": tr("needs %s") % tr(" and ", "list join").join(missing),
			"cost": cost }


	var gate:= DeliveryBook.gate_for(id)
	if gate >= 0 and not GameState.contract_signed(DeliveryBook.id_at(gate)):


		return { "ok": false, "cost": cost,
			"reason": tr("needs the %s delivery, order %d of %d on the board")
				% [DeliveryBook.title_quiet_of(gate), gate + 1, DeliveryBook.count()] }
	if not GameState.can_afford(cost):
		return { "ok": false, "reason": tr("$%s short") % Hud.money_text(cost - GameState.money),
			"cost": cost }
	return { "ok": true, "reason": "", "cost": cost }


func buy(id: String) -> bool:
	var check:= can_buy(id)
	if not check ["ok"]:
		return false
	if not GameState.spend_money(float(check ["cost"])):
		return false
	var rank:= rank_of(id) + 1
	ranks [id] = rank
	tech_changed.emit(id, rank)
	_grant_bundled()

	if rank == 1:
		GameState.note_builds_bought(id)
	GameState.note_purchase("card", id, rank, float(check ["cost"]))
	return true


func _grant_bundled() -> void:
	for id: String in TechTree.ids():
		if not is_unlocked(id):
			continue
		for child: String in TechTree.grants(id):
			if not is_unlocked(child) and TechTree.has_id(child):
				ranks [child] = 1
				tech_changed.emit(child, 1)


func grant(id: String, rank: int = 1) -> void:
	if not TechTree.has_id(id):
		return


	if TechTree.is_demo(id):
		return


	if off_site(id):
		return
	var want:= clampi(rank, 0, TechTree.max_rank(id))
	if want == rank_of(id):
		return
	if want <= 0:
		ranks.erase(id)
	else:
		ranks [id] = want
	tech_changed.emit(id, want)
	_grant_bundled()


func _size(id: String, per_rank: float) -> float:
	return pow(1.0 + per_rank, float(rank_of(id)))


func _rate(id: String, per_rank: float) -> float:
	return 1.0 + per_rank * float(rank_of(id))


func specimen_scale(key: String) -> float:
	return float(_specimens().get(key, 1.0))


func has_specimen(type: int) -> bool:
	return GameState.is_discovered(type) and NeedleTypes.has_effect(type)


func _on_needle_discovered(_type: int, _pos: Vector3) -> void:
	_invalidate_specimens()


func _invalidate_specimens() -> void:
	_specimen_dirty = true


func _specimens() -> Dictionary:
	if not _specimen_dirty:
		return _specimen_mul
	_specimen_mul = { }
	for type: int in NeedleTypes.EFFECTS:
		if not GameState.is_discovered(type):
			continue
		for key: String in NeedleTypes.effect_keys(type):
			var add:= float(NeedleTypes.effect_keys(type) [key])
			_specimen_mul [key] = float(_specimen_mul.get(key, 1.0)) * (1.0 + add)
	_specimen_dirty = false
	return _specimen_mul


const SIZE_PER_RANK:= 0.06


func spade_scale() -> float:
	return _size("shovel_size", SIZE_PER_RANK)


const TOY_BITES: Array [int] = [18, 21, 24, 27]


func toy_shovel_scale() -> float:
	var r:= clampi(rank_of("toy_shovel_size"), 0, TOY_BITES.size() - 1)
	return sqrt(float(TOY_BITES [r]) / float(TOY_BITES [0]))


func fork_scale() -> float:
	return _size("fork_size", SIZE_PER_RANK)


func scoop_max(base: int, scale: float) -> int:
	var lift:= float(base) * scale * scale * specimen_scale("scoop")
	return clampi(int(round(lift)), 1, Cfg.SHOVEL_MAX_SPAWN_PER_DIG)


func hand_capacity() -> int:
	var r:= rank_of("hand_carry")
	if r <= 0:
		return Cfg.HAND_CARRY_BASE
	return int(Cfg.HAND_HOLD_RANKS [mini(r, Cfg.HAND_HOLD_RANKS.size()) - 1])


func hand_grab() -> int:
	var r:= rank_of("hand_carry")
	if r <= 0:
		return 1
	return int(Cfg.HAND_GRAB_RANKS [mini(r, Cfg.HAND_GRAB_RANKS.size()) - 1])


func carry_stack() -> int:
	return Cfg.CARRY_STACK_BASE + rank_of("arm_load")


func bucket_scale() -> float:
	return _size("bucket_size", 0.1)


func bucket_capacity() -> int:
	return int(round(float(Cfg.BUCKET_CAPACITY) * pow(bucket_scale(), 3.0)
		* specimen_scale("container")))


func barrow_scale() -> float:
	return _size("barrow_size", 0.06)


func barrow_capacity() -> int:
	return int(round(float(Cfg.BARROW_CAPACITY) * pow(barrow_scale(), 3.0)
		* specimen_scale("container")))


func dump_hatch_unlocked() -> bool:
	return is_unlocked("dump_hatch")


func priority_arm_unlocked() -> bool:
	return is_unlocked("overflow_gate")


func belt_links_unlocked() -> bool:
	return is_unlocked("belt_links")


func overflow_arm_unlocked() -> bool:
	return is_unlocked("overflow_arm")


func pick_order_unlocked() -> bool:
	return is_unlocked("pick_order")


func drone_collect_unlocked() -> bool:
	return is_unlocked("drone_collect")


func rake_wheels_unlocked() -> bool:
	return is_unlocked("rake_wheels")


func bucket_pour_rate() -> float:
	return Cfg.BUCKET_POUR_RATE * _rate("smooth_pour", 0.12) * specimen_scale("pour")


func barrow_pour_rate() -> float:
	return Cfg.BARROW_POUR_RATE * _rate("smooth_pour", 0.12) * specimen_scale("pour")


func broom_reach_scale() -> float:
	return _rate("broom_bristles", 0.5)


func vac_capacity() -> int:
	return int(round(float(Cfg.VAC_CAPACITY) * _rate("vac_bin", 1.0 / 3.0)))


func vac_suck_rate() -> float:
	return Cfg.VAC_SUCK_RATE * _rate("vac_suction", 0.25)


func vac_bite_radius() -> float:
	return Cfg.VAC_BITE_RADIUS * _rate("vac_suction", 0.12)


func vac_pull_radius() -> float:
	return Cfg.VAC_PULL_RADIUS * _rate("vac_suction", 0.1)


func belt_speed() -> float:
	return Cfg.BELT_SPEED * _rate("belt_speed", 0.45) * specimen_scale("belt_speed")


func scanner_output_spacing() -> float:
	return Cfg.BELT_RIDE_SPACING / belt_speed()


func stand_belt_speed() -> float:
	return belt_speed() * specimen_scale("stand_belt")


func warehouse_extra() -> float:
	return YARD_METRES_PER_RANK * float(rank_of("yard_space"))


func build_cost_scale() -> float:
	return maxf(0.1, (1.0 - 0.05 * float(rank_of("steel_saving")))
		* specimen_scale("build_cost"))


func compressor_bale_strands() -> int:
	return int(round(float(Cfg.COMPRESSOR_BALE_STRANDS)
		* pow(1.25, float(rank_of("compressor_batch")))))


func compressor_press_seconds() -> float:
	return Cfg.COMPRESSOR_PRESS_SECONDS * pow(0.92, float(rank_of("compressor_speed"))) / specimen_scale("machine_speed")


func wrapper_speed() -> float:
	return specimen_scale("machine_speed") / pow(0.88, float(rank_of("wrapper_speed")))


func wrapper_seconds() -> float:
	return Cfg.WRAPPER_SECONDS / wrapper_speed()


func compressor_buffer() -> int:
	return int(round(float(Cfg.COMPRESSOR_BUFFER)
		* pow(1.25, float(rank_of("compressor_batch"))) * specimen_scale("machine_buffer")))


func bale_value_ratio() -> float:
	return Cfg.COMPRESSOR_BALE_RATIO + 0.15 * float(rank_of("bale_quality"))


func brick_value_ratio() -> float:
	return Cfg.PELLETIZER_BRICK_RATIO + 0.15 * float(rank_of("brick_quality"))


func foil_value_ratio() -> float:
	return Cfg.WRAPPER_FOILED_RATIO + 0.05 * float(rank_of("foil_quality"))


func pellet_brick_strands() -> int:
	return int(round(float(Cfg.PELLETIZER_BRICK_STRANDS)
		* pow(1.25, float(rank_of("pellet_batch")))))


func pellet_cycle_seconds() -> float:
	return Cfg.PELLETIZER_CYCLE_SECONDS * pow(0.92, float(rank_of("pellet_speed"))) / specimen_scale("machine_speed")


func pellet_buffer() -> int:
	return int(round(float(Cfg.PELLETIZER_BUFFER)
		* pow(1.25, float(rank_of("pellet_batch"))) * specimen_scale("machine_buffer")))


func pulper_batch_strands() -> int:
	return int(round(float(Cfg.PULPER_BATCH_STRANDS)
		* pow(1.25, float(rank_of("pulper_batch")))))


func pulper_cycle_seconds() -> float:
	return Cfg.PULPER_CYCLE_SECONDS * pow(0.92, float(rank_of("pulper_speed"))) / specimen_scale("machine_speed")


func pulper_buffer() -> int:
	return int(round(float(Cfg.PULPER_BUFFER)
		* pow(1.25, float(rank_of("pulper_batch"))) * specimen_scale("machine_buffer")))


func pulp_value_ratio() -> float:
	return Cfg.PULPER_PULP_RATIO + 0.3 * float(rank_of("pulp_quality"))


func paper_cycle_seconds() -> float:
	return Cfg.PAPER_CYCLE_SECONDS * pow(0.92, float(rank_of("paper_speed"))) / specimen_scale("machine_speed")


func paper_buffer() -> int:
	return maxi(Cfg.PAPER_SLABS_PER_ROLL,
		int(round(float(Cfg.PAPER_BUFFER) * specimen_scale("machine_buffer"))))


func paper_value_ratio() -> float:
	return Cfg.PAPER_ROLL_RATIO + 0.05 * float(rank_of("paper_quality"))


func briquette_cycle_seconds() -> float:
	return Cfg.BRIQUETTE_CYCLE_SECONDS * pow(0.92, float(rank_of("briquette_speed"))) / specimen_scale("machine_speed")


func briquette_batch_strands() -> int:
	return Cfg.BRIQUETTE_BATCH_STRANDS


func briquette_batch_bricks() -> int:
	return Cfg.BRIQUETTE_BATCH_BRICKS


func briquette_buffer_strands() -> int:
	return int(round(float(Cfg.BRIQUETTE_BUFFER_STRANDS)
		* specimen_scale("machine_buffer")))


func briquette_buffer_bricks() -> int:
	return maxi(Cfg.BRIQUETTE_BATCH_BRICKS,
		int(round(float(Cfg.BRIQUETTE_BUFFER_BRICKS)
			* specimen_scale("machine_buffer"))))


func disc_value_ratio() -> float:
	return Cfg.BRIQUETTE_DISC_RATIO + 0.1 * float(rank_of("briquette_quality"))


func silo_max_rate() -> float:
	return Cfg.SILO_RATE_BASE_MAX + Cfg.SILO_RATE_PER_RANK * float(rank_of("silo_rate"))


func silo_capacity() -> int:
	var rank:= rank_of("silo_capacity")
	var base:= float(Cfg.SILO_CAPACITY)
	if rank > 0:
		base = float(Cfg.SILO_CAPACITY_RANKS [
			mini(rank, Cfg.SILO_CAPACITY_RANKS.size()) - 1])
	return int(round(base * specimen_scale("machine_buffer")))


func silo_wad_strands() -> int:
	return int(round(float(Cfg.SILO_WAD_STRANDS)
		* pow(1.25, float(rank_of("silo_bulk")))))


func rake_wad_strands() -> int:
	var r:= rank_of("rake_bite")
	if r <= 0:
		return Cfg.RAKE_SMALL_WAD_STRANDS
	return int(round(float(Cfg.WAD_BASE_STRANDS) * pow(1.25, float(r - 1))))


func rake_throw_seconds() -> float:
	return Cfg.RAKE_THROW_SECONDS * pow(0.92, float(rank_of("rake_speed")))


func rake_draw_kw() -> float:
	if rank_of("rake_bite") <= 0:
		return Cfg.RAKE_DRAW_KW_NARROW
	return Cfg.RAKE_DRAW_KW


func rake_bite_strands() -> int:
	return rake_wad_strands()


func drone_radius() -> float:
	var r:= mini(rank_of("drone_radius"), Cfg.DRONE_RADIUS_RANKS)
	return (Cfg.DRONE_RADIUS + Cfg.DRONE_RADIUS_STEP * float(r)) * specimen_scale("drone_radius")


func drone_zone_max() -> float:
	var r:= mini(rank_of("drone_radius"), Cfg.DRONE_RADIUS_RANKS)
	return Cfg.DRONE_ZONE_R + Cfg.DRONE_ZONE_STEP * float(r)


func drone_speed() -> float:
	return Cfg.DRONE_SPEED * pow(1.08, float(rank_of("drone_speed"))) * specimen_scale("drone_speed")


func max_arm_tier() -> int:
	if is_unlocked("arm_long"):
		return 2
	if is_unlocked("arm_standard"):
		return 1
	return 0


func arm_unlocked() -> bool:
	return is_unlocked("arm_small")


func arm_cycle_scale() -> float:
	return pow(0.92, float(rank_of("arm_speed"))) / specimen_scale("arm_speed")


func arm_cycle_seconds(tier: int) -> float:
	var data: Dictionary = Cfg.ROBOT_ARM_TIERS [clampi(tier, 0, Cfg.ROBOT_ARM_TIERS.size() - 1)]
	return Cfg.ROBOT_ARM_WORK_SECONDS * float(data ["cycle_scale"]) * arm_cycle_scale() + Cfg.ROBOT_ARM_IDLE_SECONDS


func arm_throughput(tier: int) -> float:
	var data: Dictionary = Cfg.ROBOT_ARM_TIERS [clampi(tier, 0, Cfg.ROBOT_ARM_TIERS.size() - 1)]
	return float(arm_capacity(int(data ["capacity"]))) / maxf(arm_cycle_seconds(tier), 0.001)


func income_per_minute(strands_per_second: float, product_ratio: float = 1.0) -> float:
	return strands_per_second * hay_price() * product_ratio * 60.0


func arm_capacity(base: int) -> int:
	var want:= int(round(float(base) * _rate("arm_payload", 0.08)))
	return mini(want, Cfg.WAD_MAX_STRANDS)


func arm_visual_cap() -> int:
	return ARM_VISUAL_CAP


func radar_tier() -> int:
	for t in range(Cfg.RADAR_TIERS.size() - 1, -1, -1):
		if is_unlocked(str(Cfg.RADAR_TIERS [t] ["id"])):
			return t
	return -1


func max_scanner_tier() -> int:
	if is_unlocked("scanner_mk2"):
		return 1
	return 0


func scan_batch(base: int) -> int:
	return int(round(float(base) * pow(1.25, float(rank_of("scan_batch")))
		* specimen_scale("scan_batch")))


func scan_seconds(base: float) -> float:
	return base * pow(0.92, float(rank_of("scan_speed"))) / specimen_scale("scan_speed")


func scanner_block_seconds(base: float) -> float:
	return base * pow(0.88, float(rank_of("scan_solids"))) / specimen_scale("machine_speed")


func scanner_buffer(base: int) -> int:
	return int(round(float(base) * pow(1.25, float(rank_of("scan_batch")))
		* specimen_scale("machine_buffer")))


func needle_reveal_scale() -> float:
	return specimen_scale("reveal_radius")


func detector_range() -> float:
	return Cfg.DETECT_RANGE * _rate("detector_coil", 0.18)


func scanner_bin_capacity() -> int:
	return int(round(float(Cfg.SCANNER_BIN_CAPACITY + 4 * rank_of("drawer_space"))
		* specimen_scale("scanner_bin")))


func hay_price() -> float:
	return Cfg.HAY_PRICE * _rate("hay_price", 0.05) * specimen_scale("hay_price")


func move_speed_scale() -> float:
	return _rate("work_boots", 0.04)


func stamina_scale() -> float:
	return _rate("strong_back", 0.15)


func stamina_regen_scale() -> float:
	return _rate("second_wind", 0.18) * specimen_scale("stamina_regen")


func dig_effort_scale() -> float:


	return maxf(0.45, 1.0 - 0.08 * float(rank_of("easy_swing"))) * specimen_scale("dig_effort")


func crouch_speed() -> float:
	return Cfg.CROUCH_SPEED * _rate("careful_steps", 0.05)


func jostle_speed_ref() -> float:
	return Cfg.JOSTLE_SPEED_REF * move_speed_scale()


func carry_reach() -> float:
	return (Cfg.CARRY_REACH + 0.3 * float(rank_of("grab_reach"))) * specimen_scale("carry_reach")


func build_reach_bonus() -> float:
	return 0.5 * float(rank_of("build_reach")) + Cfg.BUILD_REACH * (specimen_scale("build_reach") - 1.0)


func jostle_scale() -> float:
	return maxf(0.0, 1.0 - 0.08 * float(rank_of("steady_carry")))


func land_kick_scale() -> float:
	return maxf(0.0, 1.0 - 0.1 * float(rank_of("soft_landings")))


func has_jetpack() -> bool:
	return not Cfg.DEMO and is_unlocked("jetpack")


func has_grippy_boots() -> bool:
	return not Cfg.DEMO and is_unlocked("grippy_boots")


func jump_velocity(base_velocity: float, gravity: float) -> float:
	var rank:= rank_of("jump_height")
	if rank <= 0 or gravity <= 0.0:
		return base_velocity
	var apex:= base_velocity * base_velocity / (2.0 * gravity)
	apex += JUMP_METRES_PER_RANK * float(rank)
	return sqrt(2.0 * gravity * apex)


func to_dict() -> Dictionary:
	return { "ranks": ranks.duplicate() }


func from_dict(d: Dictionary, refund_v5_truncation: bool = false) -> void:
	ranks = { TechTree.ROOT: 1 }
	var saved: Dictionary = d.get("ranks", { })
	var refund:= 0.0
	for id: String in saved:


		var saved_rank:= maxi(int(saved [id]), 0)
		var rank:= mini(saved_rank, TechTree.max_rank(id)) if TechTree.has_id(id) else 0
		if refund_v5_truncation and saved_rank > rank and V5_RANK_COSTS.has(id):
			var old_costs: Array = V5_RANK_COSTS [id]
			for old_rank in range(rank, mini(saved_rank, old_costs.size())):
				refund += float(old_costs [old_rank])
		elif saved_rank > rank and TRUNCATED_RANK_COSTS.has(id):
			var gone_costs: Array = TRUNCATED_RANK_COSTS [id]
			for old_rank in range(rank, mini(saved_rank, gone_costs.size())):
				refund += float(gone_costs [old_rank])
		if rank > 0:
			ranks [id] = rank
	if refund > 0.0:
		GameState.add_money(refund)
		print("[tech] refunded $%s for ranks the tree no longer sells" % Hud.money_text(refund))
	_grant_bundled()
	tech_reset.emit()


func grant_legacy() -> void:
	ranks = { }
	for id: String in TechTree.ids():
		if TechTree.kind_of(id) == "unlock" or id == TechTree.ROOT:
			ranks [id] = 1
	GameState.grant_legacy_tools()
	tech_reset.emit()


const GENERATOR_OUTPUT_RANKS:= [7.5, 9.0, 10.5, 12.0, 13.5, 15.0]


func generator_output() -> float:
	var r:= rank_of("generator_output")
	if r <= 0:
		return Cfg.GENERATOR_OUTPUT_KW
	return float(GENERATOR_OUTPUT_RANKS [mini(r, GENERATOR_OUTPUT_RANKS.size()) - 1])


const GAS_PLANT_OUTPUT_RANKS:= [125.0, 150.0, 175.0, 200.0, 225.0, 250.0]


func gas_plant_output() -> float:
	var r:= rank_of("gas_plant_output")
	if r <= 0:
		return Cfg.GAS_PLANT_OUTPUT_KW
	return float(GAS_PLANT_OUTPUT_RANKS [mini(r, GAS_PLANT_OUTPUT_RANKS.size()) - 1])


func has_gas_plant() -> bool:
	return not Cfg.DEMO and is_unlocked("gas_plant")


const PUMP_OUTPUT_RANKS:= [14.0, 16.0, 18.0, 20.0, 22.0, 24.0]


func borehole_output() -> float:
	var r:= rank_of("pump_output")
	if r <= 0:
		return Cfg.BOREHOLE_OUTPUT_LPS
	return float(PUMP_OUTPUT_RANKS [mini(r, PUMP_OUTPUT_RANKS.size()) - 1])


func pole_link_bonus() -> float:
	return 1.5 * float(rank_of("pole_span"))


func pole_supply_bonus() -> float:
	return 1.0 * float(rank_of("pole_drop"))


func pole_link_r() -> float:
	return Cfg.POLE_LINK_R + pole_link_bonus()


func pole_supply_r() -> float:
	return Cfg.POLE_SUPPLY_R + pole_supply_bonus()


func box_link_r() -> float:
	return Cfg.BOX_LINK_R + pole_link_bonus()


func box_supply_r() -> float:
	return Cfg.BOX_SUPPLY_R + pole_supply_bonus()


func underground_unlocked() -> bool:
	return is_unlocked("underground_power")


func generator_firebox_kj() -> float:
	return Cfg.GENERATOR_FIREBOX_KJ * pow(1.25, float(rank_of("firebox")))
