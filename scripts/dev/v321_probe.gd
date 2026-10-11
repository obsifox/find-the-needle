class_name DevV321Probe
extends Node

## v3.2.1 regression probe (world-side, headless-friendly):
##  1. MainMenu must build with NO "LEADERBOARD" / "OFFICIAL LINKS" UI.
##  2. OptionsPanel must still build all tabs, and on mobile the HUD page
##     must show the V40 "Custom design HUD" TOUCH section (disabled before
##     a game runs).
## Run:  godot --headless --path . -- --autostart --v321probe

var world: Node3D
var player: Node

var _fail: int = 0


func run() -> void:
	print("\n=== v3.2.1 menus ===")
	await get_tree().process_frame
	var mm:= MainMenu.new()
	world.add_child(mm)
	await get_tree().process_frame
	await get_tree().process_frame
	_scan(mm, "MainMenu")
	_sanity_menu(mm)
	Cfg.is_mobile = true
	var op:= OptionsPanel.new()
	mm.add_child(op)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_options(op)
	Cfg.is_mobile = false
	op.queue_free()
	mm.queue_free()
	print("=== v3.2.1 menus: %s ===\n" % ("FAIL" if _fail > 0 else "ok"))
	get_tree().quit(1 if _fail > 0 else 0)


func _scan(root: Node, tag: String) -> void:
	var stack: Array [Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			var t:= ""
			if n is Button:
				t = (n as Button).text
			elif n is Label:
				t = (n as Label).text
			if t.contains("LEADERBOARD") or t.contains("OFFICIAL LINKS"):
				_bad("%s still shows %s at %s" % [tag, t, n.get_path()])
		stack.append_array(n.get_children())


func _sanity_menu(mm: Control) -> void:
	# Make sure the menu actually built (so the absence checks mean something).
	var need:= PackedStringArray(["NEW GAME", "OPTIONS", "QUIT"])
	var stack: Array [Node] = [mm]
	while not stack.is_empty() and need.size() > 0:
		var n: Node = stack.pop_back()
		if n is Button:
			var t:= (n as Button).text
			if need.has(t):
				need.remove_at(need.find(t))
		stack.append_array(n.get_children())
	if need.size() > 0:
		_bad("main menu is missing entries: %s" % " / ".join(need))


func _check_options(op: Control) -> void:
	var pages: int = -1
	var p: Variant = op.get("_pages")
	if p is Array:
		pages = (p as Array).size()
	if pages < 6:
		_bad("OptionsPanel pages: %d" % pages)
	var editor_seen:= false
	var stack: Array [Node] = [op]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and (n as Button).text == tr("OPEN EDITOR"):
			editor_seen = true
			if not (n as Button).disabled:
				_bad("HUD editor button should be disabled before a game runs")
		stack.append_array(n.get_children())
	if not editor_seen:
		_bad("HUD TOUCH section missing the OPEN EDITOR row")


func _bad(what: String) -> void:
	_fail += 1
	print("  BAD: %s" % what)
