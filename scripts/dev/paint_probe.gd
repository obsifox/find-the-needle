class_name DevPaintProbe
extends Node


const SETTLE:= 8

const AT:= Vector3(-14.0, 0.0, 8.0)
const STAND_BACK:= 2.6

var world: Node3D
var player: Player

var _pass:= 0
var _fail:= 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		_pass += 1
		print("  [pass] %s" % what)
	else:
		_fail += 1
		print("  [FAIL] %s" % what)


func _near(got: float, want: float, tol: float, what: String) -> void:
	_ok(absf(got - want) <= tol, "%s (%.4f, wanted %.4f +/- %.3f)"
		% [what, got, want, tol])


func run() -> void:
	world.block_save = true
	print("--- paint board probe ---")
	_ok(Sketchbook.inert, "the sketchbook is inert, so nothing here reaches the player's drawings")
	for i in SETTLE:
		await get_tree().process_frame
	GameState.add_money(200000.0)
	for i in SETTLE:
		await get_tree().process_frame

	_case_catalogue()
	await _case_holding_it()
	await _case_geometry()
	await _case_ray()
	await _case_which_way_up()
	await _case_painting()
	await _case_erasing()
	await _case_book()
	await _case_fork()
	await _case_round_trip()
	await _case_rotation()
	await _case_taking_it_down()

	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _board() -> PaintBoard:
	var builds: BuildManager = player.build.builds
	for b in builds.paint_boards:
		return b
	var made:= builds.add_paint_board(AT, 0.0)
	return made


func _settle() -> void:
	for i in SETTLE:
		await get_tree().process_frame


func _case_catalogue() -> void:
	print("\n=== the card in the B menu ===")
	var e:= BuildCatalog.entries().get("paintboard", { }) as Dictionary
	_ok(not e.is_empty(), "there is a catalogue entry")
	_ok(e.get("mode", -1) == BuildTool.Mode.PAINT_BOARD, "it places a PAINT_BOARD")
	_ok(str(e.get("unlock", "")) == "paint_board", "it is sold by the paint_board node")
	_ok(TechTree.nodes().has("paint_board"), "...and that node is on the tree")


	_ok(CatalogPanel.BUILD_ICON_TILES.has("paintboard"),
		"the B menu has a tile for it")
	_ok(TechPanel.ICON_TILES.has("paint_board"), "the tech tree has a tile for it")


func _case_holding_it() -> void:
	print("\n=== with the board in your hands ===")


	Tech.grant("paint_board", 1)
	player.equip_build("paintboard")
	await _settle()
	_ok(player.current_tool == Player.Tool.BUILD, "equipping it takes the build tool out")


	var here:= player.global_position
	player.look_at_from_position(here, here + Vector3(2.0, -1.2, 2.0), Vector3.UP)
	await _settle()
	var st: Dictionary = player.build.status()
	_ok(not st.is_empty(), "the hologram reports a status at all")
	_ok(str(st.get("kind", "")) == "paintboard",
		"...and it reports as a paintboard rather than falling through to the conveyor")


	for key: String in ["ok", "reason", "cost", "reach", "placing"]:
		_ok(st.has(key), "the status carries '%s'" % key)
	_ok(not bool(st.get("placing", true)),
		"a board is never mid-drag, so it never reaches the length branch")
	_near(float(st.get("cost", 0.0)), Cfg.PAINT_BOARD_COST, 0.01,
		"it quotes the catalogue price")


	var hud: Hud = player.carry.hud if player.carry != null else null
	if hud != null:
		hud._update_build_readout()
		_ok(true, "the HUD builds its readout without throwing")
	else:
		_ok(false, "no HUD to read the line off")

	player.equip_build("hand")
	await _settle()


func _case_geometry() -> void:
	print("\n=== the drawing rectangle, off the model's own markers ===")
	var b:= _board()
	await _settle()


	_near(b._size.x, 2.0, 0.01, "the canvas is 2.00 m across")
	_near(b._size.y, 1.5, 0.01, "the canvas is 1.50 m tall")
	_near(b._tl.y, 2.32, 0.02, "its top edge is 2.32 m up")
	_ok(b._canvas != null, "the Canvas mesh is in the model")
	_ok(b._vp != null and b._surface != null, "the canvas viewport is built")


