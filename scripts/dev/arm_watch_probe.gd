class_name DevArmWatchProbe
extends Node


var world: Node3D


const WATCH_SECONDS:= 90.0

const REPORT_EVERY:= 5.0

const STALL_AFTER:= 3.0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	reparent(get_tree().root)
	var ua:= OS.get_cmdline_user_args()
	var i:= ua.find("--armwatch")
	var path: String = ua [i + 1] if i >= 0 and i + 1 < ua.size() else ""
	if path == "" or not FileAccess.file_exists(path):
		print("ARMWATCH: no save copy given, or it does not exist: '%s'" % path)
		get_tree().quit(1)
		return
	var f:= SaveManager.open_for_read(path)
	var payload: Variant = f.get_var(true)
	f.close()
	if typeof(payload) != TYPE_DICTIONARY:
		print("ARMWATCH: %s is not a save" % path)
		get_tree().quit(1)
		return
	var d: Dictionary = payload
	GameState.from_dict(d.get("state", { }))
	SaveManager._apply_tech(d)
	world.builds.from_array(d.get("buildings", []))


	world.props.from_array(d.get("props", []))
	for k in 90:
		await get_tree().physics_frame

	var b: BuildManager = world.builds
	print("ARMWATCH: %d arms, %d runs, belt %.2f m/s, arm capacity %d, hay %.0f"
		% [b.robotic_arms.size(), b.conveyors.size(), Tech.belt_speed(),
			Tech.arm_capacity(8), GameState.hay_total])
	_print_power()

	var seen: Dictionary = { }
	var ticks:= int(WATCH_SECONDS / maxf(get_physics_process_delta_time(), 1e-06))
	var report_every:= int(REPORT_EVERY / maxf(get_physics_process_delta_time(), 1e-06))
	for tick in ticks:
		await get_tree().physics_frame
		for arm: RoboticArm in b.robotic_arms:
			if not is_instance_valid(arm):
				continue
			var id:= arm.get_instance_id()
			var held: float = float(seen.get(id, 0.0))
			if arm._phase == RoboticArm.Phase.DESCEND_DROP and arm._payload_count > 0:
				held += get_physics_process_delta_time()
				seen [id] = held

				if held >= STALL_AFTER and held - get_physics_process_delta_time() < STALL_AFTER:
					print("\n[%.1fs] %s has been holding %d strands for %.1fs"
						% [float(tick) / 60.0, arm.name, arm._payload_count, held])
					print("        %s" % _why(arm))
			else:
				if held >= STALL_AFTER:
					print("[%.1fs] %s got moving again after %.1fs"
						% [float(tick) / 60.0, arm.name, held])
				seen [id] = 0.0
		if tick % report_every == report_every - 1:
			_standing(b, seen, float(tick) / 60.0)
	print("\nARMWATCH: done")
	get_tree().quit(0)


func _why(arm: RoboticArm) -> String:
	var run:= arm._drop_run
	if run == null or not is_instance_valid(run):
		return "gone: the run it committed to no longer exists"
	var speed:= Tech.belt_speed()
	var count:= arm._payload_count
	var as_prop:= arm._payload_prop != null
	var lead: float = arm._drop_lead()
	var half:= Cfg.WAD_BASE_SIZE.x * 0.5 * HayWad.scale_for(maxi(count, 1))
	var reach: float = Cfg.STRAND_THICK if (not as_prop and HayWad.split(count).is_empty()) else half
	var landing:= run.landing_point(arm._drop_target, speed)
	var bounds:= run.has_room_to_land(arm._drop_target, speed, lead, reach)
	var near:= run.has_room_near(landing, lead)
	var prop:= HayWad.room_at(arm.get_world_3d().direct_space_state, landing,
		count, arm._own_prop_exclusion())
	var out:= "run %.2f m, %d riders aboard, belt %.2f m/s, lead %.2f, reach %.3f\n" % [
		run.path_length(), run.riders_debug().size(), speed, lead, reach]
	out += "        power %.2f  ·  has_room_to_land %s  ·  has_room_near %s  ·  wad clearance %s" % [
		arm.power, bounds, near, prop]
	if not bounds and near:
		out += "\n        BOUNDS: the landing is off the usable part of this deck"
	elif not near:
		out += "\n        RIDERS: something is on the deck at the landing"
	elif not prop:
		out += "\n        PROP: something is standing in the landing box"
	else:
		out += "\n        NOTHING REFUSES IT: the claw is held by something else"
	return out


func _standing(b: BuildManager, seen: Dictionary, at: float) -> void:
	var stalled:= 0
	var working:= 0
	var lowest:= 1.0
	for arm: RoboticArm in b.robotic_arms:
		if not is_instance_valid(arm):
			continue
		lowest = minf(lowest, arm.power)
		if float(seen.get(arm.get_instance_id(), 0.0)) >= STALL_AFTER:
			stalled += 1
		elif arm.completed_cycles > 0:
			working += 1
	print("[%.1fs] %d arms holding, %d have delivered, lowest arm power %.2f"
		% [at, stalled, working, lowest])


func _print_power() -> void:
	var grid: PowerGrid = world.builds.grid
	if grid == null:
		print("ARMWATCH: no grid")
		return


	var seen: Array [int] = []
	for arm: RoboticArm in world.builds.robotic_arms:
		var net:= grid.network_of(arm)
		if net in seen:
			continue
		seen.append(net)
		var row:= grid.report(arm)
		print("ARMWATCH: %s is on network %d  supply %.1f kW  demand %.1f kW  everything at %d%%"
			% [arm.name, net, float(row ["supply"]), float(row ["demand"]),
				int(round(float(row ["satisfaction"]) * 100.0))])
