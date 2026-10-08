class_name LanguageFlag
extends Control


var code:= "":
	set(value):
		code = value
		queue_redraw()


var lit:= 0.0:
	set(value):
		lit = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var r:= Rect2(Vector2.ZERO, size)


	draw_rect(Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.45))
	match code:
		"en":
			_union_jack(r)
		"de":
			_tricolour_h(r, [Color("000000"), Color("dd0000"), Color("ffce00")])
		"pl":


			_tricolour_h(r, [Color("f4f4f4"), Color("dc143c")])
		"fr":
			_tricolour_v(r, [Color("0055a4"), Color("f4f4f4"), Color("ef4135")])
		"es":
			_spain(r)
		"pt":
			_brazil(r)
		"cs":
			_czech(r)
		"ru":


			_tricolour_h(r, [Color("f4f4f4"), Color("0039a6"), Color("d52b1e")])
		"tr":
			_turkey(r)
		"zh":
			_five_stars(r)
		"ja":
			_hinomaru(r)
		"ko":
			_taegukgi(r)
		_:
			_unknown(r)
	_sheen(r)
	draw_rect(r, Color(1, 1, 1, 0.18 + 0.3 * lit), false, 1.0)


func _tricolour_h(r: Rect2, colours: Array) -> void:
	var band:= r.size.y / colours.size()
	for i: int in colours.size():
		draw_rect(Rect2(r.position.x, r.position.y + band * i, r.size.x, band + 1.0), colours [i])


func _tricolour_v(r: Rect2, colours: Array) -> void:
	var band:= r.size.x / colours.size()
	for i: int in colours.size():
		draw_rect(Rect2(r.position.x + band * i, r.position.y, band + 1.0, r.size.y), colours [i])


func _czech(r: Rect2) -> void:
	_tricolour_h(r, [Color("f4f4f4"), Color("d7141a")])
	draw_colored_polygon(PackedVector2Array([
		r.position,
		r.position + Vector2(r.size.x * 0.5, r.size.y * 0.5),
		r.position + Vector2(0, r.size.y),
	]), Color("11457e"))


func _five_stars(r: Rect2) -> void:
	var gold:= Color("ffde00")
	draw_rect(r, Color("de2910"))
	var sx:= r.size.x / 30.0
	var sy:= r.size.y / 20.0
	var big:= Vector2(5, 5)
	_star(r.position + Vector2(big.x * sx, big.y * sy), 3.0 * sy, - PI * 0.5, gold)
	for c: Vector2 in [Vector2(10, 2), Vector2(12, 4), Vector2(12, 7), Vector2(10, 9)]:


		_star(r.position + Vector2(c.x * sx, c.y * sy), 1.0 * sy, (big - c).angle(), gold)


func _turkey(r: Rect2) -> void:
	var red:= Color("e30a17")
	var white:= Color("f4f4f4")
	draw_rect(r, red)
	var g:= r.size.y
	var sx:= r.size.x / 1.5
	var mid:= r.position.y + g * 0.5
	var at:= func(x: float) -> Vector2:
		return Vector2(r.position.x + x * sx, mid)
	draw_circle(at.call(0.5), g * 0.25, white, true, -1.0, true)
	draw_circle(at.call(0.5625), g * 0.2, red, true, -1.0, true)

	var star_x:= 0.5625 - 0.2 + 1.0 / 3.0 + 0.125
	_star(at.call(star_x), g * 0.125, PI, white)


const BRAZIL_STARS:= [
	[-2.857, -0.629, 0.15], [-2.548, 0.843, 0.15], [-2.976, 1.157, 0.125],
	[-2.205, 0.629, 0.071], [-1.819, 1.19, 0.125], [-1.924, 1.538, 0.1],
	[1.086, -1.086, 0.15], [2.452, 1.229, 0.15], [2.938, 1.262, 0.1],
	[2.595, 1.538, 0.125], [1.752, 2.271, 0.125], [1.748, 2.624, 0.1],
	[2.1, 1.995, 0.1], [2.381, 1.819, 0.125], [1.738, 1.929, 0.1],
	[-1.333, 0.143, 0.125], [0.952, -0.176, 0.1], [0.0, 1.571, 0.15],
	[0.405, 0.876, 0.125], [0.0, 0.562, 0.125], [-0.352, 0.876, 0.1],
	[-0.176, 1.119, 0.071], [1.048, 2.357, 0.125], [1.348, 2.048, 0.1],
	[0.771, 1.962, 0.1], [-1.405, 1.857, 0.15], [0.0, 2.738, 0.05],
]