func _look_at_point(b: PaintBoard, target: Vector3) -> Array:
	var eye:= target + b.global_transform.basis.z * STAND_BACK
	return [eye, (target - eye).normalized()]


func _case_ray() -> void:
	print("\n=== where a ray lands on the picture ===")
	var b:= _board()
	var mid:= b.to_global(Vector3(b._tl.x + b._size.x * 0.5,
		b._tl.y - b._size.y * 0.5, b._plane_z))
	var shot:= _look_at_point(b, mid)
	var uv: Vector2 = b.hit_uv(shot [0], shot [1])
	_near(uv.x, 0.5, 0.01, "dead centre is u 0.5")
	_near(uv.y, 0.5, 0.01, "dead centre is v 0.5")


	for spec: Array in [
			[Vector2(0.0, 0.0), "top left"], [Vector2(1.0, 0.0), "top right"],
			[Vector2(0.0, 1.0), "bottom left"], [Vector2(1.0, 1.0), "bottom right"]]:
		var want: Vector2 = spec [0]


		var inset:= want.lerp(Vector2(0.5, 0.5), 0.01)
		var at:= b.to_global(Vector3(
			b._tl.x + b._size.x * inset.x,
			b._tl.y - b._size.y * inset.y, b._plane_z))
		var s:= _look_at_point(b, at)
		var got: Vector2 = b.hit_uv(s [0], s [1])
		_ok(got.distance_to(inset) < 0.02,
			"the %s corner maps to (%.2f, %.2f), got (%.2f, %.2f)"
				% [spec [1], inset.x, inset.y, got.x, got.y])


	var behind:= mid - b.global_transform.basis.z * STAND_BACK
	_ok(b.hit_uv(behind, (mid - behind).normalized()).x < 0.0,
		"a ray from behind the board misses")

	var off:= mid + b.global_transform.basis.x * 4.0
	var s2:= _look_at_point(b, mid)
	_ok(b.hit_uv(s2 [0], (off - s2 [0]).normalized()).x < 0.0,
		"a ray aimed past the frame misses")


	var was:= b.global_rotation.y
	b.global_rotation.y = PI * 0.5
	var mid2:= b.to_global(Vector3(b._tl.x + b._size.x * 0.5,
		b._tl.y - b._size.y * 0.5, b._plane_z))
	var s3:= _look_at_point(b, mid2)
	var uv2: Vector2 = b.hit_uv(s3 [0], s3 [1])
	_ok(uv2.distance_to(Vector2(0.5, 0.5)) < 0.02,
		"a board turned a quarter turn still reads centre as (0.5, 0.5)")
	b.global_rotation.y = was


func _case_which_way_up() -> void:
	print("\n=== which way up ===")
	var b:= _board()


	var high:= b.to_global(Vector3(b._tl.x + b._size.x * 0.5,
		b._tl.y - 0.15, b._plane_z))
	var s:= _look_at_point(b, high)
	var uv: Vector2 = b.hit_uv(s [0], s [1])
	_near(uv.y, 0.1, 0.03, "a point near the TOP of the board has a small v")
	await _settle()


func _case_painting() -> void:
	print("\n=== laying a stroke ===")
	var b:= _board()
	b.clear()
	b.tool = PaintBoard.Tool.PEN
	b.ink = PaintBoard.SWATCHES [3]
	b.width_step = 2
	_ok(b.strokes.is_empty(), "a cleared board has nothing on it")
	_ok(not b.drafting, "...and is not a draft")


	b._paint(Vector2(0.2, 0.2))
	_ok(b.drafting, "the first mark forks the board into a draft")
	b._paint(Vector2(0.4, 0.3))
	b._paint(Vector2(0.6, 0.5))
	_ok(b.strokes.is_empty(), "a stroke still being drawn is not committed yet")
	_ok(b.visible_strokes().size() == 1, "...but it is drawn on the board")
	b._release()
	_ok(b.strokes.size() == 1, "letting go commits it")
	var s: Dictionary = b.strokes [0]
	_ok((s ["p"] as PackedVector2Array).size() == 3, "it kept all three points")
	_ok((s ["c"] as Color).is_equal_approx(PaintBoard.SWATCHES [3]),
		"it kept the colour that was picked")


	b._paint(Vector2(0.8, 0.8))
	b._paint(Vector2(0.8 + PaintBoard.SAMPLE_MIN * 0.2, 0.8))
	_ok(b._live.size() == 1, "a point that has not moved far enough is dropped")
	b._release()


	b.tool = PaintBoard.Tool.RECT
	b._paint(Vector2(0.1, 0.1))
	b._paint(Vector2(0.5, 0.5))
	b._paint(Vector2(0.9, 0.7))
	b._release()
	var box: Dictionary = b.strokes [b.strokes.size() - 1]
	_ok((box ["p"] as PackedVector2Array).size() == 2,
		"a dragged box is two corners, not a trail")
	_ok((box ["p"] as PackedVector2Array) [1].is_equal_approx(Vector2(0.9, 0.7)),
		"...and the second corner is where the button came up")
	await _settle()


