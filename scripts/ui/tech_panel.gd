class_name TechPanel
extends Control


const ICON_SHEETS:= [
	preload("res://assets/ui/tech_icons_from_game.png"),
	preload("res://assets/ui/tech_icons_rendered_v1.png"),


	preload("res://assets/ui/tech_icons_badged.png"),


	preload("res://assets/ui/tech_icons_strips.png"),
]


const ICON_GRIDS:= [9, 3, 8, 8]

const BADGED_SHEET:= 2
const STRIP_SHEET:= 3


const ICON_TILES:= {
	"arm": [1, 3, 0],
	"arm_carry": [3, 3, 0],
	"arm_load": [8, 7, 0],
	"arm_reach": [2, 3, 0],
	"arm_speed": [1, 3, 0],
	"beam": [1, 1, 0],
	"belt": [5, 1, 0],
	"belt_speed": [6, 1, 0],
	"boots": [4, 3, 0],
	"borehole": [4, 5, 0],
	"briquette_press": [1, 6, 0],
	"briquette_quality": [1, 6, 0],
	"briquette_speed": [1, 6, 0],
	"broom": [3, 0, 0],
	"broom_speed": [3, 0, 0],
	"bucket": [5, 0, 0],
	"build_reach": [6, 3, 0],
	"building_plan": [0, 3, 0],
	"cabinet": [6, 2, 0],
	"cabinet_space": [7, 2, 0],
	"careful_steps": [3, 7, 0],
	"compact_splitter": [8, 6, 0],
	"compressor": [0, 2, 0],
	"drawer_space": [5, 2, 0],
	"drone": [4, 2, 0],
	"dump_hatch": [8, 4, 0],
	"easy_swing": [6, 7, 0],
	"eco_brick": [5, 4, 0],
	"electricity": [0, 5, 0],
	"enclosed_belt": [7, 6, 0],
	"feed_disc": [1, 7, 0],
	"foiled_bale": [6, 4, 0],
	"gas_plant": [0, 8, 0],
	"gas_plant_output": [0, 8, 0],
	"grab_reach": [2, 7, 0],
	"hands": [0, 0, 0],
	"hands_reach": [0, 0, 0],
	"hay_bale": [0, 1, 0],
	"hay_lift": [0, 6, 0],
	"hay_pulp": [4, 6, 0],
	"hay_stairs": [2, 2, 0],
	"hay_strand": [4, 4, 0],
	"hay_value": [0, 1, 0],
	"hay_wad": [3, 4, 0],
	"jetpack": [4, 3, 0],
	"joiner": [1, 8, 0],
	"jump_height": [4, 7, 0],
	"launcher": [0, 4, 0],
	"lighter": [3, 6, 0],
	"material_saving": [2, 1, 0],
	"metal_detector": [7, 3, 0],
	"needle": [7, 4, 0],
	"needle_radar": [2, 6, 0],
	"paint_board": [2, 5, 0],
	"paper_machine": [8, 5, 0],
	"paper_quality": [8, 5, 0],
	"paper_roll": [5, 6, 0],
	"paper_speed": [8, 5, 0],
	"pelletizer": [1, 2, 0],
	"piston_rake": [3, 2, 0],
	"pitchfork": [2, 0, 0],
	"platform": [3, 1, 0],
	"pour_speed": [6, 0, 0],
	"power_pole": [1, 5, 0],
	"pulp_quality": [6, 5, 0],
	"pulper": [6, 5, 0],
	"pulper_batch": [6, 5, 0],
	"pulper_speed": [6, 5, 0],
	"pump_output": [4, 5, 0],
	"rake_drive": [1, 1, 1],
	"rake_head": [0, 1, 1],
	"roof": [1, 4, 0],
	"scanner": [5, 2, 0],
	"second_wind": [7, 7, 0],
	"selling": [8, 2, 0],
	"silo": [2, 4, 0],
	"smart_splitter": [0, 7, 0],
	"soft_landing": [5, 3, 0],
	"spade": [1, 0, 0],
	"splitter": [7, 1, 0],
	"stairs": [4, 1, 0],
	"strong_back": [5, 7, 0],
	"t_splitter": [6, 6, 0],
	"toy_shovel": [4, 0, 0],
	"wall": [8, 1, 0],
	"water_main": [5, 5, 0],
	"wheel_speed": [8, 0, 0],
	"wheelbarrow": [7, 0, 0],
	"work_lamp": [7, 5, 0],
	"wrapper": [8, 3, 0],
	"yard_vac": [3, 5, 0],


	"arm+link": [6, 4, 2],
	"arm+mk2": [3, 5, 2],
	"arm+mk3": [4, 5, 2],
	"arm+order": [0, 5, 2],
	"arm+overflow": [7, 4, 2],
	"arm+speed": [1, 5, 2],
	"arm_carry+more": [2, 5, 2],
	"belt_loaded+speed": [2, 1, 2],
	"boots+grip": [1, 7, 2],
	"boots+speed": [0, 7, 2],
	"borehole+more": [6, 2, 2],
	"briquette_press+quality": [2, 4, 2],
	"briquette_press+speed": [1, 4, 2],
	"broom+range": [4, 0, 2],
	"bucket+level": [2, 7, 2],
	"bucket+more": [5, 0, 2],
	"bucket_pour+speed": [7, 0, 2],
	"compressor+more": [4, 1, 2],
	"compressor+quality": [6, 1, 2],
	"compressor+speed": [5, 1, 2],
	"drone+pickup": [5, 5, 2],
	"drone+range": [6, 5, 2],
	"drone+speed": [7, 5, 2],
	"gas_plant+power": [5, 2, 2],
	"generator+more": [4, 2, 2],
	"generator+power": [3, 2, 2],
	"gloves+more": [0, 0, 2],
	"metal_detector+range": [7, 6, 2],
	"needle_radar+mk2": [4, 6, 2],
	"needle_radar+mk3": [5, 6, 2],
	"needle_radar+mk4": [6, 6, 2],
	"paper_machine+quality": [0, 4, 2],
	"paper_machine+speed": [7, 3, 2],
	"pelletizer+more": [1, 3, 2],
	"pelletizer+quality": [3, 3, 2],
	"pelletizer+speed": [2, 3, 2],
	"piston_rake+wheels": [5, 4, 2],
	"pitchfork+more": [3, 0, 2],
	"power_pole+range": [7, 2, 2],
	"power_pole+span": [3, 7, 2],
	"power_pole+underground": [0, 3, 2],
	"pulper+more": [4, 3, 2],
	"pulper+quality": [6, 3, 2],
	"pulper+speed": [5, 3, 2],
	"rake_drive+speed": [4, 4, 2],
	"rake_head+more": [3, 4, 2],
	"scanner+block": [3, 6, 2],
	"scanner+mk2": [0, 6, 2],
	"scanner+more": [1, 6, 2],
	"scanner+speed": [2, 6, 2],
	"silo+more": [2, 2, 2],
	"silo+speed": [1, 2, 2],
	"spade+more": [2, 0, 2],
	"splitter+overflow": [3, 1, 2],
	"toy_shovel+more": [1, 0, 2],
	"wheelbarrow+more": [6, 0, 2],
	"wrapper+quality": [0, 2, 2],
	"wrapper+speed": [7, 1, 2],
	"yard_vac+more": [0, 1, 2],
	"yard_vac+speed": [1, 1, 2],


}


static var LOCK_ICON: Texture2D = load("res://assets/ui/compiled/icon_lock.ctex")

const CARD_ICON:= 52.0
const INSPECTOR_ICON:= 96.0


const CARD_W:= 232.0
const CARD_H:= 92.0


const CARD_TEXT_W:= CARD_W - 19.0 - CARD_ICON - 9.0
const CARD_TEXT_H:= CARD_H - 14.0


const CARD_META_PT:= 11
const CARD_NAME_PT:= 16
const CARD_RANK_PT:= 14
const CARD_PT_MIN:= 11
const STAGE_X:= 300.0
const STAGE_STEP:= 310.0
const LANE_Y:= 160.0


const LANE_GAP:= 104.0
const ROW_STEP:= 100.0

const STACK_GAP:= ROW_STEP - CARD_H


const GROUP_HEADER:= 24.0
const ROW_H:= 30.0
const ROW_ICON:= 26.0


const BAND_PAD:= 8.0
const BAND_ALPHA:= 0.055


const RAIL_W:= 196.0
const HEADER_H:= 26.0


const RAIL_CHIP_H:= 22.0
const WORLD_MARGIN:= 60.0


const GUTTER_W:= STAGE_STEP - CARD_W


const TRACK_IN:= 22.0
const TRACK_PITCH:= 9.0


const TRACK_MIN:= 4.0


const CHANNEL_PITCH:= 12.0
const CHANNEL_INSET:= 10.0


const PORT_SPREAD:= 14.0
const PORT_MAX:= CARD_H - 30.0

const PORT_STAGGER:= 5.0


const HOP:= 0.16


const SPARK_HOPS:= 8


const SPARK_TAIL:= 60.0
const SPARK_WIDTH:= 3.5

const IGNITE:= 0.34


const IGNITE_FLASH:= Color(1.55, 2.3, 1.5, 1.0)
const IGNITE_PUNCH:= 1.055


const HINT_PAD:= 2.0
const HINT_SWELL:= 3.0


const HINT_WIDTH:= 2.5
const HINT_GLOW_STEP:= 2.0
const HINT_GLOW_STEPS:= 4

const INSPECTOR_W:= 368.0


const MIN_LAYOUT:= Vector2(1280.0, 720.0)


const SEARCH_W:= 320.0


const PATH_FADE:= 0.5


const FOCUS_ZOOM:= 1.15


const ZOOM_MIN:= 0.22
const ZOOM_MAX:= 1.3
const ZOOM_STEP:= 1.12


const PAN_SLACK:= 0.55


const PAN_KEEP:= 0.34


const DRAG_SLOP:= 6.0

const COL_TITLE:= Color(1.0, 0.86, 0.34)


const COL_CURRENT:= Color(0.42, 1.0, 0.45)


const COL_SPARK:= Color(0.8, 1.0, 0.78)
const COL_TEXT:= Color(0.92, 0.94, 0.98)
const COL_DIM:= Color(0.72, 0.76, 0.84)
const COL_LOCKED:= Color(0.5, 0.53, 0.58)
const COL_AFFORD:= Color(0.72, 0.93, 0.56)
const COL_SHORT:= Color(0.93, 0.62, 0.52)
const COL_OWNED:= Color(0.86, 0.72, 0.34)


