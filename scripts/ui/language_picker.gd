class_name LanguagePicker
extends Control


signal chosen(code: String)

const COL_TITLE:= MainMenu.COL_TITLE
const COL_TEXT:= MainMenu.COL_TEXT
const COL_DIM:= MainMenu.COL_DIM


const CARD_SIZE:= Vector2(137, 176)
const FLAG_SIZE:= Vector2(112, 68)
const CARD_GAP:= 18
const ROW_MAX:= 8

const LIFT:= 6.0


const PROMPTS:= {
	"en": ["CHOOSE YOUR LANGUAGE", "You can change it later in OPTIONS.", "CONFIRM"],
	"de": ["WÄHLE DEINE SPRACHE", "Du kannst sie später in den OPTIONEN ändern.", "BESTÄTIGEN"],
	"fr": ["CHOISIS TA LANGUE", "Tu pourras la changer plus tard dans les OPTIONS.", "CONFIRMER"],
	"es": ["ELIGE TU IDIOMA", "Puedes cambiarlo más tarde en OPCIONES.", "CONFIRMAR"],
	"pt": ["ESCOLHA SEU IDIOMA", "Você pode mudar depois em OPÇÕES.", "CONFIRMAR"],
	"pl": ["WYBIERZ SWÓJ JĘZYK", "Możesz go później zmienić w OPCJACH.", "ZATWIERDŹ"],
	"cs": ["VYBER SI JAZYK", "Později ho můžeš změnit v NASTAVENÍ.", "POTVRDIT"],
	"ru": ["ВЫБЕРИ ЯЗЫК", "Потом его можно сменить в НАСТРОЙКАХ.", "ПОДТВЕРДИТЬ"],
	"tr": ["DİLİNİ SEÇ", "Daha sonra AYARLAR'dan değiştirebilirsin.", "ONAYLA"],
	"zh": ["选择语言", "之后可以在「选项」里更改。", "确认"],
	"ja": ["言語を選択", "あとで「設定」から変えられる。", "決定"],
	"ko": ["언어 선택", "나중에 '설정'에서 바꿀 수 있어요.", "확인"],
}

const CONFIRM_SIZE:= Vector2(300, 64)
const COL_GO:= Color(0.3, 0.72, 0.34)


var preview:= false

var _dim: ColorRect
var _title: Label
var _hint: Label
var _confirm: Button
var _cards: Array [Button] = []
var _flags: Array [LanguageFlag] = []
var _codes: Array [String] = []
var _lit:= -1
var _done:= false


var _via_mouse:= false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	var first:= _guess()
	highlight(first)
	_cards [first].grab_focus.call_deferred()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.015, 0.02, 0.03, 0.74)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var centre:= CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var column:= VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.style(_title, 52, COL_TITLE, 6, true)


	_title.add_theme_font_override("font", UiFont.every_script(true))
	column.add_child(_title)


	var rule_box:= CenterContainer.new()
	rule_box.custom_minimum_size = Vector2(0, 56)
	rule_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule_box)
	var rule:= ColorRect.new()
	rule.color = Color(COL_TITLE, 0.55)
	rule.custom_minimum_size = Vector2(140, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule_box.add_child(rule)

	var entries: Array [Dictionary] = []
	for entry: Dictionary in Cfg.LOCALES:


		if str(entry ["code"]) != "":
			entries.append(entry)


	var rows:= ceili(entries.size() / float(ROW_MAX))
	var per_row:= ceili(entries.size() / float(rows))
	var grid:= VBoxContainer.new()
	grid.add_theme_constant_override("separation", CARD_GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(grid)
	var row: HBoxContainer = null
	for i: int in entries.size():
		if i % per_row == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", CARD_GAP)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(row)

		row.add_child(_card(str(entries [i] ["code"]),
			str(entries [i].get("card", entries [i] ["name"]))))

	var gap:= Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.style(_hint, 22, COL_DIM, 4)
	_hint.add_theme_font_override("font", UiFont.every_script())
	column.add_child(_hint)

	var gap2:= Control.new()
	gap2.custom_minimum_size = Vector2(0, 28)
	gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap2)

	_confirm = Button.new()
	_confirm.name = "Confirm"
	_confirm.custom_minimum_size = CONFIRM_SIZE
	_confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm.add_theme_font_override("font", UiFont.every_script(true))
	_confirm.add_theme_font_size_override("font_size", 30)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_confirm.add_theme_color_override(state, Color.WHITE)
	_confirm.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_confirm.add_theme_constant_override("outline_size", 4)
	_confirm.add_theme_stylebox_override("normal", _go_style(0.0))
	_confirm.add_theme_stylebox_override("hover", _go_style(0.18))
	_confirm.add_theme_stylebox_override("focus", _go_style(0.18))
	_confirm.add_theme_stylebox_override("pressed", _go_style(-0.12))
	_confirm.pressed.connect(func() -> void: _choose(_lit))
	column.add_child(_confirm)


func _card(code: String, endonym: String) -> Button:
	var i:= _cards.size()
	var b:= Button.new()
	b.name = "Lang_" + code
	b.custom_minimum_size = CARD_SIZE
	_style_card(b, false)


	b.mouse_entered.connect(_show_prompt.bind(i))
	b.mouse_exited.connect(func() -> void: _show_prompt(_lit))
	b.focus_entered.connect(highlight.bind(i))
	b.gui_input.connect(_card_input.bind(i))
	b.pressed.connect(_card_pressed.bind(i))

	var inner:= VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 18)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)


	var holder:= Control.new()
	holder.custom_minimum_size = FLAG_SIZE + Vector2(0, LIFT)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(holder)

	var flag:= LanguageFlag.new()
	flag.code = code
	flag.size = FLAG_SIZE
	flag.position = Vector2(0, LIFT)
	holder.add_child(flag)

	var name_label:= Label.new()
	name_label.text = endonym
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.style(name_label, 26, COL_TEXT, 5, true)
	name_label.add_theme_font_override("font", UiFont.every_script(true))
	inner.add_child(name_label)

	_cards.append(b)
	_flags.append(flag)
	_codes.append(code)
	return b


