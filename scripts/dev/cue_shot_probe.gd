class_name DevCueShotProbe
extends Node


const PEAK:= MissionCue.PULSE * 0.25
const TROUGH:= MissionCue.PULSE * 0.75
const DARK:= MissionCue.HOLD + 0.6


const ROLL_UP:= MissionCue.PULSE
const ROLL_DOWN:= MissionCue.PULSE * 1.5


const TILTS_DONE:= 3
const SECONDS_WALKED:= 2.4

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	for i in 30:
		await get_tree().process_frame


	var pile:= _pile_centre()
	var stand:= pile + Vector3(0.0, 0.0, 1.0) * 9.0
	stand.y = world.field.height_at(stand.x, stand.z) + 0.2
	player.global_position = stand
	player.set_look(atan2(pile.x - stand.x, pile.z - stand.z) + PI, -0.06)


	GameState.grant_tool("sand_shovel")
	player.select_hotbar_slot(4)

	await _cue_at("tilt_pour", out_dir, "cue_tilt_big.png", PEAK)
	await _cue_at("tilt_pour", out_dir, "cue_tilt_small.png", TROUGH)
	await _cue_at("tilt_pour", out_dir, "cue_tilt_gap.png", DARK)
	await _cue_at("pour_bucket", out_dir, "cue_pour.png", PEAK)
	await _cue_at("open_build", out_dir, "cue_build.png", PEAK)
	await _cue_at("dismantle", out_dir, "cue_dismantle.png", PEAK)


	await _cue_at("build_distance", out_dir, "cue_wheel_up.png", ROLL_UP)
	await _cue_at("build_distance", out_dir, "cue_wheel_down.png", ROLL_DOWN)


	await _cue_at("build_distance", out_dir, "cue_key_further.png", ROLL_UP, 1)
	await _cue_at("build_distance", out_dir, "cue_key_closer.png", ROLL_DOWN, 1)


	await _card_at("build_rake", out_dir, "card_rake.png")
	await _card_at("extend_shed", out_dir, "card_shed.png")


	await _badge_at("run", out_dir, "badge_shift.png")
	await _badge_at("open_tech", out_dir, "badge_tab.png")
	await _badge_at("throw_hay", out_dir, "badge_mouse.png")

	get_tree().quit(0)


func _card_at(id: String, out_dir: String, shot: String) -> void:
	GameState.mission_index = MissionBook.index_of(id)
	for i in 24:
		await get_tree().process_frame
	var cue: MissionCue = world.mission_cue
	if cue.visible:
		push_warning("cueshot: '%s' has no key and should not be cued" % id)
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s  ·  step '%s', card only" % [path, id])


func _badge_at(id: String, out_dir: String, shot: String) -> void:
	GameState.mission_index = MissionBook.index_of(id)
	for i in 24:
		await get_tree().process_frame
	world.mission_cue.visible = false
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s  ·  step '%s', card badge" % [path, id])


func _cue_at(id: String, out_dir: String, shot: String, phase: float,
		shows: int = 0) -> void:
	var missions: MissionDirector = world.missions
	GameState.mission_index = MissionBook.index_of(id)


	for i in 20:
		await get_tree().process_frame
	missions._tilts_live = TILTS_DONE
	missions._walked_live = SECONDS_WALKED


	for i in 24:
		await get_tree().process_frame

	var cue: MissionCue = world.mission_cue
	if not cue.visible:
		push_warning("cueshot: no cue is up for '%s'" % id)
	cue._t = phase
	cue._shows = shows


	cue._frame(- cos(TAU * phase / MissionCue.PULSE))
	await RenderingServer.frame_post_draw
	var path:= "%s/%s" % [out_dir, shot]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s  ·  step '%s', %.2fs into the cycle, alpha %.2f"
		% [path, id, cue._t, cue._root.modulate.a])


func _pile_centre() -> Vector3:
	var field: HayField = world.field
	var best:= Vector3.ZERO
	var best_h:= -1.0
	for x in range(-14, 15, 2):
		for z in range(-14, 15, 2):
			var h:= field.height_at(float(x), float(z))
			if h > best_h:
				best_h = h
				best = Vector3(float(x), h, float(z))
	return best