const COL_DEMO:= Color(0.56, 0.61, 0.7)


const COL_BOARD:= Color(0.014, 0.02, 0.018, 0.975)
const COL_BAND:= Color(1, 1, 1, 0.022)
const COL_GRID:= Color(1, 1, 1, 0.055)

var player: Player

var _viewport: Control
var _world: Control
var _wires: WireLayer
var _inspector: VBoxContainer


var _ins_frame: Control


var _press_at:= Vector2.INF


var _pan_from:= Vector2.INF


var _pan_button:= MOUSE_BUTTON_NONE


var _put_away:= false
var _wallet: Label
var _progress: Label
var _search: LineEdit


var _filter:= ""

var _hits: Dictionary = { }


var _shown: Dictionary = { }


var _saved_view: Dictionary = { }


var _pending_centre:= ""
var _cards: Dictionary = { }


var _parts: Dictionary = { }

var _pos: Dictionary = { }


var _lane_gaps: Array [Vector2] = []


var _lanes: Array = []


var _lane_counts: Dictionary = { }


var _group_pos: Dictionary = { }
var _group_h: Dictionary = { }


var _groups: Dictionary = { }
var _board: BoardLayer
var _rail: LaneRail
var _header: StageHeader


var _hovered:= ""
var _world_size:= Vector2(1960, 1520)

var _selected:= ""
var _open:= false
var _panning:= false


var _sparks: Array = []


var _ignites: Dictionary = { }


var _hint:= ""

var _hint_t:= 0.0


var _hint_flown:= ""


var _nudge:= ""
var _hint_layer: HintLayer

var _new_ready: Array [String] = []


var _user_moved:= false
var _zoom:= 0.7


var _ins_icon: TextureRect
var _ins_branch: Label
var _ins_name: Label
var _ins_rank: Label
var _ins_blurb: Label
var _ins_reward: Label
var _ins_value: Label
var _ins_cost: Label
var _ins_buy: Button
var _ins_show: Button
var _ins_reason: Label
var _ins_scroll: ScrollContainer


var _root: Control


var _layout_scale:= 1.0

var _card_box: StyleBoxFlat
var _card_ready: StyleBoxFlat
var _card_locked: StyleBoxFlat
var _card_owned: StyleBoxFlat

var _show_box: StyleBoxFlat
var _show_hover: StyleBoxFlat
var _card_selected: StyleBoxFlat
var _card_demo: StyleBoxFlat


class WireLayer:
	extends Control

	var segments: Array = []


	var sparks: Array = []

	func _draw() -> void:
		for seg: Dictionary in segments:


			if seg.get("hidden", false):
				continue
			draw_polyline(seg ["points"], seg ["colour"], seg ["width"], true)


		for spark: Dictionary in sparks:
			var head: float = spark ["head"]
			if head <= 0.0:
				continue
			var lit: PackedVector2Array = _slice(spark ["points"], spark ["cum"],
				head - TechPanel.SPARK_TAIL, head)
			if lit.size() < 2:
				continue


			draw_polyline(lit, Color(TechPanel.COL_CURRENT, 0.3),
				TechPanel.SPARK_WIDTH * 2.4, true)
			draw_polyline(lit, TechPanel.COL_SPARK, TechPanel.SPARK_WIDTH, true)


	static func measure(pts: PackedVector2Array) -> PackedFloat32Array:
		var cum:= PackedFloat32Array()
		cum.resize(pts.size())
		cum [0] = 0.0
		for i in range(1, pts.size()):
			cum [i] = cum [i - 1] + pts [i].distance_to(pts [i - 1])
		return cum


	static func _slice(pts: PackedVector2Array, cum: PackedFloat32Array,
			d0: float, d1: float) -> PackedVector2Array:
		var total: float = cum [cum.size() - 1]
		d0 = clampf(d0, 0.0, total)
		d1 = clampf(d1, 0.0, total)
		var out:= PackedVector2Array()
		if d1 - d0 <= 0.01:
			return out
		out.append(_at(pts, cum, d0))
		for i in pts.size():
			if cum [i] > d0 and cum [i] < d1:
				out.append(pts [i])
		out.append(_at(pts, cum, d1))
		return out


	static func _at(pts: PackedVector2Array, cum: PackedFloat32Array,
			d: float) -> Vector2:
		for i in range(1, pts.size()):
			if cum [i] >= d:
				var span: float = cum [i] - cum [i - 1]
				var f: float = 0.0 if span <= 0.0 else (d - cum [i - 1]) / span
				return pts [i - 1].lerp(pts [i], f)
		return pts [pts.size() - 1]


class HintLayer:
	extends Control

	var panel: TechPanel

	func _draw() -> void:
		if not panel._open:
			return
		_draw_new_ready()
		var id:= panel._ring_id()
		if id == "":
			return


		if panel._filter != "" and not panel._shown.has(id):
			return
		var zoom:= maxf(panel._zoom, 0.01)
		var breath:= 0.5 + 0.5 * sin(TAU * panel._hint_t / MissionCue.PULSE)
		var ring:= panel.card_rect(id).grow((HINT_PAD + HINT_SWELL * breath) / zoom)
		var step:= HINT_GLOW_STEP / zoom
		for i in HINT_GLOW_STEPS:
			var k:= float(i + 1)
			draw_rect(ring.grow(k * step), Color(COL_TITLE, (0.1 + 0.14 * breath) / k),
				false, step)
		draw_rect(ring, Color(COL_TITLE, 0.7 + 0.3 * breath), false,
			HINT_WIDTH / zoom)


	func _draw_new_ready() -> void:
		if panel._new_ready.is_empty():
			return
		var zoom:= maxf(panel._zoom, 0.01)
		var breath:= 0.5 + 0.5 * sin(TAU * panel._hint_t / MissionCue.PULSE)
		var ringed:= panel._ring_id()
		for id: String in panel._new_ready:
			if id == ringed:
				continue
			if not panel._pos.has(id) or not Tech.can_buy(id) ["ok"]:
				continue
			if panel._filter != "" and not panel._shown.has(id):
				continue
			var ring:= panel.card_rect(id).grow(HINT_PAD * 0.6 / zoom)
			draw_rect(ring, Color(ControlHints.COL_NEW, 0.25 + 0.45 * breath), false,
				HINT_WIDTH * 0.6 / zoom)


class BoardLayer:
	extends Control

	var panel: TechPanel

	func _draw() -> void:
		var stage_count:= int(roundf((panel._world_size.x - STAGE_X) / STAGE_STEP))
		for k in stage_count:
			if k % 2 == 0:
				continue
			var x0:= STAGE_X + float(k) * STAGE_STEP - GUTTER_W * 0.5
			draw_rect(Rect2(x0, 0.0, STAGE_STEP, size.y), COL_BAND)
		for lane: Dictionary in panel._lanes:
			var colour:= TechTree.branch_colour(str(lane ["branch"]))
			var top:= float(lane ["top"]) - BAND_PAD
			var h:= float(lane ["h"]) + BAND_PAD * 2.0
			var x0:= STAGE_X - GUTTER_W * 0.5
			draw_rect(Rect2(x0, top, size.x - x0, h), Color(colour, BAND_ALPHA))


			draw_rect(Rect2(x0, top, 3.0, h), Color(colour, 0.45))


class LaneRail:
	extends Control

	var panel: TechPanel

	var _hits: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		var mb:= event as InputEventMouseButton
		if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		for hit: Array in _hits:
			if (hit [0] as Rect2).has_point(mb.position):
				panel._show_lane(str(hit [1]))
				accept_event()
				return

	func _draw() -> void:
		_hits.clear()
		var bold:= UiFont.bold()
		var plain:= UiFont.regular()
		var view_h:= size.y
		var above: Array = []
		var below: Array = []
		var seen: Array = []
		for lane: Dictionary in panel._lanes:
			var y0: float = panel._world.position.y + float(lane ["top"]) * panel._zoom
			var y1: float = y0 + float(lane ["h"]) * panel._zoom
			if y1 < HEADER_H:
				above.append(lane)
			elif y0 > view_h:
				below.append(lane)
			else:
				seen.append([lane, y0, y1])


		var top_edge:= HEADER_H
		for lane: Dictionary in above:
			_chip(lane, top_edge, bold)
			top_edge += RAIL_CHIP_H
		var bottom_edge:= view_h
		for i in range(below.size() - 1, -1, -1):
			bottom_edge -= RAIL_CHIP_H
			_chip(below [i], bottom_edge, bold)
		var cursor:= top_edge
		for entry: Array in seen:
			var lane: Dictionary = entry [0]
			var branch:= str(lane ["branch"])
			var colour:= TechTree.branch_colour(branch)
			var y0:= maxf(float(entry [1]), HEADER_H)
			var y1:= minf(float(entry [2]), view_h)


			draw_rect(Rect2(RAIL_W - 5.0, y0, 3.0, maxf(y1 - y0, 0.0)), Color(colour, 0.7))
			var band_h:= y1 - y0
			var counts: Array = panel._lane_counts.get(branch, [0, 0, 0])
			var ready:= int(counts [2]) if counts.size() > 2 else 0
			var name:= Cfg.upper(TechTree.branch_name(branch))

			var block_h:= 50.0 if band_h >= 60.0 else (32.0 if band_h >= 38.0 else 16.0)
			var y:= clampf(y0 + 4.0, cursor, maxf(cursor, minf(y1 - block_h, bottom_edge - block_h)))
			if band_h < 38.0:
				y = clampf((y0 + y1) * 0.5 - block_h * 0.5, cursor, bottom_edge - block_h)
			var x:= 10.0
			draw_string(bold, Vector2(x, y + bold.get_ascent(14)), name,
				HORIZONTAL_ALIGNMENT_LEFT, RAIL_W - 24.0, 14, colour)
			if block_h >= 32.0:
				var tally:= tr("%d of %d bought") % [int(counts [0]), int(counts [1])]
				draw_string(plain, Vector2(x, y + 18.0 + plain.get_ascent(11)),
					tally, HORIZONTAL_ALIGNMENT_LEFT, RAIL_W - 24.0, 11, COL_DIM)
				if ready > 0:
					var tw:= plain.get_string_size(tally, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
					draw_string(bold, Vector2(x + tw, y + 18.0 + bold.get_ascent(11)),
						tr("  · %d ready") % ready, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_AFFORD)
			elif ready > 0:


				var nw:= bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				draw_string(bold, Vector2(x + nw + 8.0, y + bold.get_ascent(14)),
					tr("%d ready") % ready, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_AFFORD)
			if block_h >= 50.0:
				draw_string(plain, Vector2(x, y + 33.0 + plain.get_ascent(11)),
					TechTree.branch_subtitle(branch),
					HORIZONTAL_ALIGNMENT_LEFT, RAIL_W - 24.0, 11, COL_LOCKED)
			_hits.append([Rect2(0.0, y - 2.0, RAIL_W, block_h + 4.0), branch])
			cursor = y + block_h + 6.0


	func _chip(lane: Dictionary, y: float, font: Font) -> void:
		var branch:= str(lane ["branch"])
		var colour:= TechTree.branch_colour(branch)
		draw_rect(Rect2(0.0, y, RAIL_W, RAIL_CHIP_H), Color(colour, 0.07))
		draw_rect(Rect2(RAIL_W - 5.0, y + 3.0, 3.0, RAIL_CHIP_H - 6.0), Color(colour, 0.5))
		var baseline:= y + (RAIL_CHIP_H - 12.0) * 0.5 + font.get_ascent(12)
		draw_string(font, Vector2(10.0, baseline),
			Cfg.upper(TechTree.branch_name(branch)),
			HORIZONTAL_ALIGNMENT_LEFT, RAIL_W - 24.0, 12, Color(colour, 0.85))

		var counts: Array = panel._lane_counts.get(branch, [0, 0, 0])
		var ready:= int(counts [2]) if counts.size() > 2 else 0
		if ready > 0:
			var text:= tr("%d ready") % ready
			var tw:= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, Vector2(RAIL_W - 12.0 - tw, baseline), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_AFFORD)
		_hits.append([Rect2(0.0, y, RAIL_W, RAIL_CHIP_H), branch])