func _card_style(level: int) -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.095, 0.97) if level > 0 else Color(0.035, 0.045, 0.065, 0.94)
	match level:
		2: sb.border_color = COL_TITLE
		1: sb.border_color = Color(0.8, 0.82, 0.86, 0.7)
		_: sb.border_color = Color(0.55, 0.58, 0.64, 0.4)
	sb.set_border_width_all(3 if level == 2 else 2)
	sb.set_corner_radius_all(0)
	sb.shadow_color = Color(COL_TITLE, 0.22) if level == 2 else Color(0, 0, 0, 0.55)
	sb.shadow_size = 18 if level == 2 else 12
	return sb


func _style_card(b: Button, picked: bool) -> void:
	b.add_theme_stylebox_override("normal", _card_style(2 if picked else 0))
	b.add_theme_stylebox_override("hover", _card_style(2 if picked else 1))
	b.add_theme_stylebox_override("pressed", _card_style(2))
	b.add_theme_stylebox_override("focus", _card_style(2 if picked else 0))


func _go_style(shade: float) -> StyleBoxFlat:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = COL_GO.lightened(shade) if shade >= 0.0 else COL_GO.darkened(- shade)
	sb.border_color = COL_GO.lightened(0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.shadow_color = Color(COL_GO, 0.3)
	sb.shadow_size = 14
	return sb


func _guess() -> int:
	var lang:= OS.get_locale_language()
	var i:= _codes.find(lang)
	if i >= 0:
		return i
	return maxi(_codes.find("en"), 0)


func highlight(i: int) -> void:
	if i == _lit or i < 0 or i >= _cards.size():
		return

	if _lit >= 0:
		Audio.play("ui_tick", -6.0)
	_lit = i
	for j: int in _flags.size():
		var on:= j == i
		var t:= create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(_flags [j], "position:y", 0.0 if on else LIFT, 0.18)
		t.tween_property(_flags [j], "lit", 1.0 if on else 0.0, 0.18)
		_style_card(_cards [j], on)
		if not on and _cards [j].has_focus():
			_cards [j].release_focus()
	_show_prompt(i)


func _show_prompt(i: int) -> void:
	if i < 0 or i >= _codes.size():
		return
	var prompt: Array = PROMPTS.get(_codes [i], PROMPTS ["en"])
	_title.text = prompt [0]
	_hint.text = prompt [1]

	var picked: Array = PROMPTS.get(_codes [maxi(_lit, 0)], PROMPTS ["en"])
	_confirm.text = picked [2]


func _card_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton:
		_via_mouse = true
		var mb:= event as InputEventMouseButton
		if mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			highlight(i)
			_choose(i)
	elif event is InputEventKey or event is InputEventJoypadButton:
		_via_mouse = false


func _card_pressed(i: int) -> void:
	if _via_mouse:
		highlight(i)
		_cards [i].grab_focus()
	else:
		_choose(i)


func _choose(i: int) -> void:
	if _done or preview:
		return
	_done = true
	Audio.play("ui_select")
	for b: Button in _cards:
		b.disabled = true
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.disabled = true
	_confirm.mouse_filter = Control.MOUSE_FILTER_IGNORE


	Cfg.locale_asked = true
	Cfg.set_locale(_codes [i])


	var t:= create_tween()
	t.tween_property(_flags [i], "lit", 1.6, 0.12)
	t.tween_interval(0.12)
	t.tween_property(_dim, "color", Color(0.02, 0.02, 0.03, 1.0), 0.45)
	t.parallel().tween_property(_title, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(_hint, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(_confirm, "modulate:a", 0.0, 0.3)
	for b: Button in _cards:
		t.parallel().tween_property(b, "modulate:a", 0.0, 0.3)
	await t.finished
	chosen.emit(_codes [i])
	queue_free()
