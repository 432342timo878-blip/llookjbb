class_name SchoolView
extends VBoxContainer
## The School page of the People tab (GDD 4.9.3 / 4.9.7, session S2): this week at school, your evenings (the habits' line,
## session L1b; it was the two life settings), the focus
## subjects, every subject with where you stand (written the Finnish way, 8 / 8+ / 8½ / 9-; tap a subject for its latest tests),
## the averages and the report cards. PC: two columns (the week, the settings and the focus on the left, the grades and the cards
## on the right); a phone, or PC beside the hub's side panel: one column. It redraws itself when a focus subject is toggled.
## Reading the SchoolSystem and changing only its settings and focus. Every control is at least 44 px; nothing needs hovering.

## Which rows are open (subject id / "card<i>" -> bool), kept while the page redraws.
static var open := {}


func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var ss := SchoolUI.system()
	if ss == null:
		return
	ss._ensure_started()   # (before the first day the subjects don't exist yet: the same levels it would make on day 1)
	var u := SchoolUI.ui()
	var stage := ss.stage_of(Game.date)
	add_child(UIKit.label(str(u.page_head), "HeadingLabel"))
	add_child(UIKit.wrapped(str(u.stage_line).format({"stage": str(stage.name), "town": ss.town()}), "MutedLabel"))
	add_child(UIKit.wrapped(str(u.page_note), "MutedLabel"))
	var left := UIKit.vbox(12)
	var right := UIKit.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_week(ss))
	left.add_child(SchoolApplyView.new())   # the joint application in grade 9, the school you go to after it (S3a)
	var in_lukio := ss.lukio_active(Game.date)
	if in_lukio:   # the lukio's period and choices (S3b)
		left.add_child(LukioUI.period_panel(ss))
		left.add_child(LukioUI.choices_panel(ss, _build))
	var habits := HabitsUI.school_line()   # (session L1b: your evenings in one line; the habits are changed in the Season tab)
	if habits != null:
		left.add_child(habits)
	if bool(stage.get("subjects", false)):
		left.add_child(_focus(ss))
		right.add_child(LukioUI.card_panel(ss) if in_lukio else _grades(ss))
	if not ss.lukio.is_empty():   # the matriculation exams (also after the lukio, for retakes) and the plan of courses
		right.add_child(LukioUI.matric_panel())
		if in_lukio:
			right.add_child(LukioUI.plan_panel(ss))
	right.add_child(_cards(ss))
	var cols := BoxContainer.new()
	cols.vertical = Layout.stacked()
	cols.add_theme_constant_override("separation", 12)
	cols.add_child(left)
	cols.add_child(right)
	add_child(cols)


# --- This week ---------------------------------------------------------------------------------------------------------

func _week(ss: SchoolSystem) -> Control:
	var u := SchoolUI.ui()
	var w := ss.week_summary(Game.week_monday())
	var box := UIKit.vbox(4)
	box.add_child(UIKit.label(str(u.week_head), "CaptionLabel"))
	if int(w.school_days) == 0:
		box.add_child(UIKit.wrapped(str(u.week_off).format({"break": SchoolUI.break_name(str(w["break"])).to_lower()}), ""))
	else:
		box.add_child(UIKit.wrapped(str(u.week_days).format({"n": int(w.school_days)}), ""))
	var tests: Array = w.tests
	if tests.is_empty():
		box.add_child(UIKit.wrapped(str(u.week_no_tests), "MutedLabel"))
	else:
		var list := []
		for t in tests:
			list.append("%s %s" % [ss.subject_name(str(t.subject)), Training.DAY_NAMES[int(t.day)]])
		box.add_child(UIKit.wrapped(str(u.week_test_one if tests.size() == 1 else u.week_tests).format({"n": tests.size(), "list": ", ".join(list)}), ""))
		if bool(w.busy):
			box.add_child(UIKit.wrapped(str(u.week_busy), ""))
	if str(w.choice) != "":
		box.add_child(UIKit.wrapped(str(u.week_chose).format({"option": str(SchoolSystem.option_of(str(w.choice)).get("label", "")).to_lower()}), "MutedLabel"))
	var y := SchoolCalendar.year_for(ss.town(), SchoolCalendar.year_of(Game.date))
	var next: Dictionary = y.christmas_card
	if Calendar.date_key(next) < Calendar.date_key(Game.date):
		next = y.end
	if bool(ss.stage_of(Game.date).get("subjects", false)) and not ss.lukio_active(Game.date):   # (a lukio: its periods instead, S3b)
		box.add_child(UIKit.wrapped(str(u.next_card).format({"date": Calendar.format_day(next)}), "MutedLabel"))
	return UIKit.panel(box, 14)