class StageHeader:
	extends Control

	var panel: TechPanel

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), COL_BOARD)
		draw_rect(Rect2(0.0, size.y - 1.0, size.x, 1.0), Color(1, 1, 1, 0.1))
		var font:= UiFont.bold()
		var zoom: float = panel._zoom
		var origin_x: float = panel._world.position.x
		var w:= CARD_W * zoom


		var room:= STAGE_STEP * zoom - 6.0
		for k in range(-1, TechTree.stage_count()):
			var wx:= 8.0 if k < 0 else STAGE_X + float(k) * STAGE_STEP
			var x:= origin_x + wx * zoom
			if x + w < 0.0 or x > size.x:
				continue
			var text:= tr("START") if k < 0 else Cfg.upper(TechTree.stage_name(k))


			var pt:= 11
			var tw:= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x
			if tw > room:
				pt = 9
				tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x
			if tw > room:
				continue
			draw_string(font, Vector2(x + (w - tw) * 0.5,
				(size.y - float(pt)) * 0.5 + font.get_ascent(pt) - 2.0),
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, pt, COL_DIM)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	set_process(false)
	_build()
	_apply_text_scale()
	resized.connect(_apply_text_scale)
	Cfg.hud_style_changed.connect(_apply_text_scale)
	GameState.money_changed.connect(_on_money_changed)
	Tech.tech_changed.connect(_on_tech_changed)


	GameState.contracts_changed.connect(_on_contracts_changed)
	Tech.tech_reset.connect(_repaint_all)


func is_open() -> bool:
	return _open


static func layout_scale_for(window: Vector2, asked: float) -> float:
	var room:= minf(window.x / MIN_LAYOUT.x, window.y / MIN_LAYOUT.y)
	return clampf(asked, 1.0, maxf(1.0, room))


func _apply_text_scale() -> void:
	if _root == null:
		return
	var s:= layout_scale_for(size, Cfg.tech_text_scale)
	_layout_scale = s
	_root.scale = Vector2.ONE * s
	_root.position = Vector2.ZERO
	_root.size = size / s


func set_open(on: bool) -> void:
	if on == _open:
		return
	_open = on
	visible = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if player != null:
		player.capture_mouse(not on)
	if on:


		if _selected != "" and not TechTree.has_id(_selected):
			_select(_first_interesting())
		elif _selected == "" and not _put_away:
			_select(_first_interesting())
		_on_money_changed(GameState.money)
		_repaint_all()
		_scan_new_ready()
		_settle_process()
		var ring:= _ring_id()
		if ring != "" and _hint_flown != ring:


			_hint_flown = ring
			_user_moved = true
			_select(ring)
			_zoom = clampf(FOCUS_ZOOM, ZOOM_MIN, ZOOM_MAX)
			_centre_on(ring)
			_hint_t = 0.0


		elif not _user_moved and _layout_scale > 1.0 and _selected != "":
			_user_moved = true
			_zoom = clampf(FOCUS_ZOOM, ZOOM_MIN, ZOOM_MAX)
			_centre_on(_selected)
		elif not _user_moved:
			_fit_board()
			_fit_board.call_deferred()
		else:


			_clamp_pan.call_deferred()

		_settle_process()
	else:


		_clear_filter()
		_clear_surge()


		_pending_centre = ""

		if _nudge != "" and _hint_flown == _nudge:
			_nudge = ""
	_panning = false
	_pan_from = Vector2.INF
	_pan_button = MOUSE_BUTTON_NONE
	Audio.play("ui_open" if on else "ui_close", -4.0)


func _first_interesting() -> String:
	for id: String in TechTree.ids():
		if Tech.can_buy(id) ["ok"]:
			return id
	return TechTree.ROOT


func set_hint(id: String) -> void:
	if id == _hint:
		return
	_hint = id
	_hint_t = 0.0
	_settle_process()
	if _hint_layer != null:
		_hint_layer.queue_redraw()


func _hint_live() -> bool:
	return _hint != "" and TechTree.has_id(_hint) and Tech.rank_of(_hint) == 0


func set_nudge(id: String) -> void:
	_nudge = id

	if _hint_flown == id:
		_hint_flown = ""
	_hint_t = 0.0
	_settle_process()
	if _hint_layer != null:
		_hint_layer.queue_redraw()


func _ring_id() -> String:
	if _hint_live():
		return _hint
	if _nudge != "" and TechTree.has_id(_nudge) and Tech.rank_of(_nudge) == 0:
		return _nudge
	return ""


func show_node(id: String) -> void:
	if not TechTree.has_id(id):
		return


	_user_moved = true
	set_open(true)
	_select(id)


	_zoom = clampf(FOCUS_ZOOM, ZOOM_MIN, ZOOM_MAX)


	_centre_on(id)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var key:= event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_F and key.ctrl_pressed:
		_focus_search()
		get_viewport().set_input_as_handled()
		return
	if _search != null and _search.has_focus():


		if event.is_action_pressed("free_mouse"):
			_search.text = ""
			_apply_filter("")
			_search.release_focus()
			get_viewport().set_input_as_handled()
		elif key != null and key.pressed and key.keycode == KEY_TAB:


			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("free_mouse") or event.is_action_pressed("tech_tree"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _build() -> void:


	_card_box = _make_card_box(Color(1, 1, 1, 0.16), Color(0.086, 0.102, 0.098, 0.97))
	_card_ready = _make_card_box(Color(0.55, 0.64, 0.48), Color(0.094, 0.118, 0.098, 0.97))
	_card_locked = _make_card_box(Color(1, 1, 1, 0.06), Color(0.047, 0.055, 0.051, 0.92))
	_card_owned = _make_card_box(Color(0.66, 0.53, 0.3), Color(0.118, 0.106, 0.078, 0.97))
	_card_selected = _make_card_box(COL_TITLE, Color(0.13, 0.13, 0.1, 0.99))
	_show_box = _make_pill(Color(0.66, 0.53, 0.3, 0.75), Color(0.2, 0.16, 0.07, 0.55))
	_show_hover = _make_pill(COL_TITLE, Color(0.3, 0.24, 0.09, 0.9))


	_card_demo = _make_card_box(Color(0.42, 0.46, 0.54, 0.45), Color(0.055, 0.062, 0.074, 0.94))

	var root:= PanelContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP


	_root = root
	var sb:= StyleBoxFlat.new()
	sb.bg_color = COL_BOARD


	sb.set_border_width_all(0)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	root.add_theme_stylebox_override("panel", sb)
	add_child(root)

	var page:= VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	root.add_child(page)


	var head:= HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	page.add_child(head)
	var title:= _label(tr("TECH TREE"), 26, COL_TITLE, true)
	head.add_child(title)
	_search = _build_search()
	head.add_child(_search)
	var gap:= Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(gap)
	_wallet = _label("", 26, COL_TEXT, true)
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_wallet)
	page.add_child(_hrule())


	var split:= HBoxContainer.new()
	split.add_theme_constant_override("separation", 12)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(split)


	_rail = LaneRail.new()
	_rail.panel = self
	_rail.custom_minimum_size = Vector2(RAIL_W, 0)
	_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_rail)

	_viewport = Control.new()
	_viewport.clip_contents = true
	_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.gui_input.connect(_on_viewport_input)
	_viewport.resized.connect(_on_viewport_resized)
	split.add_child(_viewport)

	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_world)

	_board = BoardLayer.new()
	_board.panel = self
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_board)


	_header = StageHeader.new()
	_header.panel = self
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_header.offset_bottom = HEADER_H
	_viewport.add_child(_header)

	_wires = WireLayer.new()
	_wires.mouse_filter = Control.MOUSE_FILTER_IGNORE


	_wires.sparks = _sparks
	_world.add_child(_wires)

	split.add_child(_build_inspector())

	page.add_child(_hrule())
	_progress = _label("", 13, COL_DIM)
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_progress)

	_layout_board()
	for id: String in TechTree.ids():
		if TechTree.is_tuning(id):
			continue
		var card:= _card(id)
		_cards [id] = card
		_world.add_child(card)
	var groups:= TechTree.tuning_groups()
	for machine: String in groups:
		var group:= _group_card(machine, groups [machine])
		_groups [machine] = group
		_world.add_child(group)


	_hint_layer = HintLayer.new()
	_hint_layer.panel = self
	_hint_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


	_hint_layer.size = _world_size
	_world.add_child(_hint_layer)
	_build_wires()
	_on_money_changed(GameState.money)


func _by_parent_height(a: String, b: String) -> bool:
	var ka:= _parent_height(a)
	var kb:= _parent_height(b)
	if is_equal_approx(ka, kb):


		return TechTree.ids().find(_item_anchor(a)) < TechTree.ids().find(_item_anchor(b))
	return ka < kb