func _brazil(r: Rect2) -> void:
	var green:= Color("009b3a")
	var yellow:= Color("fedf00")
	var blue:= Color("002776")
	var white:= Color("f4f4f4")
	var sx:= r.size.x / 20.0
	var sy:= r.size.y / 14.0
	draw_rect(r, green)
	draw_colored_polygon(PackedVector2Array([
		r.position + Vector2(1.7 * sx, 7.0 * sy),
		r.position + Vector2(10.0 * sx, 1.7 * sy),
		r.position + Vector2(18.3 * sx, 7.0 * sy),
		r.position + Vector2(10.0 * sx, 12.3 * sy),
	]), yellow)

	var centre:= r.get_center()
	var to_px:= func(p: Vector2) -> Vector2:
		return centre + p * sy
	draw_circle(centre, 3.5 * sy, blue, true, -1.0, true)

	var disc:= PackedVector2Array()
	for i: int in 64:
		disc.append(Vector2.from_angle(TAU * i / 64.0) * 3.5)


	var hub:= Vector2(-2.0, 7.0)
	var band:= []
	for i: int in 41:
		band.append(hub + Vector2.from_angle(lerpf(-2.2, -0.4, i / 40.0)) * 8.5)
	for i: int in 41:
		band.append(hub + Vector2.from_angle(lerpf(-0.4, -2.2, i / 40.0)) * 8.0)
	_fill_clipped(disc, band, white, to_px)

	for s: Array in BRAZIL_STARS:
		draw_circle(to_px.call(Vector2(s [0], s [1])), maxf(float(s [2]) * 1.5 * sy, 0.6),
			white, true, -1.0, true)


func _hinomaru(r: Rect2) -> void:
	draw_rect(r, Color("f4f4f4"))
	draw_circle(r.get_center(), r.size.y * 0.3, Color("bc002d"), true, -1.0, true)


func _taegukgi(r: Rect2) -> void:
	var red:= Color("cd2e3a")
	var blue:= Color("0047a0")
	var black:= Color("000000")
	draw_rect(r, Color("f4f4f4"))
	var h:= r.size.y
	var sx:= r.size.x / 1.5
	var centre:= r.get_center()

	var fall:= Vector2(1.5, 1.0).normalized()
	var rise:= Vector2(1.5, -1.0).normalized()

	var radius:= h * 0.25
	var up:= Vector2(fall.y, - fall.x)
	draw_circle(centre, radius, blue, true, -1.0, true)
	var half:= PackedVector2Array()
	for i: int in 33:
		var a:= PI * i / 32.0
		half.append(centre + (fall * cos(a) + up * sin(a)) * radius)
	draw_colored_polygon(half, red)
	draw_circle(centre - fall * radius * 0.5, radius * 0.5, red, true, -1.0, true)
	draw_circle(centre + fall * radius * 0.5, radius * 0.5, blue, true, -1.0, true)


	var reach:= radius + h / 8.0 + h / 12.0
	var trigrams:= [
		[- fall, [1, 1, 1]],
		[fall, [0, 0, 0]],
		[rise, [0, 1, 0]],
		[- rise, [1, 0, 1]],
	]
	for t: Array in trigrams:
		var along: Vector2 = t [0]

		var at:= centre + Vector2(along.x * reach * sx / h, along.y * reach)
		var across:= Vector2(along.y, - along.x)
		var bars: Array = t [1]
		for i: int in 3:
			var mid: Vector2 = at + along * (i - 1) * (h / 24.0 + h / 48.0)
			if bars [i] == 1:
				_bar(mid, along, across, h / 8.0, h / 48.0, black)
			else:
				var shift:= h / 16.0 + h / 96.0
				_bar(mid - across * shift, along, across, h / 16.0 - h / 96.0, h / 48.0, black)
				_bar(mid + across * shift, along, across, h / 16.0 - h / 96.0, h / 48.0, black)


func _bar(mid: Vector2, along: Vector2, across: Vector2, half_len: float,
		half_thick: float, colour: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		mid - across * half_len - along * half_thick,
		mid + across * half_len - along * half_thick,
		mid + across * half_len + along * half_thick,
		mid - across * half_len + along * half_thick,
	]), colour)


