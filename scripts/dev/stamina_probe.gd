class_name DevStaminaProbe
extends Node


const BURST:= 20


const SPAM_GAP:= 3

const REST:= 6.0

var world: Node3D
var player: Player

var _fails: Array [String] = []

var _aimed:= 0


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	_stand_at_the_pile()
	GameState.grant_tool("pitchfork")
	player._set_tool(Player.Tool.PITCHFORK)
	player.pitchfork.reset_aim()
	for i in 20:
		await get_tree().physics_frame

	print("\n=== how far a full bar goes ===")
	print("  a bite costs %.0f of %.0f" % [player.stamina.dig_cost(), player.stamina.maximum()])
	_fresh_ground()
	var first:= await _burst("full bar")
	await _shoot()
	var expected: int = int(player.stamina.maximum() / player.stamina.dig_cost())
	if first > expected:
		_fails.append("a full bar paid for %d bites, which is more than it holds (%d)"
			% [first, expected])
	if first < 2:
		_fails.append("a full bar paid for %d bites, which is not a game" % first)

	print("\n=== and again, straight away ===")
	_fresh_ground()
	var tired:= await _burst("no rest")
	if tired >= first:
		_fails.append("an empty bar paid for %d bites against a full bar's %d"
			% [tired, first])

	print("\n=== after standing still for %.0f seconds ===" % REST)
	await _rest(REST)
	print("  bar is at %d%%" % int(player.stamina.fraction() * 100.0))
	_fresh_ground()
	var rested:= await _burst("rested")
	if rested < first:
		_fails.append("a rested bar paid for %d bites against a fresh bar's %d"
			% [rested, first])

	print("\n=== with the ranks bought ===")
	Tech.ranks ["strong_back"] = 5
	Tech.ranks ["second_wind"] = 5
	Tech.ranks ["easy_swing"] = 5
	player.stamina.refill()
	print("  a bite now costs %.0f of %.0f"
		% [player.stamina.dig_cost(), player.stamina.maximum()])
	_fresh_ground()
	var upgraded:= await _burst("upgraded")
	if upgraded <= first:
		_fails.append("five ranks of everything paid for %d bites against %d unbought"
			% [upgraded, first])
	Tech.ranks.erase("strong_back")
	Tech.ranks.erase("second_wind")
	Tech.ranks.erase("easy_swing")

	print("\n=== sprinting ===")
	_check_sprint()

	if _fails.is_empty():
		print("\n[probe] PASS")
	else:
		for f in _fails:
			print("  FAIL  %s" % f)
		print("\n[probe] %d FAILURE(S)" % _fails.size())
	get_tree().quit(1 if _fails.size() > 0 else 0)


func _burst(what: String) -> int:
	var before:= GameState.hay_dug
	var paid:= 0
	var dug:= 0
	for i in BURST:


		if player.pitchfork.is_full():
			player.pitchfork.dump()
			await get_tree().physics_frame
		var mark:= GameState.hay_dug
		var had:= player.stamina.current
		player._active_tool_primary(true)
		if player.stamina.current < had:
			paid += 1
		if GameState.hay_dug > mark:
			dug += 1
		for j in SPAM_GAP:
			await get_tree().physics_frame
	print("  %-10s bar paid for %2d of %d clicks (%d dug, %s strands), left at %d%%"
		% [what, paid, BURST, dug, Hud.fmt(GameState.hay_dug - before),
			int(player.stamina.fraction() * 100.0)])
	return paid


func _fresh_ground() -> void:
	_aimed += 1
	player.rotation.y = PI * 0.5 + float(_aimed) * 0.16
	player.velocity = Vector3.ZERO


func _rest(seconds: float) -> void:
	var step:= maxf(get_physics_process_delta_time(), 1e-06)
	for i in int(seconds / step):
		await get_tree().physics_frame


func _check_sprint() -> void:
	var s:= player.stamina
	s.refill()
	var held:= 0.0
	var step:= 1.0 / 60.0

	while s.sprint_allowed(true, true) and held < 30.0:
		s.tick(step, true, Player.SPRINT)
		held += step
	print("  a full bar sprints for %.1f seconds" % held)
	if held < 4.0 or held > 20.0:
		_fails.append("a full bar sprints for %.1f seconds" % held)

	var stutters:= 0
	for i in 120:
		s.tick(step, false, 0.0)
		if s.sprint_allowed(true, true):
			stutters += 1
	if stutters > 0:
		_fails.append("a held sprint key restarted %d times on an empty bar" % stutters)
	else:
		print("  holding the key on an empty bar never restarts it")

	s.sprint_allowed(false, false)
	for i in 180:
		s.tick(step, false, 0.0)
	if not s.sprint_allowed(true, false):
		_fails.append("three seconds of rest was not enough to start a sprint")
	else:
		print("  three seconds of rest is enough to start again (bar at %d%%)"
			% int(s.fraction() * 100.0))


const SHOT_FRAMES:= 6
const SHOT_GAP:= 3


func _shoot() -> void:
	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--stamshot")
	if at < 0:
		return
	var path:= args [at + 1] if at + 1 < args.size() else "user://stamina.png"
	var stem:= path.trim_suffix(".png")


	for n in SHOT_FRAMES:


		for i in SHOT_GAP:
			player._active_tool_primary(true)
			await get_tree().process_frame
		var img:= get_viewport().get_texture().get_image()
		var err:= img.save_png("%s_%d.png" % [stem, n])
		if err != OK:
			print("  shot %d FAILED" % n)
	print("  %d shots -> %s_0.png .. %s_%d.png"
		% [SHOT_FRAMES, stem, stem, SHOT_FRAMES - 1])
	get_tree().quit()


func _stand_at_the_pile() -> void:
	player.global_position = Vector3(11.5, 0.4, 0.0)
	player.rotation = Vector3(0, PI * 0.5, 0)
	player.head.rotation.x = -0.55
	player.velocity = Vector3.ZERO