func _parent_height(item: String) -> float:
	var total:= 0.0
	var n:= 0
	var needs: Array = [_group_machine(item)] if _is_group(item) else TechTree.requires(item)
	for need: String in needs:
		if need == TechTree.ROOT or not _pos.has(need):
			continue
		total += card_rect(need).get_center().y
		n += 1
	return INF if n == 0 else total / float(n)


func _group_key(machine: String) -> String:
	return "group:" + machine


func _is_group(item: String) -> bool:
	return item.begins_with("group:")


func _group_machine(item: String) -> String:
	return item.substr("group:".length())


func _item_anchor(item: String) -> String:
	return _group_machine(item) if _is_group(item) else item


func _item_h(item: String) -> float:
	if _is_group(item):
		var members: Array = TechTree.tuning_groups().get(_group_machine(item), [])
		return GROUP_HEADER + ROW_H * float(members.size())
	return CARD_H


func _column_h(items: Array) -> float:
	var h:= 0.0
	for item: String in items:
		h += _item_h(item)
	return h + STACK_GAP * float(maxi(items.size() - 1, 0))


func _place(item: String, at: Vector2) -> void:
	if not _is_group(item):
		_pos [item] = at
		return
	var machine:= _group_machine(item)
	var members: Array = TechTree.tuning_groups().get(machine, [])
	_group_pos [machine] = at
	_group_h [machine] = _item_h(item)
	for i in members.size():
		_pos [members [i]] = at + Vector2(0.0, GROUP_HEADER + ROW_H * float(i))


func _file(by_stage: Dictionary, stage: int, item: String) -> void:
	if not by_stage.has(stage):
		by_stage [stage] = []
	(by_stage [stage] as Array).append(item)


func card_rect(id: String) -> Rect2:
	var h:= ROW_H if TechTree.is_tuning(id) else CARD_H
	return Rect2(_pos.get(id, Vector2.ZERO), Vector2(CARD_W, h))


func _layout_board() -> void:
	_pos.clear()
	_group_pos.clear()
	_group_h.clear()
	_lanes.clear()
	var lane_top: Dictionary = { }
	var lane_h: Dictionary = { }
	var by_branch: Dictionary = { }


	var stage_count:= 0
	var groups:= TechTree.tuning_groups()

	for branch_index in TechTree.BRANCHES.size():
		var branch:= str(TechTree.BRANCHES [branch_index] ["id"])
		var by_stage: Dictionary = { }
		for id: String in TechTree.ids_in(branch):
			if id == TechTree.ROOT or TechTree.is_tuning(id):
				continue
			_file(by_stage, TechTree.stage_of(id), id)


			if groups.has(id):
				_file(by_stage, TechTree.stage_of(id) + 1, _group_key(id))
		var tallest:= CARD_H
		for stage: int in by_stage:
			tallest = maxf(tallest, _column_h(by_stage [stage]))
			stage_count = maxi(stage_count, stage + 1)
		by_branch [branch] = by_stage
		lane_h [branch] = tallest


	_lane_gaps.clear()
	_lane_gaps.append(Vector2(0.0, LANE_Y))
	var y_cursor:= LANE_Y
	for branch_index in TechTree.BRANCHES.size():
		var branch:= str(TechTree.BRANCHES [branch_index] ["id"])
		lane_top [branch] = y_cursor
		_lanes.append({ "branch": branch, "top": y_cursor, "h": float(lane_h [branch]) })
		y_cursor += float(lane_h [branch])
		_lane_gaps.append(Vector2(y_cursor, y_cursor + LANE_GAP))
		y_cursor += LANE_GAP


	for stage in stage_count:
		for branch_index in TechTree.BRANCHES.size():
			var branch:= str(TechTree.BRANCHES [branch_index] ["id"])
			var by_stage: Dictionary = by_branch [branch]
			if not by_stage.has(stage):
				continue
			var list: Array = by_stage [stage]
			list.sort_custom(_by_parent_height)

			var y:= float(lane_top [branch]) + (float(lane_h [branch]) - _column_h(list)) * 0.5
			for item: String in list:
				_place(item, Vector2(STAGE_X + float(stage) * STAGE_STEP, y))
				y += _item_h(item) + STACK_GAP

	var lowest:= 0.0
	var rightmost:= 0.0
	for id: String in _pos:
		var r:= card_rect(id)
		lowest = maxf(lowest, r.end.y)
		rightmost = maxf(rightmost, r.end.x)


	_pos [TechTree.ROOT] = Vector2(8.0, (LANE_Y + lowest) * 0.5 - CARD_H * 0.5)

	_world_size = Vector2(rightmost + WORLD_MARGIN, lowest + WORLD_MARGIN)
	_world.custom_minimum_size = _world_size
	_world.size = _world_size
	_wires.size = _world_size
	_board.size = _world_size
	_board.queue_redraw()


func _build_wires() -> void:
	var wires: Array = []
	for id: String in TechTree.ids():
		if not _pos.has(id):
			continue
		for need: String in TechTree.requires(id):
			if not _pos.has(need):
				continue
			wires.append({ "from": need, "to": id })
	_assign_ports(wires)
	_assign_channels(wires)
	_assign_tracks(wires)
	for w: Dictionary in wires:
		w ["points"] = _route(w)
		w ["colour"] = Color(1, 1, 1, 0.1)
		w ["width"] = 2.0
	_wires.segments = wires
	_wires.queue_redraw()


func _assign_ports(wires: Array) -> void:
	var out_of: Dictionary = { }
	var in_to: Dictionary = { }
	for w: Dictionary in wires:
		var f:= str(w ["from"])
		var t:= str(w ["to"])
		if not out_of.has(f):
			out_of [f] = []
		(out_of [f] as Array).append(w)
		if not in_to.has(t):
			in_to [t] = []
		(in_to [t] as Array).append(w)
	for id: String in out_of:
		var leaving: Array = out_of [id]
		leaving.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _card_y(str(a ["to"])) < _card_y(str(b ["to"])))
		_spread(leaving, "y0", _card_mid_y(id) + _port_stagger(id), _port_span(id))
	for id: String in in_to:
		var arriving: Array = in_to [id]
		arriving.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _card_y(str(a ["from"])) < _card_y(str(b ["from"])))
		_spread(arriving, "y1", _card_mid_y(id) + _port_stagger(id), _port_span(id))


func _card_y(id: String) -> float:
	return float((_pos [id] as Vector2).y)


func _card_mid_y(id: String) -> float:
	return card_rect(id).get_center().y


func _port_span(id: String) -> float:
	return minf(PORT_MAX, card_rect(id).size.y - 20.0)


func _port_stagger(id: String) -> float:
	var column:= int(roundf((float((_pos [id] as Vector2).x) - STAGE_X) / STAGE_STEP))
	return 0.0 if posmod(column, 2) == 0 else PORT_STAGGER


func _spread(list: Array, key: String, mid: float, limit: float = PORT_MAX) -> void:
	var n:= list.size()
	var span: float = minf(limit, float(n - 1) * PORT_SPREAD)
	var step: float = 0.0 if n < 2 else span / float(n - 1)
	for i in n:
		(list [i] as Dictionary) [key] = mid + (float(i) - float(n - 1) * 0.5) * step


func _assign_channels(wires: Array) -> void:
	var used: Dictionary = { }
	var deepest: Dictionary = { }
	for w: Dictionary in wires:
		var from: Vector2 = _pos [str(w ["from"])]
		var to: Vector2 = _pos [str(w ["to"])]
		if to.x - (from.x + CARD_W) <= GUTTER_W + 1.0:
			continue
		var band:= _nearest_band((float(w ["y0"]) + float(w ["y1"])) * 0.5)
		if band < 0:
			continue
		var x0: float = from.x + CARD_W
		var x1: float = to.x
		if not used.has(band):
			used [band] = []
		var taken: Array = used [band]
		var slot:= 0
		var settled:= false
		while not settled:
			settled = true
			for held: Array in taken:
				if int(held [2]) == slot and float(held [0]) < x1 and x0 < float(held [1]):
					settled = false
					break
			if not settled:
				slot += 1
		taken.append([x0, x1, slot])
		w ["band"] = band
		w ["slot"] = slot
		deepest [band] = maxi(int(deepest.get(band, 0)), slot)


	for w: Dictionary in wires:
		if not w.has("band"):
			continue
		var gap: Vector2 = _lane_gaps [int(w ["band"])]
		var room: float = maxf(gap.y - gap.x - CHANNEL_INSET * 2.0, 0.0)
		var n:= int(deepest [w ["band"]]) + 1
		var pitch: float = CHANNEL_PITCH
		if n > 1:
			pitch = minf(CHANNEL_PITCH, room / float(n - 1))
		w ["channel"] = gap.x + CHANNEL_INSET + float(int(w ["slot"])) * pitch


func _nearest_band(y: float) -> int:
	var best:= -1
	var best_d:= INF
	for i in _lane_gaps.size():
		var gap: Vector2 = _lane_gaps [i]
		var d: float = absf((gap.x + gap.y) * 0.5 - y)
		if d < best_d:
			best_d = d
			best = i
	return best


func _assign_tracks(wires: Array) -> void:
	var runs: Dictionary = { }
	for w: Dictionary in wires:
		var from: Vector2 = _pos [str(w ["from"])]
		var to: Vector2 = _pos [str(w ["to"])]
		if w.has("channel"):


			var ch: float = w ["channel"]
			_add_run(runs, from.x + CARD_W + GUTTER_W, float(w ["y0"]), ch, w, "track_out")
			_add_run(runs, to.x, ch, float(w ["y1"]), w, "track_in")
		else:
			_add_run(runs, to.x, float(w ["y0"]), float(w ["y1"]), w, "track_in")
	for gx: float in runs:
		var list: Array = runs [gx]
		list.sort_custom(func(a: Array, b: Array) -> bool: return float(a [0]) < float(b [0]))
		var tracks: Array = []
		for run: Array in list:
			var slot:= -1
			for i in tracks.size():
				var busy:= false
				for held: Vector2 in tracks [i]:
					if float(run [0]) < held.y and held.x < float(run [1]):
						busy = true
						break
				if not busy:
					slot = i
					break
			if slot < 0:
				tracks.append([])
				slot = tracks.size() - 1
			(tracks [slot] as Array).append(Vector2(float(run [0]), float(run [1])))
			run [4] = slot
		var room: float = maxf(gx - TRACK_IN - _gutter_wall(gx) - 4.0, 0.0)
		var n:= tracks.size()
		var pitch: float = TRACK_PITCH
		if n > 1:
			pitch = maxf(minf(TRACK_PITCH, room / float(n - 1)), TRACK_MIN)
		for run: Array in list:
			(run [2] as Dictionary) [str(run [3])] = gx - TRACK_IN - float(int(run [4])) * pitch


