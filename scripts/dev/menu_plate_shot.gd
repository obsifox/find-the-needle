class_name MenuPlateShot
extends Node


const OUT_DIR:= "res://captures"
const SHOT_SIZE:= Vector2i(2560, 1440)


const SETTLE_FRAMES:= 150

var menu: MainMenu


func run() -> void:


	DisplayServer.window_set_size(SHOT_SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))


	for sibling in menu.get_parent().get_children():
		if sibling != menu and sibling is CanvasItem:
			(sibling as CanvasItem).visible = false
	var keep:= ["Scrim", "TitleBlock"]
	for child in menu.get_children():
		if child is CanvasItem and not (String(child.name) in keep):
			(child as CanvasItem).visible = false
	await _shot("menu_plate_title", SETTLE_FRAMES)
	var title:= menu.get_node_or_null("TitleBlock")
	if title != null:
		(title as CanvasItem).visible = false
	await _shot("menu_plate_clean", 8)
	get_tree().quit()


func _shot(shot_name: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s.png" % [OUT_DIR, shot_name]
	img.save_png(ProjectSettings.globalize_path(path))
	print("[menuplate] %s  %dx%d" % [path, img.get_width(), img.get_height()])