func _spain(r: Rect2) -> void:
	var red:= Color("aa151b")
	var gold:= Color("f1bf00")
	var sx:= r.size.x / 30.0
	var sy:= r.size.y / 20.0
	draw_rect(r, red)
	draw_rect(Rect2(r.position.x, r.position.y + 5.0 * sy, r.size.x, 10.0 * sy + 1.0), gold)


	_arms(r.position + Vector2(10.0 * sx, 10.35 * sy), sy * 0.94, gold)


func _arms(centre: Vector2, u: float, gold: Color) -> void:
	var crimson:= Color("ad1519")
	var silver:= Color("f4f4f4")
	var purple:= Color("7a3b8f")
	var blue:= Color("0b3d91")
	var to_px:= func(p: Vector2) -> Vector2:
		return centre + p * u


	for side: float in [-1.0, 1.0]:
		var x:= side * 3.3
		draw_rect(Rect2(to_px.call(Vector2(x - 0.4, -2.6)), Vector2(0.8 * u, 6.1 * u)), gold)
		draw_rect(Rect2(to_px.call(Vector2(x - 0.65, -3.05)), Vector2(1.3 * u, 0.45 * u)), gold)
		draw_rect(Rect2(to_px.call(Vector2(x - 0.65, 3.3)), Vector2(1.3 * u, 0.5 * u)), gold)
		draw_rect(Rect2(to_px.call(Vector2(x - 0.8, 0.1)), Vector2(1.6 * u, 0.85 * u)), crimson)


	draw_rect(Rect2(to_px.call(Vector2(-1.5, -4.3)), Vector2(3.0 * u, 0.55 * u)), gold)
	draw_colored_polygon(PackedVector2Array([
		to_px.call(Vector2(-1.5, -4.3)), to_px.call(Vector2(-1.1, -5.1)),
		to_px.call(Vector2(-0.4, -4.45)), to_px.call(Vector2(0.0, -5.35)),
		to_px.call(Vector2(0.4, -4.45)), to_px.call(Vector2(1.1, -5.1)),
		to_px.call(Vector2(1.5, -4.3)),
	]), gold)


	var shield:= PackedVector2Array([
		Vector2(-2.4, -3.75), Vector2(2.4, -3.75), Vector2(2.4, 1.3),
		Vector2(1.45, 2.95), Vector2(0.0, 3.7), Vector2(-1.45, 2.95), Vector2(-2.4, 1.3),
	])
	_fill_clipped(shield, [
		Vector2(-2.4, -3.75), Vector2(0.0, -3.75), Vector2(0.0, -0.55), Vector2(-2.4, -0.55),
	], crimson, to_px)
	_fill_clipped(shield, [
		Vector2(0.0, -3.75), Vector2(2.4, -3.75), Vector2(2.4, -0.55), Vector2(0.0, -0.55),
	], silver, to_px)
	_fill_clipped(shield, [
		Vector2(-2.4, -0.55), Vector2(0.0, -0.55), Vector2(0.0, 3.7), Vector2(-2.4, 3.7),
	], gold, to_px)
	_fill_clipped(shield, [
		Vector2(0.0, -0.55), Vector2(2.4, -0.55), Vector2(2.4, 3.7), Vector2(0.0, 3.7),
	], crimson, to_px)


	draw_rect(Rect2(to_px.call(Vector2(-1.65, -2.75)), Vector2(1.0 * u, 1.0 * u)), gold)
	draw_rect(Rect2(to_px.call(Vector2(0.7, -2.75)), Vector2(1.0 * u, 1.0 * u)), purple)
	for i: int in 2:
		var x:= -1.95 + 0.9 * i
		_fill_clipped(shield, [
			Vector2(x, -0.55), Vector2(x + 0.4, -0.55), Vector2(x + 0.4, 3.7), Vector2(x, 3.7),
		], crimson, to_px)
	_fill_clipped(shield, [
		Vector2(1.0, -0.55), Vector2(1.4, -0.55), Vector2(1.4, 3.7), Vector2(1.0, 3.7),
	], gold, to_px)
	_fill_clipped(shield, [
		Vector2(0.1, 0.75), Vector2(2.4, 0.75), Vector2(2.4, 1.15), Vector2(0.1, 1.15),
	], gold, to_px)


	_fill_clipped(shield, [
		Vector2(-2.4, 1.9), Vector2(2.4, 1.9), Vector2(2.4, 3.7), Vector2(-2.4, 3.7),
	], silver, to_px)
	draw_circle(to_px.call(Vector2(0.0, 2.55)), 0.45 * u, crimson)
	draw_circle(to_px.call(Vector2(0.0, -0.55)), 0.95 * u, gold)
	draw_circle(to_px.call(Vector2(0.0, -0.55)), 0.72 * u, blue)
	for p: Vector2 in [Vector2(0.0, -1.0), Vector2(-0.34, -0.28), Vector2(0.34, -0.28)]:
		draw_circle(to_px.call(p), 0.18 * u, gold)


