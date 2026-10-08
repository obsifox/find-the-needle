class_name DevDeliveryShotProbe
extends Node


const OUT_DEFAULT:= "user://"


const SHOTS:= [
	[Vector3(0.0, 2.1, 6.2), Vector3(0.0, 1.35, -2.6), "delivery_bay.png"],
	[Vector3(0.0, 1.7, 1.7), Vector3(0.0, 1.15, -1.6), "delivery_bed.png"],
	[Vector3(-4.2, 1.65, 3.6), Vector3(-4.2, 1.5, 2.05), "delivery_board.png"],
]


const LOADED:= 20

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	var truck: DeliveryTruck = world.truck
	var door: BayDoor = world.bay_door


	truck.snap_parked()


	var args:= OS.get_cmdline_user_args()
	var at:= args.find("--deliveryshot")
	var item:= args [at + 2] if at >= 0 and at + 2 < args.size() else "hay_bale"
	var count:= 30 if item == "eco_brick" else LOADED
	for i in count:
		truck.stack_one(item)
	world.deliveries._restate()


	player.global_position = door.to_global(Vector3(-7.0, 0.2, 4.0))

	for _w in 60:
		await get_tree().process_frame

	var cam:= Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	cam.make_current()

	for shot: Array in SHOTS:
		cam.global_position = door.to_global(shot [0])
		cam.look_at(door.to_global(shot [1]), Vector3.UP)
		for _w in 6:
			await get_tree().process_frame
		await _snap(out_dir, str(shot [2]))

	get_tree().quit(0)


func _snap(out_dir: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, file_name]
	img.save_png(path)
	print("wrote %s" % path)