# --- Focus subjects ----------------------------------------------------------------------------------------------------

## Every subject as a 44 px toggle (a ★ on the chosen ones); at most two can be on.
func _focus(ss: SchoolSystem) -> Control:
	var u := SchoolUI.ui()
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label(str(u.focus_head), "CaptionLabel"))
	box.add_child(UIKit.wrapped(str(u.focus_text), "MutedLabel"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	var full := ss.focus.size() >= int(Data.school_life.grades.focus_max)
	for s in ss.subject_list():
		var sid := str(s.id)
		var on: bool = sid in ss.focus
		var b := Button.new()
		b.toggle_mode = true
		b.theme_type_variation = "ToggleButton"
		b.text = ("★ " if on else "") + str(s.name)
		b.custom_minimum_size = Vector2(0, 44)
		b.button_pressed = on
		b.disabled = full and not on
		b.pressed.connect(func():
			var list: Array = ss.focus.duplicate()
			if sid in list:
				list.erase(sid)
			else:
				list.append(sid)
			ss.set_focus(list)
			_build())
		flow.add_child(b)
	box.add_child(flow)
	if full:
		box.add_child(UIKit.wrapped(str(u.focus_full), "MutedLabel"))
	elif ss.focus.is_empty():
		box.add_child(UIKit.wrapped(str(u.focus_none), "MutedLabel"))
	return UIKit.panel(box, 14)


# --- Grades ---------------------------------------------------------------------------------------------------------------------

func _grades(ss: SchoolSystem) -> Control:
	var u := SchoolUI.ui()
	var box := UIKit.vbox(6)
	box.add_child(UIKit.label(str(u.grades_head), "CaptionLabel"))
	box.add_child(UIKit.wrapped(str(u.grades_text), "MutedLabel"))
	box.add_child(UIKit.label(str(u.academic_head), "CaptionLabel"))
	for s in ss.subject_list():
		if str(s.kind) == "academic":
			box.add_child(_subject_row(ss, s))
	box.add_child(UIKit.label(str(u.practical_head), "CaptionLabel"))
	for s in ss.subject_list():
		if str(s.kind) != "academic":
			box.add_child(_subject_row(ss, s))
	var all_avg := UIKit.label("%.2f" % ss.average(false))
	all_avg.add_theme_color_override("font_color", SchoolUI.grade_color(ss.average(false)))
	box.add_child(UIKit.fact_row(str(u.avg_all), all_avg))
	var ac_avg := UIKit.label("%.2f" % ss.average(true))
	ac_avg.add_theme_color_override("font_color", SchoolUI.grade_color(ss.average(true)))
	box.add_child(UIKit.fact_row(str(u.avg_academic), ac_avg))
	box.add_child(UIKit.wrapped(str(u.avg_note), "MutedLabel"))
	return UIKit.panel(box, 14)


## One subject: name, a ★ when it is a focus subject, an arrow against the last report card, where you stand. Tap = the latest tests.
func _subject_row(ss: SchoolSystem, s: Dictionary) -> Control:
	var sid := str(s.id)
	var u := SchoolUI.ui()
	var row := UIKit.hbox(8)
	row.custom_minimum_size.y = 44
	var n := UIKit.label(str(s.name) + (" ★" if sid in ss.focus else ""))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	n.clip_text = true
	row.add_child(n)
	var last := ss.last_grade(sid)
	var trend := 0
	if last > 0:
		var d := ss.standing(sid) - float(last)
		trend = 1 if d >= 0.4 else (-1 if d <= -0.4 else 0)
	row.add_child(UIKit.trend_arrow(trend))
	var v := UIKit.label(ss.standing_text(sid), "AttrValueLabel")
	v.add_theme_color_override("font_color", SchoolUI.grade_color(ss.standing(sid)))
	v.custom_minimum_size.x = 40
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	# The text under the row: what the card would give, the last card, the latest tests.
	var lines := [str(u.card_would).format({"grade": ss.card_grade(sid)})]
	if last > 0:
		lines.append(str(u.last_card).format({"grade": last}))
	var tests := ss.tests_of(sid)
	if tests.is_empty():
		lines.append(str(u.no_tests) if str(s.kind) == "academic" else "")
	else:
		lines.append(str(u.tests_recent))
		for t in tests:
			lines.append("%s  %s" % [DayInfo.short_day(t.date), SchoolSystem.score_text(float(t.score))])
		var avg := ss.term_average(sid)
		if avg >= 0.0:
			lines.append(str(u.term_avg).format({"avg": "%.2f" % avg}))
	var text := "\n".join(lines.filter(func(x): return str(x) != ""))
	return _tap_row(sid, row, text)


## UIKit.tap_to_explain that remembers whether it is open while the page redraws.
func _tap_row(key: String, row: Control, text: String) -> Control:
	var box := UIKit.vbox(2)
	box.add_child(row)
	var body := UIKit.wrapped(text, "MutedLabel")
	body.visible = bool(open.get(key, false))
	box.add_child(body)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var press := {"at": Vector2.ZERO}
	row.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press.at = event.position
			elif event.position.distance_to(press.at) < 10.0:   # a tap, not a scroll drag
				body.visible = not body.visible
				open[key] = body.visible)
	return box


# --- Report cards ---------------------------------------------------------------------------------------------------------------

func _cards(ss: SchoolSystem) -> Control:
	var u := SchoolUI.ui()
	var box := UIKit.vbox(8)
	box.add_child(UIKit.label(str(u.cards_head), "CaptionLabel"))
	var cards := ss.report_cards()
	if cards.is_empty():
		var y := SchoolCalendar.year_for(ss.town(), SchoolCalendar.year_of(Game.date))
		box.add_child(UIKit.wrapped(str(u.cards_none).format({"date": Calendar.format_day(y.christmas_card)}), ""))
	for i in range(cards.size() - 1, -1, -1):
		box.add_child(_card_row(ss, cards, i))
	return UIKit.panel(box, 14)


func _card_row(ss: SchoolSystem, cards: Array, i: int) -> Control:
	var u := SchoolUI.ui()
	var r: Dictionary = cards[i]
	var head := UIKit.hbox(8)
	var card_name := str(r.get("label", Data.school_life.report_cards.names.get(str(r.kind), str(r.kind))))
	var name_label := UIKit.wrapped(str(u.card_line).format({"name": card_name, "date": Calendar.format_day(r.date)}), "SubheadingLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var detail := UIKit.vbox(2)
	detail.add_child(UIKit.wrapped(str(u.card_avg).format({"avg": "%.2f" % float(r.average), "acad": "%.2f" % float(r.academic_average)}), ""))
	var lines := []
	for sid in r.grades:   # (the card's own subjects: a grade 9 card and a lukio card list different ones)
		lines.append("%s %d" % [ss.any_subject_name(str(sid)), int(r.grades[sid])])
	detail.add_child(UIKit.wrapped(" · ".join(lines), "MutedLabel"))
	var key := "card%d" % i
	return HealthUI.expandable(head, null, detail, SchoolUI.grade_color(float(r.average)), bool(open.get(key, false)),
			func(is_open): open[key] = is_open)