func _case_erasing() -> void:
	print("\n=== rubbing out ===")
	var b:= _board()
	b.clear()
	b.tool = PaintBoard.Tool.PEN
	b._paint(Vector2(0.25, 0.25))
	b._release()
	b._paint(Vector2(0.75, 0.75))
	b._release()
	_ok(b.strokes.size() == 2, "two strokes on the board")
	b.erase_at(Vector2(0.75, 0.75))
	_ok(b.strokes.size() == 1, "the rubber takes the one it is over")
	_ok((b.strokes [0] ["p"] as PackedVector2Array) [0].is_equal_approx(
		Vector2(0.25, 0.25)), "...and leaves the other alone")
	b.erase_at(Vector2(0.5, 0.5))
	_ok(b.strokes.size() == 1, "a rubber over empty board takes nothing")
	await _settle()


func _case_book() -> void:
	print("\n=== the gallery ===")
	var b:= _board()
	b.clear()
	_ok(not b.keep(), "an empty board cannot be kept")

	b._paint(Vector2(0.3, 0.3))
	b._paint(Vector2(0.7, 0.7))
	b._release()
	var before:= Sketchbook.count()
	_ok(b.keep("first"), "a drawing with something on it is kept")
	_ok(Sketchbook.count() == before + 1, "the book grew by one")
	_ok(not b.drafting, "keeping it ends the draft")
	_ok(b.showing == 0, "the board goes on showing what was just kept")
	_ok(str(Sketchbook.at(0).get("name", "")) == "first", "it kept the title")

	Sketchbook.forget(0)
	_ok(Sketchbook.count() == before, "forgetting takes it out again")
	await _settle()


func _case_fork() -> void:
	print("\n=== drawing on a kept picture ===")
	var b:= _board()
	b.clear()
	b._paint(Vector2(0.2, 0.2))
	b._paint(Vector2(0.8, 0.8))
	b._release()
	b.keep("original")
	var kept_points: int = (Sketchbook.at(0) ["strokes"] [0] ["p"] as PackedVector2Array).size()

	b.show_kept(0)
	_ok(not b.drafting, "showing a kept drawing is not a draft")

	b._paint(Vector2(0.5, 0.1))
	b._paint(Vector2(0.5, 0.9))
	b._release()
	_ok(b.drafting, "drawing on a shown picture forks it into a draft")
	_ok(b.showing == -1, "...and the board stops claiming to be showing it")
	_ok(b.strokes.size() == 2, "the draft has the old strokes and the new one")
	_ok((Sketchbook.at(0) ["strokes"] as Array).size() == 1,
		"THE KEPT DRAWING STILL HAS ONE STROKE")
	_ok((Sketchbook.at(0) ["strokes"] [0] ["p"] as PackedVector2Array).size()
		== kept_points, "...and that stroke is untouched")


	b.erase_at(Vector2(0.2, 0.2))
	_ok((Sketchbook.at(0) ["strokes"] as Array).size() == 1,
		"rubbing out on the draft does not rub out the kept copy")
	Sketchbook.forget(0)
	b.clear()
	await _settle()


