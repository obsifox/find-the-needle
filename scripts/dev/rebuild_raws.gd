extends SceneTree
## Rebuild real raw asset files from the compiled copies:
##  - compiled/*.oggvorbisstr -> <stem>.ogg   (AudioStreamOggVorbis.data)
##  - compiled/*.mp3str       -> <stem>.mp3   (AudioStreamMP3.data)
##  - assets/ui/compiled/*.ctex (lossless)    -> assets/ui/<stem>.png
## Run: godot --headless -s scripts/dev/rebuild_raws.gd

func _init() -> void:
	var ogg := 0
	var mp3 := 0
	var png := 0
	for root: String in ["res://assets"]:
		_walk(root, ogg, mp3, png)
	print("[rebuild_raws] done")
	quit(0)

func _walk(dir_path: String, ogg: int, mp3: int, png: int) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_walk(full, ogg, mp3, png)
		else:
			if name.ends_with(".oggvorbisstr"):
				var stream := load(full) as AudioStreamOggVorbis
				if stream != null and stream.data.size() > 0:
					var out := full.replace("/compiled/", "/").replace(".oggvorbisstr", ".ogg")
					var f := FileAccess.open(out, FileAccess.WRITE)
					f.store_buffer(stream.data)
					f.close()
					ogg += 1
			elif name.ends_with(".mp3str"):
				var stream2 := load(full) as AudioStreamMP3
				if stream2 != null and stream2.data.size() > 0:
					var out2 := full.replace("/compiled/", "/").replace(".mp3str", ".mp3")
					var f2 := FileAccess.open(out2, FileAccess.WRITE)
					f2.store_buffer(stream2.data)
					f2.close()
					mp3 += 1
			elif name.ends_with(".ctex") and dir_path.ends_with("/compiled"):
				var tex := load(full) as CompressedTexture2D
				if tex != null:
					var img := tex.get_image()
					if img != null and not img.is_empty():
						var out3 := dir_path.replace("/compiled", "").path_join(name.replace(".ctex", ".png"))
						img.save_png(out3)
						png += 1
		name = dir.get_next()
	# counters travel by value; print locally
	if ogg + mp3 + png > 0:
		print("[rebuild_raws] %s: ogg=%d mp3=%d png=%d" % [dir_path, ogg, mp3, png])
