class_name GoalsEventPanel
extends VBoxContainer
## The coach's offer of the season's goals (SeasonGoals.offer, event kind "goals", GDD 4.9.2 "Season goals with times", session C5) as a
## panel in the career hub's dimmed decision layer, in the same look as the other stop panels (caption with the date and a "?",
## heading, his words, one row per goal, 44 px buttons). Each goal is a STEPPER: the level chosen with a left and a right button
## (easier / harder), what it asks as a sentence, what the level is called with his words on the chance, and a star on the level HE
## would pick; a row of dots shows where in the list it stands. "Set these goals" answers "set:i,j,k" (a level index per goal),
## "Decide later" answers "later". Texts: data/goals.json ui.

signal rebuilt

var _e: Dictionary
var _width := 480.0
var _on_answer: Callable
var _on_help: Callable
var _pack: Dictionary
var _sel: Array = []   # the chosen option index of each goal of the offer


static func handles(e: Dictionary) -> bool:
	return e.get("source", "") == "goals" and str(e.get("kind", "")) == "goals" and SeasonGoals.sys() != null \
			and SeasonGoals.sys().offers.has(int(e.get("year", 0)))


static func max_width(_e: Dictionary) -> float:
	return 520.0 if Layout.compact else 620.0


func _init(e: Dictionary, width: float, on_answer: Callable, on_help := Callable()) -> void:
	_e = e
	_width = width
	_on_answer = on_answer
	_on_help = on_help
	_pack = SeasonGoals.sys().offers[int(e.year)]
	for def in _pack.goals:
		_sel.append(int(def.pick))
	add_theme_constant_override("separation", 10)
	custom_minimum_size.x = width
	_build()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var ui: Dictionary = Data.goals.ui
	var year := int(_e.year)
	var caption := UIKit.label(str(ui.offer_caption).format({"date": Calendar.format_day(_e.date).to_upper()}), "CaptionLabel")
	if _on_help.is_valid():
		var row := UIKit.hbox(8)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		caption.clip_text = true
		row.add_child(caption)
		var help := HelpButton.new(str(ui.help_entry))
		help.pressed.connect(func(): _on_help.call())
		row.add_child(help)
		add_child(row)
	else:
		add_child(caption)
	add_child(UIKit.wrapped(str(_e.title), "HeadingLabel"))
	add_child(UIKit.wrapped(str(_e.text), ""))
	for i in _pack.goals.size():
		add_child(_stepper(i, year))
	var row2: BoxContainer = UIKit.vbox(8) if Layout.compact else UIKit.hbox(8)
	var set_b := UIKit.button(str(ui.offer_set), true, 220)
	set_b.pressed.connect(func(): _on_answer.call("set:" + ",".join(_sel.map(func(x): return str(x)))))
	var later := UIKit.button(str(ui.offer_later), false, 200)
	later.pressed.connect(func(): _on_answer.call("later"))
	for b in [set_b, later]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(b)
	add_child(row2)
	add_child(UIKit.wrapped(str(ui.offer_later_hint)))
	rebuilt.emit()


## One goal: ◀ [what it asks · the level and his words] ▶ and the dots.
func _stepper(i: int, year: int) -> Control:
	var ui: Dictionary = Data.goals.ui
	var def: Dictionary = _pack.goals[i]
	var opts: Array = def.options
	var idx := clampi(int(_sel[i]), 0, opts.size() - 1)
	var o: Dictionary = opts[idx]
	var box := UIKit.vbox(4)
	box.add_child(UIKit.label(str(ui.kind_head[def.kind]), "CaptionLabel"))
	var row := UIKit.hbox(8)
	var left := UIKit.button("◀", false, 44)
	left.custom_minimum_size = Vector2(44, 44)
	left.disabled = idx <= 0
	left.pressed.connect(func():
		_sel[i] = idx - 1
		_build())
	var right := UIKit.button("▶", false, 44)
	right.custom_minimum_size = Vector2(44, 44)
	right.disabled = idx >= opts.size() - 1
	right.pressed.connect(func():
		_sel[i] = idx + 1
		_build())
	var mid := UIKit.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var what := UIKit.wrapped(SeasonGoals.goal_text(o, year), "SubheadingLabel")
	what.custom_minimum_size.x = 120
	mid.add_child(what)
	var words := "%s · %s" % [str(o.level_name), str(o.chance)]
	if idx == int(def.pick):
		words += "   " + str(ui.pick_mark)
	var chance := UIKit.wrapped(words, "")
	chance.custom_minimum_size.x = 120
	if idx == int(def.pick):
		chance.add_theme_color_override("font_color", Palette.ACCENT)
	mid.add_child(chance)
	if bool(o.get("estimated", false)):
		mid.add_child(UIKit.wrapped(str(ui.estimated_note)))
	var dots := UIKit.hbox(4)
	for k in opts.size():
		var d := UIKit.dot(Palette.ACCENT if k == idx else Palette.BORDER, 9)
		dots.add_child(d)
	mid.add_child(dots)
	row.add_child(left)
	row.add_child(mid)
	row.add_child(right)
	box.add_child(row)
	return UIKit.panel(box, 12)