func _add_run(runs: Dictionary, gx: float, y0: float, y1: float,
		w: Dictionary, key: String) -> void:
	if not runs.has(gx):
		runs [gx] = []
	(runs [gx] as Array).append([minf(y0, y1), maxf(y0, y1), w, key, 0])


func _gutter_wall(gx: float) -> float:
	var wall:= 0.0
	for id: String in _pos:
		var right: float = float((_pos [id] as Vector2).x) + CARD_W
		if right <= gx + 1.0:
			wall = maxf(wall, right)
	return wall


func _route(w: Dictionary) -> PackedVector2Array:
	var from: Vector2 = _pos [str(w ["from"])]
	var to: Vector2 = _pos [str(w ["to"])]
	var sx: float = from.x + CARD_W
	var sy: float = w ["y0"]
	var ex: float = to.x
	var ey: float = w ["y1"]
	var into: float = w ["track_in"]
	if not w.has("channel"):
		return PackedVector2Array([
			Vector2(sx, sy), Vector2(into, sy), Vector2(into, ey), Vector2(ex, ey)])
	var out: float = w ["track_out"]
	var ch: float = w ["channel"]
	return PackedVector2Array([
		Vector2(sx, sy), Vector2(out, sy), Vector2(out, ch),
		Vector2(into, ch), Vector2(into, ey), Vector2(ex, ey)])


func _build_inspector() -> Control:
	var frame:= PanelContainer.new()
	frame.custom_minimum_size = Vector2(INSPECTOR_W, 0)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.094, 0.09, 0.98)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	frame.add_theme_stylebox_override("panel", sb)

	_inspector = VBoxContainer.new()
	_inspector.add_theme_constant_override("separation", 7)
	_ins_frame = frame
	frame.add_child(_inspector)

	var title_row:= HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	_inspector.add_child(title_row)
	_ins_icon = TextureRect.new()
	_ins_icon.custom_minimum_size = Vector2(INSPECTOR_ICON, INSPECTOR_ICON)
	_ins_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ins_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ins_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_ins_icon)

	var title_text:= VBoxContainer.new()
	title_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_text.add_theme_constant_override("separation", 3)
	title_row.add_child(title_text)
	_ins_branch = _label("", 12, COL_TITLE, true)
	title_text.add_child(_ins_branch)
	_ins_name = _label("", 24, COL_TEXT, true)
	_ins_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_text.add_child(_ins_name)
	_ins_rank = _label("", 14, COL_DIM)
	_inspector.add_child(_ins_rank)
	_inspector.add_child(_hrule())


	_ins_scroll = ScrollContainer.new()
	_ins_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ins_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspector.add_child(_ins_scroll)
	var body:= VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 7)
	_ins_scroll.add_child(body)

	_ins_blurb = _label("", 15, COL_TEXT)
	_ins_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_ins_blurb)

	_ins_value = _label("", 15, COL_OWNED, true)
	_ins_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_ins_value)

	_ins_reward = _label("", 13, COL_DIM)
	_ins_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_ins_reward)

	_ins_cost = _label("", 22, COL_TITLE, true)
	_ins_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inspector.add_child(_ins_cost)


	var action_row:= HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	_inspector.add_child(action_row)

	_ins_buy = Button.new()
	_ins_buy.text = tr("BUY")
	_ins_buy.focus_mode = Control.FOCUS_NONE
	_ins_buy.custom_minimum_size = Vector2(0, 48)
	_ins_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ins_buy.add_theme_font_override("font", UiFont.bold())
	_ins_buy.add_theme_font_size_override("font_size", 18)
	_ins_buy.pressed.connect(_buy_selected)
	action_row.add_child(_ins_buy)


	_ins_show = Button.new()
	_ins_show.text = tr("SHOW")
	_ins_show.focus_mode = Control.FOCUS_NONE
	_ins_show.custom_minimum_size = Vector2(96, 48)
	_ins_show.add_theme_font_override("font", UiFont.bold())
	_ins_show.add_theme_font_size_override("font_size", 18)
	_ins_show.tooltip_text = tr("Open this in the build catalogue")
	_ins_show.visible = false
	_ins_show.pressed.connect(_show_selected_build)
	action_row.add_child(_ins_show)

	_ins_reason = _label("", 13, COL_SHORT)
	_ins_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ins_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ins_reason.custom_minimum_size = Vector2(0, 34)
	_inspector.add_child(_ins_reason)
	return frame


func _make_pill(border: Color, bg: Color) -> StyleBoxFlat:
	var b:= StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(0)
	b.content_margin_left = 6.0
	b.content_margin_right = 6.0
	b.content_margin_top = 0.0
	b.content_margin_bottom = 0.0
	return b


func _make_card_box(border: Color, bg: Color) -> StyleBoxFlat:
	var b:= StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.set_border_width(SIDE_LEFT, 4)
	b.set_corner_radius_all(0)
	b.content_margin_left = 10.0
	b.content_margin_right = 9.0
	b.content_margin_top = 7.0
	b.content_margin_bottom = 7.0
	return b


func _card(id: String) -> PanelContainer:
	var card:= PanelContainer.new()
	card.name = id


	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.position = _pos.get(id, Vector2.ZERO)
	card.size = Vector2(CARD_W, CARD_H)
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)


	card.pivot_offset = Vector2(CARD_W, CARD_H) * 0.5
	card.add_theme_stylebox_override("panel", _card_box)
	card.gui_input.connect(_on_card_input.bind(id))
	card.mouse_entered.connect(_on_card_hover.bind(id))
	card.mouse_exited.connect(_on_card_hover.bind(""))


	var row:= HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	card.add_child(row)
	var icon:= _icon(id, CARD_ICON)
	row.add_child(icon)

	var box:= VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)
	row.add_child(box)

	var meta:= _label(Cfg.upper(TechTree.branch_name(TechTree.branch_of(id))), CARD_META_PT,
		TechTree.branch_colour(TechTree.branch_of(id)), true)
	box.add_child(meta)

	var name_label:= _label(TechTree.display_name(id), CARD_NAME_PT, COL_TEXT, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(name_label)

	var foot:= HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(foot)
	var cost:= _label("", 15, COL_TITLE, true)
	cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(cost)


	var show_btn: Button = null
	if not BuildCatalog.builds_for(id).is_empty():
		show_btn = Button.new()
		show_btn.text = tr("SHOW")
		show_btn.visible = false
		show_btn.focus_mode = Control.FOCUS_NONE
		show_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER


		show_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		show_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		show_btn.add_theme_font_override("font", UiFont.bold())
		show_btn.add_theme_font_size_override("font_size", 13)
		show_btn.add_theme_color_override("font_color", COL_OWNED)
		show_btn.add_theme_color_override("font_hover_color", COL_TITLE)
		show_btn.add_theme_color_override("font_pressed_color", COL_TITLE)
		show_btn.add_theme_stylebox_override("normal", _show_box)
		show_btn.add_theme_stylebox_override("hover", _show_hover)
		show_btn.add_theme_stylebox_override("pressed", _show_hover)
		show_btn.tooltip_text = tr("Open this in the build catalogue")
		show_btn.pressed.connect(_show_build.bind(id))
		foot.add_child(show_btn)


	var gate_btn: Button = null
	if DeliveryBook.gate_for(id) >= 0:
		gate_btn = Button.new()
		gate_btn.text = tr("CONTRACT")
		gate_btn.visible = false
		gate_btn.focus_mode = Control.FOCUS_NONE
		gate_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		gate_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		gate_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gate_btn.add_theme_font_override("font", UiFont.bold())
		gate_btn.add_theme_font_size_override("font_size", 13)
		gate_btn.add_theme_color_override("font_color", COL_SHORT)
		gate_btn.add_theme_color_override("font_hover_color", COL_TITLE)
		gate_btn.add_theme_color_override("font_pressed_color", COL_TITLE)
		gate_btn.add_theme_stylebox_override("normal", _show_box)
		gate_btn.add_theme_stylebox_override("hover", _show_hover)
		gate_btn.add_theme_stylebox_override("pressed", _show_hover)
		gate_btn.tooltip_text = tr("Why this one cannot be bought yet")
		gate_btn.pressed.connect(_select.bind(id))
		foot.add_child(gate_btn)

	var rank:= _label("", CARD_RANK_PT, COL_OWNED, true)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(rank)
	_parts [id] = { "meta": meta, "name": name_label, "cost": cost, "rank": rank,
		"icon": icon, "show": show_btn, "gate": gate_btn, "compact": false }
	return card


func _group_card(machine: String, members: Array) -> PanelContainer:
	var card:= PanelContainer.new()
	card.name = "group_" + machine
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = _group_pos.get(machine, Vector2.ZERO)
	var h: float = _group_h.get(machine, GROUP_HEADER)
	card.size = Vector2(CARD_W, h)
	card.custom_minimum_size = Vector2(CARD_W, h)
	var colour:= TechTree.branch_colour(TechTree.branch_of(machine))
	var frame:= StyleBoxFlat.new()
	frame.bg_color = Color(0.04, 0.048, 0.046, 0.96)
	frame.border_color = Color(colour, 0.32)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(0)


	frame.content_margin_left = 0.0
	frame.content_margin_right = 0.0
	frame.content_margin_top = 0.0
	frame.content_margin_bottom = 0.0
	card.add_theme_stylebox_override("panel", frame)

	var column:= VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	card.add_child(column)

	var head:= MarginContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.custom_minimum_size = Vector2(CARD_W, GROUP_HEADER)
	head.add_theme_constant_override("margin_left", 10)
	head.add_theme_constant_override("margin_top", 5)
	column.add_child(head)
	head.add_child(_label(Cfg.upper(TechTree.tuning_title(machine)), 11, colour, true))

	for id: String in members:
		var row:= _row(id)
		_cards [id] = row
		column.add_child(row)
	return card


func _row(id: String) -> PanelContainer:
	var row:= PanelContainer.new()
	row.name = id

	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.custom_minimum_size = Vector2(CARD_W, ROW_H)
	row.pivot_offset = Vector2(CARD_W, ROW_H) * 0.5
	row.add_theme_stylebox_override("panel", _card_box)
	row.gui_input.connect(_on_card_input.bind(id))
	row.mouse_entered.connect(_on_card_hover.bind(id))
	row.mouse_exited.connect(_on_card_hover.bind(""))

	var line:= HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)


	var icon:= _icon(id, ROW_ICON)
	icon.texture = strip_icon_for(TechTree.icon_of(id))
	icon.visible = icon.texture != null
	line.add_child(icon)
	var name_label:= _label(TechTree.display_name(id), 12, COL_TEXT, true)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(name_label)
	var cost:= _label("", 12, COL_TITLE, true)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(cost)
	var rank:= _label("", 12, COL_OWNED, true)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank.custom_minimum_size = Vector2(30, 0)
	line.add_child(rank)
	var meta:= _label(Cfg.upper(TechTree.branch_name(TechTree.branch_of(id))), CARD_META_PT,
		TechTree.branch_colour(TechTree.branch_of(id)), true)
	_parts [id] = { "meta": meta, "name": name_label, "cost": cost, "rank": rank,
		"icon": icon, "show": null, "gate": null, "compact": true }
	return row


