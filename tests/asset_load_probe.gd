# Godot headless asset load test - checks whether the GDRE-recovered
# compiled artifacts load directly and via the fake .import remaps.
extends SceneTree

func _init() -> void:
	var paths := [
		"res://assets/models/compiled/water_splitter.scn",        # via fake .import -> compiled .scn
		"res://assets/models/compiled/water_splitter.scn", # direct artifact
		"res://assets/blender/compiled/conveyorbelt.scn",        # via fake .import
		"res://assets/blender/compiled/conveyorbelt.scn", # direct artifact
		"res://assets/ui/compiled/icon_lock.ctex",                  # via fake .import -> compiled .ctex
		"res://assets/audio/sfx/dig/compiled/dig_01.oggvorbisstr",          # via fake .import -> compiled .oggvorbisstr
		"res://assets/audio/sfx/dig/compiled/dig_01.oggvorbisstr", # direct artifact
		"res://compiled/robotic_arm_game_ready.scn",               # root-level model
	]
	for p: String in paths:
		var res: Resource = load(p)
		print("TESTLOAD %s -> %s" % [p, "NULL" if res == null else res.get_class()])
	quit(0)
