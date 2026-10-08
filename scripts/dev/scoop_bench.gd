class_name DevScoopBench
extends Node


var world: Node3D
var player: Player

const SCOOPS:= 14
const SAMPLE:= 30


func run() -> void:
	for i in 40:
		await get_tree().process_frame


	var eye:= Vector3(11.6, 1.7, 0.6)
	var look:= Vector3(9.2, 1.35, 0.3)
	player.global_position = eye - Vector3(0, Player.EYE_HEIGHT, 0)
	var flat:= Vector3(look.x - eye.x, 0.0, look.z - eye.z)
	player.rotation = Vector3(0.0, atan2(- flat.x, - flat.z), 0.0)
	player.head.rotation.x = atan2(look.y - eye.y, maxf(flat.length(), 0.001))


	Tech.reset()
	Tech.grant("spade", 1)
	GameState.grant_tool("spade")
	player._set_tool(Player.Tool.SHOVEL)
	for i in 20:
		await get_tree().process_frame

	print("\n=== repeated scoop, measured from the click ===")
	print("   n  lifted   live  awake   worst_ms   mean_ms  worst_phys_ms")
	for n in range(1, SCOOPS + 1):
		var lifted: int = player.shovel.scoop()
		var worst:= 0.0
		var worst_phys:= 0.0
		var total:= 0.0
		for i in SAMPLE:
			await get_tree().process_frame
			var dt:= get_process_delta_time()
			total += dt
			worst = maxf(worst, dt)
			worst_phys = maxf(worst_phys,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		print("  %2d  %6d  %5d  %5d   %8.2f  %8.2f   %12.2f"
			% [n, lifted, world.live.active_count(), _awake(),
						worst * 1000.0, total / SAMPLE * 1000.0, worst_phys * 1000.0])
	print("  (16.7 ms = 60 fps;  worst_ms is the single worst frame after a click)")
	get_tree().quit()


func _awake() -> int:
	var n:= 0
	for b in world.live._active:
		if not b.sleeping:
			n += 1
	return n
