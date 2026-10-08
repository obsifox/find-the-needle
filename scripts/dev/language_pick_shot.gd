class_name LanguagePickShot
extends Node


var layer: CanvasLayer
var out_dir:= "res://captures"


func run() -> void:
	var ua:= OS.get_cmdline_user_args()
	var at:= ua.find("--langshot")
	if at >= 0 and at + 1 < ua.size() and not ua [at + 1].begins_with("--"):
		out_dir = ua [at + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)

	var picker:= LanguagePicker.new()
	picker.preview = true
	layer.add_child(picker)


	for i: int in 150:
		await get_tree().process_frame
	_shoot(out_dir.path_join("language_picker_first.png"))


	var other:= 1 if picker._lit == 0 else 0
	picker._cards [other].grab_focus()
	for i: int in 30:
		await get_tree().process_frame
	_shoot(out_dir.path_join("language_picker_other.png"))


	for i: int in picker._cards.size():
		if i == other or picker._codes [i] == "en":
			continue
		picker._cards [i].grab_focus()
		for f: int in 30:
			await get_tree().process_frame
		_shoot(out_dir.path_join("language_picker_%s.png" % picker._codes [i]))
	get_tree().quit()


func _shoot(path: String) -> void:
	var img:= get_viewport().get_texture().get_image()
	var err:= img.save_png(path)
	print("[langshot] ", path, " ", "ok" if err == OK else "FAILED %d" % err)