func _case_round_trip() -> void:
	print("\n=== through a save ===")
	var b:= _board()
	b.clear()
	b._paint(Vector2(0.4, 0.4))
	b._paint(Vector2(0.6, 0.6))
	b._release()
	b.keep("kept for the round trip")
	b.rotate_secs = 60
	var d:= b.to_dict()
	_ok(str(d.get("type", "")) == "paint_board", "it saves as a paint_board")
	_ok(int(d.get("showing", -99)) == 0, "it saves which drawing is up")
	_ok(int(d.get("rotate_secs", -1)) == 60, "it saves the rotation")
	_ok(not d.has("strokes"),
		"THE PICTURE IS NOT IN THE SAVE: a drawing belongs to the player, not the yard")


	var builds: BuildManager = player.build.builds
	var again:= builds.add_paint_board(AT + Vector3(6.0, 0.0, 0.0), 0.0)
	await _settle()
	again.from_dict(d)
	_ok(again.showing == 0, "a reloaded board shows the drawing it was showing")
	_ok(again.rotate_secs == 60, "...at the rotation it was set to")
	_ok(again.strokes.size() == 1, "...with the picture on it")


	again.from_dict({ "showing": 0, "rotate_secs": 47 })
	_ok(again.rotate_secs == PaintBoard.ROTATE_DEFAULT,
		"a rotation that is not one of the choices falls back to the default")
	builds.demolish(again)
	Sketchbook.forget(0)
	await _settle()


func _case_rotation() -> void:
	print("\n=== swapping the picture ===")
	var b:= _board()
	b.clear()
	for i in 3:
		b._paint(Vector2(0.2 + 0.2 * float(i), 0.3))
		b._paint(Vector2(0.2 + 0.2 * float(i), 0.7))
		b._release()
		b.keep("picture %d" % i)
		b.clear()
	_ok(Sketchbook.count() == 3, "three drawings in the book")

	b.show_kept(0)
	b.rotate_secs = 60


	b._rotate(61.0)
	_ok(b.showing == 1, "the rotation moves on to the next drawing")
	b._rotate(61.0)
	_ok(b.showing == 2, "...and the next")
	b._rotate(61.0)
	_ok(b.showing == 0, "...and wraps round")


	b.rotate_secs = 0
	b._rotate(600.0)
	_ok(b.showing == 0, "OFF leaves the board alone")


	b.rotate_secs = 60
	b._paint(Vector2(0.5, 0.5))
	b._release()
	_ok(b.drafting, "the board is now holding a draft")
	b._rotate(600.0)
	_ok(b.drafting and b.showing == -1,
		"THE ROTATION LEAVES A DRAFT ALONE, however long it has been sitting")
	await _settle()


func _case_taking_it_down() -> void:
	print("\n=== taking one down ===")
	var builds: BuildManager = player.build.builds


	var look:= player.look_direction()
	var flat:= Vector3(look.x, 0.0, look.z).normalized()
	var at:= player.global_position + flat * 3.2
	at.y = player.global_position.y


	var board:= builds.add_paint_board(at,
		atan2(- flat.x, - flat.z))
	await _settle()

	var mid:= board.to_global(Vector3(0.0, 1.57, 0.0))
	var eye:= player.eye_position()
	var q:= PhysicsRayQueryParameters3D.create(eye, mid)
	q.collision_mask = Cfg.L_BUILD
	q.collide_with_areas = true


	var hit:= player.get_world_3d().direct_space_state.intersect_ray(q)
	_ok(not hit.is_empty(), "the dismantle ray hits something on the board")
	var found:= builds.owner_of(hit.get("collider") as Node)
	_ok(found == board,
		"OWNER_OF WALKS THE MODEL'S COLLIDER BACK UP TO THE BOARD")


	player.rotation.x = 0.0
	var d:= mid - player.eye_position()
	var flat_d:= Vector2(d.x, d.z).length()
	player.set_look(atan2(- d.x, - d.z), atan2(d.y, flat_d))
	await _settle()
	_ok(player.build.dismantle_target() == board,
		"THE DISMANTLE KEY'S OWN LOOKUP FINDS THE BOARD")
	_ok(builds.demolish_blocked_reason(board) == "",
		"nothing blocks taking a board down")


	player.capture_mouse(true)
	await _settle()
	player.build._begin_dismantle()
	_ok(player.build.dismantle_name() == BuildCatalog.display_name("paintboard"),
		"the hold names it on screen while it comes apart")
	_ok(player.build.dismantle_progress() >= 0.0,
		"...and the meter under the crosshair starts running")

	var before:= builds.paint_boards.size()
	var back:= builds.demolish(board)
	_near(back, Cfg.PAINT_BOARD_COST, 0.01, "it pays back what it cost")
	_ok(builds.paint_boards.size() == before - 1, "it leaves the yard's list")
	await _settle()