static var _icon_cache: Dictionary = { }

static func icon_for(tile: String) -> Texture2D:
	if tile == TechTree.DEMO_ICON:
		return LOCK_ICON
	if tile == "" or not ICON_TILES.has(tile):
		return null
	var where: Array = ICON_TILES [tile]
	return _cell(tile, int(where [2]), where)


static func strip_icon_for(tile: String) -> Texture2D:
	if ICON_TILES.has(tile) and int(ICON_TILES [tile] [2]) == BADGED_SHEET:
		return _cell("strip:" + tile, STRIP_SHEET, ICON_TILES [tile])
	return icon_for(tile)


static func _cell(key: String, sheet_index: int, where: Array) -> Texture2D:
	if _icon_cache.has(key):
		return _icon_cache [key]
	var sheet: Texture2D = ICON_SHEETS [sheet_index]


	var step:= Vector2(sheet.get_width(), sheet.get_height()) / float(ICON_GRIDS [sheet_index])
	var atlas:= AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(Vector2(float(where [0]), float(where [1])) * step, step)
	_icon_cache [key] = atlas
	return atlas


func _icon(id: String, side: float) -> TextureRect:
	var rect:= TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.custom_minimum_size = Vector2(side, side)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER


	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex:= icon_for(TechTree.icon_of(id))
	rect.texture = tex
	rect.visible = tex != null
	return rect

func _label(text: String, size: int, colour: Color, heavy: bool = false) -> Label:
	var l:= Label.new()


	UiFont.style(l, size, colour, 3, heavy)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	return l


func _hrule() -> Control:
	var r:= ColorRect.new()
	r.color = Color(1, 1, 1, 0.12)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build_search() -> LineEdit:
	var box:= LineEdit.new()
	box.placeholder_text = tr("search the tree")
	box.custom_minimum_size = Vector2(SEARCH_W, 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.clear_button_enabled = true
	box.add_theme_font_override("font", UiFont.regular())
	box.add_theme_font_size_override("font_size", 15)
	box.add_theme_color_override("font_color", COL_TEXT)
	box.add_theme_color_override("font_placeholder_color", COL_LOCKED)
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.065, 0.062, 0.96)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	box.add_theme_stylebox_override("normal", sb)


	var lit:= sb.duplicate() as StyleBoxFlat
	lit.border_color = COL_TITLE
	box.add_theme_stylebox_override("focus", lit)
	box.text_changed.connect(_apply_filter)
	box.text_submitted.connect(_on_search_submitted)
	return box


func _drop_search_focus() -> void:
	if _search != null and _search.has_focus():
		_search.release_focus()


func _focus_search() -> void:
	if _search == null:
		return
	_search.grab_focus()
	_search.select_all()


func _on_search_submitted(_text: String) -> void:
	var first:= _first_hit()
	if first != "":
		_select(first)
		_centre_on(first)
	if _search != null:
		_search.release_focus()


func _is_hit(id: String, deep: bool) -> bool:
	var fields:= [
		TechTree.display_name(id),
		TechTree.branch_name(TechTree.branch_of(id)),
		id,
	]
	if deep:
		fields.append(TechTree.blurb(id))
		fields.append(TechTree.reward(id))
	var hay:= " ".join(fields).to_lower()
	for word in _filter.split(" ", false):
		if not hay.contains(word):
			return false
	return true


func _first_hit() -> String:
	for id: String in TechTree.ids():
		if _hits.has(id):
			return id
	return ""


func _add_path(id: String) -> void:
	for need: String in TechTree.requires(id):
		if _shown.has(need):
			continue
		_shown [need] = true
		_add_path(need)


func _apply_filter(text: String) -> void:
	var next:= text.strip_edges().to_lower()
	if next == _filter:
		return
	var was_filtering:= _filter != ""


	_pending_centre = ""
	_filter = next
	_hits.clear()
	_shown.clear()
	if _filter == "":
		for id: String in _cards:
			(_cards [id] as Control).visible = true
		_sync_groups()
		if was_filtering:
			_restore_view()
		_repaint_all()
		return
	if not was_filtering:
		_save_view()
	for deep in [false, true]:
		for id: String in TechTree.ids():
			if _is_hit(id, deep):
				_hits [id] = true
				_shown [id] = true
				_add_path(id)
		if not _hits.is_empty():
			break
	for id: String in _cards:
		(_cards [id] as Control).visible = _shown.has(id)
	_sync_groups()


	if not _hits.is_empty():
		if not _hits.has(_selected):
			_select(_first_hit())
		_fit_shown()
	_repaint_all()


func _sync_groups() -> void:
	var groups:= TechTree.tuning_groups()
	for machine: String in _groups:
		var any:= false
		for id: String in groups.get(machine, []):
			if (_cards [id] as Control).visible:
				any = true
				break
		(_groups [machine] as Control).visible = any


func _clear_filter() -> void:
	if _search != null:
		_search.text = ""
		_search.release_focus()
	_apply_filter("")


func _save_view() -> void:
	_saved_view = { "zoom": _zoom, "pos": _world.position, "moved": _user_moved }


func _restore_view() -> void:
	if _saved_view.is_empty():
		return
	_zoom = float(_saved_view ["zoom"])
	_world.scale = Vector2.ONE * _zoom
	_world.position = _saved_view ["pos"]


	_user_moved = bool(_saved_view ["moved"])
	_saved_view = { }
	_clamp_pan()


func _fit_shown() -> void:
	var view:= _viewport.size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var rect:= Rect2()
	var found:= false
	for id: String in _shown:
		if not _pos.has(id):
			continue
		var one:= card_rect(id)
		rect = one if not found else rect.merge(one)
		found = true
	if not found:
		return
	rect = rect.grow(WORLD_MARGIN)
	_zoom = clampf(minf(view.x / rect.size.x, view.y / rect.size.y),
			ZOOM_MIN, ZOOM_MAX)
	_world.scale = Vector2.ONE * _zoom
	_world.position = view * 0.5 - rect.get_center() * _zoom
	_clamp_pan()


func _on_viewport_resized() -> void:
	if not _open:
		return


	if _pending_centre != "":
		_centre_on(_pending_centre)
		return
	if _filter != "":
		_fit_shown()
	elif not _user_moved:
		_fit_board()


