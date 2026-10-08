class_name DevGiftShotProbe
extends Node


const BEATS:= [0.2, 0.5, 0.95, 1.3, 1.75, 1.97, 2.2, 2.6, 3.0, 3.18, 3.3, 3.5, 4.0, 4.7, 5.5]


const HOLD_BEATS:= [5.05, 5.65, 5.8, 6.6, 7.6, 7.72]

var world: Node3D
var out_dir:= ""


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i in 90:
		await get_tree().process_frame
	var card: GiftCard = world.gift_card
	var which:= "rake"
	var hold:= false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "cabinet" or arg == "pole":
			which = arg
		elif arg == "hold":
			hold = true


	if hold:
		card.play(which, func() -> void: pass)
	else:
		card.play(which)
	var start:= Time.get_ticks_msec()
	for beat: float in (BEATS + HOLD_BEATS if hold else BEATS):
		while card._t < beat:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img:= get_viewport().get_texture().get_image()
		var path:= out_dir.path_join("gift_%s_%04d.png" % [which, int(round(card._t * 1000.0))])
		img.save_png(path)
		print("[giftshot] %s at %.2f s" % [path, card._t])
	print("[giftshot] done in %.1f s" % ((Time.get_ticks_msec() - start) / 1000.0))
	get_tree().quit(0)
