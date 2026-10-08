class_name EnclosedConveyorCorner
extends ConveyorCorner


func _ready() -> void:
	record_only = true
	loose_mouth = -1.0
	loose_tail = -1.0
	super ()


const CASING_STEP:= 0.2


func _lay() -> void:
	super ()
	set_belt_drawn(false)
	BeltRunBatch.unwatch(run)
	_fit_casing()


func _fit_casing() -> void:
	if not is_inside_tree():
		return
	var turn:= float(_arc.get("turn", 0.0))
	var pieces:= clampi(int(ceil(turn / CASING_STEP)), 1, 16)
	var points:= _sample(pieces)
	var shapes:= EnclosedConveyor.casing_body(self, "ShellBend", pieces).get_children()
	var over:= EnclosedConveyor.CASING_HALF_WIDTH * tan(turn / pieces * 0.5)
	for i in pieces:
		var length:= points [i].distance_to(points [i + 1])
		EnclosedConveyor.fit_casing_box(shapes [i], points [i], points [i + 1],
			- over, length + over,
			- EnclosedConveyor.CASING_HALF_WIDTH, EnclosedConveyor.CASING_HALF_WIDTH,
			- EnclosedConveyor.CASING_BELOW, EnclosedConveyor.CASING_ABOVE)
