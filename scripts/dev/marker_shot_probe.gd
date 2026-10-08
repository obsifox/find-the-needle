class_name DevMarkerShotProbe
extends Node


var world: Node3D
var player: Player
var out_dir:= ""


func run() -> void:
	call_deferred("_run")


func _run() -> void:
	world.block_save = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i in 90:
		await get_tree().process_frame

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var shop:= world.get("shop") as HayShop
	var at:= shop.focus_point()

	GameState.mission_index = MissionBook.index_of("find_shop")

	var out:= shop.interact_point() - at
	out.y = 0.0
	var from:= at + out.normalized() * 14.0 + Vector3(4.0, 0.0, 0.0)
	from.y = 1.0
	_face(from, at)
	await _shot("shop_ahead")
	_face(from, from + (from - at))
	await _shot("shop_behind")


	GameState.mission_index = MissionBook.index_of("pick_up_shovel")
	var mission: MissionDirector = world.get("missions")
	var feet:= Vector3(-4.0, 1.0, 4.0)
	_face(feet, feet + Vector3(0.0, 0.0, -10.0))
	var toy:= (world.get("props") as PropManager).spawn_at_feet("sand_shovel", player)
	await _shot("shovel_level")
	print("[markershot] shovel %s, point %s" % [toy.global_position,
		mission.marker_point() if mission != null else null])
	player.set_look(0.0, deg_to_rad(-70.0))
	await _shot("shovel_down")
	(world.get("props") as PropManager).remove(toy)

	var builds: BuildManager = world.get("builds")
	var rake_at:= Vector3(4.0, 0.05, 8.0)
	builds.add_piston_rake(rake_at, 0.0, 0.0, true)
	GameState.mission_index = MissionBook.index_of("rake_throw")
	var far:= rake_at + Vector3(-9.0, 1.0, -6.0)
	_face(far, rake_at)
	await _shot("rake_far")
	var near:= rake_at + Vector3(-2.2, 1.0, -2.2)
	_face(near, rake_at)
	await _shot("rake_near")


	GameState.mission_index = MissionBook.index_of("reverse_belt")
	var belt_a:= Vector3(-6.0, 0.05, 10.0)
	var belt_b:= Vector3(10.0, 0.05, 10.0)
	var view:= Vector3(-8.0, 1.0, 4.0)
	_face(view, belt_a)
	await _shot("belt_none")

	var none_pt: Variant = mission.marker_point() if mission != null else null
	print("[markershot] no belt, point %s" % [none_pt])
	builds.add_conveyor(belt_a, belt_b)
	await _shot("belt_near")
	var pt: Variant = mission.marker_point() if mission != null else null
	print("[markershot] belt, point %s" % [pt])


	GameState.mission_index = -1
	builds.add_cabinet(Vector3(-10.0, 0.05, -6.0), 0.0)
	var aim:= Vector3(0.0, 1.0, 0.0)
	_face(aim, aim + Vector3(0.0, 0.0, -10.0))
	player.set_look(0.0, deg_to_rad(-25.0))
	Tech.grant("cabinet")
	player.equip_build("cabinet")
	await _shot("cabinet_stuck")
	print("[markershot] stuck %s" % player.build.stuck())


	player.put_away_build()
	for id: String in BuildCatalog.ordered_ids():
		Tech.grant(id)
	var catalog: CatalogPanel = world.get("catalog_panel")
	catalog.set_open(true)
	await _shot("catalog")
	var bar:= catalog.find_children("*", "VScrollBar", true, false)
	for b: VScrollBar in bar:
		print("[markershot] scroll bar %s at %s, shown %s" % [b.size, b.global_position,
			b.is_visible_in_tree()])
	get_tree().quit(0)


func _face(from: Vector3, to: Vector3) -> void:
	player.global_position = from
	player.velocity = Vector3.ZERO
	var d:= to - from
	player.set_look(atan2(- d.x, - d.z), deg_to_rad(-8.0))


func _shot(label: String) -> void:


	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= out_dir.path_join("marker_%s.png" % label)
	img.save_png(path)
	print("[markershot] %s" % path)
