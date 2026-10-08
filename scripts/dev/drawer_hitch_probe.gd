class_name DevDrawerHitchProbe
extends Node


const STOCK:= 40
const FRAMES:= 5

var world: Node3D
var player: Player
var panel: NeedleDrawer


func run() -> void:
	if world != null:
		world.block_save = true
	while Loading.is_active():
		await get_tree().process_frame
	await _wait(1.0)

	var scanner: HaystackScanner = world.builds.add_scanner(
		player.global_position + Vector3(4.0, 0.0, 0.0), 0.0)
	scanner.live = world.live
	await _wait(0.5)
	var kinds:= NeedleTypes.count()
	for i in STOCK:
		var index:= GameState.register_needle(Vector3.ZERO, null, i % kinds)
		GameState.needle_taken [index] = 1
		scanner._bank(index)
	await _wait(0.5)

	for label: String in ["cold", "warm", "warm again"]:
		await _open_once(scanner, label)
		panel.set_open(false)
		await _wait(0.8)
	print("[drawerhitch] done")
	get_tree().quit(0)


func _open_once(scanner: HaystackScanner, label: String) -> void:
	await get_tree().process_frame
	var pipes_before:= _pipelines()
	var t0:= Time.get_ticks_usec()
	panel.open(scanner)
	var open_us:= Time.get_ticks_usec() - t0
	var frames: PackedStringArray = []
	var worst:= 0
	var last:= Time.get_ticks_usec()
	for i in FRAMES:
		await get_tree().process_frame
		var now:= Time.get_ticks_usec()
		var ms:= (now - last) / 1000.0
		worst = maxi(worst, now - last)
		frames.append("%.1f" % ms)
		last = now
	var pipes:= _pipelines()
	var diff: PackedStringArray = []
	for k in pipes.size():
		diff.append(str(pipes [k] - pipes_before [k]))
	print("[drawerhitch] %s: %d cards, open() %.1f ms, next %d frames [%s] ms (worst %.1f), pipelines draw/surface/mesh/spec +[%s]"
		% [label, panel.cards().size(), open_us / 1000.0, FRAMES, ", ".join(frames),
		worst / 1000.0, ", ".join(diff)])


func _pipelines() -> Array [int]:
	return [
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION),
	]


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
