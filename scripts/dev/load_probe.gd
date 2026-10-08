class_name DevLoadProbe
extends Node


const GAME_SCENE:= "res://scenes/main.tscn"
const MENU_SCENE:= "res://scenes/main_menu.tscn"


const PATIENCE:= 40.0

var _fails:= 0

var _blank:= 0
var _samples:= 0


var _first_blank: Dictionary = { }


func run() -> void:
	print("\n=== title -> world ===")
	await _walk_into_world()
	print("\n=== world -> title ===")
	await _walk_back_to_title()
	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> int:
	print("  FAIL  %s" % msg)
	_fails += 1
	return 1


func _walk_into_world() -> void:
	if Loading.is_active():
		_fail("the loading screen was already up before anything asked for it")


	Cfg.set_no_hud(true)
	Loading.show_screen("FIND THE NEEDLE", "PREPARING THE PILE")
	if not Loading.is_active():
		_fail("show_screen() did not put the loading screen up")
	get_tree().change_scene_to_file(GAME_SCENE)

	var world:= await _watch_until_settled()
	if world == null:
		return
	if not (world is Node3D) or not world.has_method("save_now"):
		_fail("landed somewhere that is not the world: %s" % world)
		return
	if get_tree().paused:
		_fail("the world was handed over with the tree still paused")


	for part: String in ["field", "player", "hud", "builds", "props", "stand"]:
		if world.get(part) == null:
			_fail("the world finished with no %s" % part)


	if Cfg.no_hud:
		_fail("camera mode followed the player into the game")
	if world.hud != null and bool(world.hud.get("_no_hud")):
		_fail("the world cleared camera mode but the HUD did not hear about it")
	print("  world built, %d frames watched, %d of them blank" % [_samples, _blank])


func _walk_back_to_title() -> void:
	_blank = 0
	_samples = 0
	_first_blank = { }
	Loading.show_screen("FIND THE NEEDLE", "RETURNING TO THE YARD")
	get_tree().change_scene_to_file(MENU_SCENE)
	var menu:= await _watch_until_settled()
	if menu == null:
		return
	if menu.get_node_or_null("Background") == null:
		_fail("the title screen came back without its backdrop")
	if menu.get_node_or_null("MenuLayer/MainMenu") == null:
		_fail("the title screen came back without its menu")
	print("  title screen rebuilt, %d frames watched, %d of them blank" % [_samples, _blank])


func _watch_until_settled() -> Node:
	var waited:= 0.0
	while Loading.is_active():
		await get_tree().process_frame


		if not Loading.is_active():
			break
		_samples += 1


		if not Loading.is_covering():
			_blank += 1
			if _first_blank.is_empty():
				_first_blank = Loading.cover_state()
				_first_blank ["frame"] = _samples
		waited += get_process_delta_time()
		if waited > PATIENCE:
			_fail("nothing settled within %.0f s" % PATIENCE)
			return null
	if _blank > 0:
		_fail("%d of %d frames had nothing on the screen -- first at %s"
			% [_blank, _samples, _first_blank])
	if _samples < 2:
		_fail("the transition was over in %d frame(s) -- nothing was staged" % _samples)

	await get_tree().process_frame
	return get_tree().current_scene
