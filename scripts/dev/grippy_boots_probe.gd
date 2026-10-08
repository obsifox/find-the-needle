class_name DevGrippyBootsProbe
extends Node


var world: Node3D
var player: Player

var _pass:= 0
var _fail:= 0


const START:= Vector3(13.0, Cfg.BELT_FRAME_DEPTH + Cfg.BELT_STAND_CLEAR, -5.0)
const LENGTH:= 10.0
const ALONG:= Vector3(0.0, 0.0, 1.0)

const SLAB:= Vector3(15.5, 0.05, 3.0)

const STAND:= 2.0


func run() -> void:
	await _frames(60)
	print("[grippyboots] build: %s" % ("demo" if Cfg.DEMO else "full"))
	player.capture_mouse(true)
	_card_case()
	var builds: BuildManager = world.builds
	var belt:= builds.add_conveyor(START, START + ALONG * LENGTH)
	_ok(belt != null, "a %d m belt is laid" % int(LENGTH))
	await _frames(30)

	Tech.reset()
	await _ride_case(false)
	if not Cfg.DEMO:
		Tech.grant("grippy_boots", 1)
		_ok(Tech.has_grippy_boots(), "a granted card is boots worn")
		await _ride_case(true)
		await _walk_case()
		Tech.reset()
		await _ride_case(false)
	_release_keys()
	print("\n[grippyboots] %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("  ok    %s" % what)
	else:
		_fail += 1
		print("  FAIL  %s" % what)


func _card_case() -> void:
	print("\n=== the card ===")
	_ok(TechTree.has_id("grippy_boots"), "there is a Grippy Boots card")
	_ok(TechTree.branch_of("grippy_boots") == "fitness", "filed under Fitness")
	_ok(TechTree.is_demo("grippy_boots") == Cfg.DEMO,
		"it is %s" % ("a demo padlock" if Cfg.DEMO else "for sale"))
	if Cfg.DEMO:
		Tech.grant("grippy_boots", 1)
		_ok(not Tech.is_unlocked("grippy_boots"), "a free grant does not hand the demo the card")
		_ok(not Tech.has_grippy_boots(), "and Tech.has_grippy_boots says no")
		var can:= Tech.can_buy("grippy_boots")
		_ok(not bool(can ["ok"]), "and it cannot be bought")
	else:
		_ok(is_equal_approx(Tech.next_cost("grippy_boots"), Cfg.GRIPPY_BOOTS_CARD_COST),
			"it costs $%d" % int(Cfg.GRIPPY_BOOTS_CARD_COST))


func _ride_case(boots: bool) -> void:
	print("\n=== standing on a running belt, %s ===" % ("with the boots" if boots else "without the boots"))
	await _land_at(START + ALONG * 1.5 + Vector3(0.0, 0.3, 0.0))
	_ok(player.is_on_floor(), "the player is standing on the belt")
	var from:= player.global_position
	await _secs(STAND)
	var to:= player.global_position
	var along:= (to - from).dot(ALONG)
	var y_drift:= absf(to.y - from.y)
	if boots:
		_ok(absf(along) < 0.05, "%.1f s on the belt moved them %.3f m" % [STAND, along])
	else:

		var want:= Cfg.BELT_SPEED * STAND * 0.5
		_ok(along > want, "%.1f s on the belt carried them %.2f m (want over %.2f)"
			% [STAND, along, want])
	_ok(y_drift < 0.05, "and they stayed on top of the rubber (%.3f m up or down)" % y_drift)
	_ok(player.is_on_floor(), "still standing on it")


func _walk_case() -> void:
	print("\n=== walking up and down the belt with the boots ===")

	var against:= await _walk_from(START + ALONG * (LENGTH - 1.0) + Vector3(0.0, 0.3, 0.0), 0.0)
	var with:= await _walk_from(START + ALONG * 1.0 + Vector3(0.0, 0.3, 0.0), PI)
	var slab:= await _walk_from(SLAB, 0.0)
	_ok(against > 0.5, "a second's walk against the belt covered %.2f m" % against)
	_ok(absf(against - with) < 0.1,
		"and one with it covered %.2f m, so the belt neither helps nor holds" % with)
	print("  (the same walk on the slab covered %.2f m)" % slab)


func _walk_from(at: Vector3, yaw: float) -> float:
	await _land_at(at)
	player.set_look(yaw, 0.0)
	var from:= player.global_position
	Input.action_press("move_forward")
	await _secs(1.0)
	Input.action_release("move_forward")
	var moved:= player.global_position - from
	return Vector2(moved.x, moved.z).length()


func _land_at(p: Vector3) -> void:
	_release_keys()
	player.velocity = Vector3.ZERO
	player.global_position = p + Vector3(0.0, 0.1, 0.0)
	for i in 180:
		await get_tree().physics_frame
		if i > 5 and player.is_on_floor():
			break
	await _frames(3)


func _release_keys() -> void:
	for a: String in ["jump", "move_forward", "move_back", "move_left", "move_right", "sprint"]:
		Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await _frames(int(ceil(s * float(Engine.physics_ticks_per_second))))
