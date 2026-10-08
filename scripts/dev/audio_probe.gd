extends SceneTree


func _init() -> void:
	await process_frame
	var au: Node = root.get_node_or_null("/root/Audio")
	if au == null:
		print("[audio] FAILED: no /root/Audio -- is the autoload registered?")
		quit(1)
		return

	var missing: Array [String] = []
	var libs: Array [Dictionary] = [au.SFX_LIB, au.UI_LIB]
	var played:= 0

	for lib in libs:
		for key: String in lib:
			for path: String in (lib [key] as Array):
				if not ResourceLoader.exists(path):
					missing.append("%s -> %s" % [key, path])


			au._last_play.erase(key)
			au.play_3d(key, Vector3.ZERO)
			au._last_play.erase(key)
			au.play(key)
			played += 1

	for path: String in au.MUSIC_TRACKS:
		if not ResourceLoader.exists(path):
			missing.append("music -> %s" % path)
	for path: String in [au.AMB_OUTSIDE, au.AMB_INSIDE]:
		if not ResourceLoader.exists(path):
			missing.append("ambience -> %s" % path)


	var before: int = au.loops_available()
	var handles: Array [int] = []
	for key: String in au.LOOP_LIB:
		var path: String = au.LOOP_LIB [key]
		if not ResourceLoader.exists(path):
			missing.append("loop -> %s" % path)
			continue
		var h: int = au.loop_acquire(key)
		if h < 0:
			missing.append("loop -> no free voice for '%s'" % key)
			continue
		handles.append(h)
	for h in handles:
		au.loop_release(h)
	var after: int = au.loops_available()

	await process_frame

	print("[audio] keys exercised:   %d" % played)
	print("[audio] loop voices:      %d before, %d after acquire/release" % [before, after])
	print("[audio] voices leaked:    %d" % (before - after))
	print("[audio] unresolved paths: %d" % missing.size())
	for m in missing:
		print("        MISSING %s" % m)
	var ok:= missing.is_empty() and before == after
	print("[audio] %s" % ("OK" if ok else "FAILED"))
	quit(0 if ok else 1)
