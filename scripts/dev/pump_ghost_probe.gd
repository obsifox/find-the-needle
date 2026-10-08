class_name DevPumpGhostProbe
extends Node


const FRAMES:= 90
const EYE:= Vector3(13.0, 1.66, 0.0)

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	GameState.add_money(50000.0)
	var tool: BuildTool = player.build
	for i in 30:
		await get_tree().physics_frame
	await _find_site(tool)
	await _sweep(tool, BuildTool.Mode.BOREHOLE, "pump", out_dir)
	await _sweep(tool, BuildTool.Mode.GENERATOR, "gen", out_dir)
	get_tree().quit(0)


var _stand:= Vector3(11.5, 0.0, 12.0)
var _base_yaw:= 0.0


func _find_site(tool: BuildTool) -> void:
	tool.set_mode(BuildTool.Mode.BOREHOLE)
	tool.set_active(true)
	for ring: float in [12.5, 13.5]:
		for step in 16:
			var a:= TAU * step / 16.0
			_stand = Vector3(cos(a), 0.0, sin(a)) * ring


			_base_yaw = a + PI * 0.5
			var look:= Vector3(cos(_base_yaw), 0.0, sin(_base_yaw))
			player.global_position = _stand
			player.look_at_from_position(_stand, _stand + look, Vector3.UP)
			player.rotation.x = 0.0
			player.head.rotation.x = -0.55
			await get_tree().physics_frame
			await get_tree().process_frame
			await get_tree().process_frame
			var ev: Dictionary = tool._eval
			print("[pumpghost] site %s yaw %.2f: ok=%s '%s'" % [
				_stand, _base_yaw, ev.get("ok"), ev.get("reason", "")])
			if bool(ev.get("ok", false)):
				return
	tool.set_active(false)


func _sweep(tool: BuildTool, mode: BuildTool.Mode, tag: String, out_dir: String) -> void:
	tool.set_mode(mode)
	tool.set_active(true)
	var flips:= 0
	var last_ok:= -1
	var last_green:= -1
	var green_drops:= 0
	for f in FRAMES:


		var yaw:= _base_yaw + deg_to_rad(8.0 * sin(f * 0.15))
		var look:= Vector3(cos(yaw), 0.0, sin(yaw))
		player.global_position = _stand
		player.look_at_from_position(player.global_position,
			player.global_position + look, Vector3.UP)
		player.rotation.x = 0.0
		if player.head != null:
			player.head.rotation.x = -0.55 + 0.2 * sin(f * 0.07)
		await RenderingServer.frame_post_draw
		var img:= get_viewport().get_texture().get_image()
		var green:= _green_near_centre(img)
		var ev: Dictionary = tool._eval
		var ok:= 1 if bool(ev.get("ok", false)) else 0
		var ghost: Node3D = tool._borehole_ghost if mode == BuildTool.Mode.BOREHOLE else tool._generator_ghost
		if last_ok >= 0 and ok != last_ok:
			flips += 1
		if last_green > 2000 and green < last_green / 3:
			green_drops += 1
		last_ok = ok
		last_green = green
		var what:= ""
		if ev.get("reason", "") == "blocked" and mode == BuildTool.Mode.BOREHOLE:
			var col: Object = tool._probe_obstruction(tool._borehole_probe_query)
			what = str(col.get_path()) if col is Node else str(col)
		print("[pumpghost] %s f%02d vis=%s ok=%d reason='%s' %s at=%s green=%d" % [
			tag, f, ghost.is_visible_in_tree(), ok, ev.get("reason", ""), what,
			ghost.global_position, green])
		if f % 15 == 0:
			img.save_png("%s/%s_%02d.png" % [out_dir, tag, f])
	print("[pumpghost] %s: %d ok flips, %d green drops over %d frames" % [
		tag, flips, green_drops, FRAMES])
	tool.set_active(false)


func _green_near_centre(img: Image) -> int:
	var w:= img.get_width()
	var h:= img.get_height()
	var n:= 0
	for y in range(h / 3, h * 2 / 3, 4):
		for x in range(w / 6, w * 5 / 6, 4):
			var c:= img.get_pixel(x, y)
			if c.g > 0.35 and c.g > c.r * 1.4 and c.g > c.b * 1.4:
				n += 1
	return n