func _star(centre: Vector2, radius: float, aim: float, colour: Color) -> void:
	var inner:= radius * sin(deg_to_rad(18.0)) / sin(deg_to_rad(54.0))
	var pts:= PackedVector2Array()
	for i: int in 10:
		var a:= aim + TAU * i / 10.0
		pts.append(centre + Vector2.from_angle(a) * (radius if i % 2 == 0 else inner))
	draw_colored_polygon(pts, colour)


func _union_jack(r: Rect2) -> void:
	var blue:= Color("012169")
	var red:= Color("c8102e")
	var sx:= r.size.x / 60.0
	var sy:= r.size.y / 30.0
	var to_px:= func(p: Vector2) -> Vector2:
		return r.position + Vector2(p.x * sx, p.y * sy)
	var field:= PackedVector2Array([Vector2(0, 0), Vector2(60, 0), Vector2(60, 30), Vector2(0, 30)])

	draw_rect(r, blue)

	var centre:= Vector2(30, 15)
	var corners:= [Vector2(0, 0), Vector2(60, 0), Vector2(60, 30), Vector2(0, 30)]
	for corner: Vector2 in corners:
		var along:= (corner - centre).normalized()


		var side:= Vector2(along.y, - along.x)
		var reach:= along * 40.0
		_fill_clipped(field, [
			centre + side * 3.0, centre + side * 3.0 + reach,
			centre - side * 3.0 + reach, centre - side * 3.0,
		], Color.WHITE, to_px)
		_fill_clipped(field, [
			centre, centre + reach,
			centre + side * 2.0 + reach, centre + side * 2.0,
		], red, to_px)

	draw_rect(Rect2(to_px.call(Vector2(0, 10)), Vector2(60 * sx, 10 * sy)), Color.WHITE)
	draw_rect(Rect2(to_px.call(Vector2(25, 0)), Vector2(10 * sx, 30 * sy)), Color.WHITE)
	draw_rect(Rect2(to_px.call(Vector2(0, 12)), Vector2(60 * sx, 6 * sy)), red)
	draw_rect(Rect2(to_px.call(Vector2(27, 0)), Vector2(6 * sx, 30 * sy)), red)


func _fill_clipped(field: PackedVector2Array, band: Array, colour: Color, to_px: Callable) -> void:
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(PackedVector2Array(band), field):
		var pts:= PackedVector2Array()
		for p: Vector2 in piece:
			pts.append(to_px.call(p))
		draw_colored_polygon(pts, colour)


func _unknown(r: Rect2) -> void:
	draw_rect(r, Color(0.2, 0.23, 0.28))
	var font:= UiFont.bold()
	var fs:= int(r.size.y * 0.42)
	var text:= code.to_upper()
	var w:= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, r.position + Vector2((r.size.x - w) * 0.5, r.size.y * 0.5 + fs * 0.35),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.85, 0.88, 0.93))


func _sheen(r: Rect2) -> void:
	var top:= Color(1, 1, 1, 0.07 + 0.06 * lit)
	var mid:= Color(1, 1, 1, 0.0)
	var foot:= Color(0, 0, 0, 0.14)
	var tl:= r.position
	var br:= r.end
	var half:= tl.y + r.size.y * 0.5
	draw_polygon(PackedVector2Array([
		tl, Vector2(br.x, tl.y), Vector2(br.x, half), Vector2(tl.x, half),
	]), PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([
		Vector2(tl.x, half), Vector2(br.x, half), br, Vector2(tl.x, br.y),
	]), PackedColorArray([mid, mid, foot, foot]))
