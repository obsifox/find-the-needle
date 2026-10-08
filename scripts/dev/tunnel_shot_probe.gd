class_name DevTunnelShotProbe
extends Node


const OUT_DEFAULT:= "user://tunnel"


const KEEP:= ["BrutalistPlaza", "BayDoor", "DeliveryTruck"]


const SHOTS:= [
	{ "file": "tunnel_shut.png", "eye": Vector3(0.0, 1.7, 13.0),
		"at": Vector3(0.0, 3.0, 0.0), "open": false, "truck": false,
		"note": "from the yard, door shut: does the door fit the portal" },
	{ "file": "tunnel_open.png", "eye": Vector3(0.0, 1.7, 13.0),
		"at": Vector3(0.0, 3.0, -12.0), "open": true, "truck": false,
		"note": "same spot, door up: down the empty bore" },
	{ "file": "tunnel_truck.png", "eye": Vector3(3.4, 2.2, 9.0),
		"at": Vector3(0.0, 2.0, -6.0), "open": true, "truck": true,
		"note": "the lorry parked in the mouth, off the door's centreline" },
	{ "file": "tunnel_head.png", "eye": Vector3(0.0, 1.7, 4.0),
		"at": Vector3(0.0, 8.0, -2.0), "open": true, "truck": false,
		"note": "under the head, looking up at the portal and the roof" },


	{ "file": "tunnel_block.png", "eye": Vector3(24.0, 24.0, 37.0),
		"at": Vector3(0.0, 20.0, -14.0), "open": false, "truck": false,
		"note": "off the corner and up: the ends, the roof and where it buries" },
]


const TRUCK_AT:= - DeliveryTruck.PARK_IN

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:


	world.block_save = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var plaza: BrutalistPlaza = world.get("plaza")
	if plaza == null:
		push_error("--tunnelshot: no plaza. It only means anything on that site.")
		get_tree().quit(1)
		return
	if plaza.tunnel == null:
		push_error("--tunnelshot: the plaza has no '%s'. Nothing to photograph."
			% BrutalistPlaza.TUNNEL_NODE)
		get_tree().quit(1)
		return

	var door: Node3D = world.get("bay_door")
	if door == null:
		push_error("--tunnelshot: no bay door to frame the shots off.")
		get_tree().quit(1)
		return

	_strip_the_yard()
	_hide_the_hud()
	_report(plaza, door)
	await get_tree().process_frame
	await get_tree().process_frame

	for shot: Dictionary in SHOTS:
		await _look(out_dir, shot, door)
	get_tree().quit(0)


func _report(plaza: BrutalistPlaza, door: Node3D) -> void:
	var deepest:= 0.0
	var widest:= 0.0
	var tallest:= 0.0
	for kid: Node in plaza.tunnel.get_children():
		var mi:= kid as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box: AABB = mi.transform * mi.mesh.get_aabb()
		deepest = maxf(deepest, - box.position.z)
		widest = maxf(widest, box.end.x)
		tallest = maxf(tallest, box.end.y)


	var needs:= DeliveryTruck.VANISH_PAST
	print("tunnel: bore %.1f m deep, %.1f m to the outside wall, %.1f m to the roof"
		% [deepest, widest, tallest])
	print("tunnel: the lorry is gone by %.1f m out, so the bore is %+.1f m on it"
		% [needs, deepest - needs])
	print("tunnel: seated on the door at (%.1f, %.1f, %.1f)"
		% [door.global_position.x, door.global_position.y, door.global_position.z])


func _strip_the_yard() -> void:
	var hidden:= 0
	for child: Node in world.get_children():
		if child == player or String(child.name) in KEEP:
			continue
		if child is DirectionalLight3D or child is WorldEnvironment or child is Camera3D:
			continue
		if child is Node3D:
			(child as Node3D).visible = false
			hidden += 1
	print("tunnel: hid %d yard nodes" % hidden)


func _hide_the_hud() -> void:
	for child: Node in world.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	if player != null:
		for kid: Node in player.get_children():
			if kid is CanvasLayer:
				(kid as CanvasLayer).visible = false


func _look(out_dir: String, shot: Dictionary, door: Node3D) -> void:
	var frame:= door.global_transform
	var eye: Vector3 = frame * (shot ["eye"] as Vector3)
	var at: Vector3 = frame * (shot ["at"] as Vector3)


	if door.has_method("set_open_amount"):
		door.call("set_open_amount", 1.0 if bool(shot ["open"]) else 0.0)

	var truck: Node3D = world.get("truck")
	if truck != null:
		truck.visible = bool(shot ["truck"])
		if bool(shot ["truck"]):


			truck.global_transform = frame.translated_local(
				Vector3(0.0, 0.0, - TRUCK_AT))

	player.global_position = eye
	player.look_at_from_position(eye, at, Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:


		var to:= at - eye
		player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	img.save_png("%s/%s" % [out_dir, shot ["file"]])
	print("wrote %-18s (%s)" % [shot ["file"], shot ["note"]])
