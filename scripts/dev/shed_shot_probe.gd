class_name DevShedShotProbe
extends Node


const EYE_HEIGHT:= 7.4
const PITCH:= -14.0

var world: Node3D
var player: Player


func shoot(out_dir: String) -> void:
	world.block_save = true
	Tech.reset()
	await _look(out_dir, "shed_stock.png")
	await _outside(out_dir, "shed_outside.png")
	Tech.grant("yard_space", TechTree.max_rank("yard_space"))

	await get_tree().process_frame
	await _look(out_dir, "shed_extended.png")
	await _outside(out_dir, "shed_outside_extended.png")
	get_tree().quit(0)


const OUT_BACK:= 1.75
const OUT_UP:= 0.62
const OUT_PITCH:= -9.0


func _outside(out_dir: String, name: String) -> void:
	var shed: Warehouse = world.warehouse
	var span: float = shed.inner if shed != null else Warehouse.INNER


	var at:= Vector3(span * OUT_BACK, span * OUT_UP, span * OUT_BACK)
	var cam:= Camera3D.new()
	cam.fov = 55.0
	cam.far = 4000.0
	world.add_child(cam)
	cam.look_at_from_position(at, Vector3(0.0, span * 0.45, 0.0), Vector3.UP)
	cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(OUT_PITCH))
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s  (%.0f m across, outside)" % [path, span * 2.0])
	cam.queue_free()


	if player.camera != null:
		player.camera.make_current()
	await get_tree().process_frame


func _look(out_dir: String, name: String) -> void:
	var shed: Warehouse = world.warehouse
	var span: float = shed.inner if shed != null else Warehouse.INNER


	var at:= Vector3(Warehouse.INNER - 2.0, EYE_HEIGHT, Warehouse.INNER - 2.0)
	await _shoot_from(at, Vector3(- span, 2.0, - span), PITCH, out_dir, name)


func _shoot_from(at: Vector3, aim: Vector3, pitch: float, out_dir: String,
		name: String) -> void:
	var shed: Warehouse = world.warehouse
	var span: float = shed.inner if shed != null else Warehouse.INNER
	player.global_position = at
	player.look_at_from_position(at, aim, Vector3.UP)
	player.rotation.x = 0.0
	if player.head != null:
		player.head.rotation.x = deg_to_rad(pitch)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()
	var path:= "%s/%s" % [out_dir, name]
	img.save_png(path)
	print("wrote %s  (%.0f m across)" % [path, span * 2.0])
