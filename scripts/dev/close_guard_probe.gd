class_name DevCloseGuardProbe
extends Node


var _fails:= 0
var _ear: Ear


class Ear extends Node:
	var heard:= 0
	var acted:= 0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			heard += 1
			if get_tree().auto_accept_quit:
				acted += 1


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   %s" % what)
	else:
		_fails += 1
		print("  FAIL %s" % what)


func _close() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func run() -> void:
	print("--- close guard probe ---")
	var tree:= get_tree()
	_ear = Ear.new()
	add_child(_ear)
	var before:= tree.auto_accept_quit
	_ok(not Loading.is_active(), "the title screen starts with no load running")


	tree.auto_accept_quit = false
	_close()
	_ok(not Loading._close_note.visible, "a close with no load running puts no note up")
	tree.auto_accept_quit = before
	_ear.heard = 0

	Loading.show_screen("FIND THE NEEDLE", "CLOSE GUARD")
	_ok(not tree.auto_accept_quit, "the screen going up stops a close quitting on its own")

	_close()
	_ok(Loading._close_note.visible and Loading._close_note.text != "",
		"the first close puts the note up")
	_ok(not Loading._tip.visible, "and the tip steps aside for it")
	_ok(_ear.heard == 1 and _ear.acted == 0,
		"and the save and the crash report hear a close they must not act on")


	OS.delay_msec(Loading.CLOSE_AGAIN_MS + 100)
	_close()
	_close()
	_close()
	await _frames(1)
	_ok(_ear.acted == 0 and not tree.auto_accept_quit,
		"clicks queued in one long frame count as the first close, not a second")


	Loading.hide_screen()
	_ok(tree.auto_accept_quit == before, "the screen coming down puts auto accept back")
	_ok(not Loading._close_note.visible, "and takes the note with it")


	Loading.show_screen("FIND THE NEEDLE", "CLOSE GUARD")
	_ok(not Loading._close_note.visible, "a new load opens with no note")
	var held_at:= Time.get_ticks_msec()
	_close()
	_ok(Loading._close_note.visible and _ear.acted == 0,
		"and holds its own first close back")


	await _frames(Loading.CLOSE_AGAIN_FRAMES + 1)
	_close()
	var soon:= Time.get_ticks_msec() - held_at < Loading.CLOSE_AGAIN_MS
	await _frames(1)
	if soon:
		_ok(_ear.acted == 0, "a close sooner than CLOSE_AGAIN_MS after the note is still held")
	else:
		print("  --   frames ran too slowly to try a close inside CLOSE_AGAIN_MS")


	OS.delay_msec(Loading.CLOSE_AGAIN_MS + 100)
	await _frames(Loading.CLOSE_AGAIN_FRAMES + 1)
	var heard_before:= _ear.heard
	_close()
	_ok(_ear.heard == heard_before + 1 and _ear.acted == 0,
		"the close being let through is not acted on twice in its own delivery")


	_finish.call_deferred(heard_before)


func _finish(heard_before: int) -> void:
	_ok(_ear.heard == heard_before + 2 and _ear.acted == 1,
		"a second close after the note is let through, and heard once as a quit")
	_ok(get_tree().auto_accept_quit, "with auto accept on, as a close with no guard")
	print("\n[probe] %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)
