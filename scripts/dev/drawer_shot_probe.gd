class_name DevDrawerShotProbe
extends Node


const STOCKED:= [0, 1, 6, 7, 12, 13, 18, 23]
const SEEN:= [0, 6, 13]

var world: Node3D
var player: Player
var panel: NeedleDrawer


func shoot(out_dir: String) -> void:
	if world != null:
		world.block_save = true


	while Loading.is_active():
		await get_tree().process_frame
	await _wait(0.6)

	var scanner: HaystackScanner = world.builds.add_scanner(
		player.global_position + Vector3(4.0, 0.0, 0.0), 0.0)
	scanner.live = world.live
	await _wait(0.3)


	for type: int in STOCKED:
		var index:= GameState.register_needle(Vector3.ZERO, null, type)
		GameState.needle_taken [index] = 1
		scanner._bank(index)
	for type: int in SEEN:
		GameState.discover(type, Vector3.ZERO)

	panel.open(scanner)


	for i in 3:
		await get_tree().process_frame
	await _shot(out_dir, "drawer_full.png")


	panel.set_open(false)
	await _wait(0.4)
	var held:= GameState.register_needle(Vector3.ZERO, null, 23)
	GameState.needle_taken [held] = 1
	player.hand.take_needle(held, player.global_position + Vector3(0, 1.2, 0))
	panel.open(scanner)
	for i in 3:
		await get_tree().process_frame
	await _shot(out_dir, "drawer_hands_full.png")


	panel.set_open(false)
	player.hand.drop_held()
	DisplayServer.window_set_size(Vector2i(890, 606))
	await _wait(0.4)
	panel.open(scanner)
	for i in 3:
		await get_tree().process_frame
	await _shot(out_dir, "drawer_small.png")
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(out_dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s" % path)
