class_name DevCrustProbe
extends Node


const OUT_DIR:= "res://captures"


const VIEWS:= [
	[Vector3(11.2, 1.7, 0.0), Vector3(4.0, 2.6, 0.0), "crust_face"],
	[Vector3(9.6, 1.2, 6.2), Vector3(2.0, 3.4, 1.0), "crust_low"],
	[Vector3(7.4, 2.4, -6.0), Vector3(0.0, 4.2, 0.0), "crust_up"],
	[Vector3(12.4, 1.7, 8.6), Vector3(3.2, 4.2, 4.8), "crust_repro"],
]


const CHANNEL_MARGIN:= 40
const FLOOR:= 60


const BUDGET:= 400

var world: Node3D
var player: Player

var _cam: Camera3D
var _fails:= 0


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Cfg.perf_scale = 1.0


	Cfg.set_quality(Cfg.Quality.ULTRA)

	_cam = Camera3D.new()
	_cam.fov = 74.0
	_cam.near = 0.01
	_cam.far = 320.0
	world.add_child(_cam)
	_cam.current = true

	print("\n=== the pile, close up, LOD wide open ===")
	for v: Array in VIEWS:
		await _check(v [0], v [1], String(v [2]))

	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _check(eye: Vector3, look: Vector3, label: String) -> void:
	_cam.look_at_from_position(eye, look, Vector3.UP)


	for i in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img:= get_viewport().get_texture().get_image()

	var bad:= _count_impossible(img)
	if bad > BUDGET:


		img.save_png("%s/FAIL_%s.png" % [OUT_DIR, label])
		_fails += 1
		print("  FAIL  %s: %d impossible pixels (budget %d) -- wrote FAIL_%s.png"
			% [label, bad, BUDGET, label])
	else:
		print("  ok    %s: %d impossible pixels" % [label, bad])


func _count_impossible(img: Image) -> int:
	var w:= img.get_width()
	var h:= img.get_height()
	var bad:= 0


	var y:= 0
	while y < h:
		var x:= 0
		while x < w:
			var c:= img.get_pixel(x, y)
			var r:= int(c.r * 255.0)
			var g:= int(c.g * 255.0)
			var b:= int(c.b * 255.0)
			if r > FLOOR and b > FLOOR and g < mini(r, b) - CHANNEL_MARGIN:
				bad += 1
			elif g > FLOOR and g > r + CHANNEL_MARGIN and g > b + CHANNEL_MARGIN:
				bad += 1
			x += 4
		y += 4
	return bad * 16