func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb:= event as InputEventMouseButton
		if mb.pressed:
			_drop_search_focus()
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_moved_by_hand()
				_zoom_at(mb.position, ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				_moved_by_hand()
				_zoom_at(mb.position, 1.0 / ZOOM_STEP)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:


				if mb.pressed:
					if _pan_button == MOUSE_BUTTON_NONE:
						_panning = true
						_pan_button = mb.button_index
						_pan_from = mb.position
				elif mb.button_index == _pan_button:
					_panning = false
					_pan_button = MOUSE_BUTTON_NONE
					_pan_from = Vector2.INF


				if mb.button_index == MOUSE_BUTTON_LEFT:
					if mb.pressed:
						_press_at = mb.position
					elif _press_at != Vector2.INF:
						var moved:= mb.position.distance_to(_press_at)
						if moved < DRAG_SLOP and _selected != "":
							_select("")
							Audio.play("ui_hotbar", -8.0)
						_press_at = Vector2.INF
			_:
				return
		accept_event()
	elif event is InputEventMouseMotion and _panning:
		var mm:= event as InputEventMouseMotion
		_moved_by_hand()
		_world.position += mm.relative
		_clamp_pan()


		if _pan_button == MOUSE_BUTTON_LEFT and _selected != "" and mm.position.distance_to(_pan_from) >= DRAG_SLOP:
			_select("")
		accept_event()


func _moved_by_hand() -> void:
	_user_moved = true
	_pending_centre = ""


func _zoom_at(where: Vector2, factor: float) -> void:
	var next:= clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(next, _zoom):
		return


	var world_point:= (where - _world.position) / _zoom
	_zoom = next
	_world.scale = Vector2.ONE * _zoom
	_world.position = where - world_point * _zoom
	_clamp_pan()


func _clamp_pan() -> void:
	var view:= Vector2(_viewport.size)
	var span:= _world_size * _zoom
	var slack:= view * PAN_SLACK
	var flush:= view - span


	var keep:= Vector2(minf(span.x, view.x), minf(span.y, view.y)) * PAN_KEEP
	var p:= _world.position
	p.x = clampf(p.x,
		maxf(minf(flush.x, 0.0) - slack.x, keep.x - span.x),
		minf(maxf(flush.x, 0.0) + slack.x, view.x - keep.x))
	p.y = clampf(p.y,
		maxf(minf(flush.y, 0.0) - slack.y, keep.y - span.y),
		minf(maxf(flush.y, 0.0) + slack.y, view.y - keep.y))
	_world.position = p


	if _rail != null:
		_rail.queue_redraw()
	if _header != null:
		_header.queue_redraw()


func _fit_board() -> void:
	var view:= _viewport.size
	if view.x <= 0.0 or view.y <= 0.0:
		return


	var room:= Vector2(view.x, view.y - HEADER_H)
	_zoom = clampf(minf(room.x / _world_size.x, room.y / _world_size.y),
			ZOOM_MIN, ZOOM_MAX)
	_world.scale = Vector2.ONE * _zoom
	_world.position = (room - _world_size * _zoom) * 0.5 + Vector2(0.0, HEADER_H)
	_clamp_pan()


func _centre_on(id: String) -> void:
	if not _pos.has(id):
		return
	_pending_centre = id
	if _viewport.size.x <= 0.0 or _viewport.size.y <= 0.0:
		return
	_world.scale = Vector2.ONE * _zoom
	var centre: Vector2 = card_rect(id).get_center()
	_world.position = _viewport.size * 0.5 - centre * _zoom
	_clamp_pan()


func _show_lane(branch: String) -> void:
	var rect:= Rect2()
	var found:= false
	for id: String in TechTree.ids_in(branch):
		if id == TechTree.ROOT or not _pos.has(id):
			continue
		var one:= card_rect(id)
		rect = one if not found else rect.merge(one)
		found = true
	var view:= _viewport.size
	if not found or view.x <= 0.0 or view.y <= 0.0:
		return
	rect = rect.grow(WORLD_MARGIN)
	_moved_by_hand()
	_zoom = clampf(minf(view.x / rect.size.x, view.y / rect.size.y), ZOOM_MIN, 1.0)
	_world.scale = Vector2.ONE * _zoom
	_world.position = view * 0.5 - rect.get_center() * _zoom
	_clamp_pan()
	Audio.play("ui_hotbar", -6.0)


func _on_card_hover(id: String) -> void:
	if id == "" and _hovered == "":
		return
	_hovered = id

	if _new_ready.has(id):
		Cfg.see_tech(id)
		_new_ready.erase(id)
	_paint_wires()


func _on_card_input(event: InputEvent, id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb:= event as InputEventMouseButton
	if not mb.pressed:
		return
	_drop_search_focus()
	if mb.button_index == MOUSE_BUTTON_LEFT:


		if mb.double_click:
			_buy(id)
		elif _selected != id:
			_select(id)
			Audio.play("ui_hotbar", -6.0)
	else:


		return
	accept_event()


func _select(id: String) -> void:
	_selected = id


	if _ins_frame != null:
		_ins_frame.visible = id != ""


	if _ins_scroll != null:
		_ins_scroll.scroll_vertical = 0
	_put_away = id == ""
	_repaint_all()


func _buy_selected() -> void:
	if _selected == "":
		return
	_buy(_selected)


func _show_selected_build() -> void:
	_show_build(_selected)


func _show_build(id: String) -> void:
	var builds:= BuildCatalog.builds_for(id)
	var panel: CatalogPanel = player.catalog if player != null else null
	if builds.is_empty() or panel == null:
		Audio.play("ui_error")
		return
	set_open(false)
	panel.show_entry(str(builds [0]))


func _buy(id: String) -> void:
	if not TechTree.has_id(id):
		return
	var check:= Tech.can_buy(id)
	if not check ["ok"]:
		Audio.play("ui_error")
		return


	var first_rank:= Tech.rank_of(id) == 0
	if not Tech.buy(id):
		Audio.play("ui_error")
		return
	_surge(id)


	Audio.play("tech_buy", -3.0 if first_rank else -8.0)


	Audio.play("tech_current", -7.0 if first_rank else -12.0)


func _surge(bought: String) -> void:
	_ignite(bought)
	var seen:= { bought: true }
	var frontier: Array [String] = [bought]
	for depth in SPARK_HOPS:
		if frontier.is_empty():
			return
		var next: Array [String] = []
		for child: String in frontier:
			for seg: Dictionary in _wires.segments:
				if str(seg ["to"]) != child:
					continue
				var parent:= str(seg ["from"])
				if seen.has(parent):
					continue
				seen [parent] = true
				next.append(parent)
				_spark(seg ["points"], float(depth) * HOP, parent)
		frontier = next


func _spark(points: PackedVector2Array, delay: float, arrives_at: String) -> void:
	var path:= PackedVector2Array(points)
	path.reverse()
	var cum:= WireLayer.measure(path)
	_sparks.append({
		"points": path,
		"cum": cum,
		"length": cum [cum.size() - 1],


		"t": - delay,
		"head": 0.0,
		"to": arrives_at,
	})
	set_process(true)


func _process(delta: float) -> void:
	if _hint_layer != null:
		_hint_t += delta


		_hint_layer.queue_redraw()
	if _sparks.is_empty():
		_settle_process()
		return
	var i:= _sparks.size()
	while i > 0:
		i -= 1
		var spark: Dictionary = _sparks [i]
		spark ["t"] = float(spark ["t"]) + delta
		var t: float = spark ["t"]
		if t < 0.0:
			continue
		var f: float = t / HOP
		if f >= 1.0:


			_ignite(str(spark ["to"]))
			_sparks.remove_at(i)
			continue


		spark ["head"] = float(spark ["length"]) * ease(f, 0.62)
	_wires.queue_redraw()
	if _sparks.is_empty():
		_settle_process()


func _settle_process() -> void:
	set_process(not _sparks.is_empty() or (_open and (_ring_id() != "" or not _new_ready.is_empty())))


func _scan_new_ready() -> void:
	_new_ready.clear()
	if not Cfg.teach_hints:
		return
	for id: String in _cards.keys():
		if not TechTree.has_id(id) or Cfg.tech_seen(id):
			continue

		if Tech.rank_of(id) > 0:
			continue
		if Tech.can_buy(id) ["ok"]:
			_new_ready.append(id)


func _ignite(id: String) -> void:
	var card: PanelContainer = _cards.get(id)
	if card == null:
		return
	var old: Tween = _ignites.get(id)
	if old != null and old.is_valid():
		old.kill()
	card.modulate = IGNITE_FLASH
	card.scale = Vector2(IGNITE_PUNCH, IGNITE_PUNCH)
	var tw:= create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "modulate", Color.WHITE, IGNITE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(card, "scale", Vector2.ONE, IGNITE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_ignites [id] = tw


func _clear_surge() -> void:
	_sparks.clear()
	_settle_process()
	for id: String in _ignites:
		var tw: Tween = _ignites [id]
		if tw != null and tw.is_valid():
			tw.kill()
	_ignites.clear()
	for id: String in _cards:
		var card: PanelContainer = _cards [id]
		card.modulate = Color.WHITE
		card.scale = Vector2.ONE
	if _wires != null:
		_wires.queue_redraw()


func _on_tech_changed(_id: String, _rank: int) -> void:
	_repaint_all()


func _on_contracts_changed() -> void:
	_repaint_all()


func _on_money_changed(amount: float) -> void:
	if _wallet != null:
		_wallet.text = "$%s" % Hud.money_text(amount)
	if _open:
		_repaint_all()


func _repaint_all() -> void:
	for id: String in _cards:
		_paint(id)
	_paint_wires()
	_paint_inspector()
	_count_lanes()
	if _rail != null:
		_rail.queue_redraw()
	if _progress != null and _filter != "":


		if _hits.is_empty():
			_progress.text = tr("Nothing matches. Empty the box for the whole tree.")
		else:


			_progress.text = tr_n("%d matching card, with everything they need behind them. Empty the box for the whole tree.", "%d matching cards, with everything they need behind them. Empty the box for the whole tree.", _hits.size()) % _hits.size()
	elif _progress != null:
		var bought:= 0
		var total:= 0
		for id: String in TechTree.ids():
			bought += Tech.rank_of(id)
			total += TechTree.max_rank(id)
		_progress.text = tr("%d of %d levels bought   ·   wheel to zoom, click a card, double-click to buy, right-drag to move without closing it") % [bought, total]


func _count_lanes() -> void:
	_lane_counts.clear()
	for b: Dictionary in TechTree.BRANCHES:
		var branch:= str(b ["id"])
		var bought:= 0
		var total:= 0
		var ready:= 0
		for id: String in TechTree.ids_in(branch):
			if id == TechTree.ROOT:
				continue
			bought += Tech.rank_of(id)
			total += TechTree.max_rank(id)
			if Tech.can_buy(id) ["ok"]:
				ready += 1
		_lane_counts [branch] = [bought, total, ready]


func _paint(id: String) -> void:
	var card: PanelContainer = _cards.get(id)
	if card == null:
		return
	var rank:= Tech.rank_of(id)
	var top:= TechTree.max_rank(id)
	var maxed:= Tech.is_maxed(id)


	var reachable:= Tech.requires_met(id) or Tech.rank_of(id) > 0
	var ready: bool = Tech.can_buy(id) ["ok"]

	var demo:= TechTree.is_demo(id)


	var offsite:= Tech.off_site(id)
	var unsold:= demo or offsite
	var style:= _card_box
	if _selected == id:
		style = _card_selected
	elif unsold:
		style = _card_demo
	elif maxed:
		style = _card_owned
	elif not reachable:
		style = _card_locked
	elif ready:
		style = _card_ready


	var box:= style.duplicate() as StyleBoxFlat
	box.border_color = style.border_color
	box.set_border_width(SIDE_LEFT, 4)
	var parts: Dictionary = _parts.get(id, { })
	var compact:= bool(parts.get("compact", false))
	if compact:


		box.set_corner_radius_all(0)
		box.set_border_width_all(0)
		box.set_border_width(SIDE_LEFT, 4)
		box.content_margin_top = 2.0
		box.content_margin_bottom = 2.0
		box.content_margin_right = 8.0
	card.add_theme_stylebox_override("panel", box)

	if parts.is_empty():
		return
	var name_label: Label = parts ["name"]
	name_label.add_theme_color_override("font_color",
		COL_DEMO if unsold else (COL_TEXT if reachable else COL_LOCKED))


	var icon: TextureRect = parts ["icon"]


	icon.modulate = Color(COL_DEMO, 0.85) if demo else Color(1, 1, 1, 1.0 if reachable and not offsite else 0.38)
	var meta: Label = parts ["meta"]
	meta.add_theme_color_override("font_color",
		COL_DEMO if unsold else (TechTree.branch_colour(TechTree.branch_of(id))
			if reachable else COL_LOCKED))

	var rank_label: Label = parts ["rank"]
	if unsold:


		rank_label.text = ""
	elif top <= 1:
		rank_label.text = tr("OWNED") if rank > 0 else ""
	else:
		rank_label.text = "%d/%d" % [rank, top]
	rank_label.add_theme_color_override("font_color",
		COL_OWNED if rank > 0 else COL_LOCKED)


	var show_btn: Button = parts.get("show")
	var offers_show: bool = show_btn != null and maxed and not unsold
	if show_btn != null:
		show_btn.visible = offers_show


	var gate_btn: Button = parts.get("gate")
	var offers_gate: bool = gate_btn != null and not unsold and not maxed and contract_gate_text(id) != ""
	if gate_btn != null:
		gate_btn.visible = offers_gate

	var cost: Label = parts ["cost"]
	cost.visible = not offers_show and not offers_gate


	cost.add_theme_font_size_override("font_size",
		12 if compact else (13 if unsold else 15))
	if demo:


		cost.text = tr(TechTree.DEMO_TEXT)
		cost.add_theme_color_override("font_color", COL_DEMO)
	elif offsite:
		cost.text = tr(TechTree.SITE_TEXT)
		cost.add_theme_color_override("font_color", COL_DEMO)
	elif maxed:
		cost.text = tr("DONE")
		cost.add_theme_color_override("font_color", COL_OWNED)
	elif compact and contract_gate_text(id) != "":


		cost.text = tr("CONTRACT")
		cost.add_theme_color_override("font_color", COL_SHORT)
	elif not reachable:
		cost.text = tr("LOCKED")
		cost.add_theme_color_override("font_color", COL_LOCKED)
	else:
		cost.text = _strip_money(Tech.next_cost(id)) if compact else _compact_money(Tech.next_cost(id))
		cost.add_theme_color_override("font_color", COL_AFFORD if ready else COL_SHORT)

	if show_btn != null:
		show_btn.modulate = Color.WHITE
	if not compact:
		_fit_words(parts, 13 if unsold else 15)


	if _filter != "" and not _hits.has(id) and _selected != id:
		box.bg_color = box.bg_color.lerp(COL_BOARD, PATH_FADE)
		box.border_color = box.border_color.lerp(COL_BOARD, PATH_FADE)
		icon.modulate = Color(icon.modulate, icon.modulate.a * (1.0 - PATH_FADE))
		if show_btn != null:


			show_btn.modulate = Color(1, 1, 1, 1.0 - PATH_FADE)
		for part: String in ["meta", "name", "cost", "rank"]:
			var l: Label = parts [part]
			l.add_theme_color_override("font_color",
				(l.get_theme_color("font_color") as Color).lerp(COL_BOARD, PATH_FADE))


func _fit_words(parts: Dictionary, cost_pt: int) -> void:
	var cost: Label = parts ["cost"]
	var name_label: Label = parts ["name"]
	var key:= "%s|%s|%d|%s" % [name_label.text, cost.text, cost_pt, cost.visible]
	if parts.get("fit_key", "") != key:
		parts ["fit_key"] = key
		var bold:= UiFont.bold()
		var pt:= cost_pt
		if cost.visible:


			var room_x:= CARD_TEXT_W - 1.0 - float(cost.get_parent().get_theme_constant("separation"))
			while pt > CARD_PT_MIN and bold.get_string_size(cost.text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x > room_x:
				pt -= 1


		var room:= CARD_TEXT_H - bold.get_height(CARD_META_PT) - maxf(bold.get_height(pt), bold.get_height(CARD_RANK_PT)) - 2.0
		var spacing:= float(name_label.get_theme_constant("line_spacing"))
		var name_pt:= CARD_NAME_PT
		while name_pt > CARD_PT_MIN and _wrapped_height(name_label.text, bold, name_pt, spacing) > room:
			name_pt -= 1
		parts ["fit_pt"] = [pt, name_pt]
	var sizes: Array = parts ["fit_pt"]
	cost.add_theme_font_size_override("font_size", int(sizes [0]))
	name_label.add_theme_font_size_override("font_size", int(sizes [1]))


static func _wrapped_height(text: String, font: Font, pt: int, spacing: float) -> float:
	var para:= TextParagraph.new()
	para.width = CARD_TEXT_W
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.add_string(text, font, pt)
	var lines:= para.get_line_count()
	return float(lines) * font.get_height(pt) + float(lines - 1) * spacing


func _paint_wires() -> void:
	var traced:= _hovered if _hovered != "" else _selected
	for seg: Dictionary in _wires.segments:
		var from:= str(seg ["from"])
		var to:= str(seg ["to"])
		var live:= Tech.is_unlocked(from)
		var on_trace: bool = traced == from or traced == to
		seg ["hidden"] = _filter != "" and not (_shown.has(from) and _shown.has(to))


		var foreign: bool = from != TechTree.ROOT and TechTree.branch_of(from) != TechTree.branch_of(to)
		if on_trace:
			seg ["colour"] = COL_TITLE
			seg ["width"] = 3.0
		elif _hovered != "":
			seg ["colour"] = Color(1, 1, 1, 0.035)
			seg ["width"] = 2.0
		elif foreign:
			seg ["colour"] = Color(TechTree.branch_colour(TechTree.branch_of(from)),
				0.5 if live else 0.28)
			seg ["width"] = 2.0
		elif live:
			seg ["colour"] = Color(0.62, 0.72, 0.55, 0.55)
			seg ["width"] = 2.0
		else:
			seg ["colour"] = Color(1, 1, 1, 0.08)
			seg ["width"] = 2.0


	_wires.segments.sort_custom(_by_faintness)
	_wires.queue_redraw()


func _by_faintness(a: Dictionary, b: Dictionary) -> bool:
	return (a ["colour"] as Color).a < (b ["colour"] as Color).a


func _paint_inspector() -> void:
	if _ins_name == null:
		return
	var id:= _selected
	if id == "" or not TechTree.has_id(id):
		_ins_icon.visible = false
		_ins_branch.text = ""
		_ins_name.text = tr("Nothing selected")
		_ins_rank.text = ""
		_ins_blurb.text = tr("Click a card on the board.")
		_ins_value.text = ""
		_ins_reward.text = ""
		_ins_cost.text = ""
		_ins_buy.disabled = true
		_ins_show.visible = false
		_ins_reason.text = ""
		return
	var rank:= Tech.rank_of(id)
	var top:= TechTree.max_rank(id)
	var check:= Tech.can_buy(id)
	var branch_colour:= TechTree.branch_colour(TechTree.branch_of(id))


	_ins_reason.add_theme_color_override("font_color", COL_SHORT)

	var tex:= icon_for(TechTree.icon_of(id))
	_ins_icon.texture = tex
	_ins_icon.visible = tex != null
	_ins_icon.modulate = Color(COL_DEMO, 0.9) if TechTree.is_demo(id) else Color.WHITE
	_ins_branch.text = Cfg.upper(TechTree.branch_name(TechTree.branch_of(id)))
	_ins_branch.add_theme_color_override("font_color", branch_colour)
	_ins_name.text = TechTree.display_name(id)


	_ins_show.visible = Tech.is_unlocked(id) and not BuildCatalog.builds_for(id).is_empty()


	if TechTree.is_demo(id):
		_ins_rank.text = tr(TechTree.DEMO_TEXT)
		_ins_blurb.text = TechTree.blurb(id)
		_ins_value.text = ""
		_ins_reward.text = ""
		_ins_cost.text = Cfg.upper(tr(TechTree.DEMO_TEXT))
		_ins_cost.add_theme_color_override("font_color", COL_DEMO)
		_ins_buy.disabled = true
		_ins_buy.text = tr("LOCKED")
		_ins_reason.add_theme_color_override("font_color", COL_DEMO)
		_ins_reason.text = tr("Available in the full game.")
		return


	if Tech.off_site(id):
		_ins_rank.text = tr(TechTree.SITE_TEXT)
		_ins_blurb.text = TechTree.blurb(id)
		_ins_value.text = ""
		_ins_reward.text = ""
		_ins_cost.text = Cfg.upper(tr(TechTree.SITE_TEXT))
		_ins_cost.add_theme_color_override("font_color", COL_DEMO)
		_ins_buy.disabled = true
		_ins_buy.text = tr("LOCKED")
		_ins_reason.add_theme_color_override("font_color", COL_DEMO)
		_ins_reason.text = tr("Only works in the shed.")
		return

	if top <= 1:


		_ins_rank.text = tr("Unlock   ·   owned") if rank > 0 else tr("Unlock   ·   not bought")
	else:
		_ins_rank.text = tr("Level %d of %d") % [rank, top]
	_ins_blurb.text = TechTree.blurb(id)


	var now:= TechTree.value_at(id, rank)
	var next:= TechTree.value_at(id, rank + 1)
	if now != "" and next != "":
		_ins_value.text = tr("now %s   ->   next %s") % [now, next]
	elif next != "":
		_ins_value.text = tr("next level:  %s") % next
	else:
		_ins_value.text = now
	_ins_reward.text = TechTree.reward(id) if rank > 0 or top <= 1 else ""

	if Tech.is_maxed(id):
		_ins_cost.text = tr("FULLY BOUGHT")
		_ins_cost.add_theme_color_override("font_color", COL_OWNED)
		_ins_buy.disabled = true
		_ins_buy.text = tr("DONE")
		_ins_reason.text = ""
		return
	_ins_cost.text = "$%s" % Hud.money_text(Tech.next_cost(id))
	_ins_cost.add_theme_color_override("font_color",
		COL_AFFORD if check ["ok"] else COL_SHORT)
	_ins_buy.disabled = not check ["ok"]
	_ins_buy.text = tr("BUY") if top <= 1 else tr("BUY LEVEL %d") % (rank + 1)


	var gate_says:= contract_gate_text(id)
	if gate_says != "":
		_ins_reason.text = gate_says
	else:
		_ins_reason.text = "" if check ["ok"] else str(check ["reason"])


static func contract_gate_text(id: String) -> String:
	var gate:= DeliveryBook.gate_for(id)
	if gate < 0 or GameState.contract_signed(DeliveryBook.id_at(gate)):
		return ""


	return Cfg.tr("Unlocked by finishing the %s order on the board by the bay door. %s") % [
		DeliveryBook.title_quiet_of(gate), DeliveryBook.detail_of(gate)]


static func _compact_money(v: float) -> String:
	if v >= 1000.0:
		var k:= v / 1000.0
		return Cfg.tr("$%.1fk", "thousands") % k if k < 10.0 and not is_equal_approx(k, roundf(k)) else Cfg.tr("$%dk", "thousands") % int(round(k))
	return "$%s" % Hud.money_text(v)


static func _strip_money(v: float) -> String:
	if v < 1000.0 and is_equal_approx(v, roundf(v)):
		return "$%d" % int(roundf(v))
	return _compact_money(v)
